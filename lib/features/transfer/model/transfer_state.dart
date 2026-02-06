class TransferState {
  final String id;
  final String fileName;
  final String filePath;
  final int totalBytes;
  final int transferredBytes;
  final String peerAddress;
  final DateTime lastUpdate;
  final bool isComplete;
  final bool isSending;

  TransferState({
    required this.id,
    required this.fileName,
    required this.filePath,
    required this.totalBytes,
    required this.transferredBytes,
    required this.peerAddress,
    required this.lastUpdate,
    this.isComplete = false,
    this.isSending = false,
  });

  TransferState copyWith({
    int? transferredBytes,

    DateTime? lastUpdate,
    bool? isComplete,
  }) {
    return TransferState(
      id: id,
      fileName: fileName,
      filePath: filePath,
      totalBytes: totalBytes,
      transferredBytes: transferredBytes ?? this.transferredBytes,
      peerAddress: peerAddress,
      lastUpdate: lastUpdate ?? this.lastUpdate,
      isComplete: isComplete ?? this.isComplete,
      isSending: isSending,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'fileName': fileName,
      'filePath': filePath,
      'totalBytes': totalBytes,
      'transferredBytes': transferredBytes,
      'peerAddress': peerAddress,
      'lastUpdate': lastUpdate.toIso8601String(),
      'isComplete': isComplete,
      'isSending': isSending,
    };
  }

  factory TransferState.fromMap(Map<String, dynamic> map) {
    return TransferState(
      id: map['id'] as String,
      fileName: map['fileName'] as String,
      filePath: map['filePath'] as String,
      totalBytes: map['totalBytes'] as int,
      transferredBytes: map['transferredBytes'] as int,
      peerAddress: map['peerAddress'] as String,
      lastUpdate: DateTime.parse(map['lastUpdate']),
      isComplete: map['isComplete'] as bool,
      isSending: map['isSending'] as bool,
    );
  }
}
