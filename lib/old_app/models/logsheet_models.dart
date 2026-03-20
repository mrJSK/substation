// lib/models/logsheet_models.dart

import 'package:cloud_firestore/cloud_firestore.dart';

class LogsheetEntry {
  final String? id;
  final String bayId;
  final String templateId;
  final Timestamp readingTimestamp;
  final String recordedBy;
  final Timestamp recordedAt;
  final Map<String, dynamic> values;
  final String frequency;
  final int? readingHour;
  final String substationId;
  // Denormalized for manager-level collection group queries
  final String subdivisionId;
  final String divisionId;
  // "YYYY-MM-DD" for easy date filtering without compound indexes
  final String date;
  final String? modificationReason;

  LogsheetEntry({
    this.id,
    required this.bayId,
    required this.templateId,
    required this.readingTimestamp,
    required this.recordedBy,
    required this.recordedAt,
    required this.values,
    required this.frequency,
    this.readingHour,
    required this.substationId,
    required this.subdivisionId,
    required this.divisionId,
    required this.date,
    this.modificationReason,
  });

  LogsheetEntry copyWith({
    String? id,
    String? bayId,
    String? templateId,
    Timestamp? readingTimestamp,
    String? recordedBy,
    Timestamp? recordedAt,
    Map<String, dynamic>? values,
    String? frequency,
    int? readingHour,
    String? substationId,
    String? subdivisionId,
    String? divisionId,
    String? date,
    String? modificationReason,
  }) {
    return LogsheetEntry(
      id: id ?? this.id,
      bayId: bayId ?? this.bayId,
      templateId: templateId ?? this.templateId,
      readingTimestamp: readingTimestamp ?? this.readingTimestamp,
      recordedBy: recordedBy ?? this.recordedBy,
      recordedAt: recordedAt ?? this.recordedAt,
      values: values ?? this.values,
      frequency: frequency ?? this.frequency,
      readingHour: readingHour ?? this.readingHour,
      substationId: substationId ?? this.substationId,
      subdivisionId: subdivisionId ?? this.subdivisionId,
      divisionId: divisionId ?? this.divisionId,
      date: date ?? this.date,
      modificationReason: modificationReason ?? this.modificationReason,
    );
  }

  factory LogsheetEntry.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final ts = data['readingTimestamp'] as Timestamp;
    final dt = ts.toDate();
    return LogsheetEntry(
      id: doc.id,
      bayId: data['bayId'] as String,
      templateId: data['templateId'] as String,
      readingTimestamp: ts,
      recordedBy: data['recordedBy'] as String,
      recordedAt: data['recordedAt'] as Timestamp,
      values: Map<String, dynamic>.from(data['values'] as Map<String, dynamic>),
      frequency: data['frequency'] as String,
      readingHour: data['readingHour'] as int?,
      substationId: data['substationId'] as String,
      subdivisionId: data['subdivisionId'] as String? ?? '',
      divisionId: data['divisionId'] as String? ?? '',
      date: data['date'] as String? ??
          '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}',
      modificationReason: data['modificationReason'] as String?,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'bayId': bayId,
      'templateId': templateId,
      'readingTimestamp': readingTimestamp,
      'recordedBy': recordedBy,
      'recordedAt': recordedAt,
      'values': values,
      'frequency': frequency,
      'readingHour': readingHour,
      'substationId': substationId,
      'subdivisionId': subdivisionId,
      'divisionId': divisionId,
      'date': date,
      'modificationReason': modificationReason,
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is LogsheetEntry &&
        other.id == id &&
        other.bayId == bayId &&
        other.templateId == templateId &&
        other.readingTimestamp == readingTimestamp &&
        other.recordedBy == recordedBy &&
        other.recordedAt == recordedAt &&
        other.frequency == frequency &&
        other.readingHour == readingHour &&
        other.substationId == substationId &&
        other.modificationReason == modificationReason;
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      bayId,
      templateId,
      readingTimestamp,
      recordedBy,
      recordedAt,
      frequency,
      readingHour,
      substationId,
      modificationReason,
    );
  }

  @override
  String toString() {
    return 'LogsheetEntry('
        'id: $id, '
        'bayId: $bayId, '
        'templateId: $templateId, '
        'readingTimestamp: $readingTimestamp, '
        'recordedBy: $recordedBy, '
        'recordedAt: $recordedAt, '
        'values: $values, '
        'frequency: $frequency, '
        'readingHour: $readingHour, '
        'substationId: $substationId, '
        'modificationReason: $modificationReason'
        ')';
  }
}
