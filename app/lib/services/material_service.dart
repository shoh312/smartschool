import '../models/material.dart';
import 'api_client.dart';
import 'public_api_client.dart';

/// Learning materials, which live on both servers for a reason:
///
/// * teachers author and mark on the **school server** -- that's where the
///   journal is, and where the answer key belongs;
/// * pupils and parents read and answer through the **Public Server**,
///   because a pupil doing homework at home can't reach the school's LAN.
///
/// Finished work travels back to the school on its own (a background worker
/// there collects it), so nothing in this class has to bridge the two.
class MaterialService {
  MaterialService(this._apiClient, this._publicApiClient);

  final ApiClient _apiClient;
  final PublicApiClient _publicApiClient;

  // ------------------------------------------------------------------
  // Teacher: library
  // ------------------------------------------------------------------

  /// [schoolWide] switches from "what I wrote" to the whole school's
  /// shelf -- same rows, but including colleagues' work, each carrying the
  /// author's name so the app can say whose it is.
  Future<List<LearningMaterial>> fetchLibrary({bool schoolWide = false}) async {
    final data = await _apiClient.get(
      '/materials',
      query: {'scope': schoolWide ? 'school' : 'mine'},
    ) as List<dynamic>;
    return data
        .map((item) => LearningMaterial.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<LearningMaterial> fetchMaterial(int id) async {
    final data = await _apiClient.get('/materials/$id') as Map<String, dynamic>;
    return LearningMaterial.fromJson(data);
  }

  Future<LearningMaterial> createMaterial({
    required String title,
    String? description,
    String? subject,
    required List<MaterialBlock> blocks,
  }) async {
    final data = await _apiClient.post('/materials', body: {
      'title': title,
      if (description != null && description.isNotEmpty) 'description': description,
      if (subject != null && subject.isNotEmpty) 'subject': subject,
      'blocks': blocks.map((b) => b.toJson()).toList(),
    }) as Map<String, dynamic>;
    return LearningMaterial.fromJson(data);
  }

  Future<LearningMaterial> updateMaterial(
    int id, {
    String? title,
    String? description,
    List<MaterialBlock>? blocks,
  }) async {
    final data = await _apiClient.patch('/materials/$id', body: {
      if (title != null) 'title': title,
      if (description != null) 'description': description,
      if (blocks != null) 'blocks': blocks.map((b) => b.toJson()).toList(),
    }) as Map<String, dynamic>;
    return LearningMaterial.fromJson(data);
  }

  Future<void> deleteMaterial(int id) => _apiClient.delete('/materials/$id');

  /// The way round the "already handed out, can't edit" lock.
  Future<LearningMaterial> duplicateMaterial(int id) async {
    final data = await _apiClient.post('/materials/$id/duplicate') as Map<String, dynamic>;
    return LearningMaterial.fromJson(data);
  }

  /// Turns a teacher's pasted text into blocks. Nothing is saved -- the
  /// result is dropped into the editor for them to check first.
  Future<List<MaterialBlock>> parsePaste(String text) async {
    final data = await _apiClient.post(
      '/materials/parse-paste',
      body: {'text': text},
    ) as Map<String, dynamic>;
    return (data['blocks'] as List<dynamic>)
        .map((e) => MaterialBlock.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Drafts a material with Gemini. Saves nothing -- the teacher reviews
  /// and edits the blocks, then the normal createMaterial stores them.
  ///
  /// Sent as multipart because the source may be a photo of a textbook
  /// page; with a topic or pasted text the file is simply absent.
  Future<AiDraft> generateWithAi({
    required bool testOnly,
    String? topic,
    String? sourceText,
    String? imagePath,
    String? className,
    required int questionCount,
    required int pageCount,
    required List<QuestionType> questionTypes,
    required String difficulty,
    String language = 'tojik (kirill)',
  }) async {
    final data = await _apiClient.multipartPost(
      '/materials/ai/generate',
      fields: {
        'kind': testOnly ? 'test' : 'lesson',
        if (topic != null && topic.isNotEmpty) 'topic': topic,
        if (sourceText != null && sourceText.isNotEmpty) 'source_text': sourceText,
        if (className != null && className.isNotEmpty) 'class_name': className,
        'question_count': questionCount.toString(),
        'page_count': pageCount.toString(),
        // Comma-separated: multipart repeats a key for a list, which the
        // server would then have to special-case.
        'question_types': questionTypes.map(questionTypeToJson).join(','),
        'difficulty': difficulty,
        'language': language,
      },
      filePath: imagePath,
    ) as Map<String, dynamic>;
    return AiDraft.fromJson(data);
  }

  // ------------------------------------------------------------------
  // Teacher: handing out and marking
  // ------------------------------------------------------------------

  Future<List<MaterialAssignment>> fetchAssignments({int? classId, int? materialId}) async {
    final data = await _apiClient.get('/material-assignments', query: {
      if (classId != null) 'class_id': classId.toString(),
      if (materialId != null) 'material_id': materialId.toString(),
    }) as List<dynamic>;
    return data
        .map((item) => MaterialAssignment.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<List<MaterialAssignment>> assign({
    required int materialId,
    required List<int> classIds,
    required AssignmentMode mode,
    DateTime? dueAt,
    int? maxAttempts,
  }) async {
    final data = await _apiClient.post('/material-assignments', body: {
      'material_id': materialId,
      'class_ids': classIds,
      'mode': assignmentModeToJson(mode),
      // Sent as UTC with an explicit marker rather than a bare local
      // timestamp: the server can't otherwise tell a Dushanbe wall-clock
      // deadline from a UTC one, and guessing wrong moves every deadline
      // five hours.
      if (dueAt != null) 'due_at': dueAt.toUtc().toIso8601String(),
      if (maxAttempts != null) 'max_attempts': maxAttempts,
    }) as List<dynamic>;
    return data
        .map((item) => MaterialAssignment.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<MaterialAssignment> updateAssignment(
    int assignmentId, {
    required int materialId,
    required int classId,
    required AssignmentMode mode,
    DateTime? dueAt,
    int? maxAttempts,
  }) async {
    final data = await _apiClient.patch('/material-assignments/$assignmentId', body: {
      'material_id': materialId,
      'class_ids': [classId],
      'mode': assignmentModeToJson(mode),
      if (dueAt != null) 'due_at': dueAt.toUtc().toIso8601String(),
      if (maxAttempts != null) 'max_attempts': maxAttempts,
    }) as Map<String, dynamic>;
    return MaterialAssignment.fromJson(data);
  }

  Future<void> deleteAssignment(int assignmentId) =>
      _apiClient.delete('/material-assignments/$assignmentId');

  Future<AssignmentResults> fetchResults(int assignmentId) async {
    final data = await _apiClient
        .get('/material-assignments/$assignmentId/results') as Map<String, dynamic>;
    return AssignmentResults.fromJson(data);
  }

  /// Pushes the marks the teacher approved into the journal. Only the
  /// pupils in [grades] get one.
  Future<AssignmentResults> transferGrades(
    int assignmentId,
    Map<int, int> grades,
  ) async {
    final data = await _apiClient.post(
      '/material-assignments/$assignmentId/transfer-grades',
      body: {
        'items': grades.entries
            .map((entry) => {'student_id': entry.key, 'value': entry.value})
            .toList(),
      },
    ) as Map<String, dynamic>;
    return AssignmentResults.fromJson(data);
  }

  // ------------------------------------------------------------------
  // Pupil (and parent, read-only) -- Public Server
  // ------------------------------------------------------------------

  Future<List<StudentAssignment>> fetchStudentAssignments(int studentId) async {
    final data = await _publicApiClient.get(
      '/materials/assignments',
      query: {'student_id': studentId.toString()},
    ) as List<dynamic>;
    return data
        .map((item) => StudentAssignment.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<StudentAssignment> fetchStudentAssignment(int assignmentId, int studentId) async {
    final data = await _publicApiClient.get(
      '/materials/assignments/$assignmentId',
      query: {'student_id': studentId.toString()},
    ) as Map<String, dynamic>;
    return StudentAssignment.fromJson(data);
  }

  /// Opens (or resumes) an attempt and returns the playable content.
  Future<StudentAssignment> startAttempt(int assignmentId, int studentId) async {
    final data = await _publicApiClient.post(
      '/materials/assignments/$assignmentId/start?student_id=$studentId',
    ) as Map<String, dynamic>;
    return StudentAssignment.fromJson(data);
  }

  /// Saves one answer as the pupil goes, so a closed app costs them nothing.
  /// Returns whether it was right -- null in a control test, where the
  /// pupil is deliberately told nothing until the deadline.
  Future<bool?> submitAnswer({
    required int attemptId,
    required int blockId,
    required dynamic answer,
  }) async {
    final data = await _publicApiClient.post(
      '/materials/attempts/$attemptId/answer',
      body: {'block_id': blockId, 'answer': answer},
    ) as Map<String, dynamic>;
    return data['correct'] as bool?;
  }

  Future<AttemptResult> finishAttempt(int attemptId) async {
    final data = await _publicApiClient
        .post('/materials/attempts/$attemptId/submit') as Map<String, dynamic>;
    return AttemptResult.fromJson(data);
  }
}
