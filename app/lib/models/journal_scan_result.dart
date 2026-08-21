/// One row detected in a scanned journal photo, before the teacher has
/// reviewed it. Mutable (unlike the rest of this app's models) because the
/// review screen edits these fields in place as the teacher fixes a
/// mismatched student or a misread grade.
class JournalScanResult {
  JournalScanResult({
    required this.rawName,
    required this.absent,
    this.grade,
    this.studentId,
    this.matchedName,
    this.confidence = 0,
  });

  final String rawName;

  /// True when the journal cell held an absence mark (e.g. "н") rather than
  /// a grade -- read straight off the page, never guessed. Absent rows have
  /// no [grade] and aren't sent to POST /grades on confirm.
  final bool absent;
  int? grade;
  int? studentId;
  String? matchedName;
  final double confidence;

  factory JournalScanResult.fromJson(Map<String, dynamic> json) {
    return JournalScanResult(
      rawName: json['raw_name'] as String? ?? '',
      absent: json['absent'] as bool? ?? false,
      grade: json['grade'] as int?,
      studentId: json['student_id'] as int?,
      matchedName: json['matched_name'] as String?,
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0,
    );
  }
}
