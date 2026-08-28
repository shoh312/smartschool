/// The two switches a director owns for their whole school.
///
/// Not device preferences: both change what every other person in the school
/// sees, so they live on the server and arrive the same for everyone.
class SchoolSettings {
  const SchoolSettings({
    required this.liveVideoEnabled,
    required this.groupMode,
  });

  /// When off, nobody -- including the director -- gets a live picture. A
  /// camera pointed at a classroom is not something to leave watchable by
  /// default, and a school that only wants attendance has no use for it.
  final bool liveVideoEnabled;

  /// Academies run several groups through one room in a day; ordinary
  /// schools give each class its own room. With this on, a camera belongs to
  /// the room and a timetable decides whose lesson is in front of it.
  final bool groupMode;

  factory SchoolSettings.fromJson(Map<String, dynamic> json) => SchoolSettings(
        liveVideoEnabled: json['live_video_enabled'] as bool? ?? true,
        groupMode: json['group_mode'] as bool? ?? false,
      );

  SchoolSettings copyWith({bool? liveVideoEnabled, bool? groupMode}) =>
      SchoolSettings(
        liveVideoEnabled: liveVideoEnabled ?? this.liveVideoEnabled,
        groupMode: groupMode ?? this.groupMode,
      );
}
