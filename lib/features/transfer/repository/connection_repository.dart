import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:fileflow/core/exceptions/app_exceptions.dart';
import 'package:fileflow/core/services/background_transfer_service.dart';
import 'package:fileflow/core/services/certificate_service.dart';
import 'package:fileflow/core/utils/packet_reader.dart';
import 'package:fileflow/features/transfer/model/transfer_event.dart';
import 'package:fileflow/features/transfer/model/transfer_state.dart';
import 'package:fileflow/features/transfer/repository/transfer_state_repository.dart';
import 'package:fileflow/features/settings/repository/settings_repository.dart';
import 'package:fileflow/core/services/pin_auth_service.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

class ConnectionRepository {
  SecureServerSocket? _serverSocket;
  SecureSocket? _socket;

  final _eventController = StreamController<TransferEvent>.broadcast();
  Stream<TransferEvent> get eventStream => _eventController.stream;

  final _progressController = StreamController<double>.broadcast();
  Stream<double> get progressStream => _progressController.stream;

  final _speedController = StreamController<double>.broadcast();
  Stream<double> get speedStream => _speedController.stream;

  final _packetReader = PacketReader();

  final _transferStateRepo = TransferStateRepository();
  final _backgroundService = BackgroundTransferService();
  final SettingsRepository _settingsRepo;
  final PinAuthService _pinAuthService = PinAuthService();
  
  bool _isInitialized = false;
  String? _sessionPin;
  bool _isPinRequired = false;

  ConnectionRepository(this._settingsRepo);

  String? get sessionPin => _sessionPin;
  bool get isPinRequired => _isPinRequired;

  Future<void> startConnectionForegroundService(String deviceName) async {
    await _backgroundService.startConnectionService(deviceName);
  }

  Future<void> stopForegroundService() async {
    await _backgroundService.stopForegroundService();
  }

  static const int kPacketTypeJson = 0;
  static const int kPacketTypeBinary = 1;

  File? _receivingFile;
  IOSink? _fileSink;
  int _receivedBytes = 0;
  int _totalBytes = 0;
  bool _isTransferCancelled = false;
  bool _isTransferPaused = false;
  int _pausedAtBytes = 0;
  bool _isSendingFile = false;

  int _expectedFileCount = 1;
  int _processedFileCount = 0;

  int _lastReceivedBytes = 0;
  DateTime? _lastSpeedUpdate;
  Timer? _speedUpdateTimer;

  Future<void> _ensureInitialized() async {
    if (!_isInitialized) {
      await _transferStateRepo.init();
      _isInitialized = true;
    }
  }

  Future<void> startServer(int port, String myDeviceName) async {
    try {
      await _ensureInitialized();
      await close();
      
      _isPinRequired = _settingsRepo.requiredPin();
      if (_isPinRequired) {
        _sessionPin = _pinAuthService.generatePin();
        debugPrint("🔐 Server requires PIN: $_sessionPin");
      } else {
        _sessionPin = null;
      }
      
      debugPrint("🔐 Generating X.509 TLS certificate...");
      final securityContext =
          await CertificateService.generateSecurityContext();
      debugPrint("✅ Certificate generated successfully");

      _serverSocket = await SecureServerSocket.bind(
        InternetAddress.anyIPv4,
        port,
        securityContext,
        requestClientCertificate: false,
      );
      debugPrint("🔒 TLS Server Started on port $port (Encrypted)");

      _serverSocket!.listen((socket) {
        debugPrint(
          "🤝 TLS handshake completed with ${socket.remoteAddress.address}",
        );
        socket.setOption(SocketOption.tcpNoDelay, true);
        _handleNewSocket(socket);
      });
    } catch (e, stackTrace) {
      debugPrint('❌ TLS Server Error: $e');
      throw ServerStartupFailed(
        'Failed to start TLS server on port $port: $e',
        e,
        stackTrace,
      );
    }
  }

  Future<void> connect(
    String ip,
    int port,
    String myDeviceName, {
    String? pin,
  }) async {
    try {
      await _ensureInitialized();
      await close();
      debugPrint("🔐 Generating X.509 TLS certificate for connection...");
      final securityContext =
          await CertificateService.generateSecurityContext();
      debugPrint("✅ Certificate generated, connecting to $ip:$port...");

      final socket = await SecureSocket.connect(
        ip,
        port,
        onBadCertificate: (certificate) {
          debugPrint("📜 Accepting self-signed certificate from server");
          return true;
        },
        context: securityContext,
        timeout: const Duration(seconds: 5),
      );

      debugPrint("🔒 TLS connection established with $ip (Encrypted)");
      socket.setOption(SocketOption.tcpNoDelay, true);
      _handleNewSocket(socket);
      _sendControlMessage(TransferEventType.connectionRequest, {
        "deviceName": myDeviceName,
        "pin": pin,
      });
    } catch (e, stackTrace) {
      debugPrint("❌ TLS Connection Error: $e");
      debugPrintStack(stackTrace: stackTrace);
      throw ConnectionFailed('Failed to establish TLS connection to $ip:$port');
    }
  }

  void _handleNewSocket(SecureSocket socket) {
    _socket = socket;
    _packetReader.clear();
    debugPrint(
      '🔌 New socket connection established from ${socket.remoteAddress.address}:${socket.remotePort}',
    );

    _socket!.listen(
      (data) {
        try {
          _packetReader.addBytes(data);

          while (true) {
            final packet = _packetReader.tryReadPacket();
            if (packet == null) break;

            if (packet.type == kPacketTypeJson) {
              // JSON String
              final jsonString = utf8.decode(packet.payload);
              try {
                final jsonMap = json.decode(jsonString);
                final event = TransferEvent.fromMap(jsonMap);
                debugPrint('🔌 Event received from socket: ${event.type}');
                _eventController.add(event);
                debugPrint('✅ Event added to stream: ${event.type}');
                _handleIncomingEvent(event);
              } catch (e) {
                debugPrint("JSON Decode Error: $e");
              }
            } else if (packet.type == kPacketTypeBinary) {
              // Binary File Chunk
              _handleBinaryChunk(packet.payload);
            }
          }
        } catch (e) {
          debugPrint('Error processing socket data: $e');
        }
      },
      onDone: () {
        // Peer initiated disconnection - just close the socket, not the whole connection
        debugPrint('🔌 Socket closed by peer');
        _socket = null;
        _eventController.add(
          TransferEvent(
            type: TransferEventType.peerDisconnected,
            data: {'reason': 'Peer closed connection'},
          ),
        );
      },
      onError: (e) {
        debugPrint('Error on socket: $e');
        _socket = null;
      },
    );
  }

  Future<void> _handleIncomingEvent(TransferEvent event) async {
    switch (event.type) {
      case TransferEventType.fileMetadata:
        final fileName = event.data['fileName'];
        final totalSize = event.data['fileSize'];
        final transferID = event.data['transferID'] ?? "${fileName}_$totalSize";
        _totalBytes = totalSize;
        _receivedBytes = 0;

        _lastReceivedBytes = 0;
        _lastSpeedUpdate = DateTime.now();
        _startSpeedTracking();

        try {
          Directory? fileFlowDir;
          if (Platform.isAndroid) {
            fileFlowDir = Directory('/storage/emulated/0/FileFlow/');
          } else {
            final appDir = await getApplicationDocumentsDirectory();
            fileFlowDir = Directory('${appDir.path}/FileFlow/');
          }

          if (!fileFlowDir.existsSync()) {
            fileFlowDir.createSync(recursive: true);
          }

          final path = "${fileFlowDir.path}/$fileName";
          _receivingFile = File(path);

          _fileSink = _receivingFile!.openWrite(mode: FileMode.write);

          final state = TransferState(
            id: transferID,
            fileName: fileName,
            filePath: path,
            totalBytes: _totalBytes,
            transferredBytes: _receivedBytes,
            peerAddress: _socket?.remoteAddress.address ?? 'Unknown',
            lastUpdate: DateTime.now(),
            isSending: false,
          );
          await _transferStateRepo.saveState(state);
          await _backgroundService.startForegroundService(fileName);

          debugPrint('Receiving file to ${_receivingFile!.absolute.path}');
        } catch (e, stackTrace) {
          debugPrint('❌ Error setting up file write: $e');
          throw FileWriteError(
            'Failed to set up file write for $fileName: $e',
            filePath: _receivingFile?.path,
            original: e,
            stack: stackTrace,
          );
        }
        break;

      case TransferEventType.transferComplete:
        _stopSpeedTracking();
        await _fileSink?.flush();
        await _fileSink?.close();
        _fileSink = null;

        if (_receivingFile != null) {
          event.data['path'] = _receivingFile!.path;
        }

        final transferID = event.data['transferID'] ?? 'Unknown';
        final state = _transferStateRepo.getState(transferID);
        if (state != null) {
          await _transferStateRepo.saveState(
            state.copyWith(
              transferredBytes: state.totalBytes,
              isComplete: true,
            ),
          );
        }

        _processedFileCount++;
        // On receiver side, only stop service if all files processed
        // But NOTE: if it is a single file transfer, _expectedFileCount is 1.
        if (_processedFileCount >= _expectedFileCount) {
          await _backgroundService.stopForegroundService();
        }

        debugPrint(
          'Transfer Complete: ${_receivingFile?.path} (Batch: $_processedFileCount/$_expectedFileCount)',
        );
        break;

      case TransferEventType.transferCancelled:
        debugPrint('⛔ Transfer Cancelled by peer');
        _isTransferCancelled = true;
        _stopSpeedTracking();
        try {
          await _fileSink?.close();
        } catch (e) {
          debugPrint('⚠️ Error closing file sink: $e');
        }
        _fileSink = null;
        
        try {
          if (_receivingFile != null && _receivingFile!.existsSync()) {
            // Deletes incomplete transfer file
            _receivingFile!.deleteSync();
          }
        } catch (e) {
          debugPrint('⚠️ Error deleting incomplete file: $e');
        }
        await _backgroundService.stopForegroundService();
        break;

      case TransferEventType.transferPaused:
        debugPrint(
          '⏸️ Transfer paused by peer at ${event.data['pausedAtBytes']} bytes',
        );
        _isTransferPaused = true;
        _pausedAtBytes = event.data['pausedAtBytes'] ?? 0;
        _stopSpeedTracking();
        break;

      case TransferEventType.transferResumed:
        debugPrint(
          '▶️ Transfer resumed by peer from ${event.data['resumedFromBytes']} bytes',
        );
        _isTransferPaused = false;
        _startSpeedTracking();
        break;

      case TransferEventType.connectionRequest:
        debugPrint(
          '📞 Connection request received from ${event.data['deviceName']}',
        );
        event.data['timestamp'] = DateTime.now().toIso8601String();
        
        if (_isPinRequired) {
             final peerPin = event.data['pin'];
             if (peerPin == null || !_pinAuthService.verifyPin(peerPin)) {
                debugPrint("❌ PIN Verification Failed: Expected $_sessionPin, got $peerPin");
                await rejectConnection(reason: "Invalid PIN");
                // Don't propagate the event if rejected
                return;
             }
             debugPrint("✅ PIN Verified for connection request");
        }
        break;

      case TransferEventType.connectionAccepted:
        debugPrint('✅ Connection accepted by ${event.data['deviceName']}');
        event.data['timestamp'] = DateTime.now().toIso8601String();
        break;

      case TransferEventType.connectionRejected:
        debugPrint(
          '❌ Connection rejected by ${event.data['deviceName']}: ${event.data['reason'] ?? 'No reason'}',
        );
        event.data['timestamp'] = DateTime.now().toIso8601String();
        break;

      case TransferEventType.transferRequested:
        debugPrint(
          '📥 Transfer requested: ${event.data['fileName']} (${event.data['fileSize']} bytes)',
        );
        event.data['timestamp'] = DateTime.now().toIso8601String();
        event.data['receivedAt'] = DateTime.now().toIso8601String();

        // Initialize batch tracking
        _expectedFileCount = event.data['fileCount'] ?? 1;
        _processedFileCount = 0;
        break;

      case TransferEventType.transferAccepted:
        debugPrint('✅ Transfer accepted for ${event.data['fileName']}');
        event.data['timestamp'] = DateTime.now().toIso8601String();
        break;

      case TransferEventType.transferRejected:
        debugPrint(
          '❌ Transfer rejected: ${event.data['reason'] ?? 'No reason'}',
        );
        event.data['timestamp'] = DateTime.now().toIso8601String();
        break;

      case TransferEventType.clipboardText:
        debugPrint(
          '📋 Clipboard text received: ${event.data['text']?.substring(0, 50) ?? 'empty'}...',
        );
        event.data['timestamp'] = DateTime.now().toIso8601String();
        break;

      case TransferEventType.error:
        debugPrint(
          '⚠️ Error event received: ${event.data['message'] ?? 'Unknown error'}',
        );
        event.data['timestamp'] = DateTime.now().toIso8601String();
        break;

      default:
        debugPrint('⚠️ Unknown event type: ${event.type}');
        break;
    }
  }

  void _handleBinaryChunk(Uint8List bytes) {
    if (_fileSink != null) {
      _fileSink!.add(bytes);
      _receivedBytes += bytes.length;

      if (_totalBytes > 0) {
        final progress = _receivedBytes / _totalBytes;
        _progressController.add(progress);

        // Update background service every 1%
        if ((progress * 100).toInt() % 1 == 0) {
          _backgroundService.updateProgress(
            _receivingFile?.uri.pathSegments.last ?? "File",
            (progress * 100).toInt(),
          );
        }
      }
    }
  }

  void _startSpeedTracking() {
    _speedUpdateTimer?.cancel();
    _speedUpdateTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _updateTransferSpeed();
    });
  }

  void _stopSpeedTracking() {
    _speedUpdateTimer?.cancel();
    _speedUpdateTimer = null;
  }

  void _updateTransferSpeed() {
    if (_socket == null) {
      _stopSpeedTracking();
      return;
    }
    final now = DateTime.now();
    if (_lastSpeedUpdate == null) return;

    final timeDiff = now.difference(_lastSpeedUpdate!).inMilliseconds / 1000.0;
    if (timeDiff <= 0) return;

    final bytesDiff = _receivedBytes - _lastReceivedBytes;
    final speed = bytesDiff / timeDiff; // bytes per second

    _lastReceivedBytes = _receivedBytes;
    _lastSpeedUpdate = now;

    // Emit speed update event
    _speedController.add(speed);
  }

  Future<void> _sendPacket(
    int type,
    List<int> payload, {
    bool flush = false,
  }) async {
    if (_socket == null) return;

    try {
      // Header
      final header = Uint8List(5); // 4 length + 1 type
      final bd = ByteData.sublistView(header);
      bd.setUint32(0, payload.length, Endian.big);
      header[4] = type;

      _socket!.add(header);
      _socket!.add(payload);
      if (flush) await _socket!.flush();
    } catch (e) {
      debugPrint(
        "⚠️ Warning: Failed to send packet - Socket likely closed: $e",
      );
      _isTransferCancelled = true; // Implicit cancel
    }
  }

  Future<void> _sendControlMessage(
    TransferEventType type,
    Map<String, dynamic> data,
  ) async {
    final event = TransferEvent(type: type, data: data);
    final jsonString = event.toRawJson();
    final bytes = utf8.encode(jsonString);
    await _sendPacket(kPacketTypeJson, bytes);
  }

  Future<void> acceptConnection(String myDeviceName) async {
    await _sendControlMessage(TransferEventType.connectionAccepted, {
      "deviceName": myDeviceName,
    });
  }

  Future<void> rejectConnection({String? reason}) async {
    await _sendControlMessage(TransferEventType.connectionRejected, {
      "reason": reason ?? "Connection Refused",
    });
    close();
  }

  Future<void> requestTransfer(String fileName, int fileSize) async {
    await _sendControlMessage(TransferEventType.transferRequested, {
      "fileName": fileName,
      "fileSize": fileSize,
      "fileCount": 1,
    });
  }

  Future<void> requestTransferBatch(List<File> files) async {
    int totalSize = 0;
    try {
      totalSize = files.fold(0, (sum, f) => sum + f.lengthSync());
    } catch (e) {
      debugPrint("Error calculating total size: $e");
    }

    final fileList = files
        .map(
          (f) => {
            'fileName': f.uri.pathSegments.last,
            'fileSize': f.lengthSync(),
          },
        )
        .toList();

    await _sendControlMessage(TransferEventType.transferRequested, {
      "fileName": "Batch of ${files.length} files",
      "fileSize": totalSize,
      "fileCount": files.length,
      "isBatch": true,
      "files": fileList,
    });
  }

  Future<void> sendTransferResponse(bool accepted) async {
    await _sendControlMessage(
      accepted
          ? TransferEventType.transferAccepted
          : TransferEventType.transferRejected,
      {},
    );
  }

  Future<void> sendClipboardText(String text) async {
    await _sendControlMessage(TransferEventType.clipboardText, {"text": text});
  }

  Future<void> sendFile(File file, {int offset = 0}) async {
    try {
      final fileName = file.uri.pathSegments.last;

      if (!await file.exists()) {
        throw FileNotFound(
          'File not found during transfer: $fileName',
          filePath: file.path,
        );
      }

      final fileLen = await file.length();
      final transferID = "${fileName}_$fileLen";

      // 1. Send Metadata [JSON]
      await _sendControlMessage(TransferEventType.fileMetadata, {
        "fileName": fileName,
        "fileSize": fileLen,
        "transferID": transferID,
        "offset": offset, // Include offset for resume capability
      });

      // 2. Read and Send chunks [Binary]
      final stream = file.openRead(offset);
      int bytesSent = offset;

      _receivedBytes = offset;
      _lastReceivedBytes = offset;
      _lastSpeedUpdate = DateTime.now();
      _isTransferCancelled = false;
      _isTransferPaused = false;
      _isSendingFile = true;
      _startSpeedTracking();

      await _backgroundService.startForegroundService(fileName);

      bool sentPauseMsg = false;

      await for (final chunk in stream) {
        // Check for cancel or pause
        if (_isTransferPaused) {
          if (!sentPauseMsg && !_isTransferCancelled) {
            debugPrint('⏸️ Pausing inside send loop at $_receivedBytes bytes');
            await _sendControlMessage(TransferEventType.transferPaused, {
              "pausedAtBytes": _receivedBytes,
              "totalBytes": _totalBytes,
            });
            sentPauseMsg = true;
            _stopSpeedTracking();
          }

          while (_isTransferPaused && !_isTransferCancelled) {
            await Future.delayed(const Duration(milliseconds: 200));
          }

          if (!_isTransferPaused && !_isTransferCancelled && sentPauseMsg) {
            debugPrint(
              '▶️ Resuming inside send loop from $_receivedBytes bytes',
            );
            await _sendControlMessage(TransferEventType.transferResumed, {
              "resumedFromBytes": _receivedBytes,
              "totalBytes": _totalBytes,
            });
            sentPauseMsg = false;
            _startSpeedTracking();
          }
        }

        if (_socket == null || _isTransferCancelled) break;

        // Flush every 1MB to keep speed high while ensuring data is sent
        bool shouldFlush = (bytesSent % (1024 * 1024)) == 0;
        await _sendPacket(kPacketTypeBinary, chunk, flush: shouldFlush);

        bytesSent += chunk.length;
        _receivedBytes = bytesSent; // Update for speed tracker
        if (fileLen > 0) {
          final progress = bytesSent / fileLen;
          _progressController.add(progress);
          if ((progress * 100).toInt() % 1 == 0) {
            _backgroundService.updateProgress(
              fileName,
              (progress * 100).toInt(),
            );
          }
        }
      }
      _isSendingFile = false;

      if (_isTransferCancelled) {
        try {
          await _sendControlMessage(TransferEventType.transferCancelled, {});
        } catch (e) {
          debugPrint("⚠️ Failed to send cancel message: $e");
        }
        await _backgroundService.stopForegroundService();
        return;
      }

      // 3. Complete [JSON]
      await _sendControlMessage(TransferEventType.transferComplete, {
        "fileName": fileName,
        "transferID": transferID,
      });
      _stopSpeedTracking();
      await _backgroundService.stopForegroundService();
    } catch (e, stackTrace) {
      _isSendingFile = false;
      debugPrint('❌ Error during file transfer: $e');
      _stopSpeedTracking();
      await _backgroundService.stopForegroundService();

      if (e is AppExceptions) {
        rethrow;
      }

      throw FileReadError(
        'Failed to read and send file: $e',
        filePath: file.path,
        original: e,
        stack: stackTrace,
      );
    }
  }

  Future<void> cancelTransfer() async {
    _isTransferCancelled = true;
    _stopSpeedTracking();
    try {
      await _sendControlMessage(TransferEventType.transferCancelled, {});
    } catch (e) {
      debugPrint("⚠️ Failed to send cancel message: $e");
    }
  }

  Future<void> pauseTransfer() async {
    if (_isTransferPaused) return; // Already paused

    _isTransferPaused = true;
    _pausedAtBytes = _receivedBytes;
    _stopSpeedTracking();

    debugPrint(
      '⏸️ Transfer paused at $_pausedAtBytes bytes (Sending: $_isSendingFile)',
    );

    if (!_isSendingFile) {
      await _sendControlMessage(TransferEventType.transferPaused, {
        "pausedAtBytes": _pausedAtBytes,
        "totalBytes": _totalBytes,
      });
    }
  }

  Future<void> resumeTransfer() async {
    if (!_isTransferPaused) return; // Not paused

    _isTransferPaused = false;
    _startSpeedTracking();

    debugPrint(
      '▶️ Transfer resumed from $_pausedAtBytes bytes (Sending: $_isSendingFile)',
    );

    if (!_isSendingFile) {
      await _sendControlMessage(TransferEventType.transferResumed, {
        "resumedFromBytes": _pausedAtBytes,
        "totalBytes": _totalBytes,
      });
    }
  }

  Future<void> close({bool isManualDisconnect = false}) async {
    _socket?.destroy();
    _socket = null;
    await _serverSocket?.close();
    _serverSocket = null;

    // Emit appropriate disconnection event
    if (isManualDisconnect) {
      _eventController.add(
        TransferEvent(
          type: TransferEventType.manualDisconnection,
          data: {'reason': 'User initiated disconnection'},
        ),
      );
    }
    await stopForegroundService();
  }
}
