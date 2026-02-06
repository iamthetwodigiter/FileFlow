import 'package:fileflow/core/exceptions/app_exceptions.dart';
import 'package:fileflow/core/models/device_info.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final deviceInfoProvider = Provider<DeviceInfo>((ref) {
  throw ProviderInitializationFailed(
    "Device Info not initialized. Override in main.dart",
  );
});