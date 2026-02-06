import 'dart:convert';

enum TransferEventType {
  // Connection events
  connectionRequest,
  connectionAccepted,
  connectionRejected,
  
  // Transfer request events
  transferRequested,
  transferAccepted,
  transferRejected,
  
  // Transfer progress events
  transferComplete,
  transferCancelled,
  transferPaused,
  transferResumed,
  
  // File data events
  fileMetadata,
  fileChunk,
  
  // Special events
  clipboardText,
  
  // Disconnection events
  peerDisconnected,
  manualDisconnection,
  
  // Error events
  error,
}

class TransferEvent {
  final TransferEventType type;
  final Map<String, dynamic> data;

  TransferEvent({required this.type, this.data = const {}});

  factory TransferEvent.fromMap(Map<String, dynamic> map) {
    return TransferEvent(
      type: TransferEventType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => TransferEventType.connectionRequest,
      ),
      data: map['data'] ?? {}
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'type': type.name,
      'data': data
    };
  }
  
  String toRawJson() => json.encode(toMap());
}
