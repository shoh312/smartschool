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
    this.classId,
    this.className,
    this.classInSession = false,
    this.cameraId,
    this.timeIn,
    this.timeOut,
    this.lastSeen,
    this.detectedAt,
  });

  final int studentId;
  final String firstName;
  final String lastName;
  final AttendanceStatus status;
  final DateTime attendanceDate;

  // Sent with the live feed rather than looked up on the client: the pupil
  // list the app loads separately is not always complete, and joining the
  // two made classes show nobody present while the header counted dozens.
  final int? classId;
  final String? className;

  /// Whether this pupil's class is in a lesson at this moment. An academy's
  /// dashboard shows only the groups that are actually in the building, and
  /// a group whose lesson has finished drops out of the panel.
  final bool classInSession;

  final int? cameraId;
  final DateTime? timeIn;
  final DateTime? timeOut;
  final DateTime? lastSeen;

  /// Last resort for "when": a pupil marked present from outside the camera
  /// can carry no arrival time and no last-seen at all.
  final DateTime? detectedAt;

  /// Whatever is known about when this pupil turned up, or null when the
  /// record carries no time at all.
  DateTime? get arrivedAt => timeIn ?? lastSeen ?? detectedAt;

  String get fullName => '$firstName $lastName';

  factory LiveAttendance.fromJson(Map<String, dynamic> json) {
    return LiveAttendance(
      studentId: json['student_id'] as int,
      firstName: json['first_name'] as String? ?? '',
      lastName: json['last_name'] as String? ?? '',
      status: attendanceStatusFromApi(json['status'] as String?),
      attendanceDate: DateTime.parse(json['attendance_date'] as String),
      classId: json['class_id'] as int?,
      className: json['class_name'] as String?,
      classInSession: json['class_in_session'] as bool? ?? false,
      cameraId: json['camera_id'] as int?,
      timeIn: _parseDateTime(json['time_in']),
      timeOut: _parseDateTime(json['time_out']),
      lastSeen: _parseDateTime(json['last_seen']),
      detectedAt: _parseDateTime(json['detected_at']),
    );
  }
}

DateTime? _parseDateTime(dynamic value) {
  if (value == null) return null;
  return DateTime.tryParse(value as String);
}
