import 'package:flutter/foundation.dart';

import '../models/teacher.dart';
import '../services/teacher_service.dart';

/// Director-side management of teachers and their class assignments.
class TeacherAdminProvider extends ChangeNotifier {
  TeacherService? _service;

  List<Teacher> teachers = [];
  bool isLoading = false;
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
  }) async {
    isLoading = true;
    error = null;
    notifyListeners();
    try {
      final created = await _service!.createTeacher(
        fullName: fullName,
        email: email,
        password: password,
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
}
