enum TransferItemStatus { pending, transferring, completed, failed }

class TransferItem {
  final String id;
  final String fileName;
  final int fileSize;
  final TransferItemStatus status;
  final double progress;

  const TransferItem({
    required this.id,
    required this.fileName,
    required this.fileSize,
    this.status = TransferItemStatus.pending,
    this.progress = 0.0,
  });

  TransferItem copyWith({
    String? id,
    String? fileName,
    int? fileSize,
    TransferItemStatus? status,
    double? progress,
  }) {
    return TransferItem(
      id: id ?? this.id,
      fileName: fileName ?? this.fileName,
      fileSize: fileSize ?? this.fileSize,
      status: status ?? this.status,
      progress: progress ?? this.progress,
    );
  }
}
