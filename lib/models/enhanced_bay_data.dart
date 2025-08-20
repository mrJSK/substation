// lib/models/enhanced_bay_data.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'bay_model.dart';
import 'reading_models.dart';
import 'logsheet_models.dart';
import 'energy_readings_data.dart';

class EnhancedBayData {
  // Core bay information
  final Bay bay;

  // Embedded reading assignments
  final List<ReadingField> readingFields;

  // Recent readings cache (last 7 days)
  final Map<String, LogsheetEntry> recentReadings; // "2025-08-20" -> entry

  // Completion status cache
  final Map<String, bool> completionStatus; // "daily_2025-08-20" -> bool

  // Latest energy data
  final BayEnergyData? latestEnergyData;

  // Metadata
  final DateTime lastUpdated;

  EnhancedBayData({
    required this.bay,
    this.readingFields = const [],
    this.recentReadings = const {},
    this.completionStatus = const {},
    this.latestEnergyData,
    DateTime? lastUpdated,
  }) : lastUpdated = lastUpdated ?? DateTime.now();

  // Convenience getters
  String get id => bay.id;
  String get name => bay.name;
  String get bayType => bay.bayType;
  String get voltageLevel => bay.voltageLevel;

  // Get reading fields by frequency
  List<ReadingField> getReadingFields(
    String frequency, {
    bool mandatoryOnly = false,
  }) {
    var fields = readingFields
        .where(
          (field) => field.frequency.toString().split('.').last == frequency,
        )
        .toList();

    if (mandatoryOnly) {
      fields = fields.where((field) => field.isMandatory).toList();
    }
    return fields;
  }

  // Check if bay has readings for frequency
  bool hasReadingsFor(String frequency) {
    return getReadingFields(frequency, mandatoryOnly: true).isNotEmpty;
  }

  // Get reading for specific date/time
  LogsheetEntry? getReading(DateTime date, String frequency, {int? hour}) {
    final dateKey = _getDateKey(date);
    final entry = recentReadings[dateKey];

    if (entry == null) return null;
    if (entry.frequency != frequency) return null;
    if (frequency == 'hourly' && entry.readingHour != hour) return null;

    return entry;
  }

  // Check completion status
  bool isComplete(DateTime date, String frequency, {int? hour}) {
    final key = _getCompletionKey(date, frequency, hour);
    return completionStatus[key] ?? false;
  }

  // Update methods
  EnhancedBayData updateReading(LogsheetEntry entry) {
    final dateKey = _getDateKey(entry.readingTimestamp.toDate());
    final completionKey = _getCompletionKey(
      entry.readingTimestamp.toDate(),
      entry.frequency,
      entry.readingHour,
    );

    final newRecentReadings = Map<String, LogsheetEntry>.from(recentReadings);
    final newCompletionStatus = Map<String, bool>.from(completionStatus);

    newRecentReadings[dateKey] = entry;
    newCompletionStatus[completionKey] = true;

    return EnhancedBayData(
      bay: bay,
      readingFields: readingFields,
      recentReadings: newRecentReadings,
      completionStatus: newCompletionStatus,
      latestEnergyData: latestEnergyData,
      lastUpdated: DateTime.now(),
    );
  }

  String _getDateKey(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  String _getCompletionKey(DateTime date, String frequency, int? hour) {
    final dateStr = _getDateKey(date);
    if (frequency == 'hourly' && hour != null) {
      return '${frequency}_${dateStr}_${hour.toString().padLeft(2, '0')}';
    }
    return '${frequency}_$dateStr';
  }

  // Serialization
  Map<String, dynamic> toFirestore() {
    return {
      'bay': bay.toFirestore(),
      'readingFields': readingFields.map((f) => f.toMap()).toList(),
      'recentReadings': recentReadings.map(
        (key, entry) => MapEntry(key, entry.toFirestore()),
      ),
      'completionStatus': completionStatus,
      'latestEnergyData': latestEnergyData?.toMap(),
      'lastUpdated': Timestamp.fromDate(lastUpdated),
    };
  }

  factory EnhancedBayData.fromFirestore(Map<String, dynamic> data) {
    return EnhancedBayData(
      bay: Bay.fromFirestore(data['bay'] as DocumentSnapshot),
      readingFields: (data['readingFields'] as List? ?? [])
          .map((f) => ReadingField.fromMap(f))
          .toList(),
      recentReadings: (data['recentReadings'] as Map? ?? {}).map(
        (key, value) => MapEntry(
          key as String,
          LogsheetEntry.fromFirestore(value as DocumentSnapshot),
        ),
      ),
      completionStatus: Map<String, bool>.from(data['completionStatus'] ?? {}),
      latestEnergyData: data['latestEnergyData'] != null
          ? BayEnergyData.fromMap(
              data['latestEnergyData'],
              Bay.fromFirestore(data['bay'] as DocumentSnapshot),
            )
          : null,
      lastUpdated:
          (data['lastUpdated'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}
