import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:fileflow/core/constants/app_constants.dart';
import 'package:fileflow/core/exceptions/app_exceptions.dart';
import 'package:fileflow/core/models/device_info.dart';
import 'package:fileflow/features/discovery/model/peer.dart';
import 'package:flutter/material.dart';
import 'package:nsd/nsd.dart';

class DiscoveryRepository {
  Discovery? _discovery;
  Registration? _registration;

  Future<void> registerService(DeviceInfo deviceInfo) async {
    if (_registration != null) {
      try {
        await unregister(_registration!);
      } catch (e) {
        // Ignore unregistration errors to prevent crash during race conditions
        debugPrint("⚠️ Warning: Failed to unregister previous service (likely already done): $e");
      }
      _registration = null;
    }

    try {
      final message = <String, Uint8List>{
        'id': utf8.encode(deviceInfo.id),
        'name': utf8.encode(deviceInfo.name),
        'model': utf8.encode(deviceInfo.model),
        'os': utf8.encode(deviceInfo.os),
        'version': utf8.encode(deviceInfo.version),
        'pin': utf8.encode(deviceInfo.isPinRequired.toString()),
      };

      _registration = await register(
        Service(
          name: deviceInfo.id,
          type: '_fileflow._tcp',
          port: AppConstants.port,
          txt: message,
        ),
      );
    } catch (e, stackTrace) {
      debugPrint("❌ Error registering mDNS service: $e");
      throw DiscoveryException(
        'Failed to register mDNS service for ${deviceInfo.name}: $e',
        e,
        stackTrace,
      );
    }
  }

  Stream<List<Peer>> startScanning() {
    final controller = StreamController<List<Peer>>();

    startDiscovery('_fileflow._tcp', autoResolve: true)
        .then((discovery) {
          _discovery = discovery;
          controller.add(_mapServicesToPeers(_discovery!.services));

          _discovery!.addListener(() {
            controller.add(_mapServicesToPeers(_discovery!.services));
          });
        })
        .catchError((e, stackTrace) {
          debugPrint('❌ Discovery error: $e');
          controller.addError(
            DiscoveryException(
              'Failed to start service discovery: $e',
              e,
              stackTrace,
            ),
          );
        });
    return controller.stream;
  }

  Future<void> stop() async {
    if (_discovery != null) {
      await stopDiscovery(_discovery!);
      _discovery = null;
    }
    if (_registration != null) {
      try {
        await unregister(_registration!);
      } catch (e) {
        debugPrint("⚠️ Error stopping registration: $e");
      }
      _registration = null;
    }
  }

  List<Peer> _mapServicesToPeers(List<Service> services) {
    final uniquePeers = <String, Peer>{};

    for (final service in services) {
      String? id;
      String? name;
      String? model;
      String? os;
      String? version;
      bool isPinRequired = false;

      if (service.txt != null) {
        id = _decodeTxtValue(service.txt!['id']);
        name = _decodeTxtValue(service.txt!['name']);
        model = _decodeTxtValue(service.txt!['model']);
        os = _decodeTxtValue(service.txt!['os']);
        version = _decodeTxtValue(service.txt!['version']);
        final pinStr = _decodeTxtValue(service.txt!['pin']);
        isPinRequired = pinStr == 'true';
      }

      if (id == null) continue;

      final deviceInfo = DeviceInfo(
        id: id,
        name: name ?? service.name ?? 'Unknown Device',
        model: model ?? 'Unknown Model',
        os: os ?? 'Unknown OS',
        version: version ?? 'Unknown Version',
        isPinRequired: isPinRequired,
      );

      final peer = Peer(
        deviceInfo: deviceInfo,
        ip: service.host ?? '',
        port: service.port ?? 4000,
      );

      uniquePeers[id] = peer;
    }

    return uniquePeers.values.toList();
  }

  String? _decodeTxtValue(Uint8List? value) {
    if (value == null) return null;
    try {
      return utf8.decode(value);
    } catch (e) {
      return null;
    }
  }
}
