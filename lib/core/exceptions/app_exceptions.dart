// Base exception class for all FileFlow exceptions
class AppExceptions implements Exception {
  final String message;
  final String? prefix;
  final dynamic originalException;
  final StackTrace? stackTrace;

  AppExceptions(
    this.message, [
    this.prefix,
    this.originalException,
    this.stackTrace,
  ]);

  @override
  String toString() {
    final baseMessage = "${prefix ?? 'Error'}: $message";
    if (originalException != null) {
      return '$baseMessage\nCaused by: $originalException';
    }
    return baseMessage;
  }
}

// ============================================================================
// DEVICE & INITIALIZATION EXCEPTIONS
// ============================================================================

class DeviceInfoFetchFailed extends AppExceptions {
  DeviceInfoFetchFailed(String message, [dynamic original, StackTrace? stack])
      : super(message, "Device Info Error", original, stack);
}

class ProviderInitializationFailed extends AppExceptions {
  ProviderInitializationFailed(String message, [dynamic original, StackTrace? stack])
      : super(message, "Provider Initialization Error", original, stack);
}

// ============================================================================
// DISCOVERY & CONNECTION EXCEPTIONS
// ============================================================================

class DiscoveryException extends AppExceptions {
  DiscoveryException(String message, [dynamic original, StackTrace? stack])
      : super(message, "Discovery Error", original, stack);
}

class ServerStartupFailed extends AppExceptions {
  ServerStartupFailed(String message, [dynamic original, StackTrace? stack])
      : super(message, "Server Startup Failed", original, stack);
}

class ConnectionFailed extends AppExceptions {
  ConnectionFailed(String message, [dynamic original, StackTrace? stack])
      : super(message, "Connection Failed", original, stack);
}

class ConnectionTimeout extends AppExceptions {
  ConnectionTimeout(String message, [dynamic original, StackTrace? stack])
      : super(message, "Connection Timeout", original, stack);
}

class ConnectionRejected extends AppExceptions {
  final String? peerName;
  final String? reason;

  ConnectionRejected(
    String message, {
    this.peerName,
    this.reason,
    dynamic original,
    StackTrace? stack,
  }) : super(message, "Connection Rejected", original, stack);

  @override
  String toString() {
    final base = super.toString();
    if (peerName != null) {
      return '$base (from: $peerName)';
    }
    return base;
  }
}

class InvalidPIN extends AppExceptions {
  InvalidPIN([String? message, dynamic original, StackTrace? stack])
      : super(message ?? 'Invalid PIN provided', "PIN Error", original, stack);
}

// ============================================================================
// TRANSFER EXCEPTIONS
// ============================================================================

class TransferInitializationFailed extends AppExceptions {
  TransferInitializationFailed(String message, [dynamic original, StackTrace? stack])
      : super(message, "Transfer Init Failed", original, stack);
}

class FileReadError extends AppExceptions {
  final String? filePath;

  FileReadError(
    String message, {
    this.filePath,
    dynamic original,
    StackTrace? stack,
  }) : super(message, "File Read Error", original, stack);
}

class FileWriteError extends AppExceptions {
  final String? filePath;

  FileWriteError(
    String message, {
    this.filePath,
    dynamic original,
    StackTrace? stack,
  }) : super(message, "File Write Error", original, stack);
}

class FileNotFound extends AppExceptions {
  final String? filePath;

  FileNotFound(
    String message, {
    this.filePath,
    dynamic original,
    StackTrace? stack,
  }) : super(message, "File Not Found", original, stack);
}

class InsufficientStorage extends AppExceptions {
  final int requiredBytes;
  final int availableBytes;

  InsufficientStorage(
    String message, {
    required this.requiredBytes,
    required this.availableBytes,
    dynamic original,
    StackTrace? stack,
  }) : super(message, "Insufficient Storage", original, stack);

  @override
  String toString() {
    final base = super.toString();
    return '$base\nRequired: ${(requiredBytes / (1024 * 1024)).toStringAsFixed(2)} MB, '
        'Available: ${(availableBytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }
}

class TransferRejected extends AppExceptions {
  final String? peerName;
  final String? reason;

  TransferRejected(
    String message, {
    this.peerName,
    this.reason,
    dynamic original,
    StackTrace? stack,
  }) : super(message, "Transfer Rejected", original, stack);
}

class TransferCancelled extends AppExceptions {
  final String? cancelledBy;
  final String? reason;

  TransferCancelled(
    String message, {
    this.cancelledBy,
    this.reason,
    dynamic original,
    StackTrace? stack,
  }) : super(message, "Transfer Cancelled", original, stack);
}

class TransferCorrupted extends AppExceptions {
  final int? expectedSize;
  final int? actualSize;

  TransferCorrupted(
    String message, {
    this.expectedSize,
    this.actualSize,
    dynamic original,
    StackTrace? stack,
  }) : super(message, "Transfer Corrupted", original, stack);
}

// ============================================================================
// SECURITY & CRYPTOGRAPHY EXCEPTIONS
// ============================================================================

class CertificateGenerationFailed extends AppExceptions {
  CertificateGenerationFailed(String message, [dynamic original, StackTrace? stack])
      : super(message, "Certificate Generation Failed", original, stack);
}

class CertificateValidationFailed extends AppExceptions {
  CertificateValidationFailed(String message, [dynamic original, StackTrace? stack])
      : super(message, "Certificate Validation Failed", original, stack);
}

class TLSHandshakeFailed extends AppExceptions {
  TLSHandshakeFailed(String message, [dynamic original, StackTrace? stack])
      : super(message, "TLS Handshake Failed", original, stack);
}

class EncryptionFailed extends AppExceptions {
  EncryptionFailed(String message, [dynamic original, StackTrace? stack])
      : super(message, "Encryption Failed", original, stack);
}

// ============================================================================
// PACKET & PROTOCOL EXCEPTIONS
// ============================================================================

class InvalidPacket extends AppExceptions {
  final int? receivedSize;
  final int? expectedSize;

  InvalidPacket(
    String message, {
    this.receivedSize,
    this.expectedSize,
    dynamic original,
    StackTrace? stack,
  }) : super(message, "Invalid Packet", original, stack);
}

class PacketTimeout extends AppExceptions {
  PacketTimeout(String message, [dynamic original, StackTrace? stack])
      : super(message, "Packet Timeout", original, stack);
}

class ProtocolViolation extends AppExceptions {
  ProtocolViolation(String message, [dynamic original, StackTrace? stack])
      : super(message, "Protocol Violation", original, stack);
}

// ============================================================================
// STORAGE & DATABASE EXCEPTIONS
// ============================================================================

class StorageAccessDenied extends AppExceptions {
  StorageAccessDenied(String message, [dynamic original, StackTrace? stack])
      : super(message, "Storage Access Denied", original, stack);
}

class DatabaseError extends AppExceptions {
  DatabaseError(String message, [dynamic original, StackTrace? stack])
      : super(message, "Database Error", original, stack);
}

class HistoryOperationFailed extends AppExceptions {
  HistoryOperationFailed(String message, [dynamic original, StackTrace? stack])
      : super(message, "History Operation Failed", original, stack);
}

// ============================================================================
// NETWORK EXCEPTIONS
// ============================================================================

class NetworkError extends AppExceptions {
  NetworkError(String message, [dynamic original, StackTrace? stack])
      : super(message, "Network Error", original, stack);
}

class SocketError extends AppExceptions {
  SocketError(String message, [dynamic original, StackTrace? stack])
      : super(message, "Socket Error", original, stack);
}

class PeerDisconnected extends AppExceptions {
  PeerDisconnected(String message, [dynamic original, StackTrace? stack])
      : super(message, "Peer Disconnected", original, stack);
}

// ============================================================================
// NOTIFICATION EXCEPTIONS
// ============================================================================

class NotificationFailed extends AppExceptions {
  NotificationFailed(String message, [dynamic original, StackTrace? stack])
      : super(message, "Notification Failed", original, stack);
}

// ============================================================================
// CLIPBOARD & UTILITY EXCEPTIONS
// ============================================================================

class ClipboardOperationFailed extends AppExceptions {
  ClipboardOperationFailed(String message, [dynamic original, StackTrace? stack])
      : super(message, "Clipboard Operation Failed", original, stack);
}

class InvalidArgument extends AppExceptions {
  final String? argumentName;
  final dynamic invalidValue;

  InvalidArgument(
    String message, {
    this.argumentName,
    this.invalidValue,
    dynamic original,
    StackTrace? stack,
  }) : super(message, "Invalid Argument", original, stack);
}

class UnimplementedFeature extends AppExceptions {
  UnimplementedFeature(String message, [dynamic original, StackTrace? stack])
      : super(message, "Feature Not Implemented", original, stack);
}