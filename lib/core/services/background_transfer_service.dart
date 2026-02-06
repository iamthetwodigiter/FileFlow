import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class BackgroundTransferService {
  static const platform = MethodChannel('com.fileflow/background');

  Future<void> startForegroundService(String fileName) async {
    try {
      await platform.invokeMethod('startService', {'fileName': fileName});
    } catch (e) {
      debugPrint('Error starting foreground service: $e');
    }
  }

  Future<void> startConnectionService(String deviceName) async {
    try {
      await platform.invokeMethod('startConnectionService', {'deviceName': deviceName});
    } catch (e) {
      debugPrint('Error starting connection service: $e');
    }
  }

  Future<void> updateProgress(String fileName, int progress) async {
    try {
      await platform.invokeMethod('updateProgress', {
        'fileName': fileName,
        'progress': progress,
      });
    } catch (e) {
      debugPrint('Error updating progress: $e');
    }
  }

  Future<void> stopForegroundService() async {
    try {
      await platform.invokeMethod('stopService');
    } catch (e) {
      debugPrint('Error stopping foreground service: $e');
    }
  }
}
