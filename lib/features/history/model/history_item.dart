import 'package:hive_flutter/hive_flutter.dart';

part 'history_item.g.dart';

@HiveType(typeId: 0)
enum HistoryType {
  @HiveField(0)
  sent,
  @HiveField(1)
  received
}

@HiveType(typeId: 2)
class HistoryFileDetail {
  @HiveField(0)
  final String fileName;
  
  @HiveField(1)
  final String filePath;
  
  @HiveField(2)
  final int fileSize;

  HistoryFileDetail({
    required this.fileName,
    required this.filePath,
    required this.fileSize,
  });
}

@HiveType(typeId: 1)
class HistoryItem {
  @HiveField(0)
  final String id;
  
  @HiveField(1)
  final String fileName;
  
  @HiveField(2)
  final String filePath;
  
  @HiveField(3)
  final int fileSize;
  
  @HiveField(4)
  final String deviceName; 
  
  @HiveField(5)
  final DateTime timestamp;
  
  @HiveField(6)
  final HistoryType type;

  @HiveField(7)
  final bool isBatch;

  @HiveField(8)
  final int fileCount;

  @HiveField(9)
  final List<HistoryFileDetail>? batchFiles;

  HistoryItem({
    required this.id,
    required this.fileName,
    required this.filePath,
    required this.fileSize,
    required this.deviceName,
    required this.timestamp,
    required this.type,
    this.isBatch = false,
    this.fileCount = 1,
    this.batchFiles,
  });
}
