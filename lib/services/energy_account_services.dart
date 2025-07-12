// lib/services/energy_account_services.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart'; // For Offset, Size, Color
import 'dart:math'; // For min/max
import 'package:collection/collection.dart'; // For firstWhereOrNull

// Core Models
import '../models/bay_model.dart';
import '../models/equipment_model.dart';
import '../models/hierarchy_models.dart';
import '../models/user_model.dart'; // If service needs user for createdBy
import '../models/reading_models.dart';
import '../models/logsheet_models.dart';
import '../models/bay_connection_model.dart';
import '../models/busbar_energy_map.dart';
import '../models/hierarchy_models.dart';
import '../models/assessment_model.dart';
import '../models/saved_sld_model.dart'; // For BayEnergyData.fromMap in saved SLD context
import '../utils/snackbar_utils.dart'; // For SnackBars

// NEW SLD BUILDER MODELS (only if needed for data types, not logic)
import '../models/sld_models.dart';

/// Data model for energy data associated with a bay
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

/// Data model for Aggregated Feeder Energy Table
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

/// Data model for rendering the SLD with energy data (adapted for PDF only)
/// This class acts as a consolidated data package for the SingleLineDiagramPainter.
class SldRenderData {
  final List<BayRenderData> bayRenderDataList;
  final Map<String, Rect> finalBayRects;
  final Map<String, Rect> busbarRects;
  final Map<String, Map<String, Offset>> busbarConnectionPoints;
  final Map<String, BayEnergyData> bayEnergyData;
  final Map<String, Map<String, double>> busEnergySummary;
  final Map<String, dynamic> abstractEnergyData;
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
}

class EnergyAccountService {
  final FirebaseFirestore _firestore;
  // Hold a reference to BuildContext for SnackBarUtils, must be set by UI
  BuildContext? _context;

  // Live data storage within the service
  List<Bay> _allBaysInSubstation = [];
  Map<String, Bay> _baysMap = {};
  List<BayConnection> _allConnections = [];
  List<EquipmentInstance> _allEquipmentInstances = [];
  Map<String, List<EquipmentInstance>> _equipmentByBayId = {};
  Map<String, BusbarEnergyMap> _busbarEnergyMaps = {};
  Map<String, Assessment> _latestAssessmentsPerBay = {};
  List<Assessment> _allAssessmentsForDisplay = []; // For PDF assessments table

  // Hierarchy maps for lookup (Transmission Hierarchy)
  Map<String, Zone> _zonesMap = {};
  Map<String, Circle> _circlesMap = {};
  Map<String, Division> _divisionsMap = {};
  Map<String, Subdivision> _subdivisionsMap = {};
  Map<String, Substation> _substationsMap = {};

  // Maps for Distribution Hierarchy lookup
  Map<String, DistributionZone> _distributionZonesMap = {};
  Map<String, DistributionCircle> _distributionCirclesMap = {};
  Map<String, DistributionDivision> _distributionDivisionsMap = {};
  Map<String, DistributionSubdivision> _distributionSubdivisionsMap = {};

  // Processed energy data
  Map<String, BayEnergyData> _bayEnergyData = {};
  Map<String, Map<String, double>> _busEnergySummary = {};
  Map<String, dynamic> _abstractEnergyData = {};
  List<AggregatedFeederEnergyData> _aggregatedFeederEnergyData = [];

  // Getters for processed data
  List<Bay> get allBaysInSubstation => _allBaysInSubstation;
  Map<String, Bay> get baysMap => _baysMap;
  List<BayConnection> get allConnections => _allConnections;
  Map<String, List<EquipmentInstance>> get equipmentByBayId =>
      _equipmentByBayId;
  Map<String, BayEnergyData> get bayEnergyData => _bayEnergyData;
  Map<String, Map<String, double>> get busEnergySummary => _busEnergySummary;
  Map<String, dynamic> get abstractEnergyData => _abstractEnergyData;
  List<AggregatedFeederEnergyData> get aggregatedFeederEnergyData =>
      _aggregatedFeederEnergyData;
  List<Assessment> get allAssessmentsForDisplay => _allAssessmentsForDisplay;
  Map<String, Zone> get zonesMap => _zonesMap;
  Map<String, Circle> get circlesMap => _circlesMap;
  Map<String, Division> get divisionsMap => _divisionsMap;
  Map<String, Subdivision> get subdivisionsMap => _subdivisionsMap;
  Map<String, Substation> get substationsMap => _substationsMap;
  Map<String, DistributionZone> get distributionZonesMap =>
      _distributionZonesMap;
  Map<String, DistributionCircle> get distributionCirclesMap =>
      _distributionCirclesMap;
  Map<String, DistributionDivision> get distributionDivisionsMap =>
      _distributionDivisionsMap;
  Map<String, DistributionSubdivision> get distributionSubdivisionsMap =>
      _distributionSubdivisionsMap;
  Map<String, BusbarEnergyMap> get busbarEnergyMaps => _busbarEnergyMaps;
  Map<String, Assessment> get latestAssessmentsPerBay =>
      _latestAssessmentsPerBay;

  EnergyAccountService({FirebaseFirestore? firestore, BuildContext? context})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _context = context;

  void setContext(BuildContext context) {
    _context = context;
  }

  double _getVoltageLevelValue(String voltageLevel) {
    final regex = RegExp(r'(\d+(\.\d+)?)');
    final match = regex.firstMatch(voltageLevel);
    if (match != null) {
      return double.tryParse(match.group(1)!) ?? 0.0;
    }
    return 0.0;
  }

  // Consolidated method to load all necessary data
  Future<void> loadEnergyData({
    required String substationId,
    required DateTime startDate,
    required DateTime endDate,
    SavedSld? savedSld,
  }) async {
    bool fromSaved = savedSld != null;
    Map<String, dynamic>? loadedSldParameters = savedSld?.sldParameters;
    List<Map<String, dynamic>> loadedAssessmentsSummary =
        savedSld?.assessmentsSummary ?? [];

    _clearAllData(); // Clear previous data

    try {
      await _fetchTransmissionHierarchyData();
      await _fetchDistributionHierarchyData();

      final baysSnapshot = await _firestore
          .collection('bays')
          .where('substationId', isEqualTo: substationId)
          .orderBy('name')
          .get();
      _allBaysInSubstation = baysSnapshot.docs
          .map((doc) => Bay.fromFirestore(doc))
          .toList();

      _allBaysInSubstation.sort((a, b) {
        final double voltageA = _getVoltageLevelValue(a.voltageLevel);
        final double voltageB = _getVoltageLevelValue(b.voltageLevel);
        return voltageB.compareTo(voltageA);
      });

      _baysMap = {for (var bay in _allBaysInSubstation) bay.id: bay};

      final connectionsSnapshot = await _firestore
          .collection('bay_connections')
          .where('substationId', isEqualTo: substationId)
          .get();
      _allConnections = connectionsSnapshot.docs
          .map((doc) => BayConnection.fromFirestore(doc))
          .toList();

      final equipmentSnapshot = await _firestore
          .collection('equipmentInstances')
          .where(
            'bayId',
            whereIn: _allBaysInSubstation.map((b) => b.id).toList(),
          )
          .get();
      _allEquipmentInstances = equipmentSnapshot.docs
          .map((doc) => EquipmentInstance.fromFirestore(doc))
          .toList();
      _equipmentByBayId.clear();
      for (var eq in _allEquipmentInstances) {
        _equipmentByBayId.putIfAbsent(eq.bayId, () => []).add(eq);
      }

      if (fromSaved && loadedSldParameters != null) {
        debugPrint('EnergyAccountService: Loading energy data from SAVED SLD.');
        _bayEnergyData =
            (loadedSldParameters['bayEnergyData'] as Map<String, dynamic>?)
                ?.map<String, BayEnergyData>(
                  (key, value) => MapEntry(
                    key,
                    BayEnergyData.fromMap(value as Map<String, dynamic>),
                  ),
                ) ??
            {};
        _busEnergySummary = Map<String, Map<String, double>>.from(
          (loadedSldParameters['busEnergySummary'] as Map<String, dynamic>?)
                  ?.map(
                    (key, value) => MapEntry(
                      key,
                      Map<String, double>.from(
                        value as Map<String, dynamic>? ?? {},
                      ),
                    ),
                  ) ??
              {},
        );
        _abstractEnergyData = Map<String, double>.from(
          loadedSldParameters['abstractEnergyData'] as Map<String, dynamic>? ??
              {},
        );
        _aggregatedFeederEnergyData =
            (loadedSldParameters['aggregatedFeederEnergyData']
                    as List<dynamic>?)
                ?.map(
                  (e) => AggregatedFeederEnergyData.fromMap(
                    e as Map<String, dynamic>? ?? {},
                  ),
                )
                .toList() ??
            [];
        _allAssessmentsForDisplay = loadedAssessmentsSummary
            .map((e) => Assessment.fromMap(e))
            .toList();
      } else {
        debugPrint('EnergyAccountService: Loading LIVE energy data.');
        final busbarEnergyMapsSnapshot = await _firestore
            .collection('busbarEnergyMaps')
            .where('substationId', isEqualTo: substationId)
            .get();
        _busbarEnergyMaps = {
          for (var doc in busbarEnergyMapsSnapshot.docs)
            '${doc['busbarId']}-${doc['connectedBayId']}':
                BusbarEnergyMap.fromFirestore(doc),
        };

        final startOfStartDate = DateTime(
          startDate.year,
          startDate.month,
          startDate.day,
        );
        final endOfStartDate = DateTime(
          startDate.year,
          startDate.month,
          startDate.day,
          23,
          59,
          59,
          999,
        );

        final startOfEndDate = DateTime(
          endDate.year,
          endDate.month,
          endDate.day,
        );
        final endOfEndDate = DateTime(
          endDate.year,
          endDate.month,
          endDate.day,
          23,
          59,
          59,
          999,
        );

        Map<String, LogsheetEntry> startDayReadings = {};
        Map<String, LogsheetEntry> endDayReadings = {};
        Map<String, LogsheetEntry> previousDayToStartDateReadings = {};

        final startDayLogsheetsSnapshot = await _firestore
            .collection('logsheetEntries')
            .where('substationId', isEqualTo: substationId)
            .where('frequency', isEqualTo: 'daily')
            .where('readingTimestamp', isGreaterThanOrEqualTo: startOfStartDate)
            .where('readingTimestamp', isLessThanOrEqualTo: endOfEndDate)
            .get();
        startDayReadings = {
          for (var doc in startDayLogsheetsSnapshot.docs)
            (doc.data() as Map<String, dynamic>)['bayId']:
                LogsheetEntry.fromFirestore(doc),
        };

        if (!startDate.isAtSameMomentAs(endDate)) {
          final endDayLogsheetsSnapshot = await _firestore
              .collection('logsheetEntries')
              .where('substationId', isEqualTo: substationId)
              .where('frequency', isEqualTo: 'daily')
              .where('readingTimestamp', isGreaterThanOrEqualTo: startOfEndDate)
              .where('readingTimestamp', isLessThanOrEqualTo: endOfEndDate)
              .get();
          endDayReadings = {
            for (var doc in endDayLogsheetsSnapshot.docs)
              (doc.data() as Map<String, dynamic>)['bayId']:
                  LogsheetEntry.fromFirestore(doc),
          };
        } else {
          endDayReadings = startDayReadings;
          final previousDay = startDate.subtract(const Duration(days: 1));
          final startOfPreviousDay = DateTime(
            previousDay.year,
            previousDay.month,
            previousDay.day,
          );
          final endOfPreviousDay = DateTime(
            previousDay.year,
            previousDay.month,
            previousDay.day,
            23,
            59,
            59,
            999,
          );

          final previousDayToStartDateLogsheetsSnapshot = await _firestore
              .collection('logsheetEntries')
              .where('substationId', isEqualTo: substationId)
              .where('frequency', isEqualTo: 'daily')
              .where(
                'readingTimestamp',
                isGreaterThanOrEqualTo: Timestamp.fromDate(startOfPreviousDay),
              )
              .where(
                'readingTimestamp',
                isLessThanOrEqualTo: Timestamp.fromDate(endOfPreviousDay),
              )
              .get();
          previousDayToStartDateReadings = {
            for (var doc in previousDayToStartDateLogsheetsSnapshot.docs)
              (doc.data() as Map<String, dynamic>)['bayId']:
                  LogsheetEntry.fromFirestore(doc),
          };
        }

        final assessmentsRawSnapshot = await _firestore
            .collection('assessments')
            .where('substationId', isEqualTo: substationId)
            .where(
              'assessmentTimestamp',
              isGreaterThanOrEqualTo: Timestamp.fromDate(startOfStartDate),
            )
            .where(
              'assessmentTimestamp',
              isLessThanOrEqualTo: Timestamp.fromDate(endOfEndDate),
            )
            .orderBy('assessmentTimestamp', descending: true)
            .get();

        _allAssessmentsForDisplay = [];
        _latestAssessmentsPerBay.clear();

        for (var doc in assessmentsRawSnapshot.docs) {
          final assessment = Assessment.fromFirestore(doc);
          _allAssessmentsForDisplay.add(assessment);
          if (!_latestAssessmentsPerBay.containsKey(assessment.bayId)) {
            _latestAssessmentsPerBay[assessment.bayId] = assessment;
          }
        }
        _allAssessmentsForDisplay.sort(
          (a, b) => b.assessmentTimestamp.compareTo(a.assessmentTimestamp),
        );

        for (var bay in _allBaysInSubstation) {
          final double? mf = bay.multiplyingFactor;
          double calculatedImpConsumed = 0.0;
          double calculatedExpConsumed = 0.0;

          bool bayHasAssessmentForPeriod = _latestAssessmentsPerBay.containsKey(
            bay.id,
          );

          if (startDate.isAtSameMomentAs(endDate)) {
            final currentReadingLogsheet = endDayReadings[bay.id];
            final previousReadingLogsheetDocument =
                previousDayToStartDateReadings[bay.id];

            final double? currImpVal = double.tryParse(
              currentReadingLogsheet?.values['Current Day Reading (Import)']
                      ?.toString() ??
                  '',
            );
            final double? currExpVal = double.tryParse(
              currentReadingLogsheet?.values['Current Day Reading (Export)']
                      ?.toString() ??
                  '',
            );

            double? prevImpValForCalculation;
            double? prevExpValForCalculation;

            final double? prevImpValFromPreviousDocument = double.tryParse(
              previousReadingLogsheetDocument
                      ?.values['Current Day Reading (Import)']
                      ?.toString() ??
                  '',
            );
            final double? prevExpValFromPreviousDocument = double.tryParse(
              previousReadingLogsheetDocument
                      ?.values['Current Day Reading (Export)']
                      ?.toString() ??
                  '',
            );

            if (prevImpValFromPreviousDocument != null) {
              prevImpValForCalculation = prevImpValFromPreviousDocument;
            } else {
              prevImpValForCalculation = double.tryParse(
                currentReadingLogsheet?.values['Previous Day Reading (Import)']
                        ?.toString() ??
                    '',
              );
            }

            if (prevExpValFromPreviousDocument != null) {
              prevExpValForCalculation = prevExpValFromPreviousDocument;
            } else {
              prevExpValForCalculation = double.tryParse(
                currentReadingLogsheet?.values['Previous Day Reading (Export)']
                        ?.toString() ??
                    '',
              );
            }

            if (currImpVal != null &&
                prevImpValForCalculation != null &&
                mf != null) {
              calculatedImpConsumed = max(
                0.0,
                (currImpVal - prevImpValForCalculation) * mf,
              );
            }
            if (currExpVal != null &&
                prevExpValForCalculation != null &&
                mf != null) {
              calculatedExpConsumed = max(
                0.0,
                (currExpVal - prevExpValForCalculation) * mf,
              );
            }

            _bayEnergyData[bay.id] = BayEnergyData(
              bayName: bay.name,
              prevImp: prevImpValForCalculation,
              currImp: currImpVal,
              prevExp: prevExpValForCalculation,
              currExp: currExpVal,
              mf: mf,
              impConsumed: calculatedImpConsumed,
              expConsumed: calculatedExpConsumed,
              hasAssessment: bayHasAssessmentForPeriod,
            );
          } else {
            final startReading = startDayReadings[bay.id];
            final endReading = endDayReadings[bay.id];

            final double? startImpVal = double.tryParse(
              startReading?.values['Current Day Reading (Import)']
                      ?.toString() ??
                  '',
            );
            final double? startExpVal = double.tryParse(
              startReading?.values['Current Day Reading (Export)']
                      ?.toString() ??
                  '',
            );
            final double? endImpVal = double.tryParse(
              endReading?.values['Current Day Reading (Import)']?.toString() ??
                  '',
            );
            final double? endExpVal = double.tryParse(
              endReading?.values['Current Day Reading (Export)']?.toString() ??
                  '',
            );

            if (startImpVal != null && endImpVal != null && mf != null) {
              calculatedImpConsumed = max(0.0, (endImpVal - startImpVal) * mf);
            }
            if (startExpVal != null && endExpVal != null && mf != null) {
              calculatedExpConsumed = max(0.0, (endExpVal - startExpVal) * mf);
            }

            _bayEnergyData[bay.id] = BayEnergyData(
              bayName: bay.name,
              prevImp: startImpVal,
              currImp: endImpVal,
              prevExp: startExpVal,
              currExp: endExpVal,
              mf: mf,
              impConsumed: calculatedImpConsumed,
              expConsumed: calculatedExpConsumed,
              hasAssessment: bayHasAssessmentForPeriod,
            );
          }

          final latestAssessment = _latestAssessmentsPerBay[bay.id];
          if (latestAssessment != null) {
            _bayEnergyData[bay.id] = _bayEnergyData[bay.id]!.applyAssessment(
              importAdjustment: latestAssessment.importAdjustment,
              exportAdjustment: latestAssessment.exportAdjustment,
            );
            debugPrint('Applied assessment for ${bay.name}');
          }
        }

        Map<String, Map<String, double>> temporaryBusFlows = {};
        for (var busbar in _allBaysInSubstation.where(
          (b) => b.bayType == BayType.Busbar,
        )) {
          temporaryBusFlows[busbar.id] = {'import': 0.0, 'export': 0.0};
        }

        for (var entry in _busbarEnergyMaps.values) {
          final Bay? connectedBay = _baysMap[entry.connectedBayId];
          final BayEnergyData? connectedBayEnergy =
              _bayEnergyData[entry.connectedBayId];

          if (connectedBay != null &&
              connectedBayEnergy != null &&
              temporaryBusFlows.containsKey(entry.busbarId)) {
            if (entry.importContribution == EnergyContributionType.busImport) {
              temporaryBusFlows[entry.busbarId]!['import'] =
                  (temporaryBusFlows[entry.busbarId]!['import'] ?? 0.0) +
                  (connectedBayEnergy.impConsumed ?? 0.0);
            } else if (entry.importContribution ==
                EnergyContributionType.busExport) {
              temporaryBusFlows[entry.busbarId]!['export'] =
                  (temporaryBusFlows[entry.busbarId]!['export'] ?? 0.0) +
                  (connectedBayEnergy.impConsumed ?? 0.0);
            }

            if (entry.exportContribution == EnergyContributionType.busImport) {
              temporaryBusFlows[entry.busbarId]!['import'] =
                  (temporaryBusFlows[entry.busbarId]!['import'] ?? 0.0) +
                  (connectedBayEnergy.expConsumed ?? 0.0);
            } else if (entry.exportContribution ==
                EnergyContributionType.busExport) {
              temporaryBusFlows[entry.busbarId]!['export'] =
                  (temporaryBusFlows[entry.busbarId]!['export'] ?? 0.0) +
                  (connectedBayEnergy.expConsumed ?? 0.0);
            }
          }
        }

        for (var busbar in _allBaysInSubstation.where(
          (b) => b.bayType == BayType.Busbar,
        )) {
          double busTotalImp = temporaryBusFlows[busbar.id]?['import'] ?? 0.0;
          double busTotalExp = temporaryBusFlows[busbar.id]?['export'] ?? 0.0;

          double busDifference = busTotalImp - busTotalExp;
          double busLossPercentage = 0.0;
          if (busTotalImp > 0) {
            busLossPercentage = (busDifference / busTotalImp) * 100;
          }

          _busEnergySummary[busbar.id] = {
            'totalImp': busTotalImp,
            'totalExp': busTotalExp,
            'difference': busDifference,
            'lossPercentage': busLossPercentage,
          };
          print(
            'DEBUG: Bus Energy Summary for ${busbar.name}: Imp=${busTotalImp}, Exp=${busTotalExp}, Diff=${busDifference}, Loss=${busLossPercentage}%',
          );
        }

        final highestVoltageBus = _allBaysInSubstation.firstWhereOrNull(
          (b) => b.bayType == BayType.Busbar,
        );
        final lowestVoltageBus = _allBaysInSubstation.lastWhereOrNull(
          (b) => b.bayType == BayType.Busbar,
        );

        double currentAbstractSubstationTotalImp = 0;
        double currentAbstractSubstationTotalExp = 0;

        if (highestVoltageBus != null) {
          currentAbstractSubstationTotalImp =
              (_busEnergySummary[highestVoltageBus.id]?['totalImp']) ?? 0.0;
        }
        if (lowestVoltageBus != null) {
          currentAbstractSubstationTotalExp =
              (_busEnergySummary[lowestVoltageBus.id]?['totalExp']) ?? 0.0;
        }

        double overallDifference =
            currentAbstractSubstationTotalImp -
            currentAbstractSubstationTotalExp;
        double overallLossPercentage = 0;
        if (currentAbstractSubstationTotalImp > 0) {
          overallLossPercentage =
              (overallDifference / currentAbstractSubstationTotalImp) * 100;
        }

        _abstractEnergyData = {
          'totalImp': currentAbstractSubstationTotalImp,
          'totalExp': currentAbstractSubstationTotalExp,
          'difference': overallDifference,
          'lossPercentage': overallLossPercentage,
        };

        final Map<String, AggregatedFeederEnergyData> tempAggregatedData = {};

        for (var bay in _allBaysInSubstation) {
          if (bay.bayType == BayType.Feeder) {
            final energyData = _bayEnergyData[bay.id];
            if (energyData != null) {
              final DistributionSubdivision? distSubdivision =
                  _distributionSubdivisionsMap[bay.distributionSubdivisionId];
              final DistributionDivision? distDivision =
                  _distributionDivisionsMap[distSubdivision
                      ?.distributionDivisionId];
              final DistributionCircle? distCircle =
                  _distributionCirclesMap[distDivision?.distributionCircleId];
              final DistributionZone? distZone =
                  _distributionZonesMap[distCircle?.distributionZoneId];

              final String zoneName = distZone?.name ?? 'N/A';
              final String circleName = distCircle?.name ?? 'N/A';
              final String divisionName = distDivision?.name ?? 'N/A';
              final String distSubdivisionName = distSubdivision?.name ?? 'N/A';

              final String groupKey =
                  '$zoneName-$circleName-$divisionName-$distSubdivisionName';

              final aggregatedEntry = tempAggregatedData.putIfAbsent(
                groupKey,
                () => AggregatedFeederEnergyData(
                  zoneName: zoneName,
                  circleName: circleName,
                  divisionName: divisionName,
                  distributionSubdivisionName: distSubdivisionName,
                ),
              );

              aggregatedEntry.importedEnergy += (energyData.impConsumed ?? 0.0);
              aggregatedEntry.exportedEnergy += (energyData.expConsumed ?? 0.0);
            }
          }
        }

        _aggregatedFeederEnergyData = tempAggregatedData.values.toList();

        _aggregatedFeederEnergyData.sort((a, b) {
          int result = a.zoneName.compareTo(b.zoneName);
          if (result != 0) return result;

          result = a.circleName.compareTo(b.circleName);
          if (result != 0) return result;

          result = a.divisionName.compareTo(b.divisionName);
          if (result != 0) return result;

          return a.distributionSubdivisionName.compareTo(
            b.distributionSubdivisionName,
          );
        });
      }
    } catch (e) {
      print("EnergyAccountService Error: $e");
      if (_context != null) {
        SnackBarUtils.showSnackBar(
          _context!,
          'Failed to load energy data: $e',
          isError: true,
        );
      }
      rethrow; // Re-throw to be caught by the caller (EnergySldScreen)
    }
  }

  // Helper for hierarchical data fetching
  Future<void> _fetchTransmissionHierarchyData() async {
    _zonesMap.clear();
    _circlesMap.clear();
    _divisionsMap.clear();
    _subdivisionsMap.clear();
    _substationsMap.clear();

    final zonesSnapshot = await _firestore.collection('zones').get();
    _zonesMap = {
      for (var doc in zonesSnapshot.docs) doc.id: Zone.fromFirestore(doc),
    };

    final circlesSnapshot = await _firestore.collection('circles').get();
    _circlesMap = {
      for (var doc in circlesSnapshot.docs) doc.id: Circle.fromFirestore(doc),
    };

    final divisionsSnapshot = await _firestore.collection('divisions').get();
    _divisionsMap = {
      for (var doc in divisionsSnapshot.docs)
        doc.id: Division.fromFirestore(doc),
    };

    final subdivisionsSnapshot = await _firestore
        .collection('subdivisions')
        .get();
    _subdivisionsMap = {
      for (var doc in subdivisionsSnapshot.docs)
        doc.id: Subdivision.fromFirestore(doc),
    };

    final substationsSnapshot = await _firestore
        .collection('substations')
        .get();
    _substationsMap = {
      for (var doc in substationsSnapshot.docs)
        doc.id: Substation.fromFirestore(doc),
    };
  }

  Future<void> _fetchDistributionHierarchyData() async {
    _distributionZonesMap.clear();
    _distributionCirclesMap.clear();
    _distributionDivisionsMap.clear();
    _distributionSubdivisionsMap.clear();

    final zonesSnapshot = await _firestore
        .collection('distributionZones')
        .get();
    _distributionZonesMap = {
      for (var doc in zonesSnapshot.docs)
        doc.id: DistributionZone.fromFirestore(doc),
    };

    final circlesSnapshot = await _firestore
        .collection('distributionCircles')
        .get();
    _distributionCirclesMap = {
      for (var doc in circlesSnapshot.docs)
        doc.id: DistributionCircle.fromFirestore(doc),
    };

    final divisionsSnapshot = await _firestore
        .collection('distributionDivisions')
        .get();
    _distributionDivisionsMap = {
      for (var doc in divisionsSnapshot.docs)
        doc.id: DistributionDivision.fromFirestore(doc),
    };

    final subdivisionsSnapshot = await _firestore
        .collection('distributionSubdivisions')
        .get();
    _distributionSubdivisionsMap = {
      for (var doc in subdivisionsSnapshot.docs)
        doc.id: DistributionSubdivision.fromFirestore(doc),
    };
  }

  // Helper method to reconstruct BayRenderData list for SingleLineDiagramPainter
  // This is used exclusively for PDF generation where the painter still draws the scene.
  SldRenderData buildSldRenderData({
    required SldData sldData,
    required Map<String, Bay> baysMap, // Pass live baysMap from EnergySldScreen
    required Map<String, BayEnergyData> bayEnergyData, // Pass live energy data
    required Map<String, Map<String, double>>
    busEnergySummary, // Pass live bus summary
  }) {
    final List<BayRenderData> bayRenderDataList = [];
    final Map<String, Rect> finalBayRects = {};
    final Map<String, Rect> busbarRects = {};
    final Map<String, Map<String, Offset>> busbarConnectionPoints = {};

    const double busbarHitboxHeight = 50.0;

    for (var element in sldData.elements.values) {
      if (element is SldNode) {
        final Bay? bay = baysMap[element.associatedBayId ?? element.id];
        if (bay == null) continue;

        Rect rect;
        if (element.nodeShape == SldNodeShape.busbar) {
          final double busbarLen =
              (element.properties['busbarLength'] as num?)?.toDouble() ?? 150.0;
          rect = Rect.fromLTWH(
            element.position.dx,
            element.position.dy,
            busbarLen,
            busbarHitboxHeight,
          );
          busbarRects[element.id] = rect;
        } else {
          rect = Rect.fromLTWH(
            element.position.dx,
            element.position.dy,
            element.size.width,
            element.size.height,
          );
        }
        finalBayRects[element.id] = rect;

        bayRenderDataList.add(
          BayRenderData(
            bay: bay,
            rect: rect,
            center: rect.center,
            topCenter: rect.topCenter,
            bottomCenter: rect.bottomCenter,
            leftCenter: rect.centerLeft,
            rightCenter: rect.centerRight,
            equipmentInstances: equipmentByBayId[bay.id] ?? [],
            textOffset: Offset(
              (element.properties['textOffsetDx'] as num?)?.toDouble() ?? 0.0,
              (element.properties['textOffsetDy'] as num?)?.toDouble() ?? 0.0,
            ),
            busbarLength:
                (element.properties['busbarLength'] as num?)?.toDouble() ?? 0.0,
            energyTextOffset: Offset(
              (element.properties['energyTextOffsetDx'] as num?)?.toDouble() ??
                  0.0,
              (element.properties['energyTextOffsetDy'] as num?)?.toDouble() ??
                  0.0,
            ),
          ),
        );
      } else if (element is SldTextLabel) {
        // You might want to include SldTextLabel in SldRenderData if painter needs to draw it directly
        // Current SingleLineDiagramPainter doesn't have a direct way to draw SldTextLabel as a separate element.
        // If a text label is meant to be part of the SLD PDF, you'd need to modify SingleLineDiagramPainter
        // to accept a list of SldTextLabel and draw them.
      }
    }

    // Reconstruct busbarConnectionPoints from SldEdges for painter
    for (var element in sldData.elements.values) {
      if (element is SldEdge) {
        final sourceNode = sldData.nodes[element.sourceNodeId];
        final targetNode = sldData.nodes[element.targetNodeId];
        if (sourceNode == null || targetNode == null) continue;

        final sourceConnectionPoint =
            sourceNode.connectionPoints[element.sourceConnectionPointId];
        final targetConnectionPoint =
            targetNode.connectionPoints[element.targetConnectionPointId];

        if (sourceConnectionPoint != null && targetConnectionPoint != null) {
          final startPointGlobal =
              sourceNode.position + sourceConnectionPoint.localOffset;
          final endPointGlobal =
              targetNode.position + targetConnectionPoint.localOffset;

          busbarConnectionPoints.putIfAbsent(
            sourceNode.id,
            () => {},
          )[targetNode.id] = startPointGlobal;
          busbarConnectionPoints.putIfAbsent(
            targetNode.id,
            () => {},
          )[sourceNode.id] = endPointGlobal;
        }
      }
    }

    return SldRenderData(
      bayRenderDataList: bayRenderDataList,
      finalBayRects: finalBayRects,
      busbarRects: busbarRects,
      busbarConnectionPoints: busbarConnectionPoints,
      bayEnergyData: bayEnergyData,
      busEnergySummary: busEnergySummary,
      abstractEnergyData: abstractEnergyData,
      aggregatedFeederEnergyData: aggregatedFeederEnergyData,
    );
  }

  // Dummy BayRenderData for orElse (needed by SingleLineDiagramPainter)
  BayRenderData createDummyBayRenderData() {
    return BayRenderData(
      bay: Bay(
        id: 'dummy',
        name: 'Dummy Bay',
        substationId: '',
        voltageLevel: '',
        bayType: BayType.Feeder,
        createdBy: '',
        createdAt: Timestamp.now(),
      ),
      rect: Rect.zero,
      center: Offset.zero,
      topCenter: Offset.zero,
      bottomCenter: Offset.zero,
      leftCenter: Offset.zero,
      rightCenter: Offset.zero,
      textOffset: Offset.zero,
      busbarLength: 0.0,
    );
  }

  void _clearAllData() {
    _allBaysInSubstation.clear();
    _baysMap.clear();
    _allConnections.clear();
    _allEquipmentInstances.clear();
    _equipmentByBayId.clear();
    _busbarEnergyMaps.clear();
    _latestAssessmentsPerBay.clear();
    _allAssessmentsForDisplay.clear();
    _bayEnergyData.clear();
    _busEnergySummary.clear();
    _abstractEnergyData.clear();
    _aggregatedFeederEnergyData.clear();

    _zonesMap.clear();
    _circlesMap.clear();
    _divisionsMap.clear();
    _subdivisionsMap.clear();
    _substationsMap.clear();
    _distributionZonesMap.clear();
    _distributionCirclesMap.clear();
    _distributionDivisionsMap.clear();
    _distributionSubdivisionsMap.clear();
  }
}

// Dummy class needed for SingleLineDiagramPainter to avoid compile errors
// as BayRenderData used to be a separate class.
class BayRenderData {
  final Bay bay;
  final Rect rect;
  final Offset center;
  final Offset topCenter;
  final Offset bottomCenter;
  final Offset leftCenter;
  final Offset rightCenter;
  final List<EquipmentInstance> equipmentInstances;
  final Offset textOffset;
  final double busbarLength;
  final Offset energyTextOffset;

  BayRenderData({
    required this.bay,
    required this.rect,
    required this.center,
    required this.topCenter,
    required this.bottomCenter,
    required this.leftCenter,
    required this.rightCenter,
    this.equipmentInstances = const [],
    required this.textOffset,
    required this.busbarLength,
    this.energyTextOffset = Offset.zero,
  });
}
