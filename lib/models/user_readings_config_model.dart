// lib/models/user_readings_config_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class UserReadingsConfig {
  final String userId;
  // NEW: Granularity of readings (hourly, daily) -- this tells us WHICH collection/type of reading to fetch
  final String readingGranularity;
  // NEW: Duration value and unit for how far back to fetch data
  final int durationValue; // e.g., 48, 7, 1
  final String durationUnit; // e.g., 'hours', 'days', 'weeks', 'months'

  final List<ConfiguredBayReading> configuredReadings;
  final Timestamp createdAt;
  final Timestamp updatedAt;

  UserReadingsConfig({
    required this.userId,
    required this.readingGranularity,
    required this.durationValue,
    required this.durationUnit,
    required this.configuredReadings,
    required this.createdAt,
    required this.updatedAt,
  });

  factory UserReadingsConfig.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return UserReadingsConfig(
      userId: doc.id,
      readingGranularity:
          data['readingGranularity'] as String? ?? 'hourly', // Default
      durationValue:
          (data['durationValue'] as num?)?.toInt() ?? 48, // Default 48
      durationUnit: data['durationUnit'] as String? ?? 'hours', // Default hours
      configuredReadings:
          (data['configuredReadings'] as List<dynamic>?)
              ?.map(
                (item) =>
                    ConfiguredBayReading.fromMap(item as Map<String, dynamic>),
              )
              .toList() ??
          [],
      createdAt: data['createdAt'] as Timestamp? ?? Timestamp.now(),
      updatedAt: data['updatedAt'] as Timestamp? ?? Timestamp.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'readingGranularity': readingGranularity,
      'durationValue': durationValue,
      'durationUnit': durationUnit,
      'configuredReadings': configuredReadings
          .map((cbr) => cbr.toMap())
          .toList(),
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }

  UserReadingsConfig copyWith({
    String? userId,
    String? readingGranularity,
    int? durationValue,
    String? durationUnit,
    List<ConfiguredBayReading>? configuredReadings,
    Timestamp? createdAt,
    Timestamp? updatedAt,
  }) {
    return UserReadingsConfig(
      userId: userId ?? this.userId,
      readingGranularity: readingGranularity ?? this.readingGranularity,
      durationValue: durationValue ?? this.durationValue,
      durationUnit: durationUnit ?? this.durationUnit,
      configuredReadings: configuredReadings ?? this.configuredReadings,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class ConfiguredBayReading {
  final String bayId;
  final String bayName;
  final String substationId;
  final String substationName;
  final List<String> readingFields;

  ConfiguredBayReading({
    required this.bayId,
    required this.bayName,
    required this.substationId,
    required this.substationName,
    required this.readingFields,
  });

  factory ConfiguredBayReading.fromMap(Map<String, dynamic> map) {
    return ConfiguredBayReading(
      bayId: map['bayId'] as String,
      bayName: map['bayName'] as String? ?? '',
      substationId: map['substationId'] as String,
      substationName: map['substationName'] as String? ?? '',
      readingFields: List<String>.from(
        map['readingFields'] as List<dynamic>? ?? [],
      ),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'bayId': bayId,
      'bayName': bayName,
      'substationId': substationId,
      'substationName': substationName,
      'readingFields': readingFields,
    };
  }
}
