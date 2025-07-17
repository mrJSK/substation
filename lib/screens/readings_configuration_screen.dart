import 'package:cloud_firestore/cloud_firestore.dart';

class UserReadingsConfig {
  final String userId;
  final String readingGranularity;
  final int durationValue;
  final String durationUnit;
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
    final data = doc.data() as Map<String, dynamic>;
    return UserReadingsConfig(
      userId: data['userId'] as String,
      readingGranularity: data['readingGranularity'] as String,
      durationValue: data['durationValue'] as int,
      durationUnit: data['durationUnit'] as String,
      configuredReadings:
          (data['configuredReadings'] as List<dynamic>?)
              ?.map(
                (e) => ConfiguredBayReading.fromMap(e as Map<String, dynamic>),
              )
              .toList() ??
          [],
      createdAt: data['createdAt'] as Timestamp,
      updatedAt: data['updatedAt'] as Timestamp,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'readingGranularity': readingGranularity,
      'durationValue': durationValue,
      'durationUnit': durationUnit,
      'configuredReadings': configuredReadings.map((e) => e.toMap()).toList(),
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
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
      bayName: map['bayName'] as String,
      substationId: map['substationId'] as String,
      substationName: map['substationName'] as String,
      readingFields: (map['readingFields'] as List<dynamic>).cast<String>(),
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
