import 'package:fileflow/core/providers/providers.dart';
import 'package:fileflow/features/history/provider/history_provider.dart';
import 'package:fileflow/features/settings/provider/settings_provider.dart';
import 'package:fileflow/features/transfer/repository/connection_repository.dart';
import 'package:fileflow/features/transfer/viewmodel/connection_viewmodel.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

final connectionRepositoryProvider = Provider((ref) {
  final settingsRepo = ref.watch(settingsRepositoryProvider);
  return ConnectionRepository(settingsRepo);
});

final connectionViewModelProvider =
    StateNotifierProvider<ConnectionViewModel, ConnectionState>((ref) {
      final deviceInfo = ref.watch(deviceInfoProvider);
      final historyViewModel = ref.watch(historyViewModelProvider.notifier);
      return ConnectionViewModel(
        ref.read(connectionRepositoryProvider),
        deviceInfo.name,
        historyViewModel,
      );
    });
