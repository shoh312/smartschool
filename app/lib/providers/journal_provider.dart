import 'package:flutter/foundation.dart';

import '../models/grade.dart';
import '../models/homework.dart';
import '../services/journal_service.dart';

/// Read-side view of grades/homework for a student (parent) or a school (director).
class JournalProvider extends ChangeNotifier {
  JournalService? _service;

  List<Grade> grades = [];
  List<Homework> homework = [];
  bool isLoading = false;
  String? error;

  void attach(JournalService service) {
    _service = service;
  }

  Future<void> loadForStudent(int studentId) async {
    isLoading = true;
    error = null;
    notifyListeners();
    try {
      grades = await _service!.listGrades(studentId: studentId);
      homework = await _service!.listHomework(studentId: studentId);
    } catch (exception) {
      error = exception.toString();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadForSchool() async {
    isLoading = true;
    error = null;
    notifyListeners();
    try {
      grades = await _service!.listGrades();
    } catch (exception) {
      error = exception.toString();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }
}
