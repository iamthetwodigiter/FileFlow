import 'dart:io';

import 'package:path_provider/path_provider.dart';

class AppConstants {
  static const String multicastAddress = '239.255.12.34';
  static const int port = 26841;

  static const String historyBoxName = 'history';
  static const String settingsBoxName = 'settings';
  static const String transferStatesBoxName = 'transferStates';

  static final String appDir = Platform.isAndroid
      ? '/storage/emulated/0/FileFlow/'
      : Platform.isLinux
      ? '~/Documents/FileFlow/'
      : Platform.isMacOS
      ? '~/Documents/FileFlow/'
      : Platform.isWindows
      ? 'C:\\Users\\%USERNAME%\\Documents\\FileFlow\\'
      : getApplicationDocumentsDirectory()
            .then((dir) => '${dir.path}/FileFlow/')
            .toString();
}
