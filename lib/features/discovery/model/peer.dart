import 'package:fileflow/core/models/device_info.dart';

class Peer {
  final DeviceInfo deviceInfo;
  final String ip;
  final int port;

  Peer({
    required this.deviceInfo,
    required this.ip,
    required this.port,
  });

  Peer copyWith({
    DeviceInfo? deviceInfo,
    String? ip,
    int? port,
  }) {
    return Peer(
      deviceInfo: deviceInfo ?? this.deviceInfo,
      ip: ip ?? this.ip,
      port: port ?? this.port,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'deviceInfo': deviceInfo.toMap(),
      'ip': ip,
      'port': port,
    };
  }

  factory Peer.fromMap(Map<String, dynamic> map) {
    return Peer(
      deviceInfo: DeviceInfo.fromMap(map['deviceInfo'] as Map<String,dynamic>),
      ip: map['ip'] as String,
      port: map['port'] as int,
    );
  }
}
