// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'history_item.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class HistoryFileDetailAdapter extends TypeAdapter<HistoryFileDetail> {
  @override
  final int typeId = 2;

  @override
  HistoryFileDetail read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return HistoryFileDetail(
      fileName: fields[0] as String,
      filePath: fields[1] as String,
      fileSize: fields[2] as int,
    );
  }

  @override
  void write(BinaryWriter writer, HistoryFileDetail obj) {
    writer
      ..writeByte(3)
      ..writeByte(0)
      ..write(obj.fileName)
      ..writeByte(1)
      ..write(obj.filePath)
      ..writeByte(2)
      ..write(obj.fileSize);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HistoryFileDetailAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class HistoryItemAdapter extends TypeAdapter<HistoryItem> {
  @override
  final int typeId = 1;

  @override
  HistoryItem read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return HistoryItem(
      id: fields[0] as String,
      fileName: fields[1] as String,
      filePath: fields[2] as String,
      fileSize: fields[3] as int,
      deviceName: fields[4] as String,
      timestamp: fields[5] as DateTime,
      type: fields[6] as HistoryType,
      isBatch: fields[7] as bool,
      fileCount: fields[8] as int,
      batchFiles: (fields[9] as List?)?.cast<HistoryFileDetail>(),
    );
  }

  @override
  void write(BinaryWriter writer, HistoryItem obj) {
    writer
      ..writeByte(10)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.fileName)
      ..writeByte(2)
      ..write(obj.filePath)
      ..writeByte(3)
      ..write(obj.fileSize)
      ..writeByte(4)
      ..write(obj.deviceName)
      ..writeByte(5)
      ..write(obj.timestamp)
      ..writeByte(6)
      ..write(obj.type)
      ..writeByte(7)
      ..write(obj.isBatch)
      ..writeByte(8)
      ..write(obj.fileCount)
      ..writeByte(9)
      ..write(obj.batchFiles);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HistoryItemAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class HistoryTypeAdapter extends TypeAdapter<HistoryType> {
  @override
  final int typeId = 0;

  @override
  HistoryType read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return HistoryType.sent;
      case 1:
        return HistoryType.received;
      default:
        return HistoryType.sent;
    }
  }

  @override
  void write(BinaryWriter writer, HistoryType obj) {
    switch (obj) {
      case HistoryType.sent:
        writer.writeByte(0);
        break;
      case HistoryType.received:
        writer.writeByte(1);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HistoryTypeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
