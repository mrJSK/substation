// lib/services/fcm_service.dart
import 'dart:io' show Platform;
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

      // Listen for token refresh - IMPROVED
      FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
        print('FCM Token refreshed: ${newToken.substring(0, 20)}...');
        _saveTokenToFirestore(newToken);
      });

      // Initialize background handler
      FirebaseMessaging.onBackgroundMessage(
        _firebaseMessagingBackgroundHandler,
      );
    } else {
      print('User declined or has not accepted permission');
    }
  }

  /// Background message handler (must be top-level function)
  static Future<void> _firebaseMessagingBackgroundHandler(
    RemoteMessage message,
  ) async {
    print('Handling background message: ${message.messageId}');
    // Handle background notification here if needed
  }

  /// FIXED: Store tokens by userId instead of by token
  static Future<void> _saveTokenToFirestore([String? token]) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    token ??= await _messaging.getToken();
    if (token == null) return;

    try {
      // Store by userId as document ID (matching Cloud Function expectations)
      await _firestore.collection('fcmTokens').doc(user.uid).set({
        'userId': user.uid,
        'token': token,
        'active': true,
        'platform': _getPlatform(),
        'createdAt': FieldValue.serverTimestamp(),
        'lastUsed': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      print('✅ FCM Token stored successfully for user: ${user.uid}');
      print('Token: ${token.substring(0, 20)}...');
    } catch (e) {
      print('❌ Error storing FCM token: $e');
    }
  }

  /// Force refresh and store new token
  static Future<void> refreshToken() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      // Delete old token
      await _messaging.deleteToken();

      // Get new token
      String? newToken = await _messaging.getToken();
      if (newToken != null) {
        await _saveTokenToFirestore(newToken);
        print('✅ Token refreshed successfully');
      }
    } catch (e) {
      print('❌ Error refreshing token: $e');
    }
  }

  /// Mark token as inactive instead of deleting
  static Future<void> deactivateToken() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      await _firestore.collection('fcmTokens').doc(user.uid).update({
        'active': false,
        'deactivatedAt': FieldValue.serverTimestamp(),
      });

      print('✅ Token deactivated for user: ${user.uid}');
    } catch (e) {
      print('❌ Error deactivating token: $e');
    }
  }

  /// Get current user's FCM token
  static Future<String?> getCurrentToken() async {
    try {
      final token = await _messaging.getToken();
      return token;
    } catch (e) {
      print('❌ Error getting current token: $e');
      return null;
    }
  }

  /// Check if user has active FCM token - IMPROVED
  static Future<bool> hasActiveToken() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;

    try {
      final doc = await _firestore.collection('fcmTokens').doc(user.uid).get();
      if (doc.exists) {
        final data = doc.data();
        return data != null && data['active'] == true;
      }
      return false;
    } catch (e) {
      print('❌ Error checking token status: $e');
      return false;
    }
  }

  /// Ensure token is stored and active (call this on login)
  static Future<void> ensureTokenIsStored() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      String? token = await _messaging.getToken();
      if (token != null) {
        await _firestore.collection('fcmTokens').doc(user.uid).set({
          'userId': user.uid,
          'token': token,
          'active': true,
          'platform': _getPlatform(),
          'createdAt': FieldValue.serverTimestamp(),
          'lastUsed': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        print('✅ FCM Token ensured for user: ${user.uid}');
      }
    } catch (e) {
      print('❌ Error ensuring FCM token: $e');
    }
  }

  /// Handle user logout - deactivate token
  static Future<void> handleLogout() async {
    await deactivateToken();
    await _messaging.deleteToken();
    print('✅ FCM token cleaned up on logout');
  }

  /// Get platform identifier - IMPROVED
  static String _getPlatform() {
    try {
      if (Platform.isAndroid) {
        return 'android';
      } else if (Platform.isIOS) {
        return 'ios';
      } else {
        return 'flutter';
      }
    } catch (e) {
      return 'flutter';
    }
  }

  /// Clean up old/inactive tokens (optional maintenance method)
  static Future<void> cleanupOldTokens() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      await _firestore.collection('fcmTokens').doc(user.uid).update({
        'lastCleanup': FieldValue.serverTimestamp(),
      });

      print('✅ Token cleanup completed');
    } catch (e) {
      print('❌ Error during token cleanup: $e');
    }
  }
}
