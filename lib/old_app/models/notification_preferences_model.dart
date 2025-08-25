// lib/models/notification_preferences_model.dart

import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationPreferences {
  final String userId;
  final List<int> subscribedVoltageThresholds; // Default: [132, 220, 400, 765]
  final List<int>
  optionalVoltageThresholds; // Available optionals: [11, 33, 66, 110]
  final List<int> enabledOptionalVoltages; // User-enabled optionals: []
  final List<String>
  subscribedBayTypes; // Default: ["all"] (includes Transformer, Line, etc.)
  final List<String>
  subscribedSubstations; // Default: ["all"] (all substations under hierarchy)
  final bool enableTrippingNotifications;
  final bool enableShutdownNotifications;

  NotificationPreferences({
    required this.userId,
    required this.subscribedVoltageThresholds,
    required this.optionalVoltageThresholds,
    required this.enabledOptionalVoltages,
    required this.subscribedBayTypes,
    required this.subscribedSubstations,
    this.enableTrippingNotifications = true,
    this.enableShutdownNotifications = true,
  });

  /// Factory constructor with proper defaults
  factory NotificationPreferences.withDefaults(String userId) {
    return NotificationPreferences(
      userId: userId,
      subscribedVoltageThresholds: [
        132,
        220,
        400,
        765,
      ], // Default mandatory voltages
      optionalVoltageThresholds: [
        11,
        33,
        66,
        110,
      ], // Available optional voltages
      enabledOptionalVoltages: [], // No optional voltages enabled by default
      subscribedBayTypes: ["all"], // All bay types (Transformer, Line, etc.)
      subscribedSubstations: ["all"], // All substations under user's hierarchy
      enableTrippingNotifications: true,
      enableShutdownNotifications: true,
    );
  }

  factory NotificationPreferences.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>?;

    if (data == null) {
      // Return defaults if document doesn't exist
      return NotificationPreferences.withDefaults(doc.id);
    }

    return NotificationPreferences(
      userId: doc.id,
      subscribedVoltageThresholds: List<int>.from(
        data['subscribedVoltageThresholds'] ?? [132, 220, 400, 765],
      ),
      optionalVoltageThresholds: List<int>.from(
        data['optionalVoltageThresholds'] ?? [11, 33, 66, 110],
      ),
      enabledOptionalVoltages: List<int>.from(
        data['enabledOptionalVoltages'] ?? [],
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
      'optionalVoltageThresholds': optionalVoltageThresholds,
      'enabledOptionalVoltages': enabledOptionalVoltages,
      'subscribedBayTypes': subscribedBayTypes,
      'subscribedSubstations': subscribedSubstations,
      'enableTrippingNotifications': enableTrippingNotifications,
      'enableShutdownNotifications': enableShutdownNotifications,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  /// Get all active voltage thresholds (default + enabled optional)
  List<int> get allActiveVoltageThresholds {
    final allVoltages = <int>[...subscribedVoltageThresholds];

    // Add enabled optional voltages
    for (int voltage in enabledOptionalVoltages) {
      if (optionalVoltageThresholds.contains(voltage) &&
          !allVoltages.contains(voltage)) {
        allVoltages.add(voltage);
      }
    }

    return allVoltages..sort(); // Sort in ascending order
  }

  /// Check if a voltage level should receive notifications
  bool shouldNotifyForVoltage(int voltageLevel) {
    return allActiveVoltageThresholds.any(
      (threshold) => voltageLevel >= threshold,
    );
  }

  /// Check if a bay type should receive notifications
  bool shouldNotifyForBayType(String bayType) {
    if (subscribedBayTypes.contains("all")) return true;
    return subscribedBayTypes.any(
      (type) => type.toLowerCase() == bayType.toLowerCase(),
    );
  }

  /// Check if a substation should receive notifications
  bool shouldNotifyForSubstation(String substationId) {
    if (subscribedSubstations.contains("all")) return true;
    return subscribedSubstations.contains(substationId);
  }

  /// Enable an optional voltage
  NotificationPreferences enableOptionalVoltage(int voltage) {
    if (!optionalVoltageThresholds.contains(voltage)) return this;

    final newEnabledOptionals = <int>[...enabledOptionalVoltages];
    if (!newEnabledOptionals.contains(voltage)) {
      newEnabledOptionals.add(voltage);
    }

    return copyWith(enabledOptionalVoltages: newEnabledOptionals);
  }

  /// Disable an optional voltage
  NotificationPreferences disableOptionalVoltage(int voltage) {
    final newEnabledOptionals = <int>[...enabledOptionalVoltages];
    newEnabledOptionals.remove(voltage);

    return copyWith(enabledOptionalVoltages: newEnabledOptionals);
  }

  /// Add a specific substation to subscription list
  NotificationPreferences addSubstation(String substationId) {
    final newSubstations = <String>[...subscribedSubstations];

    // Remove "all" if adding specific substations
    if (newSubstations.contains("all")) {
      newSubstations.remove("all");
    }

    if (!newSubstations.contains(substationId)) {
      newSubstations.add(substationId);
    }

    return copyWith(subscribedSubstations: newSubstations);
  }

  /// Remove a substation from subscription list
  NotificationPreferences removeSubstation(String substationId) {
    final newSubstations = <String>[...subscribedSubstations];
    newSubstations.remove(substationId);

    // If no specific substations, default back to "all"
    if (newSubstations.isEmpty) {
      newSubstations.add("all");
    }

    return copyWith(subscribedSubstations: newSubstations);
  }

  /// Subscribe to all substations under user's hierarchy
  NotificationPreferences subscribeToAllSubstations() {
    return copyWith(subscribedSubstations: ["all"]);
  }

  /// Copy with method for immutable updates
  NotificationPreferences copyWith({
    String? userId,
    List<int>? subscribedVoltageThresholds,
    List<int>? optionalVoltageThresholds,
    List<int>? enabledOptionalVoltages,
    List<String>? subscribedBayTypes,
    List<String>? subscribedSubstations,
    bool? enableTrippingNotifications,
    bool? enableShutdownNotifications,
  }) {
    return NotificationPreferences(
      userId: userId ?? this.userId,
      subscribedVoltageThresholds:
          subscribedVoltageThresholds ?? this.subscribedVoltageThresholds,
      optionalVoltageThresholds:
          optionalVoltageThresholds ?? this.optionalVoltageThresholds,
      enabledOptionalVoltages:
          enabledOptionalVoltages ?? this.enabledOptionalVoltages,
      subscribedBayTypes: subscribedBayTypes ?? this.subscribedBayTypes,
      subscribedSubstations:
          subscribedSubstations ?? this.subscribedSubstations,
      enableTrippingNotifications:
          enableTrippingNotifications ?? this.enableTrippingNotifications,
      enableShutdownNotifications:
          enableShutdownNotifications ?? this.enableShutdownNotifications,
    );
  }

  @override
  String toString() {
    return 'NotificationPreferences{userId: $userId, '
        'subscribedVoltages: $subscribedVoltageThresholds, '
        'enabledOptionalVoltages: $enabledOptionalVoltages, '
        'bayTypes: $subscribedBayTypes, '
        'substations: $subscribedSubstations, '
        'tripping: $enableTrippingNotifications, '
        'shutdown: $enableShutdownNotifications}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is NotificationPreferences &&
        other.userId == userId &&
        _listEquals(
          other.subscribedVoltageThresholds,
          subscribedVoltageThresholds,
        ) &&
        _listEquals(
          other.optionalVoltageThresholds,
          optionalVoltageThresholds,
        ) &&
        _listEquals(other.enabledOptionalVoltages, enabledOptionalVoltages) &&
        _listEquals(other.subscribedBayTypes, subscribedBayTypes) &&
        _listEquals(other.subscribedSubstations, subscribedSubstations) &&
        other.enableTrippingNotifications == enableTrippingNotifications &&
        other.enableShutdownNotifications == enableShutdownNotifications;
  }

  @override
  int get hashCode {
    return Object.hash(
      userId,
      Object.hashAll(subscribedVoltageThresholds),
      Object.hashAll(optionalVoltageThresholds),
      Object.hashAll(enabledOptionalVoltages),
      Object.hashAll(subscribedBayTypes),
      Object.hashAll(subscribedSubstations),
      enableTrippingNotifications,
      enableShutdownNotifications,
    );
  }

  /// Helper method to compare lists
  bool _listEquals<T>(List<T>? a, List<T>? b) {
    if (a == null) return b == null;
    if (b == null || a.length != b.length) return false;
    for (int index = 0; index < a.length; index += 1) {
      if (a[index] != b[index]) return false;
    }
    return true;
  }
}
