import 'package:fileflow/features/settings/repository/settings_repository.dart';
import 'package:fileflow/features/settings/viewmodel/settings_viewmodel.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

final settingsRepositoryProvider = Provider((ref) => SettingsRepository());

final settingsViewModelProvider =
    StateNotifierProvider<SettingsViewModel, SettingsState>((ref) {
      return SettingsViewModel(ref.read(settingsRepositoryProvider));
    });
