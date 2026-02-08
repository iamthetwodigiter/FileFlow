import 'dart:io';
import 'package:fileflow/core/providers/providers.dart';
import 'package:fileflow/core/utils/get_device_info.dart';
import 'package:fileflow/core/app/fileflow_app.dart';
import 'package:fileflow/features/history/model/history_item.dart';
import 'package:fileflow/features/history/repository/history_repository.dart';
import 'package:fileflow/features/history/provider/history_provider.dart';
import 'package:fileflow/features/settings/provider/settings_provider.dart';
import 'package:fileflow/features/settings/repository/settings_repository.dart';
import 'package:fileflow/features/transfer/provider/transfer_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter(
    getApplicationDocumentsDirectory().then((dir) => dir.path).toString(),
  );

  Hive.registerAdapter(HistoryTypeAdapter());
  Hive.registerAdapter(HistoryItemAdapter());
  Hive.registerAdapter(HistoryFileDetailAdapter());

  final deviceInfo = await GetDeviceInfo().getDeviceInfo();

  final settingsRepo = SettingsRepository();
  await settingsRepo.init();
  await settingsRepo.setDeviceName(deviceInfo.name);

  final historyRepo = HistoryRepository();
  await historyRepo.init();

  _requestPermissions(deviceInfo);

  runApp(
    ProviderScope(
      overrides: [
        deviceInfoProvider.overrideWithValue(deviceInfo),
        settingsRepositoryProvider.overrideWithValue(settingsRepo),
        historyRepositoryProvider.overrideWithValue(historyRepo),
      ],
      child: const _AppInitializer(),
    ),
  );
}

class _AppInitializer extends ConsumerWidget {
  const _AppInitializer();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Start the server when the app initializes
    ref.listen(connectionViewModelProvider, (previous, next) {
      // Just listening to ensure the provider is created
    });

    // Call startServer on the connection viewmodel
    Future.microtask(() {
      ref.read(connectionViewModelProvider.notifier).startServer();
    });

    return const FileFlowApp();
  }
}

Future<void> _requestPermissions(dynamic deviceInfo) async {
  // Permissions are only needed on mobile platforms
  if (!Platform.isAndroid && !Platform.isIOS) {
    debugPrint('✅ Skipping permissions on desktop platform');
    return;
  }

  try {
    final notification = Permission.notification;
    final storage = Permission.storage;
    final manageExternalStorage = Permission.manageExternalStorage;

    debugPrint('📱 Checking notification permission...');
    final notifStatus = await notification.status;
    debugPrint('📱 Notification status: $notifStatus');
    if (!notifStatus.isGranted) {
      debugPrint('📱 Requesting notification permission...');
      final result = await notification.request();
      debugPrint('📱 Notification permission result: $result');
    }

    String versionString = deviceInfo.version;
    int androidVersion;
    if (versionString.contains('.')) {
      androidVersion = int.tryParse(versionString.split('.').first) ?? 0;
    } else {
      androidVersion = int.tryParse(versionString) ?? 0;
    }

    debugPrint('🔒 Android version: $androidVersion');

    if (androidVersion >= 13) {
      debugPrint(
        '🔒 Android $androidVersion detected - Using MANAGE_EXTERNAL_STORAGE',
      );

      final storageStatus = await manageExternalStorage.status;
      debugPrint('🔒 MANAGE_EXTERNAL_STORAGE status: $storageStatus');

      if (storageStatus.isDenied) {
        debugPrint(
          '🔒 Permission denied - Requesting MANAGE_EXTERNAL_STORAGE...',
        );
        final result = await manageExternalStorage.request();
        debugPrint('🔒 MANAGE_EXTERNAL_STORAGE request result: $result');
      } else if (storageStatus.isPermanentlyDenied) {
        debugPrint(
          '🔒 Permission permanently denied - Opening app settings...',
        );
        openAppSettings();
      }
    } else {
      debugPrint('🔒 Android <13 detected - Using WRITE_EXTERNAL_STORAGE');

      final storageStatus = await storage.status;
      debugPrint('🔒 WRITE_EXTERNAL_STORAGE status: $storageStatus');

      if (storageStatus.isDenied) {
        debugPrint(
          '🔒 Permission denied - Requesting WRITE_EXTERNAL_STORAGE...',
        );
        final result = await storage.request();
        debugPrint('🔒 WRITE_EXTERNAL_STORAGE request result: $result');
      } else if (storageStatus.isPermanentlyDenied) {
        debugPrint(
          '🔒 Permission permanently denied - Opening app settings...',
        );
        openAppSettings();
      }
    }

    debugPrint('✅ Permission requests completed');
  } catch (e) {
    debugPrint('❌ Permission request error: $e');
  }
}
