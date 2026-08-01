import 'package:flutter/foundation.dart';

import '../models/camera_config.dart';
import '../models/school_class.dart';
import '../services/school_service.dart';
import '../utils/error_formatter.dart';

class SchoolProvider extends ChangeNotifier {
  SchoolService? _service;

  List<SchoolClass> classes = [];
  List<CameraConfig> cameras = [];
  bool isLoading = false;
  String? error;

  void attach(SchoolService service) {
    _service = service;
  }

  Future<void> loadSchoolData() async {
    isLoading = true;
    error = null;
    notifyListeners();
    try {
      classes = await _service!.fetchClasses();
      cameras = await _service!.fetchCameras();
    } catch (exception) {
      error = classifyError(exception);
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> createClass(SchoolClass schoolClass) async {
    final created = await _service!.createClass(schoolClass);
    classes = [created, ...classes];
    notifyListeners();
  }

  Future<void> updateClass(SchoolClass schoolClass) async {
    final updated = await _service!.updateClass(schoolClass);
    final index = classes.indexWhere((c) => c.id == schoolClass.id);
    if (index != -1) {
      classes[index] = updated;
    }
    notifyListeners();
  }

  Future<void> deleteClass(int id) async {
    await _service!.deleteClass(id);
    classes.removeWhere((c) => c.id == id);
    notifyListeners();
  }

  Future<void> createCamera(CameraConfig camera) async {
    final created = await _service!.createCamera(camera);
    cameras = [created, ...cameras];
    notifyListeners();
  }

  Future<void> updateCamera(CameraConfig camera) async {
    final updated = await _service!.updateCamera(camera);
    final index = cameras.indexWhere((c) => c.id == camera.id);
    if (index != -1) {
      cameras[index] = updated;
    }
    notifyListeners();
  }

  Future<void> deleteCamera(int id) async {
    await _service!.deleteCamera(id);
    cameras.removeWhere((c) => c.id == id);
    notifyListeners();
  }
}
