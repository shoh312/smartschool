import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import '../models/notification_event.dart';
import '../services/notification_service.dart';

class NotificationProvider extends ChangeNotifier {
  NotificationService? _service;
  
  List<NotificationEvent> notifications = [];
  bool isLoading = false;
  String? error;

  void attach(NotificationService service) {
    _service = service;
  }

  Future<void> initialize(int parentId) async {
    // Request permissions
    final messaging = FirebaseMessaging.instance;
    await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // Get token and save to backend
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

    // Listen for foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      loadNotifications(parentId);
    });

    loadNotifications(parentId);
  }

  Future<void> loadNotifications(int parentId) async {
    isLoading = true;
    error = null;
    notifyListeners();

    try {
      notifications = await _service!.parentNotifications(parentId);
    } catch (e) {
      error = e.toString();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }
}
