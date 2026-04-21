import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:panafix/pages/notifications_page.dart';

class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();
  static final GlobalKey<ScaffoldMessengerState> messengerKey =
      GlobalKey<ScaffoldMessengerState>();
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    if (kIsWeb) {
      // Keep the in-app notification center working through Firestore on web,
      // but avoid initializing Firebase Messaging where browser support varies.
      return;
    }

    final messaging = FirebaseMessaging.instance;
    await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    await _syncToken();

    FirebaseMessaging.instance.onTokenRefresh.listen((token) async {
      await _saveToken(token);
    });

    if (!kIsWeb) {
      final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
      if (initialMessage != null) {
        _handleMessageTap(initialMessage);
      }

      FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageTap);
    }

    FirebaseMessaging.onMessage.listen((message) {
      final title = message.notification?.title ?? 'Nueva notificacion';
      final body = message.notification?.body ?? 'Tienes una actualizacion.';

      messengerKey.currentState?.showSnackBar(
        SnackBar(content: Text('$title\n$body')),
      );
    });
  }

  Future<void> syncCurrentUserToken() async {
    if (kIsWeb) return;
    await _syncToken();
  }

  Future<void> _syncToken() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final token = await FirebaseMessaging.instance.getToken();

      if (token == null || token.isEmpty) return;
      await _saveToken(token);
    } catch (_) {
      // Avoid blocking auth flow if push setup is incomplete on a platform.
    }
  }

  Future<void> _saveToken(String token) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
      'fcmToken': token,
      'lastTokenSyncAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  void _handleMessageTap(RemoteMessage message) {
    final navigator = navigatorKey.currentState;
    if (navigator == null) return;

    navigator.push(
      MaterialPageRoute(
        builder: (_) => const NotificationsPage(),
      ),
    );
  }
}
