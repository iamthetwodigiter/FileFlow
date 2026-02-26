import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class NotificationService {
  static const platform = MethodChannel('app.fileflow/notifications');

  // Helper to check if platform supports notifications
  bool _supportsNotifications() {
    return Platform.isAndroid || Platform.isIOS || Platform.isMacOS;
  }

  // Show connection established notification
  Future<void> showConnectionEstablished(String deviceName) async {
    if (!_supportsNotifications()) return;
    try {
      await platform.invokeMethod('showConnectionEstablished', {
        'deviceName': deviceName,
      });
    } catch (e) {
      debugPrint('Error showing connection notification: $e');
    }
  }

  // Show connection request notification
  Future<void> showConnectionRequest(String deviceName) async {
    if (!_supportsNotifications()) return;
    try {
      await platform.invokeMethod('showConnectionRequest', {
        'deviceName': deviceName,
      });
    } catch (e) {
      debugPrint('Error showing connection request notification: $e');
    }
  }

  // Show connection rejected notification
  Future<void> showConnectionRejected(String deviceName, {String? reason}) async {
    if (!_supportsNotifications()) return;
    try {
      await platform.invokeMethod('showConnectionRejected', {
        'deviceName': deviceName,
        'reason': reason ?? 'Connection rejected',
      });
    } catch (e) {
      debugPrint('Error showing connection rejected notification: $e');
    }
  }

  // Show transfer request received notification
  Future<void> showTransferRequest(
    String deviceName,
    String fileName,
    int fileSize,
  ) async {
    if (!_supportsNotifications()) return;
    try {
      await platform.invokeMethod('showTransferRequest', {
        'deviceName': deviceName,
        'fileName': fileName,
        'fileSize': fileSize,
      });
    } catch (e) {
      debugPrint('Error showing transfer request notification: $e');
    }
  }

  // Show transfer started notification
  Future<void> showTransferStarted(String fileName, {bool isSending = false}) async {
    if (!_supportsNotifications()) return;
    try {
      await platform.invokeMethod('showTransferStarted', {
        'fileName': fileName,
        'isSending': isSending,
      });
    } catch (e) {
      debugPrint('Error showing transfer started notification: $e');
    }
  }

  // Update transfer progress notification
  Future<void> updateTransferProgress(
    String fileName,
    int progressPercent,
    double speedMBps,
    {bool isSending = false}
  ) async {
    if (!_supportsNotifications()) return;
    try {
      await platform.invokeMethod('updateTransferProgress', {
        'fileName': fileName,
        'progress': progressPercent,
        'speedMBps': speedMBps,
        'isSending': isSending,
      });
    } catch (e) {
      debugPrint('Error updating transfer progress notification: $e');
    }
  }

  // Show transfer paused notification
  Future<void> showTransferPaused(String fileName) async {
    if (!_supportsNotifications()) return;
    try {
      await platform.invokeMethod('showTransferPaused', {
        'fileName': fileName,
      });
    } catch (e) {
      debugPrint('Error showing transfer paused notification: $e');
    }
  }

  // Show transfer resumed notification
  Future<void> showTransferResumed(String fileName) async {
    if (!_supportsNotifications()) return;
    try {
      await platform.invokeMethod('showTransferResumed', {
        'fileName': fileName,
      });
    } catch (e) {
      debugPrint('Error showing transfer resumed notification: $e');
    }
  }

  // Show transfer completed notification
  Future<void> showTransferCompleted(
    String fileName,
    int fileSize, {
    bool isSending = false,
  }) async {
    if (!_supportsNotifications()) return;
    try {
      await platform.invokeMethod('showTransferCompleted', {
        'fileName': fileName,
        'fileSize': fileSize,
        'isSending': isSending,
      });
    } catch (e) {
      debugPrint('Error showing transfer completed notification: $e');
    }
  }

  // Show transfer cancelled notification
  Future<void> showTransferCancelled(String fileName, {String? reason}) async {
    if (!_supportsNotifications()) return;
    try {
      await platform.invokeMethod('showTransferCancelled', {
        'fileName': fileName,
        'reason': reason ?? 'Transfer cancelled',
      });
    } catch (e) {
      debugPrint('Error showing transfer cancelled notification: $e');
    }
  }

  // Show error notification
  Future<void> showError(String title, String message) async {
    if (!_supportsNotifications()) return;
    try {
      await platform.invokeMethod('showError', {
        'title': title,
        'message': message,
      });
    } catch (e) {
      debugPrint('Error showing error notification: $e');
    }
  }
}
