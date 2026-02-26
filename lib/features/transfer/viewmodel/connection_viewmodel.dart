import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:fileflow/core/constants/app_constants.dart';
import 'package:fileflow/core/exceptions/app_exceptions.dart';
import 'package:fileflow/core/services/notification_service.dart';
import 'package:fileflow/features/history/model/history_item.dart';
import 'package:fileflow/features/history/viewmodel/history_viewmodel.dart';
import 'package:fileflow/features/transfer/model/transfer_event.dart';
import 'package:fileflow/features/transfer/repository/connection_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fileflow/features/transfer/model/transfer_item.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum ConnectionStatus {
  disconnected,
  listening,
  connecting,
  awaitingConfirmation,
  connected,
  transferRequestReceived,
  awaitingTransferAcceptance,
  transferring,
  transferPaused,
  transferCompleted,
  error,
}

class ConnectionState {
  final ConnectionStatus status;
  final String? errorMessage;
  final String? connectedTo;
  final String? notificationMessage;

  final String? incomingFileName;
  final int? incomingFileSize;
  final double transferProgress;
  final bool isBatch;
  final bool isIncoming;

  final double transferSpeed; // bytes/second
  final int transferredBytes;
  final DateTime? transferStartTime;

  // Batch Progress Tracking
  final int totalBatchSize;
  final int totalBatchBytesTransferred;
  final int currentFileIndex;
  final int totalFilesCount;

  final String? sessionPin;
  final bool isPinRequired;
  final String? lastSavedPath;
  final List<TransferItem> transferQueue;

  ConnectionState({
    required this.status,
    this.errorMessage,
    this.connectedTo,
    this.notificationMessage,
    this.incomingFileName,
    this.incomingFileSize,
    this.transferProgress = 0.0,
    this.isBatch = false,
    this.isIncoming = false,
    this.transferSpeed = 0.0,
    this.transferredBytes = 0,
    this.transferStartTime,
    this.totalBatchSize = 0,
    this.totalBatchBytesTransferred = 0,
    this.currentFileIndex = 0,
    this.totalFilesCount = 0,
    this.sessionPin,
    this.isPinRequired = false,
    this.lastSavedPath,
    this.transferQueue = const [],
  });

  ConnectionState copyWith({
    ConnectionStatus? status,
    String? errorMessage,
    String? connectedTo,
    String? notificationMessage,
    String? incomingFileName,
    int? incomingFileSize,
    double? transferProgress,
    bool? isBatch,
    bool? isIncoming,
    double? transferSpeed,
    int? transferredBytes,
    DateTime? transferStartTime,
    int? totalBatchSize,
    int? totalBatchBytesTransferred,
    int? currentFileIndex,
    int? totalFilesCount,
    String? sessionPin,
    bool? isPinRequired,
    String? lastSavedPath,
    List<TransferItem>? transferQueue,
  }) {
    return ConnectionState(
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
      connectedTo: connectedTo ?? this.connectedTo,
      notificationMessage: notificationMessage ?? this.notificationMessage,
      incomingFileName: incomingFileName ?? this.incomingFileName,
      incomingFileSize: incomingFileSize ?? this.incomingFileSize,
      transferProgress: transferProgress ?? this.transferProgress,
      isBatch: isBatch ?? this.isBatch,
      isIncoming: isIncoming ?? this.isIncoming,
      transferSpeed: transferSpeed ?? this.transferSpeed,
      transferredBytes: transferredBytes ?? this.transferredBytes,
      transferStartTime: transferStartTime ?? this.transferStartTime,
      totalBatchSize: totalBatchSize ?? this.totalBatchSize,
      totalBatchBytesTransferred: totalBatchBytesTransferred ?? this.totalBatchBytesTransferred,
      currentFileIndex: currentFileIndex ?? this.currentFileIndex,
      totalFilesCount: totalFilesCount ?? this.totalFilesCount,
      sessionPin: sessionPin ?? this.sessionPin,
      isPinRequired: isPinRequired ?? this.isPinRequired,
      lastSavedPath: lastSavedPath ?? this.lastSavedPath,
      transferQueue: transferQueue ?? this.transferQueue,
    );
  }

  factory ConnectionState.initial() =>
      ConnectionState(status: ConnectionStatus.disconnected);

  int? get estimatedTimeRemaining {
    if (transferSpeed <= 0 || incomingFileSize == null) return null;

    final remaining = incomingFileSize! - transferredBytes;
    if (remaining <= 0) return 0;
    return (remaining / transferSpeed).ceil();
  }
}

class ConnectionViewModel extends StateNotifier<ConnectionState> {
  final ConnectionRepository _repo;
  final String _myDeviceName;
  final HistoryViewModel _historyViewModel;
  final NotificationService _notificationService = NotificationService();
  List<File> _pendingFiles = [];
  final List<HistoryFileDetail> _batchHistoryDetails = [];
  String? _currentTransferingDevice;

  ConnectionViewModel(this._repo, this._myDeviceName, this._historyViewModel)
    : super(ConnectionState.initial()) {
    debugPrint('🔍 ConnectionViewModel initialized - setting up event listener');
    // Listen to repository events
    _repo.eventStream.listen((event) async {
      debugPrint('📨 ConnectionViewModel received event: ${event.type}');
      switch (event.type) {
        case TransferEventType.connectionRequest:
          debugPrint('🔗 Connection request received from ${event.data['deviceName']}');
          final deviceName = event.data['deviceName'];
          debugPrint('✅ Updating state to awaitingConfirmation for $deviceName');
          state = state.copyWith(
            status: ConnectionStatus.awaitingConfirmation,
            connectedTo: deviceName ?? 'Unknown Device',
          );
          break;

        case TransferEventType.connectionAccepted:
          // Peer accepted the request, update name if available
          _currentTransferingDevice = event.data['deviceName'];
          await _notificationService.showConnectionEstablished(
            _currentTransferingDevice ?? 'Unknown Device',
          );
          await _repo.startConnectionForegroundService(event.data['deviceName'] ?? 'Unknown Device');

          state = state.copyWith(
            status: ConnectionStatus.connected,
            connectedTo:
                event.data['deviceName'] ??
                state.connectedTo ??
                'Unknown Device',
          );
          break;

        case TransferEventType.connectionRejected:
          final reason = event.data['reason'] ?? 'Rejected by User';
          await _notificationService.showConnectionRejected(
            state.connectedTo ?? 'Unknown Device',
            reason: reason,
          );
          state = state.copyWith(
            status: ConnectionStatus.error,
            errorMessage: 'Connection Rejected: $reason',
          );
          _repo.close();
          break;

        case TransferEventType.transferRequested:
          debugPrint(
            "📥 Incoming transfer request: ${event.data['fileName']} (${event.data['fileSize']} bytes)",
          );
          await _notificationService.showTransferRequest(
            state.connectedTo ?? 'Unknown Device',
            event.data['fileName'] ?? 'File',
            event.data['fileSize'] ?? 0,
          );
          state = state.copyWith(
            status: ConnectionStatus.transferRequestReceived,
            incomingFileName: event.data['fileName'],
            incomingFileSize: event.data['fileSize'], // This is total size if batch
            transferProgress: 0.0,
            isBatch: event.data['isBatch'] ?? false,
            isIncoming: true,
            totalFilesCount: event.data['fileCount'] ?? 1,
            totalBatchSize: (event.data['isBatch'] ?? false) ? (event.data['fileSize'] ?? 0) : 0,
            currentFileIndex: 0,
            totalBatchBytesTransferred: 0,
            transferQueue: (event.data['files'] as List?)?.map((f) => TransferItem(
              id: f['fileName'],
              fileName: f['fileName'],
              fileSize: f['fileSize'],
              status: TransferItemStatus.pending,
            )).toList() ?? [
               TransferItem(
                 id: event.data['fileName'] ?? 'unknown',
                 fileName: event.data['fileName'] ?? 'File',
                 fileSize: event.data['fileSize'] ?? 0,
                 status: TransferItemStatus.pending,
               )
            ],
          );
          break;

        case TransferEventType.fileMetadata:
          debugPrint('📥 Receiving file metadata: ${event.data['fileName']}');
          state = state.copyWith(
            incomingFileName: event.data['fileName'],
            incomingFileSize: event.data['fileSize'],
            transferProgress: 0.0,
            currentFileIndex: state.currentFileIndex + 1,
          );
          await _notificationService.showTransferStarted(
             event.data['fileName'],
             isSending: false
          );
          
          // Update status of current file in queue
          List<TransferItem> queueWithActive = List.from(state.transferQueue);
          final idxMetadata = queueWithActive.indexWhere((i) => i.fileName == event.data['fileName']);
          if (idxMetadata != -1) {
             queueWithActive[idxMetadata] = queueWithActive[idxMetadata].copyWith(
                status: TransferItemStatus.transferring,
             );
          }
          state = state.copyWith(transferQueue: queueWithActive);
          break;

        case TransferEventType.transferAccepted:
          if (_pendingFiles.isNotEmpty) {
            await _notificationService.showTransferStarted(
              _pendingFiles.first.uri.pathSegments.last,
              isSending: true,
            );
            state = state.copyWith(
              status: ConnectionStatus.transferring,
              transferProgress: 0.0,
            );
            // Start processing queue
            _processTransferQueue();
          }
          break;

        case TransferEventType.transferRejected:
          await _notificationService.showTransferCancelled(
            state.incomingFileName ?? 'File',
            reason: 'Rejected by peer',
          );
          state = state.copyWith(
            status: ConnectionStatus.error,
            errorMessage: "Transfer Rejected",
            isBatch: false,
          );
          _pendingFiles.clear();
          break;

        case TransferEventType.transferComplete:
          final savedPath = event.data['path'] as String?;
          final isBatchComplete = !state.isBatch || (state.currentFileIndex >= state.totalFilesCount);

          if (isBatchComplete) {
            await _notificationService.showTransferCompleted(
              state.incomingFileName ?? 'File',
              state.incomingFileSize ?? 0,
              isSending: false,
            );
            
             if (state.connectedTo != null) {
                _repo.startConnectionForegroundService(state.connectedTo!);
             }
          }
          
          state = state.copyWith(
            status: isBatchComplete ? ConnectionStatus.transferCompleted : state.status,
            transferProgress: 1.0,
            transferredBytes: state.incomingFileSize ?? 0,
            lastSavedPath: savedPath,
            totalBatchBytesTransferred: state.totalBatchBytesTransferred + (state.incomingFileSize ?? 0),
          );

          if (!isBatchComplete && state.incomingFileName != null) {
              // Forced notification update for individual file in batch
              _notificationService.updateTransferProgress(
                 state.incomingFileName!,
                 100,
                 0,
                 isSending: false
              );
          }

          // Add to History [Receiver]
          if (state.incomingFileName != null) {
              _historyViewModel.addItem(
              HistoryItem(
                id: DateTime.now().millisecondsSinceEpoch.toString(),
                fileName: state.incomingFileName!,
                filePath: state.lastSavedPath ?? 'Unknown Path',
                fileSize: state.incomingFileSize ?? 0,
                deviceName: state.connectedTo ?? 'Unknown',
                timestamp: DateTime.now(),
                type: HistoryType.received,
              ),
            );
          }
          
          // Update status of completed file in queue
          List<TransferItem> queueWithCompleted = List.from(state.transferQueue);
          final idxCompleted = queueWithCompleted.indexWhere((i) => i.fileName == state.incomingFileName);
          if (idxCompleted != -1) {
             queueWithCompleted[idxCompleted] = queueWithCompleted[idxCompleted].copyWith(
                status: TransferItemStatus.completed,
                progress: 1.0,
             );
          }
          state = state.copyWith(transferQueue: queueWithCompleted);
          break;

        case TransferEventType.clipboardText:
          final text = event.data['text'];
          if (text != null) {
            Clipboard.setData(ClipboardData(text: text)).then((_) {
              state = state.copyWith(
                notificationMessage: 'Clipboard copied from sender!',
              );
              Future.delayed(const Duration(seconds: 3), () {
                // Clear notification
                state = state.copyWith(notificationMessage: null);
              });
            });
          }
          break;

        case TransferEventType.transferCancelled:
          await _notificationService.showTransferCancelled(
            state.incomingFileName ?? 'File',
            reason: 'Cancelled by peer',
          );
          state = state.copyWith(
            status: ConnectionStatus.connected,
            errorMessage: null, // Clear error
            incomingFileName: null, 
            incomingFileSize: null,
            transferProgress: 0.0,
            notificationMessage: 'Transfer cancelled by peer',
          );
          _pendingFiles.clear();
          break;

        case TransferEventType.transferPaused:
          debugPrint('⏸️ Transfer paused');
          await _notificationService.showTransferPaused(
            state.incomingFileName ?? 'File',
          );
          state = state.copyWith(
            status: ConnectionStatus.transferPaused,
            notificationMessage: 'Transfer paused',
          );
          break;

        case TransferEventType.transferResumed:
          debugPrint('▶️ Transfer resumed');
          await _notificationService.showTransferResumed(
            state.incomingFileName ?? 'File',
          );
          state = state.copyWith(
            status: ConnectionStatus.transferring,
            notificationMessage: 'Transfer resumed',
          );
          break;


        case TransferEventType.peerDisconnected:
          final reason = event.data['reason'] ?? 'Peer disconnected';
          debugPrint('❌ Peer disconnected: $reason');
          
          // Peer disconnected - treat as unexpected disconnection
          if (state.status == ConnectionStatus.transferring ||
              state.status == ConnectionStatus.transferPaused) {
            await _notificationService.showTransferCancelled(
              state.incomingFileName ?? 'File',
              reason: 'Peer disconnected unexpectedly',
            );
          }
          
          // Reset connection state
          state = ConnectionState.initial().copyWith(
            isPinRequired: state.isPinRequired,
            errorMessage: 'Peer disconnected',
            status: ConnectionStatus.disconnected, // Explicitly set disconnected
          );
          _pendingFiles.clear();
          break;

        case TransferEventType.manualDisconnection:
          final reason = event.data['reason'] ?? 'User disconnected';
          debugPrint('📴 Manual disconnection: $reason');
          
          // Manual disconnection - graceful shutdown without error notification
          if (state.status == ConnectionStatus.transferring ||
              state.status == ConnectionStatus.transferPaused) {
            await _notificationService.showTransferCancelled(
              state.incomingFileName ?? 'File',
              reason: 'Disconnected by user',
            );
          }
          
          // Reset connection state cleanly
          state = ConnectionState.initial().copyWith(
            isPinRequired: state.isPinRequired,
          );
          _pendingFiles.clear();
          break;

        default:
          break;
      }
    });

    _repo.progressStream.listen((progress) {
      if (state.status == ConnectionStatus.transferring) {
        state = state.copyWith(
          transferProgress: progress,
          transferredBytes: (progress * (state.incomingFileSize ?? 0)).toInt(),
        );
      }
    });

    // Listen to speed updates
    _repo.speedStream.listen((speed) {
      if (state.status == ConnectionStatus.transferring) {
        final progressPercent = (state.transferProgress * 100).toInt();
        final speedMBps = speed / (1024 * 1024);
        
        // Update notification with progress and speed
        if (state.incomingFileName != null) {
          _notificationService.updateTransferProgress(
            state.incomingFileName!,
            progressPercent,
            speedMBps,
            isSending: !state.isIncoming,
          );
        }
        
        state = state.copyWith(
          transferSpeed: speed,
          transferredBytes:
              (state.transferProgress * (state.incomingFileSize ?? 0)).toInt(),
        );
        
        // Update queue item progress
        List<TransferItem> queueProgress = List.from(state.transferQueue);
        final idxProgress = queueProgress.indexWhere((i) => i.fileName == state.incomingFileName);
        if (idxProgress != -1) {
            queueProgress[idxProgress] = queueProgress[idxProgress].copyWith(
            status: TransferItemStatus.transferring,
            progress: state.transferProgress,
            );
             state = state.copyWith(transferQueue: queueProgress);
        }
      }
    });
  }

  Future<void> startServer() async {
    try {
      await _repo.startServer(AppConstants.port, _myDeviceName);
      
      state = state.copyWith(
        status: ConnectionStatus.listening,
        sessionPin: _repo.sessionPin,
        isPinRequired: _repo.isPinRequired,
      );
    } catch (e) {
      debugPrint('❌ Failed to start server: $e');
      
      final errorMessage = e is AppExceptions 
          ? e.toString() 
          : 'Server startup failed: $e';
      
      state = state.copyWith(
        status: ConnectionStatus.error,
        errorMessage: errorMessage,
      );
    }
  }


  Future<void> connect(String ip, int port, {String? pin}) async {
    try {
      debugPrint('🔗 [ViewModel] Starting connection to $ip:$port');
      _currentTransferingDevice = ip;
      state = state.copyWith(status: ConnectionStatus.connecting);
      debugPrint('🔗 [ViewModel] State updated to connecting');
      await _repo.connect(ip, port, _myDeviceName, pin: pin);
      debugPrint('🔗 [ViewModel] Connection completed successfully');
    } catch (e) {
      debugPrint('❌ Connection failed to $ip:$port: $e');
      
      final errorMessage = e is AppExceptions 
          ? e.toString() 
          : 'Could not connect to $ip:$port: $e';
      
      await _notificationService.showError(
        'Connection Failed',
        errorMessage,
      );
      state = state.copyWith(
        status: ConnectionStatus.error,
        errorMessage: errorMessage,
      );
      rethrow;
    }
  }

  void acceptConnection() {
    _repo.acceptConnection(_myDeviceName);
    state = state.copyWith(status: ConnectionStatus.connected);
    _repo.startConnectionForegroundService(state.connectedTo ?? "Unknown Device");
  }

  Future<void> restartServer() async {
    debugPrint('🔄 Restarting server to apply new settings...');
    // Close existing server/connections gracefully
    await _repo.close();
    // Reset state but keep relevant fields if necessary, or just rely on startServer to set listening
    state = ConnectionState.initial(); 
    // Start server again (this will read fresh settings)
    await startServer();
  }

  void rejectConnection() {
    _repo.rejectConnection();
    disconnect();
  }

  void disconnect() {
    final wasPinRequired = state.isPinRequired;
    _repo.close(isManualDisconnect: true);
    state = ConnectionState.initial().copyWith(isPinRequired: wasPinRequired);
    // Restart the server to listen again
    startServer();
  }

  void cancelTransfer() {
    _pendingFiles.clear(); // Stop any pending batch items
    _repo.cancelTransfer();
    state = state.copyWith(
      status: ConnectionStatus.connected,
      transferProgress: 0.0,
    );
  }

  void pauseTransfer() {
    _repo.pauseTransfer();
    state = state.copyWith(
      status: ConnectionStatus.transferPaused,
      notificationMessage: 'Transfer paused',
    );
  }

  void resumeTransfer() {
    _repo.resumeTransfer();
    state = state.copyWith(
      status: ConnectionStatus.transferring,
      notificationMessage: 'Transfer resumed',
    );
  }

  void resetTransfer() {
    if (state.status == ConnectionStatus.transferCompleted ||
        state.status == ConnectionStatus.error) {
      state = state.copyWith(
        status: ConnectionStatus.connected,
        transferProgress: 0.0,
        incomingFileName: null,
        incomingFileSize: null,
        isBatch: false,
      );
    }
  }

  void acceptTransfer() {
    _repo.sendTransferResponse(true);
    state = state.copyWith(
      status: ConnectionStatus.transferring,
      transferProgress: 0.0,
    );
  }

  void rejectTransfer() {
    _repo.sendTransferResponse(false);
    state = state.copyWith(status: ConnectionStatus.connected);
  }

  Future<void> sendFiles(List<File> files) async {
    if (files.isEmpty) return;

    _pendingFiles = files;
    _batchHistoryDetails.clear();

    int totalSize = 0;
    for (var f in _pendingFiles) {
      totalSize += f.lengthSync();
    }

    // Request Transfer
      state = state.copyWith(
      status: ConnectionStatus.awaitingTransferAcceptance,
      isIncoming: false,
      totalBatchSize: totalSize,
      totalFilesCount: _pendingFiles.length,
      currentFileIndex: 0,
      totalBatchBytesTransferred: 0,
      transferQueue: _pendingFiles.map((f) => TransferItem(
              id: f.path,
              fileName: f.uri.pathSegments.last,
              fileSize: f.lengthSync(),
              status: TransferItemStatus.pending,
      )).toList(),
    );

    try {
      await _repo.requestTransferBatch(_pendingFiles);
    } catch (e) {
      state = state.copyWith(
        status: ConnectionStatus.error,
        errorMessage: 'Request Failed: $e',
      );
    }
  }

  Future<void> pickAndSendFiles() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        dialogTitle: 'Send files via FileFlow',
        allowMultiple: true,
      );

      if (result != null) {
        // Convert to file objects
        final files = result.paths
            .where((path) => path != null)
            .map((path) => File(path!))
            .toList();
        await sendFiles(files);
      }
    } catch (e) {
      state = state.copyWith(
        status: ConnectionStatus.error,
        errorMessage: 'File Pick Error: $e',
      );
    }
  }

  Future<void> pickFolder() async {
    try {
      String? selectedDirectory = await FilePicker.platform.getDirectoryPath();

      if (selectedDirectory != null) {
        final dir = Directory(selectedDirectory);
        final List<File> files = dir
            .listSync(recursive: true)
            .whereType<File>()
            .toList();

        if (files.isNotEmpty) {
          await sendFiles(files);
        } else {
          state = state.copyWith(
            notificationMessage: 'Selected folder is empty',
          );
          Future.delayed(const Duration(seconds: 2), () {
            state = state.copyWith(notificationMessage: null);
          });
        }
      }
    } catch (e) {
      state = state.copyWith(
        status: ConnectionStatus.error,
        errorMessage: 'Folder Pick Error: $e',
      );
    }
  }

  Future<void> sendClipboard() async {
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      if (data != null && data.text != null && data.text!.isNotEmpty) {
        await _repo.sendClipboardText(data.text!);
      }
    } catch (e) {
      state = state.copyWith(
        status: ConnectionStatus.error,
        errorMessage: 'Clipboard Error: $e',
      );
    }
  }

  Future<void> sendClipboardText(String text) async {
    try {
      if (text.isNotEmpty) {
        await _repo.sendClipboardText(text);
      }
    } catch (e) {
      state = state.copyWith(
        status: ConnectionStatus.error,
        errorMessage: 'Clipboard Error: $e',
      );
    }
  }

  // Helper methods to send queue
  Future<void> _processTransferQueue() async {
    if (_pendingFiles.isEmpty) {
      // Save batch history if we have details
      if (_batchHistoryDetails.isNotEmpty) {
           final isBatch = _batchHistoryDetails.length > 1;
           final totalSize = _batchHistoryDetails.fold(0, (sum, f) => sum + f.fileSize);
           final fileCount = _batchHistoryDetails.length;
           
           _historyViewModel.addItem(
            HistoryItem(
              id: DateTime.now().millisecondsSinceEpoch.toString(),
              fileName: isBatch ? "Batch Transfer" : _batchHistoryDetails.first.fileName,
              filePath: isBatch ? "Multiple Files" : _batchHistoryDetails.first.filePath,
              fileSize: totalSize,
              deviceName: state.connectedTo ?? "Unknown",
              timestamp: DateTime.now(),
              type: HistoryType.sent,
              isBatch: isBatch,
              fileCount: fileCount,
              batchFiles: List.from(_batchHistoryDetails),
            ),
          );
          _batchHistoryDetails.clear();
      }

      await _notificationService.showTransferCompleted(
          "Batch Transfer",
          state.totalBatchSize,
          isSending: true
      );

      state = state.copyWith(
        status: ConnectionStatus.transferCompleted,
        transferProgress: 1.0,
      );
      return;
    }

    // Send next file
    File nextFile = _pendingFiles.removeAt(0);
    final nextFileName = nextFile.uri.pathSegments.last;
    final nextFileSize = nextFile.lengthSync();

    final currentIndex = state.totalFilesCount - _pendingFiles.length;

    state = state.copyWith(
      incomingFileName: nextFileName,
      incomingFileSize: nextFileSize,
      transferProgress: 0.0,
      currentFileIndex: currentIndex,
    );

    try {
      // Update notification for sender
      await _notificationService.showTransferStarted(
        nextFileName,
        isSending: true,
      );

      // Must await the entire file send
      await _repo.sendFile(nextFile);

      // Check if transfer was cancelled during sendFile
      if (state.status != ConnectionStatus.transferring) {
          return;
      }

      state = state.copyWith(
        totalBatchBytesTransferred: state.totalBatchBytesTransferred + nextFileSize,
      );

      // Add to batch tracking
      _batchHistoryDetails.add(HistoryFileDetail(
        fileName: nextFileName,
        filePath: nextFile.path,
        fileSize: nextFileSize,
      ));

      // Update queue item to completed
      List<TransferItem> queueAfterSend = List.from(state.transferQueue);
      final idxSent = queueAfterSend.indexWhere((i) => i.fileName == nextFileName);
      if (idxSent != -1) {
         queueAfterSend[idxSent] = queueAfterSend[idxSent].copyWith(
            status: TransferItemStatus.completed,
            progress: 1.0,
         );
      }
      state = state.copyWith(
          transferQueue: queueAfterSend,
          transferProgress: 1.0,
          transferredBytes: nextFileSize,
      );

      await _processTransferQueue();
    } catch (e) {
      state = state.copyWith(
        status: ConnectionStatus.error,
        errorMessage: "Batch Failed: $e",
      );
      _pendingFiles.clear();
    }
  }
}
