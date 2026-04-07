import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

/// Top-level handler for background messages (required by Firebase).
/// Must be a top-level function — not a class method.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint('[FCM] Background message: ${message.messageId}');
}

/// Service to manage Firebase Cloud Messaging.
///
/// Usage:
/// ```dart
/// final pushService = PushNotificationService();
/// await pushService.initialize();
/// final token = pushService.fcmToken; // send this to backend
/// pushService.onMessage.listen((msg) { ... });
/// ```
class PushNotificationService {
  PushNotificationService._();
  static final PushNotificationService instance = PushNotificationService._();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  String? _fcmToken;
  String? get fcmToken => _fcmToken;

  /// Stream of foreground messages (when app is open).
  Stream<RemoteMessage> get onMessage => FirebaseMessaging.onMessage;

  /// Stream of messages that caused the app to open from background.
  Stream<RemoteMessage> get onMessageOpenedApp =>
      FirebaseMessaging.onMessageOpenedApp;

  /// Whether push has been initialized.
  bool _initialized = false;
  bool get isInitialized => _initialized;

  /// Initialize Firebase Messaging.
  /// Call this once at app startup, after Firebase.initializeApp().
  Future<void> initialize() async {
    if (_initialized) return;

    // Register the background handler
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    // Request permissions (iOS & Android 13+)
    final settings = await _messaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    debugPrint(
        '[FCM] Permission status: ${settings.authorizationStatus.name}');

    if (settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional) {
      // Get the FCM token
      try {
        _fcmToken = await _messaging.getToken();
        debugPrint('[FCM] Token: $_fcmToken');
      } catch (e) {
        debugPrint('[FCM] Error getting token: $e');
      }

      // Listen for token refresh
      _messaging.onTokenRefresh.listen((newToken) {
        _fcmToken = newToken;
        debugPrint('[FCM] Token refreshed: $newToken');
        _onTokenRefreshController.add(newToken);
      });

      _initialized = true;
    } else {
      debugPrint('[FCM] Notifications not authorized');
    }
  }

  /// Stream to listen for token refreshes (so backend can be updated).
  final _onTokenRefreshController = StreamController<String>.broadcast();
  Stream<String> get onTokenRefresh => _onTokenRefreshController.stream;

  /// Check if this app was launched by tapping a notification.
  /// Call once at startup to handle initial notification.
  Future<RemoteMessage?> getInitialMessage() async {
    return _messaging.getInitialMessage();
  }

  /// Subscribe to a topic (e.g., conference-specific notifications).
  Future<void> subscribeToTopic(String topic) async {
    await _messaging.subscribeToTopic(topic);
    debugPrint('[FCM] Subscribed to: $topic');
  }

  /// Unsubscribe from a topic.
  Future<void> unsubscribeFromTopic(String topic) async {
    await _messaging.unsubscribeFromTopic(topic);
    debugPrint('[FCM] Unsubscribed from: $topic');
  }

  void dispose() {
    _onTokenRefreshController.close();
  }
}
