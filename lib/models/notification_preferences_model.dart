// lib/models/notification_preferences_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationPreferences {
  final String userId;
  final List<int> subscribedVoltageThresholds; // e.g., [110, 220, 400]
  final List<String>
  subscribedBayTypes; // e.g., ["feeder", "transformer", "line"] or ["all"]
  final List<String> subscribedSubstations; // e.g., ["sub1", "sub2"] or ["all"]
  final bool enableTrippingNotifications;
  final bool enableShutdownNotifications;

  NotificationPreferences({
    required this.userId,
    required this.subscribedVoltageThresholds,
    required this.subscribedBayTypes,
    required this.subscribedSubstations,
    this.enableTrippingNotifications = true,
    this.enableShutdownNotifications = true,
  });

  factory NotificationPreferences.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return NotificationPreferences(
      userId: doc.id,
      subscribedVoltageThresholds: List<int>.from(
        data['subscribedVoltageThresholds'] ?? [],
      ),
      subscribedBayTypes: List<String>.from(
        data['subscribedBayTypes'] ?? ['all'],
      ),
      subscribedSubstations: List<String>.from(
        data['subscribedSubstations'] ?? ['all'],
      ),
      enableTrippingNotifications: data['enableTrippingNotifications'] ?? true,
      enableShutdownNotifications: data['enableShutdownNotifications'] ?? true,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'subscribedVoltageThresholds': subscribedVoltageThresholds,
      'subscribedBayTypes': subscribedBayTypes,
      'subscribedSubstations': subscribedSubstations,
      'enableTrippingNotifications': enableTrippingNotifications,
      'enableShutdownNotifications': enableShutdownNotifications,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}
