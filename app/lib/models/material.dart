// Learning materials: a lesson a pupil walks through one screen at a time,
// with questions mixed in between the explanation pages.
//
// The same models serve both sides of the wire, but note what a pupil's
// copy never carries: [MaterialBlock.correct] is only ever filled in on
// the teacher's own device, from the school server. The Public Server
// strips it, so a pupil's app has no answer key to find.

enum BlockType { page, question }

enum QuestionType { single, trueFalse, fill, match, order }

enum AssignmentMode { control, practice }

BlockType blockTypeFromJson(String? raw) =>
    raw == 'question' ? BlockType.question : BlockType.page;

String blockTypeToJson(BlockType type) =>
    type == BlockType.question ? 'question' : 'page';

QuestionType? questionTypeFromJson(String? raw) {
  switch (raw) {
    case 'single':
      return QuestionType.single;
    case 'truefalse':
      return QuestionType.trueFalse;
    case 'fill':
      return QuestionType.fill;
    case 'match':
      return QuestionType.match;
    case 'order':
      return QuestionType.order;
    default:
      return null;
  }
}

String questionTypeToJson(QuestionType type) {
  switch (type) {
    case QuestionType.single:
      return 'single';
    case QuestionType.trueFalse:
      return 'truefalse';
    case QuestionType.fill:
      return 'fill';
    case QuestionType.match:
      return 'match';
    case QuestionType.order:
      return 'order';
  }
}

AssignmentMode assignmentModeFromJson(String? raw) =>
    raw == 'control' ? AssignmentMode.control : AssignmentMode.practice;

String assignmentModeToJson(AssignmentMode mode) =>
    mode == AssignmentMode.control ? 'control' : 'practice';

class MaterialBlock {
  const MaterialBlock({
    this.id,
    this.position = 0,
    required this.blockType,
    this.body = '',
    this.questionType,
    this.options,
    this.correct,
    this.points = 1,
  });

  final int? id;
  final int position;
  final BlockType blockType;
  final String body;
  final QuestionType? questionType;

  /// Shape depends on [questionType]:
  /// single -> `List<String>`; match -> `{left: [...], right: [...]}`;
  /// order -> `List<String>`; trueFalse and fill -> null.
  final dynamic options;

  /// Null on anything a pupil's device received -- see the file header.
  final dynamic correct;

  final int points;

  bool get isQuestion => blockType == BlockType.question;

  List<String> get optionList =>
      options is List ? (options as List).map((e) => '$e').toList() : const [];

  factory MaterialBlock.fromJson(Map<String, dynamic> json) => MaterialBlock(
        id: json['id'] as int?,
        position: json['position'] as int? ?? 0,
        blockType: blockTypeFromJson(json['block_type'] as String?),
        body: json['body'] as String? ?? '',
        questionType: questionTypeFromJson(json['question_type'] as String?),
        options: json['options'],
        correct: json['correct'],
        points: json['points'] as int? ?? 1,
      );

  Map<String, dynamic> toJson() => {
        'block_type': blockTypeToJson(blockType),
        'body': body,
        if (questionType != null) 'question_type': questionTypeToJson(questionType!),
        if (options != null) 'options': options,
        if (correct != null) 'correct': correct,
        'points': points,
      };

  MaterialBlock copyWith({
    BlockType? blockType,
    String? body,
    QuestionType? questionType,
    dynamic options,
    dynamic correct,
    int? points,
  }) =>
      MaterialBlock(
        id: id,
        position: position,
        blockType: blockType ?? this.blockType,
        body: body ?? this.body,
        questionType: questionType ?? this.questionType,
        options: options ?? this.options,
        correct: correct ?? this.correct,
        points: points ?? this.points,
      );
}

/// A teacher's library item.
class LearningMaterial {
  const LearningMaterial({
    required this.id,
    required this.title,
    this.description,
    required this.subject,
    required this.teacherId,
    this.teacherName,
    this.questionCount = 0,
    this.pageCount = 0,
    this.maxScore = 0,
    this.assignedClassCount = 0,
    this.updatedAt,
    this.blocks = const [],
  });

  final int id;
  final String title;
  final String? description;
  final String subject;
  final int teacherId;
  final String? teacherName;
  final int questionCount;
  final int pageCount;
  final int maxScore;
  final int assignedClassCount;
  final DateTime? updatedAt;
  final List<MaterialBlock> blocks;

  factory LearningMaterial.fromJson(Map<String, dynamic> json) => LearningMaterial(
        id: json['id'] as int,
        title: json['title'] as String? ?? '',
        description: json['description'] as String?,
        subject: json['subject'] as String? ?? '',
        teacherId: json['teacher_id'] as int? ?? 0,
        teacherName: json['teacher_name'] as String?,
        questionCount: json['question_count'] as int? ?? 0,
        pageCount: json['page_count'] as int? ?? 0,
        maxScore: json['max_score'] as int? ?? 0,
        assignedClassCount: json['assigned_class_count'] as int? ?? 0,
        updatedAt: _date(json['updated_at']),
        blocks: (json['blocks'] as List<dynamic>? ?? [])
            .map((e) => MaterialBlock.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

/// One material handed to one class -- the teacher's view of it.
class MaterialAssignment {
  const MaterialAssignment({
    required this.id,
    required this.materialId,
    required this.materialTitle,
    required this.subject,
    required this.classId,
    this.className,
    required this.mode,
    this.dueAt,
    this.maxAttempts,
    this.publishedAt,
    this.gradesTransferredAt,
    this.questionCount = 0,
    this.maxScore = 0,
    this.studentCount = 0,
    this.submittedCount = 0,
    this.resultsVisible = false,
  });

  final int id;
  final int materialId;
  final String materialTitle;
  final String subject;
  final int classId;
  final String? className;
  final AssignmentMode mode;
  final DateTime? dueAt;
  final int? maxAttempts;
  final DateTime? publishedAt;
  final DateTime? gradesTransferredAt;
  final int questionCount;
  final int maxScore;
  final int studentCount;
  final int submittedCount;

  /// False while a control assignment is still running -- the teacher may
  /// see who has finished, but no marks.
  final bool resultsVisible;

  bool get isControl => mode == AssignmentMode.control;

  factory MaterialAssignment.fromJson(Map<String, dynamic> json) => MaterialAssignment(
        id: json['id'] as int,
        materialId: json['material_id'] as int? ?? 0,
        materialTitle: json['material_title'] as String? ?? '',
        subject: json['subject'] as String? ?? '',
        classId: json['class_id'] as int? ?? 0,
        className: json['class_name'] as String?,
        mode: assignmentModeFromJson(json['mode'] as String?),
        dueAt: _date(json['due_at']),
        maxAttempts: json['max_attempts'] as int?,
        publishedAt: _date(json['published_at']),
        gradesTransferredAt: _date(json['grades_transferred_at']),
        questionCount: json['question_count'] as int? ?? 0,
        maxScore: json['max_score'] as int? ?? 0,
        studentCount: json['student_count'] as int? ?? 0,
        submittedCount: json['submitted_count'] as int? ?? 0,
        resultsVisible: json['results_visible'] as bool? ?? false,
      );
}

class AssignmentResultRow {
  const AssignmentResultRow({
    required this.studentId,
    required this.studentName,
    this.submittedAt,
    this.attemptCount = 0,
    this.score,
    this.maxScore,
    this.percent,
    this.suggestedGrade,
    this.transferred = false,
  });

  final int studentId;
  final String studentName;
  final DateTime? submittedAt;
  final int attemptCount;
  final int? score;
  final int? maxScore;
  final int? percent;
  final int? suggestedGrade;
  final bool transferred;

  bool get hasSubmitted => submittedAt != null;

  factory AssignmentResultRow.fromJson(Map<String, dynamic> json) => AssignmentResultRow(
        studentId: json['student_id'] as int,
        studentName: json['student_name'] as String? ?? '',
        submittedAt: _date(json['submitted_at']),
        attemptCount: json['attempt_count'] as int? ?? 0,
        score: json['score'] as int?,
        maxScore: json['max_score'] as int?,
        percent: json['percent'] as int?,
        suggestedGrade: json['suggested_grade'] as int?,
        transferred: json['transferred'] as bool? ?? false,
      );
}

class AssignmentResults {
  const AssignmentResults({
    required this.assignment,
    required this.resultsVisible,
    required this.rows,
  });

  final MaterialAssignment assignment;
  final bool resultsVisible;
  final List<AssignmentResultRow> rows;

  factory AssignmentResults.fromJson(Map<String, dynamic> json) => AssignmentResults(
        assignment: MaterialAssignment.fromJson(json['assignment'] as Map<String, dynamic>),
        resultsVisible: json['results_visible'] as bool? ?? false,
        rows: (json['rows'] as List<dynamic>? ?? [])
            .map((e) => AssignmentResultRow.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

/// A pupil's (or their parent's) view of one assignment.
class StudentAssignment {
  const StudentAssignment({
    required this.id,
    required this.materialId,
    required this.title,
    this.description,
    required this.subject,
    this.teacherName,
    this.className,
    required this.mode,
    this.dueAt,
    this.maxAttempts,
    this.questionCount = 0,
    this.maxScore = 0,
    this.attemptsUsed = 0,
    this.attemptsLeft,
    this.submittedAt,
    this.isOverdue = false,
    this.canStart = false,
    this.score,
    this.percent,
    this.scoreVisible = false,
    this.blocks = const [],
    this.attemptId,
    this.savedAnswers = const {},
  });

  final int id;
  final int materialId;
  final String title;
  final String? description;
  final String subject;
  final String? teacherName;
  final String? className;
  final AssignmentMode mode;
  final DateTime? dueAt;
  final int? maxAttempts;
  final int questionCount;
  final int maxScore;
  final int attemptsUsed;

  /// Null means unlimited.
  final int? attemptsLeft;

  final DateTime? submittedAt;
  final bool isOverdue;
  final bool canStart;
  final int? score;
  final int? percent;
  final bool scoreVisible;

  final List<MaterialBlock> blocks;
  final int? attemptId;
  final Map<String, dynamic> savedAnswers;

  bool get isControl => mode == AssignmentMode.control;
  bool get isDone => submittedAt != null;

  factory StudentAssignment.fromJson(Map<String, dynamic> json) => StudentAssignment(
        id: json['id'] as int,
        materialId: json['material_id'] as int? ?? 0,
        title: json['title'] as String? ?? '',
        description: json['description'] as String?,
        subject: json['subject'] as String? ?? '',
        teacherName: json['teacher_name'] as String?,
        className: json['class_name'] as String?,
        mode: assignmentModeFromJson(json['mode'] as String?),
        dueAt: _date(json['due_at']),
        maxAttempts: json['max_attempts'] as int?,
        questionCount: json['question_count'] as int? ?? 0,
        maxScore: json['max_score'] as int? ?? 0,
        attemptsUsed: json['attempts_used'] as int? ?? 0,
        attemptsLeft: json['attempts_left'] as int?,
        submittedAt: _date(json['submitted_at']),
        isOverdue: json['is_overdue'] as bool? ?? false,
        canStart: json['can_start'] as bool? ?? false,
        score: json['score'] as int?,
        percent: json['percent'] as int?,
        scoreVisible: json['score_visible'] as bool? ?? false,
        blocks: (json['blocks'] as List<dynamic>? ?? [])
            .map((e) => MaterialBlock.fromJson(e as Map<String, dynamic>))
            .toList(),
        attemptId: json['attempt_id'] as int?,
        savedAnswers: (json['saved_answers'] as Map<String, dynamic>?) ?? const {},
      );
}

class AttemptResult {
  const AttemptResult({
    required this.attemptId,
    required this.submittedAt,
    required this.scoreVisible,
    this.score,
    this.maxScore,
    this.percent,
    this.perQuestion,
  });

  final int attemptId;
  final DateTime submittedAt;
  final bool scoreVisible;
  final int? score;
  final int? maxScore;
  final int? percent;

  /// block id -> right or wrong. Practice mode only; null for a control
  /// test, where the pupil is told nothing.
  final Map<String, bool>? perQuestion;

  factory AttemptResult.fromJson(Map<String, dynamic> json) => AttemptResult(
        attemptId: json['attempt_id'] as int,
        submittedAt: _date(json['submitted_at']) ?? DateTime.now(),
        scoreVisible: json['score_visible'] as bool? ?? false,
        score: json['score'] as int?,
        maxScore: json['max_score'] as int?,
        percent: json['percent'] as int?,
        perQuestion: (json['per_question'] as Map<String, dynamic>?)
            ?.map((key, value) => MapEntry(key, value == true)),
      );
}

DateTime? _date(dynamic value) {
  if (value == null) return null;
  return DateTime.tryParse(value as String);
}

/// What the AI drafted, on its way to the teacher for review.
///
/// Deliberately not a [LearningMaterial]: nothing has been saved, there is
/// no id, and the whole point is that the teacher edits it first.
class AiDraft {
  const AiDraft({
    required this.title,
    this.description,
    this.blocks = const [],
    this.droppedCount = 0,
  });

  final String title;
  final String? description;
  final List<MaterialBlock> blocks;

  /// How many blocks the model produced that couldn't be made answerable.
  /// Surfaced so the teacher is told why they asked for ten questions and
  /// got eight, instead of quietly receiving fewer.
  final int droppedCount;

  factory AiDraft.fromJson(Map<String, dynamic> json) => AiDraft(
        title: json['title'] as String? ?? '',
        description: json['description'] as String?,
        blocks: (json['blocks'] as List<dynamic>? ?? [])
            .map((e) => MaterialBlock.fromJson(e as Map<String, dynamic>))
            .toList(),
        droppedCount: json['dropped_count'] as int? ?? 0,
      );
}
