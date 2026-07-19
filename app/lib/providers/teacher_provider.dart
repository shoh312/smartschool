import 'package:flutter/foundation.dart';

import '../models/class_assignment.dart';
import '../models/grade.dart';
import '../models/student.dart';
import '../services/journal_service.dart';
import '../services/teacher_service.dart';

/// Session state for a logged-in teacher: their assigned classes, class
/// roster, and the grade journal for whichever class/subject is open.
class TeacherProvider extends ChangeNotifier {
  TeacherService? _teacherService;
  JournalService? _journalService;

  List<ClassAssignment> myClasses = [];
  List<Student> roster = [];
  List<Grade> classGrades = [];
  bool isLoading = false;
  bool isRosterLoading = false;
  bool isJournalLoading = false;
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
    // Clear immediately so a screen for a different class never renders
    // this class's leftover roster while loading, or forever if this
    // fetch fails.
    roster = [];
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

  Future<void> loadClassGrades(int classId, String subject) async {
    isJournalLoading = true;
    error = null;
    classGrades = [];
    notifyListeners();
    try {
      classGrades = await _journalService!.listGrades(
        classId: classId,
        subject: subject,
      );
    } catch (exception) {
      error = exception.toString();
    } finally {
      isJournalLoading = false;
      notifyListeners();
    }
  }

  Future<bool> submitGrade({
    required int studentId,
    required int classId,
    required String subject,
    required int value,
    String? comment,
    DateTime? gradeDate,
  }) async {
    error = null;
    try {
      final grade = await _journalService!.createGrade(
        studentId: studentId,
        classId: classId,
        subject: subject,
        value: value,
        comment: comment,
        gradeDate: gradeDate,
      );
      classGrades = [...classGrades, grade];
      notifyListeners();
      return true;
    } catch (exception) {
      error = exception.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateGrade({
    required int gradeId,
    required int value,
    String? comment,
  }) async {
    error = null;
    try {
      final updated = await _journalService!.updateGrade(
        gradeId: gradeId,
        value: value,
        comment: comment,
      );
      classGrades = [
        for (final grade in classGrades)
          if (grade.id == gradeId) updated else grade,
      ];
      notifyListeners();
      return true;
    } catch (exception) {
      error = exception.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteGrade(int gradeId) async {
    error = null;
    try {
      await _journalService!.deleteGrade(gradeId);
      classGrades = classGrades.where((grade) => grade.id != gradeId).toList();
      notifyListeners();
      return true;
    } catch (exception) {
      error = exception.toString();
      notifyListeners();
      return false;
    }
  }
}
