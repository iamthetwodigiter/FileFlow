import 'dart:typed_data';

class Packet {
  final int type;
  final Uint8List payload;

  Packet({required this.type, required this.payload});
}
