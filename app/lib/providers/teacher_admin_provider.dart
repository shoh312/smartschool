import 'package:flutter/foundation.dart';

import '../models/class_subject_assignment.dart';
import '../models/teacher.dart';
import '../services/teacher_service.dart';

/// Director-side management of teachers and their class assignments.
class TeacherAdminProvider extends ChangeNotifier {
  TeacherService? _service;

  List<Teacher> teachers = [];
  List<ClassSubjectAssignment> classSubjects = [];
  List<Teacher> subjectTeachers = [];
  bool isLoading = false;
  bool isClassSubjectsLoading = false;
  bool isSubjectTeachersLoading = false;
  String? error;

  void attach(TeacherService service) {
    _service = service;
  }

  Future<void> loadTeachers() async {
    isLoading = true;
    error = null;
    notifyListeners();
    try {
      teachers = await _service!.listTeachers();
    } catch (exception) {
      error = exception.toString();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> createTeacher({
    required String fullName,
    required String email,
    required String password,
    String? subject,
  }) async {
    isLoading = true;
    error = null;
    notifyListeners();
    try {
      final created = await _service!.createTeacher(
        fullName: fullName,
        email: email,
        password: password,
        subject: subject,
      );
      teachers = [created, ...teachers];
      return true;
    } catch (exception) {
      error = exception.toString();
      return false;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> deleteTeacher(int teacherId) async {
    isLoading = true;
    error = null;
    notifyListeners();
    try {
      await _service!.deleteTeacher(teacherId);
      teachers = teachers.where((teacher) => teacher.id != teacherId).toList();
      // The backend cascades and deletes all of this teacher's class
      // assignments too, so drop them here or a stale tile stays visible
      // and "remove assignment" 404s against a row that's already gone.
      classSubjects = classSubjects
          .where((assignment) => assignment.teacherId != teacherId)
          .toList();
      return true;
    } catch (exception) {
      error = exception.toString();
      return false;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> assignClass({
    required int teacherId,
    required int classId,
    required String subject,
  }) async {
    isLoading = true;
    error = null;
    notifyListeners();
    try {
      await _service!.assignClass(
        teacherId: teacherId,
        classId: classId,
        subject: subject,
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

  Future<bool> removeClassAssignment({
    required int teacherId,
    required int assignmentId,
  }) async {
    error = null;
    try {
      await _service!.removeClassAssignment(
        teacherId: teacherId,
        assignmentId: assignmentId,
      );
      classSubjects = classSubjects
          .where((assignment) => assignment.id != assignmentId)
          .toList();
      notifyListeners();
      return true;
    } catch (exception) {
      error = exception.toString();
      notifyListeners();
      return false;
    }
  }

  Future<void> loadClassSubjects(int classId) async {
    isClassSubjectsLoading = true;
    error = null;
    // Clear immediately so a different class's screen never renders this
    // class's leftover subjects while loading, or forever if this fails.
    classSubjects = [];
    notifyListeners();
    try {
      classSubjects = await _service!.classSubjects(classId);
    } catch (exception) {
      error = exception.toString();
    } finally {
      isClassSubjectsLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadTeachersBySubject(String subject) async {
    isSubjectTeachersLoading = true;
    error = null;
    notifyListeners();
    try {
      subjectTeachers = await _service!.listTeachers(subject: subject);
    } catch (exception) {
      error = exception.toString();
    } finally {
      isSubjectTeachersLoading = false;
      notifyListeners();
    }
  }
}
