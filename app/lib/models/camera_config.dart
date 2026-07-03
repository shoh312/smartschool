class CameraConfig {
  const CameraConfig({
    required this.id,
    required this.name,
    required this.isActive,
    this.classId,
    this.ipAddress,
    this.rtspUrl,
    this.detectionStartTime,
    this.detectionEndTime,
    this.detectDurationSeconds,
    this.waitDurationMinutes,
  });

  final int id;
  final int? classId;
  final String name;
  final String? ipAddress;
  final String? rtspUrl;
  final bool isActive;
  final String? detectionStartTime;
  final String? detectionEndTime;
  final int? detectDurationSeconds;
  final int? waitDurationMinutes;

  factory CameraConfig.fromJson(Map<String, dynamic> json) {
    return CameraConfig(
      id: json['id'] as int,
      classId: json['class_id'] as int?,
      name: json['name'] as String? ?? '',
      ipAddress: json['ip_address'] as String?,
      rtspUrl: json['rtsp_url'] as String?,
      isActive: json['is_active'] as bool? ?? true,
      detectionStartTime: json['detection_start_time'] as String?,
      detectionEndTime: json['detection_end_time'] as String?,
      detectDurationSeconds: json['detect_duration_seconds'] as int?,
      waitDurationMinutes: json['wait_duration_minutes'] as int?,
    );
  }

  Map<String, dynamic> toJson() => {
    'class_id': classId,
    'name': name,
    'ip_address': ipAddress,
    'rtsp_url': rtspUrl,
    'is_active': isActive,
    'detection_start_time': detectionStartTime,
    'detection_end_time': detectionEndTime,
    'detect_duration_seconds': detectDurationSeconds,
    'wait_duration_minutes': waitDurationMinutes,
  };
}
