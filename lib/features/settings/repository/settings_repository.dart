import 'package:fileflow/core/constants/app_constants.dart';
import 'package:fileflow/core/exceptions/app_exceptions.dart';
import 'package:hive_flutter/hive_flutter.dart';

class SettingsRepository {
  static const String _deviceName = 'deviceName';
  static const String _darkMode = 'darkMode';
  static const String _requiredPin = 'requiredPin';
  late Box _box;

  Future<void> init() async {
    try {
      if (!Hive.isBoxOpen(AppConstants.settingsBoxName)) {
        _box = await Hive.openBox(AppConstants.settingsBoxName);
      }
    } catch (e, stackTrace) {
      throw DatabaseError(
        'Failed to initialize settings database: $e',
        e,
        stackTrace,
      );
    }
  }

  String? getDeviceName() {
    try {
      if (!_box.isOpen) {
        throw DatabaseError('Settings box is not open');
      }
      return _box.get(_deviceName);
    } catch (e, stackTrace) {
      if (e is AppExceptions) rethrow;
      throw DatabaseError('Failed to retrieve device name: $e', e, stackTrace);
    }
  }

  Future<void> setDeviceName(String name) async {
    try {
      if (!_box.isOpen) {
        throw DatabaseError('Settings box is not open');
      }
      if (name.isEmpty) {
        throw InvalidArgument(
          'Device name cannot be empty',
          argumentName: 'name',
          invalidValue: name,
        );
      }
      await _box.put(_deviceName, name);
    } catch (e, stackTrace) {
      if (e is AppExceptions) rethrow;
      throw DatabaseError('Failed to save device name: $e', e, stackTrace);
    }
  }

  bool requiredPin() {
    try {
      if (!_box.isOpen) {
        throw DatabaseError('Settings box is not open');
      }
      return _box.get(_requiredPin, defaultValue: false);
    } catch (e, stackTrace) {
      if (e is AppExceptions) rethrow;
      throw DatabaseError(
        'Failed to retrieve required Pin setting: $e',
        e,
        stackTrace,
      );
    }
  }

  Future<void> toggleRequiredPin(bool requiredPin) async {
    try {
      if (!_box.isOpen) {
        throw DatabaseError('Settings box is not open');
      }
      await _box.put(_requiredPin, requiredPin);
    } catch (e, stackTrace) {
      if (e is AppExceptions) rethrow;
      throw DatabaseError(
        'Failed to save required Pin setting: $e',
        e,
        stackTrace,
      );
    }
  }

  bool getDarkMode() {
    try {
      if (!_box.isOpen) {
        throw DatabaseError('Settings box is not open');
      }
      return _box.get(_darkMode, defaultValue: false);
    } catch (e, stackTrace) {
      if (e is AppExceptions) rethrow;
      throw DatabaseError(
        'Failed to retrieve dark mode setting: $e',
        e,
        stackTrace,
      );
    }
  }

  Future<void> setDarkMode(bool isDark) async {
    try {
      if (!_box.isOpen) {
        throw DatabaseError('Settings box is not open');
      }
      await _box.put(_darkMode, isDark);
    } catch (e, stackTrace) {
      if (e is AppExceptions) rethrow;
      throw DatabaseError(
        'Failed to save dark mode setting: $e',
        e,
        stackTrace,
      );
    }
  }
}
