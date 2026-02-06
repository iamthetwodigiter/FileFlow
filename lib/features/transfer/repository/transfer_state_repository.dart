import 'package:fileflow/core/constants/app_constants.dart';
import 'package:fileflow/core/exceptions/app_exceptions.dart';
import 'package:fileflow/features/transfer/model/transfer_state.dart';
import 'package:hive_flutter/hive_flutter.dart';

class TransferStateRepository {
  Box<Map>? _box;

  Future<void> init() async {
    _box = await Hive.openBox<Map>(AppConstants.transferStatesBoxName);
  }

  Box<Map> get _getBox {
    if (_box == null || !_box!.isOpen) {
      throw TransferInitializationFailed('TransferStateRepository not initialized');
    }
    return _box!;
  }

  Future<void> saveState(TransferState state) async {
    await _getBox.put(state.id, state.toMap());
  }

  TransferState? getState(String id) {
    final data = _getBox.get(id);
    if (data == null) return null;
    return TransferState.fromMap(Map<String, dynamic>.from(data));
  }

  List<TransferState> getIncompleteTransfers() {
    final transfers = <TransferState>[];
    for (final key in _getBox.keys) {
      final data = _getBox.get(key);
      if (data != null) {
        final state = TransferState.fromMap(Map<String, dynamic>.from(data));
        if (!state.isComplete) {
          transfers.add(state);
        }
      }
    }
    return transfers;
  }

  Future<void> deleteState(String id) async {
    await _getBox.delete(id);
  }

  Future<void> clearAll() async {
    await _getBox.clear();
  }

  Future<void> close() async {
    await _box?.close();
  }
}