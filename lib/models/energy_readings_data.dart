import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/bay_model.dart';
import '../models/assessment_model.dart';

class BayEnergyData {
  // Core energy data properties
  final double importConsumed;
  final double exportConsumed;
  final double importReading;
  final double exportReading;
  final double previousImportReading;
  final double previousExportReading;
  final double multiplierFactor;

  // Bay association - comprehensive approach
  final Bay bay;
  final String? bayName; // For backward compatibility

  // Assessment and adjustment tracking
  final Assessment? latestAssessment;
  final double importAdjustment;
  final double exportAdjustment;
  final bool hasAssessment;

  // Timestamps for data tracking
  final DateTime lastUpdated;
  final Timestamp? readingTimestamp;
  final Timestamp? previousReadingTimestamp;

  // Additional metadata
  final Map<String, dynamic>? metadata;
  final String? sourceLogsheetId;
  final double? accuracy;
  final bool isEstimated;
  final String? notes;

  BayEnergyData({
    // Required core data
    required this.bay,
    required this.importConsumed,
    required this.exportConsumed,
    required this.importReading,
    required this.exportReading,
    required this.previousImportReading,
    required this.previousExportReading,
    required this.multiplierFactor,

    // Optional/computed fields
    this.bayName,
    this.latestAssessment,
    this.importAdjustment = 0.0,
    this.exportAdjustment = 0.0,
    this.hasAssessment = false,
    DateTime? lastUpdated,
    this.readingTimestamp,
    this.previousReadingTimestamp,
    this.metadata,
    this.sourceLogsheetId,
    this.accuracy,
    this.isEstimated = false,
    this.notes,
  }) : lastUpdated = lastUpdated ?? DateTime.now();

  // Computed properties for easy access
  String get bayId => bay.id;
  String get computedBayName => bayName ?? bay.name;

  // Adjusted values (including assessments)
  double get adjustedImportConsumed => importConsumed + importAdjustment;
  double get adjustedExportConsumed => exportConsumed + exportAdjustment;
  double get netEnergy => adjustedImportConsumed - adjustedExportConsumed;

  // Energy difference calculations
  double get importDifference => importReading - previousImportReading;
  double get exportDifference => exportReading - previousExportReading;

  // Validation properties
  bool get hasValidReadings =>
      importReading >= 0 &&
      exportReading >= 0 &&
      previousImportReading >= 0 &&
      previousExportReading >= 0;

  bool get hasReasonableConsumption =>
      importConsumed >= 0 &&
      exportConsumed >= 0 &&
      importConsumed < 999999 &&
      exportConsumed < 999999;

  // Factory constructors for different creation scenarios
  factory BayEnergyData.fromReadings({
    required Bay bay,
    required double currentImportReading,
    required double currentExportReading,
    required double previousImportReading,
    required double previousExportReading,
    required double multiplierFactor,
    Assessment? assessment,
    String? sourceLogsheetId,
    Timestamp? readingTimestamp,
    Timestamp? previousReadingTimestamp,
    Map<String, dynamic>? metadata,
  }) {
    // Calculate consumed energy
    final importConsumed = math.max(
      0.0,
      (currentImportReading - previousImportReading) * multiplierFactor,
    );
    final exportConsumed = math.max(
      0.0,
      (currentExportReading - previousExportReading) * multiplierFactor,
    );

    // Extract assessment adjustments
    double importAdjustment = 0.0;
    double exportAdjustment = 0.0;
    bool hasAssessment = false;

    if (assessment != null) {
      importAdjustment = assessment.importAdjustment ?? 0.0;
      exportAdjustment = assessment.exportAdjustment ?? 0.0;
      hasAssessment = true;
    }

    return BayEnergyData(
      bay: bay,
      importConsumed: importConsumed,
      exportConsumed: exportConsumed,
      importReading: currentImportReading,
      exportReading: currentExportReading,
      previousImportReading: previousImportReading,
      previousExportReading: previousExportReading,
      multiplierFactor: multiplierFactor,
      latestAssessment: assessment,
      importAdjustment: importAdjustment,
      exportAdjustment: exportAdjustment,
      hasAssessment: hasAssessment,
      sourceLogsheetId: sourceLogsheetId,
      readingTimestamp: readingTimestamp,
      previousReadingTimestamp: previousReadingTimestamp,
      metadata: metadata,
    );
  }

  factory BayEnergyData.fromMap(Map<String, dynamic> map, Bay bay) {
    return BayEnergyData(
      bay: bay,
      bayName: map['bayName'] as String?,
      importConsumed: (map['importConsumed'] as num?)?.toDouble() ?? 0.0,
      exportConsumed: (map['exportConsumed'] as num?)?.toDouble() ?? 0.0,
      importReading: (map['importReading'] as num?)?.toDouble() ?? 0.0,
      exportReading: (map['exportReading'] as num?)?.toDouble() ?? 0.0,
      previousImportReading:
          (map['previousImportReading'] as num?)?.toDouble() ?? 0.0,
      previousExportReading:
          (map['previousExportReading'] as num?)?.toDouble() ?? 0.0,
      multiplierFactor: (map['multiplierFactor'] as num?)?.toDouble() ?? 1.0,
      importAdjustment: (map['importAdjustment'] as num?)?.toDouble() ?? 0.0,
      exportAdjustment: (map['exportAdjustment'] as num?)?.toDouble() ?? 0.0,
      hasAssessment: map['hasAssessment'] as bool? ?? false,
      lastUpdated: map['lastUpdated'] != null
          ? (map['lastUpdated'] as Timestamp).toDate()
          : DateTime.now(),
      readingTimestamp: map['readingTimestamp'] as Timestamp?,
      previousReadingTimestamp: map['previousReadingTimestamp'] as Timestamp?,
      sourceLogsheetId: map['sourceLogsheetId'] as String?,
      accuracy: (map['accuracy'] as num?)?.toDouble(),
      isEstimated: map['isEstimated'] as bool? ?? false,
      notes: map['notes'] as String?,
      metadata: map['metadata'] as Map<String, dynamic>?,
    );
  }

  // Factory constructor for legacy compatibility
  factory BayEnergyData.legacy({
    required String bayName,
    required double importConsumed,
    required double exportConsumed,
    Bay? bay,
  }) {
    // Create a minimal bay if not provided
    final actualBay =
        bay ??
        Bay(
          id: bayName,
          name: bayName,
          bayType: 'Unknown',
          voltageLevel: '0kV',
          substationId: '',
          createdBy: '',
          createdAt: Timestamp.now(),
        );

    return BayEnergyData(
      bay: actualBay,
      bayName: bayName,
      importConsumed: importConsumed,
      exportConsumed: exportConsumed,
      importReading: 0.0,
      exportReading: 0.0,
      previousImportReading: 0.0,
      previousExportReading: 0.0,
      multiplierFactor: 1.0,
    );
  }

  // Convert to map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'bayId': bayId,
      'bayName': computedBayName,
      'importConsumed': importConsumed,
      'exportConsumed': exportConsumed,
      'importReading': importReading,
      'exportReading': exportReading,
      'previousImportReading': previousImportReading,
      'previousExportReading': previousExportReading,
      'multiplierFactor': multiplierFactor,
      'importAdjustment': importAdjustment,
      'exportAdjustment': exportAdjustment,
      'hasAssessment': hasAssessment,
      'lastUpdated': Timestamp.fromDate(lastUpdated),
      'readingTimestamp': readingTimestamp,
      'previousReadingTimestamp': previousReadingTimestamp,
      'sourceLogsheetId': sourceLogsheetId,
      'accuracy': accuracy,
      'isEstimated': isEstimated,
      'notes': notes,
      'metadata': metadata,
    };
  }

  // Create a copy with updated values
  BayEnergyData copyWith({
    Bay? bay,
    String? bayName,
    double? importConsumed,
    double? exportConsumed,
    double? importReading,
    double? exportReading,
    double? previousImportReading,
    double? previousExportReading,
    double? multiplierFactor,
    Assessment? latestAssessment,
    double? importAdjustment,
    double? exportAdjustment,
    bool? hasAssessment,
    DateTime? lastUpdated,
    Timestamp? readingTimestamp,
    Timestamp? previousReadingTimestamp,
    String? sourceLogsheetId,
    double? accuracy,
    bool? isEstimated,
    String? notes,
    Map<String, dynamic>? metadata,
  }) {
    return BayEnergyData(
      bay: bay ?? this.bay,
      bayName: bayName ?? this.bayName,
      importConsumed: importConsumed ?? this.importConsumed,
      exportConsumed: exportConsumed ?? this.exportConsumed,
      importReading: importReading ?? this.importReading,
      exportReading: exportReading ?? this.exportReading,
      previousImportReading:
          previousImportReading ?? this.previousImportReading,
      previousExportReading:
          previousExportReading ?? this.previousExportReading,
      multiplierFactor: multiplierFactor ?? this.multiplierFactor,
      latestAssessment: latestAssessment ?? this.latestAssessment,
      importAdjustment: importAdjustment ?? this.importAdjustment,
      exportAdjustment: exportAdjustment ?? this.exportAdjustment,
      hasAssessment: hasAssessment ?? this.hasAssessment,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      readingTimestamp: readingTimestamp ?? this.readingTimestamp,
      previousReadingTimestamp:
          previousReadingTimestamp ?? this.previousReadingTimestamp,
      sourceLogsheetId: sourceLogsheetId ?? this.sourceLogsheetId,
      accuracy: accuracy ?? this.accuracy,
      isEstimated: isEstimated ?? this.isEstimated,
      notes: notes ?? this.notes,
      metadata: metadata ?? this.metadata,
    );
  }

  // Apply assessment adjustments
  BayEnergyData applyAssessment(Assessment assessment) {
    return copyWith(
      latestAssessment: assessment,
      importAdjustment: assessment.importAdjustment ?? 0.0,
      exportAdjustment: assessment.exportAdjustment ?? 0.0,
      hasAssessment: true,
      lastUpdated: DateTime.now(),
    );
  }

  // Enhanced toString method
  @override
  String toString() {
    return 'BayEnergyData{\n'
        '  bayName: $computedBayName,\n'
        '  bayId: $bayId,\n'
        '  importConsumed: ${importConsumed.toStringAsFixed(2)} MWh,\n'
        '  exportConsumed: ${exportConsumed.toStringAsFixed(2)} MWh,\n'
        '  adjustedImport: ${adjustedImportConsumed.toStringAsFixed(2)} MWh,\n'
        '  adjustedExport: ${adjustedExportConsumed.toStringAsFixed(2)} MWh,\n'
        '  netEnergy: ${netEnergy.toStringAsFixed(2)} MWh,\n'
        '  hasAssessment: $hasAssessment,\n'
        '  multiplierFactor: $multiplierFactor,\n'
        '  isEstimated: $isEstimated,\n'
        '  lastUpdated: $lastUpdated\n'
        '}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is BayEnergyData &&
        other.bayId == bayId &&
        other.importConsumed == importConsumed &&
        other.exportConsumed == exportConsumed &&
        other.importAdjustment == importAdjustment &&
        other.exportAdjustment == exportAdjustment;
  }

  @override
  int get hashCode {
    return Object.hash(
      bayId,
      importConsumed,
      exportConsumed,
      importAdjustment,
      exportAdjustment,
    );
  }
}

// Keep the other classes unchanged
class AggregatedFeederEnergyData {
  final String zoneName;
  final String circleName;
  final String divisionName;
  final String distributionSubdivisionName;
  double importedEnergy; // Remove 'final' keyword
  double exportedEnergy; // Remove 'final' keyword

  AggregatedFeederEnergyData({
    required this.zoneName,
    required this.circleName,
    required this.divisionName,
    required this.distributionSubdivisionName,
    this.importedEnergy = 0.0,
    this.exportedEnergy = 0.0,
  });

  factory AggregatedFeederEnergyData.fromMap(Map<String, dynamic> map) {
    return AggregatedFeederEnergyData(
      zoneName: map['zoneName'] as String? ?? '',
      circleName: map['circleName'] as String? ?? '',
      divisionName: map['divisionName'] as String? ?? '',
      distributionSubdivisionName:
          map['distributionSubdivisionName'] as String? ?? '',
      importedEnergy: (map['importedEnergy'] as num?)?.toDouble() ?? 0.0,
      exportedEnergy: (map['exportedEnergy'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'zoneName': zoneName,
      'circleName': circleName,
      'divisionName': divisionName,
      'distributionSubdivisionName': distributionSubdivisionName,
      'importedEnergy': importedEnergy,
      'exportedEnergy': exportedEnergy,
    };
  }

  // Add convenience methods for updating values
  void addImportedEnergy(double amount) {
    importedEnergy += amount;
  }

  void addExportedEnergy(double amount) {
    exportedEnergy += amount;
  }
}
