import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

class FCMService {
  static final _fcm = FirebaseMessaging.instance;

  static Future<void> init() async {
    await _fcm.requestPermission();

    final token = await _fcm.getToken();
    debugPrint('FCM TOKEN: $token');

    FirebaseMessaging.onMessage.listen((message) {
      debugPrint('Foreground message: ${message.notification?.title}');
    });
  }
}
