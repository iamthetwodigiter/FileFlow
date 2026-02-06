import 'dart:async';
import 'package:fileflow/core/models/device_info.dart';
import 'package:fileflow/features/discovery/model/peer.dart';
import 'package:fileflow/features/discovery/repository/discovery_repository.dart';
import 'package:flutter_riverpod/legacy.dart';

class DiscoveryViewmodel extends StateNotifier<List<Peer>> {
  final DiscoveryRepository _repo;
  final DeviceInfo _deviceInfo;
  StreamSubscription? _subscription;
  String? _myIp;

  String? get myIp => _myIp;

  DiscoveryViewmodel(this._repo, this._deviceInfo) : super([]);

  Future<void> init() async {
    await _repo.registerService(_deviceInfo);

    _subscription = _repo.startScanning().listen((peers) {
      if (!mounted) return;

      // Find our own device IP from all discovered peers
      for (final peer in peers) {
        if (peer.deviceInfo.id == _deviceInfo.id) {
          _myIp = peer.ip;
          break;
        }
      }

      state = peers
          .where((curr) => curr.deviceInfo.id != _deviceInfo.id)
          .toList();
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _repo.stop();
    super.dispose();
  }
}
