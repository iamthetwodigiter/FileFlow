import 'package:fileflow/features/settings/repository/settings_repository.dart';
import 'package:flutter_riverpod/legacy.dart';

class SettingsState {
  final String? deviceName;
  final bool darkMode;
  final bool requiredPin;

  SettingsState({
    this.deviceName,
    this.darkMode = false,
    this.requiredPin = false,
  });

  SettingsState copyWith({
    String? deviceName,
    bool? darkMode,
    bool? requiredPin,
  }) {
    return SettingsState(
      deviceName: deviceName ?? this.deviceName,
      darkMode: darkMode ?? this.darkMode,
      requiredPin: requiredPin ?? this.requiredPin,
    );
  }
}

class SettingsViewModel extends StateNotifier<SettingsState> {
  final SettingsRepository _repo;
  SettingsViewModel(this._repo) : super(SettingsState()) {
    _loadSettings();
  }

  void _loadSettings() {
    final name = _repo.getDeviceName();
    final darkMode = _repo.getDarkMode();
    final requiredPin = _repo.requiredPin();
    state = state.copyWith(deviceName: name, darkMode: darkMode, requiredPin: requiredPin);
  }

  Future<void> setDeviceName(String name) async {
    await _repo.setDeviceName(name);
    state = state.copyWith(deviceName: name);
  }

  Future<void> toggleDarkMode() async {
    final darkMode = state.darkMode;
    await _repo.setDarkMode(!darkMode);
    state = state.copyWith(darkMode: !darkMode);
  }

  Future<void> toggleRequiredPin(bool requiredPin) async {
    _repo.toggleRequiredPin(requiredPin);
    state = state.copyWith(requiredPin: requiredPin);
  }
}
