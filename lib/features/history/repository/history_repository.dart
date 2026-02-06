import 'package:fileflow/core/constants/app_constants.dart';
import 'package:fileflow/core/exceptions/app_exceptions.dart';
import 'package:fileflow/features/history/model/history_item.dart';
import 'package:hive_flutter/hive_flutter.dart';

class HistoryRepository {
  late Box<HistoryItem> _box;

  Future<void> init() async {
    try {
      if (!Hive.isBoxOpen(AppConstants.historyBoxName)) {
        _box = await Hive.openBox<HistoryItem>(AppConstants.historyBoxName);
      }
    } catch (e, stackTrace) {
      throw HistoryOperationFailed(
        'Failed to initialize history database: $e',
        e,
        stackTrace,
      );
    }
  }

  List<HistoryItem> getHistory() {
    try {
      if (!_box.isOpen) {
        throw HistoryOperationFailed('History box is not open');
      }
      return _box.values.toList().reversed.toList();
    } catch (e, stackTrace) {
      if (e is AppExceptions) rethrow;
      throw HistoryOperationFailed(
        'Failed to retrieve history: $e',
        e,
        stackTrace,
      );
    }
  }

  Future<void> addHistoryItem(HistoryItem item) async {
    try {
      if (!_box.isOpen) {
        throw HistoryOperationFailed('History box is not open');
      }
      await _box.add(item);
    } catch (e, stackTrace) {
      if (e is AppExceptions) rethrow;
      throw HistoryOperationFailed(
        'Failed to add history item: $e',
        e,
        stackTrace,
      );
    }
  }

  Future<void> removeHistoryItem(HistoryItem item) async {
    try {
      if (!_box.isOpen) {
        throw HistoryOperationFailed('History box is not open');
      }
      await _box.delete(item);
    } catch (e, stackTrace) {
      if (e is AppExceptions) rethrow;
      throw HistoryOperationFailed(
        'Failed to remove history item: $e',
        e,
        stackTrace,
      );
    }
  }

  Future<void> clearHistory() async {
    try {
      if (!_box.isOpen) {
        throw HistoryOperationFailed('History box is not open');
      }
      await _box.clear();
    } catch (e, stackTrace) {
      if (e is AppExceptions) rethrow;
      throw HistoryOperationFailed(
        'Failed to clear history: $e',
        e,
        stackTrace,
      );
    }
  }
}
