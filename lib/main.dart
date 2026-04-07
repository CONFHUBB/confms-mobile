import 'package:confms_mobile/app.dart';
import 'package:confms_mobile/services/push_notification_service.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  try {
    await Firebase.initializeApp();
    await PushNotificationService.instance.initialize();
  } catch (e) {
    debugPrint('[Main] Firebase init failed (expected in dev): $e');
  }

  runApp(const App());
}