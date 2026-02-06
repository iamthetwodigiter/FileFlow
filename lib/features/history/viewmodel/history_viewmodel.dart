import 'package:fileflow/features/history/model/history_item.dart';
import 'package:fileflow/features/history/repository/history_repository.dart';
import 'package:flutter_riverpod/legacy.dart';

class HistoryViewModel extends StateNotifier<List<HistoryItem>> {
  final HistoryRepository _repo;
  HistoryViewModel(this._repo) : super([]) {
    state = _repo.getHistory();
  }

  void loadHistory() {
    state = _repo.getHistory();
  }

  Future<void> addItem(HistoryItem item) async {
    await _repo.addHistoryItem(item);
    loadHistory();
  }

  Future<void> removeItem(HistoryItem item) async {
    await _repo.removeHistoryItem(item);
    loadHistory();
  }

  Future<void> clearAll() async {
    await _repo.clearHistory();
    loadHistory();
  }
}
