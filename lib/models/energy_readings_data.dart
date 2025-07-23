// lib/models/energy_readings_data.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:substation_manager/models/bay_model.dart'; // NEW: Import Bay model

// Defines how a connected bay's energy contributes to a busbar's abstract.
// enum EnergyContributionType {
//   busImport, // Bay's energy adds to busbar's total import
//   busExport, // Bay's energy adds to busbar's total export
//   none, // Bay's energy does not contribute to this busbar's abstract (default)
// }

/// Data model for energy data associated with a bay (computed values)
class BayEnergyData {
  final Bay bay; // Changed to directly store Bay object
  final double? prevImp; // Previous Reading IMP (e.g., from start of period)
  final double? currImp; // Present Reading IMP (e.g., from end of period)
  final double? prevExp; // Previous Reading EXP
  final double? currExp; // Present Reading EXP
  final double?
  mf; // Multiplying Factor (redundant if bay.multiplyingFactor is used, but kept for clarity in computation)
  final double? impConsumed; // IMP (computed)
  final double? expConsumed; // EXP (computed)
  final bool hasAssessment;

  BayEnergyData({
    required this.bay, // Now takes a Bay object
    this.prevImp,
    this.currImp,
    this.prevExp,
    this.currExp,
    this.mf,
    this.impConsumed,
    this.expConsumed,
    this.hasAssessment = false,
    required String bayName,
    required String bayId,
  });

  // Method to apply assessment adjustments to computed energy
  BayEnergyData applyAssessment({
    double? importAdjustment,
    double? exportAdjustment,
  }) {
    double newImpConsumed = (impConsumed ?? 0.0) + (importAdjustment ?? 0.0);
    double newExpConsumed = (expConsumed ?? 0.0) + (exportAdjustment ?? 0.0);
    return BayEnergyData(
      bay: bay, // Keep existing bay object
      prevImp: prevImp,
      currImp: currImp,
      prevExp: prevExp,
      currExp: currExp,
      mf: mf,
      impConsumed: newImpConsumed,
      expConsumed: newExpConsumed,
      hasAssessment: true,
      bayName: '',
      bayId: '',
    );
  }

  // Conversion to/from Map for persistence (if needed, adjust to store bay.id and bay.name)
  // This is a simplified toMap/fromMap since Bay is a complex object.
  // For actual persistence, you might store bay.id and re-fetch the Bay object or pass it.
  Map<String, dynamic> toMap() {
    return {
      'bayId': bay.id,
      'bayName': bay.name,
      'bayVoltageLevel': bay.voltageLevel,
      'bayType': bay.bayType,
      'bayMultiplyingFactor': bay.multiplyingFactor,
      'prevImp': prevImp,
      'currImp': currImp,
      'prevExp': prevExp,
      'currExp': currExp,
      'mf': mf,
      'impConsumed': impConsumed,
      'expConsumed': expConsumed,
      'hasAssessment': hasAssessment,
    };
  }

  factory BayEnergyData.fromMap(Map<String, dynamic> map, {Bay? bayObject}) {
    // Reconstruct Bay object from map data if not provided
    final Bay reconstructedBay =
        bayObject ??
        Bay(
          id: map['bayId'],
          name: map['bayName'],
          voltageLevel: map['bayVoltageLevel'],
          bayType: map['bayType'],
          multiplyingFactor: (map['bayMultiplyingFactor'] as num?)?.toDouble(),
          substationId:
              '', // Placeholder, as full Bay may not be available from map
          createdBy: '',
          createdAt: Timestamp.now(), // Placeholder
        );

    return BayEnergyData(
      bay: reconstructedBay,
      prevImp: (map['prevImp'] as num?)?.toDouble(),
      currImp: (map['currImp'] as num?)?.toDouble(),
      prevExp: (map['prevExp'] as num?)?.toDouble(),
      currExp: (map['currExp'] as num?)?.toDouble(),
      mf: (map['mf'] as num?)?.toDouble(),
      impConsumed: (map['impConsumed'] as num?)?.toDouble(),
      expConsumed: (map['expConsumed'] as num?)?.toDouble(),
      hasAssessment: map['hasAssessment'] ?? false,
      bayName: '',
      bayId: '',
    );
  }
}

/// Data model for Aggregated Feeder Energy Table (for substation abstract)
class AggregatedFeederEnergyData {
  final String zoneName;
  final String circleName;
  final String divisionName;
  final String distributionSubdivisionName;
  double importedEnergy;
  double exportedEnergy;

  AggregatedFeederEnergyData({
    required this.zoneName,
    required this.circleName,
    required this.divisionName,
    required this.distributionSubdivisionName,
    this.importedEnergy = 0.0,
    this.exportedEnergy = 0.0,
  });

  String get uniqueKey =>
      '$zoneName-$circleName-$divisionName-$distributionSubdivisionName';

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

  factory AggregatedFeederEnergyData.fromMap(Map<String, dynamic> map) {
    return AggregatedFeederEnergyData(
      zoneName: map['zoneName'],
      circleName: map['circleName'],
      divisionName: map['divisionName'],
      distributionSubdivisionName: map['distributionSubdivisionName'],
      importedEnergy: (map['importedEnergy'] as num?)?.toDouble() ?? 0.0,
      exportedEnergy: (map['exportedEnergy'] as num?)?.toDouble() ?? 0.0,
    );
  }
}
