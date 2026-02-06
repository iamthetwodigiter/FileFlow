import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:fileflow/core/exceptions/app_exceptions.dart';
import 'package:fileflow/core/models/device_info.dart';

class GetDeviceInfo {
  static final GetDeviceInfo _instance = GetDeviceInfo._internal();
  factory GetDeviceInfo() => _instance;
  GetDeviceInfo._internal();

  Future<DeviceInfo> getDeviceInfo() async {
    DeviceInfoPlugin deviceInfoPlugin = DeviceInfoPlugin();

    try {
      if (Platform.isAndroid) {
        AndroidDeviceInfo androidInfo = await deviceInfoPlugin.androidInfo;
        return DeviceInfo.fromMap({
          "id": androidInfo.id,
          "name": '${androidInfo.manufacturer} ${androidInfo.name}',
          "model": androidInfo.model,
          "version": androidInfo.version.release,
          "os": "Android",
        });
      } else if (Platform.isIOS) {
        IosDeviceInfo iosInfo = await deviceInfoPlugin.iosInfo;
        return DeviceInfo.fromMap({
          "id": iosInfo.identifierForVendor,
          "name": iosInfo.name,
          "model": iosInfo.model,
          "version": iosInfo.systemVersion,
          "os": "iOS",
        });
      } else if (Platform.isWindows) {
        WindowsDeviceInfo windowsInfo = await deviceInfoPlugin.windowsInfo;
        return DeviceInfo.fromMap({
          "id": windowsInfo.deviceId,
          "name": windowsInfo.computerName,
          "model": windowsInfo.productName,
          "version": windowsInfo.buildNumber,
          "os": "Windows",
        });
      } else if (Platform.isLinux) {
        LinuxDeviceInfo linuxInfo = await deviceInfoPlugin.linuxInfo;
        return DeviceInfo.fromMap({
          "id": linuxInfo.machineId,
          "name": linuxInfo.name,
          "model": linuxInfo.prettyName,
          "version": linuxInfo.version,
          "os": "Linux",
        });
      } else if (Platform.isMacOS) {
        MacOsDeviceInfo macOsInfo = await deviceInfoPlugin.macOsInfo;
        return DeviceInfo.fromMap({
          "id": macOsInfo.systemGUID,
          "name": macOsInfo.computerName,
          "model": macOsInfo.model,
          "version": macOsInfo.osRelease,
          "os": "macOS",
        });
      }
    } catch (e) {
      throw DeviceInfoFetchFailed(e.toString());
    }
    throw DeviceInfoFetchFailed('Device details cannot be fetched');
  }
}
