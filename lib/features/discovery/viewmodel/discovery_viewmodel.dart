import 'dart:async';
import 'dart:io';
import 'package:fileflow/core/models/device_info.dart';
import 'package:fileflow/features/discovery/model/peer.dart';
import 'package:fileflow/features/discovery/repository/discovery_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:network_info_plus/network_info_plus.dart';

class DiscoveryViewmodel extends StateNotifier<List<Peer>> {
  final DiscoveryRepository _repo;
  final DeviceInfo _deviceInfo;
  StreamSubscription? _subscription;
  String? _myIp;

  String? get myIp => _myIp;

  DiscoveryViewmodel(this._repo, this._deviceInfo) : super([]);

  Future<void> init() async {
    await _repo.registerService(_deviceInfo);
    await _getLocalIP();

    _subscription = _repo.startScanning().listen((peers) {
      if (!mounted) return;

      state = peers
          .where((curr) => curr.deviceInfo.id != _deviceInfo.id)
          .toList();
    });
  }

  Future<void> _getLocalIP() async {
    try {
      if (Platform.isAndroid || Platform.isIOS) {
        // Use network_info_plus for mobile
        final info = NetworkInfo();
        _myIp = await info.getWifiIP();
        debugPrint('📱 Got local IP via network_info_plus: $_myIp');
      } else {
        // Use NetworkInterface for desktop platforms
        final interfaces = await NetworkInterface.list(
          type: InternetAddressType.IPv4,
          includeLinkLocal: false,
        );
        
        for (final interface in interfaces) {
          // Skip loopback
          if (interface.name.contains('lo')) continue;
          
          for (final addr in interface.addresses) {
            if (!addr.isLoopback && addr.type == InternetAddressType.IPv4) {
              _myIp = addr.address;
              debugPrint('💻 Got local IP via NetworkInterface: $_myIp on ${interface.name}');
              return;
            }
          }
        }
      }
    } catch (e) {
      debugPrint('❌ Error getting local IP: $e');
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _repo.stop();
    super.dispose();
  }
}
