enum AttendanceStatus { present, late, absent, leftSchool, notDetected }

AttendanceStatus attendanceStatusFromApi(String? value) {
  return switch (value) {
    'present' => AttendanceStatus.present,
    'late' => AttendanceStatus.late,
    'absent' => AttendanceStatus.absent,
    'left_school' => AttendanceStatus.leftSchool,
    _ => AttendanceStatus.notDetected,
  };
}

extension AttendanceStatusMeta on AttendanceStatus {
  String get label => switch (this) {
    AttendanceStatus.present => 'Present',
    AttendanceStatus.late => 'Late',
    AttendanceStatus.absent => 'Absent',
    AttendanceStatus.leftSchool => 'Left school',
    AttendanceStatus.notDetected => 'Not detected',
  };

  String get apiValue => switch (this) {
    AttendanceStatus.present => 'present',
    AttendanceStatus.late => 'late',
    AttendanceStatus.absent => 'absent',
    AttendanceStatus.leftSchool => 'left_school',
    AttendanceStatus.notDetected => 'not_detected',
  };
}

class AttendanceRecord {
  const AttendanceRecord({
    required this.id,
    required this.studentId,
    required this.status,
    required this.attendanceDate,
    this.cameraId,
    this.confidence,
    this.timeIn,
    this.timeOut,
    this.lastSeen,
  });

  final int id;
  final int studentId;
  final int? cameraId;
  final AttendanceStatus status;
  final DateTime attendanceDate;
  final double? confidence;
  final DateTime? timeIn;
  final DateTime? timeOut;
  final DateTime? lastSeen;

  factory AttendanceRecord.fromJson(Map<String, dynamic> json) {
    return AttendanceRecord(
      id: json['id'] as int,
      studentId: json['student_id'] as int,
      cameraId: json['camera_id'] as int?,
      status: attendanceStatusFromApi(json['status'] as String?),
      attendanceDate: DateTime.parse(json['attendance_date'] as String),
      confidence: (json['confidence'] as num?)?.toDouble(),
      timeIn: _parseDateTime(json['time_in']),
      timeOut: _parseDateTime(json['time_out']),
      lastSeen: _parseDateTime(json['last_seen']),
    );
  }
}

class LiveAttendance {
  const LiveAttendance({
    required this.studentId,
    required this.firstName,
    required this.lastName,
    required this.status,
    required this.attendanceDate,
    this.cameraId,
    this.timeIn,
    this.timeOut,
    this.lastSeen,
  });

  final int studentId;
  final String firstName;
  final String lastName;
  final AttendanceStatus status;
  final DateTime attendanceDate;
  final int? cameraId;
  final DateTime? timeIn;
  final DateTime? timeOut;
  final DateTime? lastSeen;

  String get fullName => '$firstName $lastName';

  factory LiveAttendance.fromJson(Map<String, dynamic> json) {
    return LiveAttendance(
      studentId: json['student_id'] as int,
      firstName: json['first_name'] as String? ?? '',
      lastName: json['last_name'] as String? ?? '',
      status: attendanceStatusFromApi(json['status'] as String?),
      attendanceDate: DateTime.parse(json['attendance_date'] as String),
      cameraId: json['camera_id'] as int?,
      timeIn: _parseDateTime(json['time_in']),
      timeOut: _parseDateTime(json['time_out']),
      lastSeen: _parseDateTime(json['last_seen']),
    );
  }
}

DateTime? _parseDateTime(dynamic value) {
  if (value == null) return null;
  return DateTime.tryParse(value as String);
}
