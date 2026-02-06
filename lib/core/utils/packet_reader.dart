import 'dart:typed_data';
import 'package:fileflow/core/models/packet.dart';

class PacketReader {
  final List<int> _buffer = [];

  // Header: 4 bytes payload length, 1 byte type
  // The payload length is 4 bytes or 32 bits that will store unsigned integer that represents the payload length or how much data is to be read
  static const int kHeaderSize = 5;
  static const int kMaxPacketSize = 10 * 1024 * 1024; // 10 MB Limit

  void addBytes(List<int> bytes) {
    _buffer.addAll(bytes);
  }

  void clear() {
    _buffer.clear();
  }

  // Returns a full packet if available in the buffer, else null if not enough data
  Packet? tryReadPacket() {
    if (_buffer.length < kHeaderSize) return null;

    // payloadLengthBytes extracts the first 4 bytes of the buffer.
    // payloadLength interprets them as 32 but unsigned integer and in big-endian order [aka network byte order where the MSB is stored first]
    final payloadLengthBytes = Uint8List.fromList(_buffer.sublist(0, 4));
    final payloadLength = ByteData.sublistView(
      payloadLengthBytes,
    ).getUint32(0, Endian.big);

    if (payloadLength > kMaxPacketSize) {
      // Clear buffer to prevent stuck state, or just throw? 
      // Clearing buffer is safer to reset state, but disconnection is best.
      _buffer.clear(); 
      throw Exception('Packet size $payloadLength exceeds limit $kMaxPacketSize');
    }

    // Check if we have full payload
    // Header (5) + Payload (payloadLength)
    if (_buffer.length < kHeaderSize + payloadLength) return null;

    // Read Type
    final type = _buffer[4];

    // Read Payload
    final payload = Uint8List.fromList(
      _buffer.sublist(kHeaderSize, kHeaderSize + payloadLength),
    );

    // Remove processed bytes from the buffer
    _buffer.removeRange(0, kHeaderSize + payloadLength);
    return Packet(type: type, payload: payload);
  }
}
