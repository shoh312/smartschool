import 'package:flutter/foundation.dart';

import '../models/student.dart';
import '../services/student_service.dart';

class StudentProvider extends ChangeNotifier {
  StudentService? _service;

  List<Student> students = [];
  bool isLoading = false;
  String? error;

  void attach(StudentService service) {
    _service = service;
  }

  Future<void> loadStudents({int? parentId}) async {
    isLoading = true;
    error = null;
    notifyListeners();
    try {
      students = await _service!.fetchStudents(parentId: parentId);
    } catch (exception) {
      error = exception.toString();
      // Don't leave a previous user's (e.g. a director's) student list on
      // screen just because this fetch failed.
      students = [];
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> createStudent(Student student) async {
    final created = await _service!.createStudent(student);
    students = [created, ...students];
    notifyListeners();
  }

  Future<bool> createStudentWithFace({
    required String firstName,
    required String lastName,
    required int classId,
    required String parentPhone,
    required String imagePath,
  }) async {
    isLoading = true;
    error = null;
    notifyListeners();
    try {
      final created = await _service!.createStudentWithFace(
        firstName: firstName,
        lastName: lastName,
        classId: classId,
        parentPhone: parentPhone,
        imagePath: imagePath,
      );
      students = [created, ...students];
      return true;
    } catch (exception) {
      error = exception.toString();
      return false;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> updateStudent({
    required int id,
    required String firstName,
    required String lastName,
    required int classId,
    required String parentPhone,
    required bool isActive,
    String? imagePath,
  }) async {
    isLoading = true;
    error = null;
    notifyListeners();
    try {
      final updated = await _service!.updateStudent(
        id: id,
        firstName: firstName,
        lastName: lastName,
        classId: classId,
        parentPhone: parentPhone,
        isActive: isActive,
        imagePath: imagePath,
      );
      final index = students.indexWhere((s) => s.id == id);
      if (index != -1) {
        students[index] = updated;
      }
      return true;
    } catch (exception) {
      error = exception.toString();
      return false;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> deleteStudent(int id) async {
    isLoading = true;
    error = null;
    notifyListeners();
    try {
      await _service!.deleteStudent(id);
      students.removeWhere((s) => s.id == id);
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
