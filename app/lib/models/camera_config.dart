class CameraConfig {
  const CameraConfig({
    required this.id,
    required this.name,
    required this.isActive,
    this.classId,
    this.ipAddress,
    this.rtspUrl,
  });

  final int id;
  final int? classId;
  final String name;
  final String? ipAddress;
  final String? rtspUrl;
  final bool isActive;

  factory CameraConfig.fromJson(Map<String, dynamic> json) {
    return CameraConfig(
      id: json['id'] as int,
      classId: json['class_id'] as int?,
      name: json['name'] as String? ?? '',
      ipAddress: json['ip_address'] as String?,
      rtspUrl: json['rtsp_url'] as String?,
      isActive: json['is_active'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
    'class_id': classId,
    'name': name,
    'ip_address': ipAddress,
    'rtsp_url': rtspUrl,
    'is_active': isActive,
  };
}
