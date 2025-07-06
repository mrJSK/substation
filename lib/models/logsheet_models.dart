import 'package:cloud_firestore/cloud_firestore.dart';

class LogsheetEntry {
  final String? id; // Null for new entries before they are saved
  final String bayId;
  final String templateId; // Reference to the ReadingTemplate used
  final String?
  equipmentInstanceId; // Optional: if reading is for a specific equipment instance
  final Timestamp readingTimestamp; // The actual time the reading was taken
  final String recordedBy;
  final Timestamp recordedAt; // When this logsheet entry was saved/submitted
  final Map<String, dynamic>
  values; // Key: ReadingField.name, Value: recorded data
  final String frequency; // To store the frequency (hourly, daily, etc.)
  final int? readingHour; // To store the specific hour for hourly readings
  final String substationId; // NEW: Added substationId to the model

  LogsheetEntry({
    this.id,
    required this.bayId,
    required this.templateId,
    this.equipmentInstanceId,
    required this.readingTimestamp,
    required this.recordedBy,
    required this.recordedAt,
    required this.values,
    required this.frequency,
    this.readingHour,
    required this.substationId,
    required String
    modificationReason, // NEW: Make substationId required in constructor
  });

  // Create a LogsheetEntry from a Firestore DocumentSnapshot
  factory LogsheetEntry.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return LogsheetEntry(
      id: doc.id,
      bayId: data['bayId'] as String,
      templateId: data['templateId'] as String,
      equipmentInstanceId: data['equipmentInstanceId'] as String?,
      readingTimestamp: data['readingTimestamp'] as Timestamp,
      recordedBy: data['recordedBy'] as String,
      recordedAt: data['recordedAt'] as Timestamp,
      values: data['values'] as Map<String, dynamic>,
      frequency: data['frequency'] as String,
      readingHour: data['readingHour'] as int?,
      substationId: data['substationId'] as String, // NEW: Read substationId
      modificationReason:
          data['modificationReason'] as String? ??
          '', // Provide a default if missing
    );
  }

  // Convert a LogsheetEntry to a Map for Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'bayId': bayId,
      'templateId': templateId,
      'equipmentInstanceId': equipmentInstanceId,
      'readingTimestamp': readingTimestamp,
      'recordedBy': recordedBy,
      'recordedAt': recordedAt,
      'values': values,
      'frequency': frequency,
      'readingHour': readingHour,
      'substationId': substationId, // NEW: Write substationId
    };
  }
}
