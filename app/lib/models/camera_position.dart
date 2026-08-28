/// One slot of a camera's day: from when to when, and whose group.
///
/// Only used in group mode. A school gives each class its own room, so a
/// camera belongs to a class and that is the whole schedule. An academy runs
/// several groups through one room in a day, and then the camera belongs to
/// the room and these say who is in front of it when.
class CameraPosition {
  const CameraPosition({
    required this.id,
    required this.cameraId,
    required this.classId,
    required this.startTime,
    required this.endTime,
    this.className,
    this.subject,
    this.dayOfWeek,
  });

  final int id;
  final int cameraId;
  final int classId;
  final String? className;

  /// What is taught in this slot. The lessons generated from this
  /// position carry it, which is what puts an absence in the right
  /// subject's column.
  final String? subject;

  /// Monday = 0. Null means every day, which is how most academy timetables
  /// actually run -- the same group at the same hour all week.
  final int? dayOfWeek;

  final String startTime;
  final String endTime;

  factory CameraPosition.fromJson(Map<String, dynamic> json) => CameraPosition(
        id: json['id'] as int,
        cameraId: json['camera_id'] as int,
        classId: json['class_id'] as int,
        className: json['class_name'] as String?,
        subject: json['subject'] as String?,
        dayOfWeek: json['day_of_week'] as int?,
        startTime: json['start_time'] as String,
        endTime: json['end_time'] as String,
      );
}
