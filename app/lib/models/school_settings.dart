/// The switches a director owns for their whole school.
///
/// Not device preferences: all of these change what every other person in
/// the school sees, so they live on the server and arrive the same for
/// everyone.
class SchoolSettings {
  const SchoolSettings({
    required this.liveVideoEnabled,
    required this.groupMode,
    required this.smsEnabled,
    required this.isActive,
  });

  /// When off, nobody -- including the director -- gets a live picture. A
  /// camera pointed at a classroom is not something to leave watchable by
  /// default, and a school that only wants attendance has no use for it.
  final bool liveVideoEnabled;

  /// Academies run several groups through one room in a day; ordinary
  /// schools give each class its own room. With this on, a camera belongs to
  /// the room and a timetable decides whose lesson is in front of it.
  final bool groupMode;

  /// The school's own kill switch for SMS (attendance fallback and
  /// credential texts). Separate from whether a schedule has been entered:
  /// a schedule can exist before a single camera is watching it, and this
  /// is what stops "your child didn't come" from reaching a real parent in
  /// that gap.
  final bool smsEnabled;

  /// Pauses attendance recording -- both "present" from a camera and
  /// "absent" from the day-end sweep -- for the whole school. Off while a
  /// schedule is entered but no camera exists yet; on once tracking is
  /// actually meaningful.
  final bool isActive;

  factory SchoolSettings.fromJson(Map<String, dynamic> json) => SchoolSettings(
        liveVideoEnabled: json['live_video_enabled'] as bool? ?? true,
        groupMode: json['group_mode'] as bool? ?? false,
        smsEnabled: json['sms_enabled'] as bool? ?? true,
        isActive: json['is_active'] as bool? ?? true,
      );

  SchoolSettings copyWith({
    bool? liveVideoEnabled,
    bool? groupMode,
    bool? smsEnabled,
    bool? isActive,
  }) =>
      SchoolSettings(
        liveVideoEnabled: liveVideoEnabled ?? this.liveVideoEnabled,
        groupMode: groupMode ?? this.groupMode,
        smsEnabled: smsEnabled ?? this.smsEnabled,
        isActive: isActive ?? this.isActive,
      );
}
