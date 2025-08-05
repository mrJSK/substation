// lib/data/energy_data_models.dart

import 'package:cloud_firestore/cloud_firestore.dart';

class BayEnergyData {
  final String bayName;
  final double? prevImp;
  final double? currImp;
  final double? prevExp;
  final double? currExp;
  final double? mf;
  final double? impConsumed;
  final double? expConsumed;
  final bool hasAssessment;

  BayEnergyData({
    required this.bayName,
    this.prevImp,
    this.currImp,
    this.currExp,
    this.mf,
    this.impConsumed,
    this.expConsumed,
    this.hasAssessment = false,
    this.prevExp,
  });

  BayEnergyData applyAssessment({
    double? importAdjustment,
    double? exportAdjustment,
  }) {
    double newImpConsumed = (impConsumed ?? 0.0) + (importAdjustment ?? 0.0);
    double newExpConsumed = (expConsumed ?? 0.0) + (exportAdjustment ?? 0.0);

    return BayEnergyData(
      bayName: bayName,
      prevImp: prevImp,
      currImp: currImp,
      prevExp: prevExp,
      currExp: currExp,
      mf: mf,
      impConsumed: newImpConsumed,
      expConsumed: newExpConsumed,
      hasAssessment: true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'bayName': bayName,
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

  factory BayEnergyData.fromMap(Map<String, dynamic> map) {
    return BayEnergyData(
      bayName: map['bayName'],
      prevImp: (map['prevImp'] as num?)?.toDouble(),
      currImp: (map['currImp'] as num?)?.toDouble(),
      prevExp: (map['prevExp'] as num?)?.toDouble(),
      currExp: (map['currExp'] as num?)?.toDouble(),
      mf: (map['mf'] as num?)?.toDouble(),
      impConsumed: (map['impConsumed'] as num?)?.toDouble(),
      expConsumed: (map['expConsumed'] as num?)?.toDouble(),
      hasAssessment: map['hasAssessment'] ?? false,
    );
  }
}

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

class SldRenderData {
  final List<dynamic> bayRenderDataList;
  final Map<String, dynamic> finalBayRects;
  final Map<String, dynamic> busbarRects;
  final Map<String, List<dynamic>> busbarConnectionPoints;
  final Map<String, BayEnergyData> bayEnergyData;
  final Map<String, Map<String, double>> busEnergySummary;
  final Map<String, double> abstractEnergyData;
  final List<AggregatedFeederEnergyData> aggregatedFeederEnergyData;

  SldRenderData({
    required this.bayRenderDataList,
    required this.finalBayRects,
    required this.busbarRects,
    required this.busbarConnectionPoints,
    required this.bayEnergyData,
    required this.busEnergySummary,
    required this.abstractEnergyData,
    required this.aggregatedFeederEnergyData,
  });

  factory SldRenderData.fromMap(
    Map<String, dynamic> map,
    Map<String, dynamic> baysMap,
  ) {
    // Implementation of deserialization logic
    return SldRenderData(
      bayRenderDataList: [],
      finalBayRects: {},
      busbarRects: {},
      busbarConnectionPoints: {},
      bayEnergyData: {},
      busEnergySummary: {},
      abstractEnergyData: {},
      aggregatedFeederEnergyData: [],
    );
  }
}

class ReadingsData {
  final Map<String, dynamic> startDayReadings;
  final Map<String, dynamic> endDayReadings;
  final Map<String, dynamic> previousDayReadings;

  ReadingsData({
    required this.startDayReadings,
    required this.endDayReadings,
    required this.previousDayReadings,
  });
}

class CalculatedEnergyData {
  final Map<String, BayEnergyData> bayEnergyData;
  final Map<String, Map<String, double>> busEnergySummary;
  final Map<String, double> abstractEnergyData;
  final List<AggregatedFeederEnergyData> aggregatedFeederEnergyData;

  CalculatedEnergyData({
    required this.bayEnergyData,
    required this.busEnergySummary,
    required this.abstractEnergyData,
    required this.aggregatedFeederEnergyData,
  });
}
