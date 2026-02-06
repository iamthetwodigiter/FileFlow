class DeviceInfo {
  final String id;
  final String name;
  final String model;
  final String version;
  final String os;
  final bool isPinRequired;

  DeviceInfo({
    required this.id,
    required this.name,
    required this.model,
    required this.version,
    required this.os,
    this.isPinRequired = false,
  });

  DeviceInfo copyWith({
    String? id,
    String? name,
    String? model,
    String? version,
    String? os,
    bool? isPinRequired,
  }) {
    return DeviceInfo(
      id: id ?? this.id,
      name: name ?? this.name,
      model: model ?? this.model,
      version: version ?? this.version,
      os: os ?? this.os,
      isPinRequired: isPinRequired ?? this.isPinRequired,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'name': name,
      'model': model,
      'version': version,
      'os': os,
      'isPinRequired': isPinRequired,
    };
  }

  factory DeviceInfo.fromMap(Map<String, dynamic> map) {
    return DeviceInfo(
      id: map['id'] as String,
      name: map['name'] as String,
      model: map['model'] as String,
      version: map['version'] as String,
      os: map['os'] as String,
      isPinRequired: map['isPinRequired'] ?? false,
    );
  }
}
