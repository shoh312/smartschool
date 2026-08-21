class RankInfo {
  const RankInfo({this.position, required this.outOf});

  final int? position;
  final int outOf;

  factory RankInfo.fromJson(Map<String, dynamic> json) => RankInfo(
        position: json['position'] as int?,
        outOf: json['out_of'] as int? ?? 0,
      );
}

class SubjectAverage {
  const SubjectAverage({
    required this.subject,
    required this.average,
    required this.gradeCount,
  });

  final String subject;
  final double average;
  final int gradeCount;

  factory SubjectAverage.fromJson(Map<String, dynamic> json) => SubjectAverage(
        subject: json['subject'] as String? ?? '',
        average: (json['average'] as num?)?.toDouble() ?? 0,
        gradeCount: json['grade_count'] as int? ?? 0,
      );
}

/// One subject's standing across a whole class.
///
/// [studentCount] is the part that isn't on [SubjectAverage]: it says how
/// many pupils the figure actually covers, which is the difference between
/// "this class is weak at music" and "the two pupils graded in music did
/// badly".
class ClassSubjectAverage {
  const ClassSubjectAverage({
    required this.subject,
    required this.average,
    required this.gradeCount,
    required this.studentCount,
  });

  final String subject;
  final double average;
  final int gradeCount;
  final int studentCount;

  factory ClassSubjectAverage.fromJson(Map<String, dynamic> json) => ClassSubjectAverage(
        subject: json['subject'] as String? ?? '',
        average: (json['average'] as num?)?.toDouble() ?? 0,
        gradeCount: json['grade_count'] as int? ?? 0,
        studentCount: json['student_count'] as int? ?? 0,
      );
}

class QuarterPoint {
  const QuarterPoint({required this.quarter, this.overallAverage});

  final int quarter;
  final double? overallAverage;

  factory QuarterPoint.fromJson(Map<String, dynamic> json) => QuarterPoint(
        quarter: json['quarter'] as int,
        overallAverage: (json['overall_average'] as num?)?.toDouble(),
      );
}

class StudentAnalyticsOverview {
  const StudentAnalyticsOverview({
    required this.studentId,
    required this.firstName,
    required this.lastName,
    required this.quarter,
    this.overallAverage,
    required this.classRank,
    required this.parallelRank,
    required this.schoolRank,
    this.classAverage,
    this.parallelAverage,
    this.schoolAverage,
    required this.subjectBreakdown,
    this.strongestSubject,
    this.weakestSubject,
    this.lessonAttendanceRate,
    this.trend = const [],
  });

  final int studentId;
  final String firstName;
  final String lastName;
  final int quarter;
  final double? overallAverage;
  final RankInfo classRank;
  final RankInfo parallelRank;
  final RankInfo schoolRank;
  final double? classAverage;
  final double? parallelAverage;
  final double? schoolAverage;
  final List<SubjectAverage> subjectBreakdown;
  final String? strongestSubject;
  final String? weakestSubject;
  final double? lessonAttendanceRate;
  final List<QuarterPoint> trend;

  String get fullName => '$firstName $lastName';

  factory StudentAnalyticsOverview.fromJson(Map<String, dynamic> json) {
    final raw = json['subject_breakdown'] as List<dynamic>? ?? [];
    final rawTrend = json['trend'] as List<dynamic>? ?? [];
    return StudentAnalyticsOverview(
      studentId: json['student_id'] as int,
      firstName: json['first_name'] as String? ?? '',
      lastName: json['last_name'] as String? ?? '',
      quarter: json['quarter'] as int? ?? 1,
      overallAverage: (json['overall_average'] as num?)?.toDouble(),
      classRank: RankInfo.fromJson(json['class_rank'] as Map<String, dynamic>),
      parallelRank: RankInfo.fromJson(json['parallel_rank'] as Map<String, dynamic>),
      schoolRank: RankInfo.fromJson(json['school_rank'] as Map<String, dynamic>),
      classAverage: (json['class_average'] as num?)?.toDouble(),
      parallelAverage: (json['parallel_average'] as num?)?.toDouble(),
      schoolAverage: (json['school_average'] as num?)?.toDouble(),
      subjectBreakdown: raw
          .map((e) => SubjectAverage.fromJson(e as Map<String, dynamic>))
          .toList(),
      strongestSubject: json['strongest_subject'] as String?,
      weakestSubject: json['weakest_subject'] as String?,
      lessonAttendanceRate: (json['lesson_attendance_rate'] as num?)?.toDouble(),
      trend: rawTrend.map((e) => QuarterPoint.fromJson(e as Map<String, dynamic>)).toList(),
    );
  }
}

class LeaderboardEntry {
  const LeaderboardEntry({
    required this.studentId,
    required this.firstName,
    required this.lastName,
    this.classId,
    this.className,
    this.overallAverage,
    required this.position,
    required this.outOf,
  });

  final int studentId;
  final String firstName;
  final String lastName;
  final int? classId;
  final String? className;
  final double? overallAverage;
  final int position;
  final int outOf;

  String get fullName => '$firstName $lastName';

  factory LeaderboardEntry.fromJson(Map<String, dynamic> json) => LeaderboardEntry(
        studentId: json['student_id'] as int,
        firstName: json['first_name'] as String? ?? '',
        lastName: json['last_name'] as String? ?? '',
        classId: json['class_id'] as int?,
        className: json['class_name'] as String?,
        overallAverage: (json['overall_average'] as num?)?.toDouble(),
        position: json['position'] as int? ?? 0,
        outOf: json['out_of'] as int? ?? 0,
      );
}

class DeclinerEntry {
  const DeclinerEntry({
    required this.studentId,
    required this.firstName,
    required this.lastName,
    required this.currentAverage,
    required this.previousAverage,
    required this.delta,
    this.className,
  });

  final int studentId;
  final String firstName;
  final String lastName;

  /// Which class the pupil is in -- a name on its own doesn't let staff
  /// place a student in a school of any size.
  final String? className;
  final double currentAverage;
  final double previousAverage;
  final double delta;

  String get fullName => '$firstName $lastName';

  factory DeclinerEntry.fromJson(Map<String, dynamic> json) => DeclinerEntry(
        studentId: json['student_id'] as int,
        firstName: json['first_name'] as String? ?? '',
        lastName: json['last_name'] as String? ?? '',
        className: json['class_name'] as String?,
        currentAverage: (json['current_average'] as num?)?.toDouble() ?? 0,
        previousAverage: (json['previous_average'] as num?)?.toDouble() ?? 0,
        delta: (json['delta'] as num?)?.toDouble() ?? 0,
      );
}

class NeedsAttentionResult {
  const NeedsAttentionResult({required this.bottomPerformers, required this.biggestDecliners});

  final List<LeaderboardEntry> bottomPerformers;
  final List<DeclinerEntry> biggestDecliners;

  factory NeedsAttentionResult.fromJson(Map<String, dynamic> json) {
    final bottom = json['bottom_performers'] as List<dynamic>? ?? [];
    final decliners = json['biggest_decliners'] as List<dynamic>? ?? [];
    return NeedsAttentionResult(
      bottomPerformers: bottom.map((e) => LeaderboardEntry.fromJson(e as Map<String, dynamic>)).toList(),
      biggestDecliners: decliners.map((e) => DeclinerEntry.fromJson(e as Map<String, dynamic>)).toList(),
    );
  }
}
