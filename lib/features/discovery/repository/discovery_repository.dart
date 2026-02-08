import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:fileflow/core/constants/app_constants.dart';
import 'package:fileflow/core/exceptions/app_exceptions.dart';
import 'package:fileflow/core/models/device_info.dart';
import 'package:fileflow/features/discovery/model/peer.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class DiscoveryRepository {
  static const Duration broadcastInterval = Duration(seconds: 3);
  static const Duration peerTimeout = Duration(seconds: 10);
  static const _multicastChannel = MethodChannel('com.fileflow/multicast');

  RawDatagramSocket? _broadcastSocket;
  RawDatagramSocket? _listenSocket;
  Timer? _broadcastTimer;
  Timer? _cleanupTimer;

  DeviceInfo? _currentDeviceInfo;
  final Map<String, _PeerEntry> _discoveredPeers = {};
  final StreamController<List<Peer>> _peersController =
      StreamController<List<Peer>>.broadcast();

  Future<void> registerService(DeviceInfo deviceInfo) async {
    _currentDeviceInfo = deviceInfo;

    // Acquire multicast lock on Android only
    if (Platform.isAndroid) {
      try {
        await _multicastChannel.invokeMethod('acquire');
        debugPrint('✅ Android multicast lock acquired');
      } catch (e) {
        debugPrint('⚠️ Failed to acquire multicast lock (non-fatal): $e');
      }
    }

    try {
      // Create socket for broadcasting our presence
      _broadcastSocket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        0,
      );
      _broadcastSocket!.broadcastEnabled = true;

      // Start periodic broadcasting
      _broadcastTimer?.cancel();
      _broadcastTimer = Timer.periodic(broadcastInterval, (_) {
        _broadcastPresence();
      });

      // Broadcast immediately
      _broadcastPresence();

      debugPrint('✅ UDP Discovery service registered for ${deviceInfo.name}');
    } catch (e, stackTrace) {
      debugPrint('❌ Error registering UDP discovery service: $e');
      throw DiscoveryException(
        'Failed to register UDP discovery service for ${deviceInfo.name}: $e',
        e,
        stackTrace,
      );
    }
  }

  Stream<List<Peer>> startScanning() {
    _startListening();

    // Start cleanup timer to remove stale peers
    _cleanupTimer?.cancel();
    _cleanupTimer = Timer.periodic(Duration(seconds: 2), (_) {
      _cleanupStalePeers();
    });

    return _peersController.stream;
  }

  Future<void> _startListening() async {
    try {
      debugPrint('🎧 Starting UDP listener on port ${AppConstants.port}...');

      // Create socket for receiving discovery broadcasts
      _listenSocket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        AppConstants.port,
        reuseAddress: true,
      );

      debugPrint('🎧 Socket bound successfully');

      // Join multicast group
      _listenSocket!.joinMulticast(InternetAddress(AppConstants.multicastAddress));
      debugPrint('🎧 Joined multicast group ${AppConstants.multicastAddress}');

      _listenSocket!.listen((event) {
        if (event == RawSocketEvent.read) {
          final datagram = _listenSocket!.receive();
          if (datagram != null) {
            _handleIncomingPacket(datagram);
          }
        }
      });

      debugPrint('✅ UDP Discovery listening on port ${AppConstants.port}');
    } catch (e, stackTrace) {
      debugPrint('❌ Error starting UDP discovery listener: $e');
      debugPrint('Stack: $stackTrace');
      _peersController.addError(
        DiscoveryException(
          'Failed to start UDP discovery listener: $e',
          e,
          stackTrace,
        ),
      );
    }
  }

  void _broadcastPresence() {
    if (_currentDeviceInfo == null || _broadcastSocket == null) return;

    try {
      final message = {
        'id': _currentDeviceInfo!.id,
        'name': _currentDeviceInfo!.name,
        'model': _currentDeviceInfo!.model,
        'os': _currentDeviceInfo!.os,
        'version': _currentDeviceInfo!.version,
        'pin': _currentDeviceInfo!.isPinRequired.toString(),
        'port': AppConstants.port.toString(),
        'timestamp': DateTime.now().millisecondsSinceEpoch.toString(),
      };

      final data = utf8.encode(json.encode(message));

      // Send to multicast group
      final bytesSent = _broadcastSocket!.send(
        data,
        InternetAddress(AppConstants.multicastAddress),
        AppConstants.port,
      );

      if (bytesSent > 0) {
        debugPrint(
          '📡 Broadcasting presence: ${_currentDeviceInfo!.name} ($bytesSent bytes)',
        );
      }
    } catch (e) {
      debugPrint('⚠️ Error broadcasting presence: $e');
    }
  }

  void _handleIncomingPacket(Datagram datagram) {
    try {
      final data = utf8.decode(datagram.data);
      final message = json.decode(data) as Map<String, dynamic>;

      final id = message['id'] as String?;
      if (id == null || id == _currentDeviceInfo?.id) {
        // Ignore our own broadcasts
        return;
      }

      final name = message['name'] as String? ?? 'Unknown Device';
      final model = message['model'] as String? ?? 'Unknown Model';
      final os = message['os'] as String? ?? 'Unknown OS';
      final version = message['version'] as String? ?? 'Unknown Version';
      final pinStr = message['pin'] as String? ?? 'false';
      final portStr = message['port'] as String?;

      final isPinRequired = pinStr == 'true';
      final port = portStr != null
          ? int.tryParse(portStr) ?? AppConstants.port
          : AppConstants.port;

      final deviceInfo = DeviceInfo(
        id: id,
        name: name,
        model: model,
        os: os,
        version: version,
        isPinRequired: isPinRequired,
      );

      final peer = Peer(
        deviceInfo: deviceInfo,
        ip: datagram.address.address,
        port: port,
      );

      // Update or add peer
      _discoveredPeers[id] = _PeerEntry(peer, DateTime.now());
      debugPrint(
        '🔍 Discovered peer: $name (${datagram.address.address}:$port) - OS: $os',
      );
      _notifyPeersUpdate();
    } catch (e) {
      debugPrint('⚠️ Error parsing discovery packet: $e');
    }
  }

  void _cleanupStalePeers() {
    final now = DateTime.now();
    final initialCount = _discoveredPeers.length;

    _discoveredPeers.removeWhere((id, entry) {
      return now.difference(entry.lastSeen) > peerTimeout;
    });

    if (_discoveredPeers.length != initialCount) {
      _notifyPeersUpdate();
    }
  }

  void _notifyPeersUpdate() {
    final peers = _discoveredPeers.values.map((e) => e.peer).toList();
    _peersController.add(peers);
  }

  Future<void> stop() async {
    _broadcastTimer?.cancel();
    _cleanupTimer?.cancel();
    _broadcastSocket?.close();

    if (_listenSocket != null) {
      try {
        _listenSocket!.leaveMulticast(InternetAddress(AppConstants.multicastAddress));
      } catch (e) {
        debugPrint('⚠️ Error leaving multicast group: $e');
      }
      _listenSocket!.close();
    }

    // Release multicast lock on Android only
    if (Platform.isAndroid) {
      try {
        await _multicastChannel.invokeMethod('release');
        debugPrint('✅ Android multicast lock released');
      } catch (e) {
        debugPrint('⚠️ Failed to release multicast lock: $e');
      }
    }

    await _peersController.close();
    _discoveredPeers.clear();

    debugPrint('✅ UDP Discovery service stopped');
  }
}

class _PeerEntry {
  final Peer peer;
  final DateTime lastSeen;

  _PeerEntry(this.peer, this.lastSeen);
}
