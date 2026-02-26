import 'package:fileflow/features/history/model/history_item.dart';
import 'package:fileflow/features/history/repository/history_repository.dart';
import 'package:fileflow/features/history/viewmodel/history_viewmodel.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final historyRepositoryProvider = Provider((ref) => HistoryRepository());

final historyViewModelProvider =
    StateNotifierProvider<HistoryViewModel, List<HistoryItem>>((ref) {
      return HistoryViewModel(ref.read(historyRepositoryProvider));
    });
