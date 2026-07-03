import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/attendance.dart';
import '../services/attendance_service.dart';
import '../websocket/attendance_socket_service.dart';

class AttendanceProvider extends ChangeNotifier {
  AttendanceService? _service;
  AttendanceSocketService? _socket;
  StreamSubscription<List<LiveAttendance>>? _subscription;
  Timer? _pollTimer;

  List<AttendanceRecord> history = [];
  List<LiveAttendance> live = [];
  bool isLoading = false;
  String? error;

  void attach(AttendanceService service, AttendanceSocketService socket) {
    _service = service;
    _socket = socket;
  }

  Future<void> loadHistory({int? studentId, int? parentId}) async {
    isLoading = true;
    error = null;
    notifyListeners();
    try {
      history = await _service!.history(
        studentId: studentId,
        parentId: parentId,
      );
    } catch (exception) {
      error = exception.toString();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadLive({int? classId}) async {
    isLoading = true;
    error = null;
    notifyListeners();
    try {
      live = await _service!.liveStatus(classId: classId);
    } catch (exception) {
      error = exception.toString();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _pollOnce({int? classId}) async {
    try {
      live = await _service!.liveStatus(classId: classId);
      notifyListeners();
    } catch (_) {}
  }

  void startRealtime({int? classId}) {
    _subscription?.cancel();
    _socket!.connect();
    _subscription = _socket!.stream.listen(
      (items) {
        live = items;
        notifyListeners();
      },
      onError: (Object exception) {
        error = exception.toString();
        notifyListeners();
      },
    );

    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _pollOnce(classId: classId);
    });
  }

  void stopRealtime() {
    _pollTimer?.cancel();
    _pollTimer = null;
    _subscription?.cancel();
    _subscription = null;
    _socket?.disconnect();
  }

  @override
  void dispose() {
    stopRealtime();
    super.dispose();
  }
}
