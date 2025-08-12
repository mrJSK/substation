// lib/services/fcm_service.dart
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FCMService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static Future<void> initializeFCM() async {
    // Request permission
    NotificationSettings settings = await _messaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      print('User granted permission');

      // Get token and save to Firestore
      await _saveTokenToFirestore();

      // Listen for token refresh
      FirebaseMessaging.instance.onTokenRefresh.listen(_saveTokenToFirestore);
    }
  }

  static Future<void> _saveTokenToFirestore([String? token]) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    token ??= await _messaging.getToken();
    if (token == null) return;

    await _firestore.collection('fcmTokens').doc(token).set({
      'userId': user.uid,
      'token': token,
      'active': true,
      'createdAt': FieldValue.serverTimestamp(),
      'lastUsed': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> deleteToken() async {
    final token = await _messaging.getToken();
    if (token != null) {
      await _firestore.collection('fcmTokens').doc(token).update({
        'active': false,
        'deletedAt': FieldValue.serverTimestamp(),
      });
    }
  }
}
