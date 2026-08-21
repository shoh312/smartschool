import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import '../models/notification_event.dart';
import '../services/notification_service.dart';
import '../utils/error_formatter.dart';

class NotificationProvider extends ChangeNotifier {
  NotificationService? _service;
  
  List<NotificationEvent> notifications = [];
  bool isLoading = false;
  String? error;

  void attach(NotificationService service) {
    _service = service;
  }

  Future<void> initialize(int parentId) async {
    // Push notifications aren't available on every platform/build (e.g.
    // Firebase isn't initialized on Windows desktop) -- fall back to
    // plain polling via loadNotifications below instead of crashing.
    try {
      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      final token = await messaging.getToken();
      if (token != null) {
        try {
          await _service?.saveDeviceToken(
            parentId: parentId,
            token: token,
            platform: Platform.isAndroid ? 'android' : 'ios',
          );
        } catch (e) {
          debugPrint('Error saving device token: $e');
        }
      }

      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        loadNotifications(parentId);
      });
    } catch (e) {
      debugPrint('Push notification setup unavailable: $e');
    }

    loadNotifications(parentId);
  }

  /// Registers a pupil's own phone so assignment reminders reach the
  /// device the homework will be done on, not their parent's.
  ///
  /// Only the token registration -- a pupil has no notification list to
  /// poll, so there is nothing to load afterwards.
  Future<void> registerStudentDevice() async {
    try {
      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission(alert: true, badge: true, sound: true);
      final token = await messaging.getToken();
      if (token == null) return;
      await _service?.saveDeviceToken(
        token: token,
        platform: Platform.isAndroid ? 'android' : 'ios',
      );
    } catch (e) {
      // Same reasoning as initialize(): no Firebase on Windows desktop, and
      // a pupil without push should still be able to use the app.
      debugPrint('Student push registration unavailable: $e');
    }
  }

  Future<void> loadNotifications(int parentId) async {
    isLoading = true;
    error = null;
    notifyListeners();

    try {
      notifications = await _service!.parentNotifications(parentId);
    } catch (e) {
      error = classifyError(e);
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }
}
