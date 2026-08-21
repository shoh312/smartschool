import 'package:flutter/foundation.dart';

import '../models/grade.dart';
import '../services/journal_service.dart';
import '../utils/error_formatter.dart';

/// Read-side view of grades for a student (parent) or a school (director).
class JournalProvider extends ChangeNotifier {
  JournalService? _service;

  List<Grade> grades = [];
  bool isLoading = false;
  String? error;

  void attach(JournalService service) {
    _service = service;
  }

  Future<void> loadForStudent(int studentId, {int? parentId, bool viaPublicServer = false}) async {
    isLoading = true;
    error = null;
    // Clear immediately so a different student's/class's screen never
    // renders leftover grades while loading, or forever if this fails.
    grades = [];
    notifyListeners();
    try {
      grades = await _service!.listGrades(
        studentId: studentId,
        parentId: parentId,
        viaPublicServer: viaPublicServer,
      );
    } catch (exception) {
      error = classifyError(exception);
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadForSchool() async {
    isLoading = true;
    error = null;
    grades = [];
    notifyListeners();
    try {
      grades = await _service!.listGrades();
    } catch (exception) {
      error = classifyError(exception);
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadForClass(int classId) async {
    isLoading = true;
    error = null;
    grades = [];
    notifyListeners();
    try {
      grades = await _service!.listGrades(classId: classId);
    } catch (exception) {
      error = classifyError(exception);
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }
}
