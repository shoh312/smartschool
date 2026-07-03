import 'package:flutter/foundation.dart';

import '../models/class_assignment.dart';
import '../models/student.dart';
import '../services/journal_service.dart';
import '../services/teacher_service.dart';

/// Session state for a logged-in teacher: their assigned classes plus
/// grade/homework submission.
class TeacherProvider extends ChangeNotifier {
  TeacherService? _teacherService;
  JournalService? _journalService;

  List<ClassAssignment> myClasses = [];
  List<Student> roster = [];
  bool isLoading = false;
  bool isRosterLoading = false;
  String? error;

  void attach(TeacherService teacherService, JournalService journalService) {
    _teacherService = teacherService;
    _journalService = journalService;
  }

  Future<void> loadMyClasses() async {
    isLoading = true;
    error = null;
    notifyListeners();
    try {
      myClasses = await _teacherService!.myClasses();
    } catch (exception) {
      error = exception.toString();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadRoster(int classId) async {
    isRosterLoading = true;
    error = null;
    notifyListeners();
    try {
      roster = await _teacherService!.classRoster(classId);
    } catch (exception) {
      error = exception.toString();
    } finally {
      isRosterLoading = false;
      notifyListeners();
    }
  }

  Future<bool> submitGrade({
    required int studentId,
    required int classId,
    required String subject,
    required int value,
    String? comment,
  }) async {
    isLoading = true;
    error = null;
    notifyListeners();
    try {
      await _journalService!.createGrade(
        studentId: studentId,
        classId: classId,
        subject: subject,
        value: value,
        comment: comment,
      );
      return true;
    } catch (exception) {
      error = exception.toString();
      return false;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> submitHomework({
    required int classId,
    required String subject,
    required String description,
    DateTime? dueDate,
  }) async {
    isLoading = true;
    error = null;
    notifyListeners();
    try {
      await _journalService!.createHomework(
        classId: classId,
        subject: subject,
        description: description,
        dueDate: dueDate,
      );
      return true;
    } catch (exception) {
      error = exception.toString();
      return false;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }
}
