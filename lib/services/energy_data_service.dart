import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../models/bay_connection_model.dart';
import '../models/user_model.dart';
import '../models/saved_sld_model.dart';
import '../models/bay_model.dart';
import '../models/assessment_model.dart';
import '../models/busbar_energy_map.dart';
import '../models/hierarchy_models.dart';
import '../models/logsheet_models.dart';
import '../models/energy_readings_data.dart';
import '../controllers/sld_controller.dart';
import '../widgets/energy_assessment_dialog.dart';
import '../screens/busbar_configuration_screen.dart';
import '../utils/snackbar_utils.dart';

class EnergyDataService {
  final String substationId;
  final AppUser currentUser;
  final VoidCallback?
  onConfigurationChanged; // ✅ NEW: Callback for configuration changes

  Map<String, BusbarEnergyMap> _busbarEnergyMaps = {};
  List<Assessment> allAssessmentsForDisplay = [];
  List<Map<String, dynamic>> loadedAssessmentsSummary = [];
  Map<String, Zone> _zonesMap = {};
  Map<String, Circle> _circlesMap = {};
  Map<String, Division> _divisionsMap = {};
  Map<String, Subdivision> _subdivisionsMap = {};
  Map<String, Substation> _substationsMap = {};
  Map<String, DistributionZone> _distributionZonesMap = {};
  Map<String, DistributionCircle> _distributionCirclesMap = {};
  Map<String, DistributionDivision> _distributionDivisionsMap = {};
  Map<String, DistributionSubdivision> _distributionSubdivisionsMap = {};

  EnergyDataService({
    required this.substationId,
    required this.currentUser,
    this.onConfigurationChanged, // ✅ NEW: Optional callback
  });

  Future<void> loadFromSavedSld(
    SavedSld savedSld,
    SldController sldController,
  ) async {
    try {
      loadedAssessmentsSummary = savedSld.assessmentsSummary;
      final sldParameters = savedSld.sldParameters;
      final Map<String, BayEnergyData> savedBayEnergyData = {};
      if (sldParameters.containsKey('bayEnergyData')) {
        final bayEnergyDataMap =
            sldParameters['bayEnergyData'] as Map<String, dynamic>;
        for (var entry in bayEnergyDataMap.entries) {
          final bayId = entry.key;
          final bay = sldController.baysMap[bayId];
          if (bay != null) {
            savedBayEnergyData[entry.key] = BayEnergyData.fromMap(
              entry.value as Map<String, dynamic>,
              bay,
            );
          }
        }
      }
      final Map<String, Map<String, double>> savedBusEnergySummary =
          _parseNestedMap(sldParameters['busEnergySummary']);
      final Map<String, double> savedAbstractEnergyData =
          Map<String, double>.from(sldParameters['abstractEnergyData'] ?? {});
      final List<AggregatedFeederEnergyData> savedAggregatedFeederEnergyData =
          [];
      if (sldParameters.containsKey('aggregatedFeederEnergyData')) {
        final aggregatedDataList =
            sldParameters['aggregatedFeederEnergyData'] as List;
        for (var item in aggregatedDataList) {
          savedAggregatedFeederEnergyData.add(
            AggregatedFeederEnergyData.fromMap(item as Map<String, dynamic>),
          );
        }
      }
      sldController.updateEnergyData(
        bayEnergyData: savedBayEnergyData,
        busEnergySummary: savedBusEnergySummary,
        abstractEnergyData: savedAbstractEnergyData,
        aggregatedFeederEnergyData: savedAggregatedFeederEnergyData,
        latestAssessmentsPerBay: {},
      );
      allAssessmentsForDisplay = loadedAssessmentsSummary
          .map((assessmentMap) => Assessment.fromMap(assessmentMap))
          .toList();
    } catch (e) {
      print('Error loading from saved SLD: $e');
      rethrow;
    }
  }

  Future<void> loadLiveEnergyData(
    DateTime startDate,
    DateTime endDate,
    SldController sldController,
  ) async {
    try {
      await _fetchHierarchyData();
      await _loadBusbarEnergyMaps();
      final readings = await _fetchReadingsData(startDate, endDate);
      await _fetchAssessmentsData(startDate, endDate, sldController);
      final energyData = await _calculateEnergyData(
        startDate,
        endDate,
        readings,
        sldController,
      );
      sldController.updateEnergyData(
        bayEnergyData: energyData.bayEnergyData,
        busEnergySummary: energyData.busEnergySummary,
        abstractEnergyData: energyData.abstractEnergyData,
        aggregatedFeederEnergyData: energyData.aggregatedFeederEnergyData,
        latestAssessmentsPerBay: sldController.latestAssessmentsPerBay,
      );
    } catch (e) {
      print('Error loading live energy data: $e');
      rethrow;
    }
  }

  Future<void> _fetchHierarchyData() async {
    try {
      final futures = [
        FirebaseFirestore.instance.collection('zones').get(),
        FirebaseFirestore.instance.collection('circles').get(),
        FirebaseFirestore.instance.collection('divisions').get(),
        FirebaseFirestore.instance.collection('subdivisions').get(),
        FirebaseFirestore.instance.collection('substations').get(),
        FirebaseFirestore.instance.collection('distributionZones').get(),
        FirebaseFirestore.instance.collection('distributionCircles').get(),
        FirebaseFirestore.instance.collection('distributionDivisions').get(),
        FirebaseFirestore.instance.collection('distributionSubdivisions').get(),
      ];
      final results = await Future.wait(futures);
      _zonesMap = {
        for (var doc in results[0].docs) doc.id: Zone.fromFirestore(doc),
      };
      _circlesMap = {
        for (var doc in results[1].docs) doc.id: Circle.fromFirestore(doc),
      };
      _divisionsMap = {
        for (var doc in results[2].docs) doc.id: Division.fromFirestore(doc),
      };
      _subdivisionsMap = {
        for (var doc in results[3].docs) doc.id: Subdivision.fromFirestore(doc),
      };
      _substationsMap = {
        for (var doc in results[4].docs) doc.id: Substation.fromFirestore(doc),
      };
      _distributionZonesMap = {
        for (var doc in results[5].docs)
          doc.id: DistributionZone.fromFirestore(doc),
      };
      _distributionCirclesMap = {
        for (var doc in results[6].docs)
          doc.id: DistributionCircle.fromFirestore(doc),
      };
      _distributionDivisionsMap = {
        for (var doc in results[7].docs)
          doc.id: DistributionDivision.fromFirestore(doc),
      };
      _distributionSubdivisionsMap = {
        for (var doc in results[8].docs)
          doc.id: DistributionSubdivision.fromFirestore(doc),
      };
    } catch (e) {
      print('Error fetching hierarchy data: $e');
      rethrow;
    }
  }

  Future<void> _loadBusbarEnergyMaps() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('busbarEnergyMaps')
          .where('substationId', isEqualTo: substationId)
          .get();
      _busbarEnergyMaps = {
        for (var doc in snapshot.docs)
          '${doc['busbarId']}-${doc['connectedBayId']}':
              BusbarEnergyMap.fromFirestore(doc),
      };
      print('DEBUG: Loaded ${_busbarEnergyMaps.length} busbar energy maps');
    } catch (e) {
      print('Error loading busbar energy maps: $e');
      rethrow;
    }
  }

  Future<ReadingsData> _fetchReadingsData(
    DateTime startDate,
    DateTime endDate,
  ) async {
    try {
      final startOfStartDate = DateTime(
        startDate.year,
        startDate.month,
        startDate.day,
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
      final query = FirebaseFirestore.instance
          .collection('logsheetEntries')
          .where('substationId', isEqualTo: substationId)
          .where('frequency', isEqualTo: 'daily')
          .where(
            'readingTimestamp',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startOfStartDate),
          )
          .where(
            'readingTimestamp',
            isLessThanOrEqualTo: Timestamp.fromDate(endOfEndDate),
          )
          .orderBy('readingTimestamp');
      final snapshot = await query.get();
      final Map<String, LogsheetEntry> startDayReadings = {};
      final Map<String, LogsheetEntry> endDayReadings = {};
      final Map<String, LogsheetEntry> previousDayReadings = {};
      final Map<String, List<LogsheetEntry>> readingsByBay = {};
      for (var doc in snapshot.docs) {
        final entry = LogsheetEntry.fromFirestore(doc);
        readingsByBay.putIfAbsent(entry.bayId, () => []).add(entry);
      }
      for (var entry in readingsByBay.entries) {
        final bayId = entry.key;
        final readings = entry.value;
        readings.sort(
          (a, b) => a.readingTimestamp.compareTo(b.readingTimestamp),
        );
        if (readings.isNotEmpty) {
          startDayReadings[bayId] = readings.first;
          endDayReadings[bayId] = readings.last;
        }
      }
      if (startDate.isAtSameMomentAs(endDate)) {
        final previousDay = startDate.subtract(const Duration(days: 1));
        final prevStart = DateTime(
          previousDay.year,
          previousDay.month,
          previousDay.day,
        );
        final prevEnd = DateTime(
          previousDay.year,
          previousDay.month,
          previousDay.day,
          23,
          59,
          59,
          999,
        );
        final prevSnapshot = await FirebaseFirestore.instance
            .collection('logsheetEntries')
            .where('substationId', isEqualTo: substationId)
            .where('frequency', isEqualTo: 'daily')
            .where(
              'readingTimestamp',
              isGreaterThanOrEqualTo: Timestamp.fromDate(prevStart),
            )
            .where(
              'readingTimestamp',
              isLessThanOrEqualTo: Timestamp.fromDate(prevEnd),
            )
            .get();
        for (var doc in prevSnapshot.docs) {
          final entry = LogsheetEntry.fromFirestore(doc);
          previousDayReadings[entry.bayId] = entry;
        }
      }
      return ReadingsData(
        startDayReadings: startDayReadings,
        endDayReadings: endDayReadings,
        previousDayReadings: previousDayReadings,
      );
    } catch (e) {
      print('Error fetching readings data: $e');
      return ReadingsData(
        startDayReadings: {},
        endDayReadings: {},
        previousDayReadings: {},
      );
    }
  }

  Future<void> _fetchAssessmentsData(
    DateTime startDate,
    DateTime endDate,
    SldController sldController,
  ) async {
    try {
      final startOfStartDate = DateTime(
        startDate.year,
        startDate.month,
        startDate.day,
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
      final snapshot = await FirebaseFirestore.instance
          .collection('assessments')
          .where('substationId', isEqualTo: substationId)
          .where(
            'createdAt',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startOfStartDate),
          )
          .where(
            'createdAt',
            isLessThanOrEqualTo: Timestamp.fromDate(endOfEndDate),
          )
          .orderBy('createdAt', descending: true)
          .get();
      allAssessmentsForDisplay.clear();
      sldController.latestAssessmentsPerBay.clear();
      for (var doc in snapshot.docs) {
        final assessment = Assessment.fromFirestore(doc);
        allAssessmentsForDisplay.add(assessment);
        if (!sldController.latestAssessmentsPerBay.containsKey(
          assessment.bayId,
        )) {
          sldController.latestAssessmentsPerBay[assessment.bayId] = assessment;
        }
      }
      allAssessmentsForDisplay.sort(
        (a, b) => b.createdAt.compareTo(a.createdAt),
      );
    } catch (e) {
      print('Error fetching assessments data: $e');
    }
  }

  Future<CalculatedEnergyData> _calculateEnergyData(
    DateTime startDate,
    DateTime endDate,
    ReadingsData readings,
    SldController sldController,
  ) async {
    final Map<String, BayEnergyData> calculatedBayEnergyData = {};
    for (var bay in sldController.allBays) {
      final assessment = sldController.latestAssessmentsPerBay[bay.id];
      final energyData = _calculateBayEnergyData(
        bay,
        startDate,
        endDate,
        readings,
        assessment: assessment,
      );
      calculatedBayEnergyData[bay.id] = energyData;
    }
    final busEnergySummary = _calculateBusEnergySummary(
      calculatedBayEnergyData,
      sldController,
    );
    final abstractEnergyData = _calculateAbstractEnergyData(
      busEnergySummary,
      sldController,
    );
    final aggregatedFeederData = _calculateAggregatedFeederData(
      calculatedBayEnergyData,
      sldController,
    );
    return CalculatedEnergyData(
      bayEnergyData: calculatedBayEnergyData,
      busEnergySummary: busEnergySummary,
      abstractEnergyData: abstractEnergyData,
      aggregatedFeederEnergyData: aggregatedFeederData,
    );
  }

  /// SAME-DATE LOGIC is here!
  BayEnergyData _calculateBayEnergyData(
    Bay bay,
    DateTime startDate,
    DateTime endDate,
    ReadingsData readings, {
    Assessment? assessment,
  }) {
    final double mf = bay.multiplyingFactor ?? 1.0;
    if (startDate.isAtSameMomentAs(endDate)) {
      final currentLog = readings.endDayReadings[bay.id];
      final previousLog = readings.previousDayReadings[bay.id];
      double curr = 0, prev = 0, expCurr = 0, expPrev = 0;
      if (currentLog != null) {
        curr =
            _extractDoubleValue(
              currentLog.values['Current Day Reading (Import)'],
            ) ??
            0.0;
        expCurr =
            _extractDoubleValue(
              currentLog.values['Current Day Reading (Export)'],
            ) ??
            0.0;
        if (previousLog != null) {
          prev =
              _extractDoubleValue(
                previousLog.values['Current Day Reading (Import)'],
              ) ??
              0.0;
          expPrev =
              _extractDoubleValue(
                previousLog.values['Current Day Reading (Export)'],
              ) ??
              0.0;
        } else {
          prev =
              _extractDoubleValue(
                currentLog.values['Previous Day Reading (Import)'],
              ) ??
              0.0;
          expPrev =
              _extractDoubleValue(
                currentLog.values['Previous Day Reading (Export)'],
              ) ??
              0.0;
        }
      }
      return BayEnergyData.fromReadings(
        bay: bay,
        currentImportReading: curr,
        currentExportReading: expCurr,
        previousImportReading: prev,
        previousExportReading: expPrev,
        multiplierFactor: mf,
        assessment: assessment,
        readingTimestamp: currentLog?.readingTimestamp,
        previousReadingTimestamp: previousLog?.readingTimestamp,
        sourceLogsheetId: currentLog?.id,
      );
    } else {
      final startLog = readings.startDayReadings[bay.id];
      final endLog = readings.endDayReadings[bay.id];
      double startImport = 0, endImport = 0, startExport = 0, endExport = 0;
      if (startLog != null) {
        startImport =
            _extractDoubleValue(
              startLog.values['Current Day Reading (Import)'],
            ) ??
            0.0;
        startExport =
            _extractDoubleValue(
              startLog.values['Current Day Reading (Export)'],
            ) ??
            0.0;
      }
      if (endLog != null) {
        endImport =
            _extractDoubleValue(
              endLog.values['Current Day Reading (Import)'],
            ) ??
            0.0;
        endExport =
            _extractDoubleValue(
              endLog.values['Current Day Reading (Export)'],
            ) ??
            0.0;
      }
      return BayEnergyData.fromReadings(
        bay: bay,
        currentImportReading: endImport,
        currentExportReading: endExport,
        previousImportReading: startImport,
        previousExportReading: startExport,
        multiplierFactor: mf,
        assessment: assessment,
        readingTimestamp: endLog?.readingTimestamp,
        previousReadingTimestamp: startLog?.readingTimestamp,
        sourceLogsheetId: endLog?.id,
      );
    }
  }

  double? _extractDoubleValue(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value);
    if (value is Map && value.containsKey('value')) {
      return _extractDoubleValue(value['value']);
    }
    return null;
  }

  // ✅ UPDATED: Apply busbar energy map configurations with new energy mapping logic
  Map<String, Map<String, double>> _calculateBusEnergySummary(
    Map<String, BayEnergyData> bayEnergyData,
    SldController sldController,
  ) {
    final Map<String, Map<String, double>> busEnergySummary = {};
    final List<Bay> busbarBays = sldController.allBays
        .where((bay) => bay.bayType == 'Busbar')
        .toList();

    for (var busbar in busbarBays) {
      double totalImp = 0.0;
      double totalExp = 0.0;
      int connectedBayCount = 0;
      int configuredBayCount = 0;

      final List<Bay> connectedBays = _getConnectedBays(busbar, sldController);

      for (var connectedBay in connectedBays) {
        if (connectedBay.bayType != 'Busbar') {
          connectedBayCount++;

          // ✅ GET BUSBAR ENERGY MAP CONFIGURATION
          final mapKey = '${busbar.id}-${connectedBay.id}';
          final busbarMap = _busbarEnergyMaps[mapKey];

          final energyData = bayEnergyData[connectedBay.id];
          if (energyData != null && busbarMap != null) {
            configuredBayCount++;

            // ✅ APPLY IMPORT CONTRIBUTION MAPPING
            switch (busbarMap.importContribution) {
              case EnergyContributionType.busImport:
                totalImp += energyData.adjustedImportConsumed;
                print(
                  'DEBUG: Adding ${connectedBay.name} import (${energyData.adjustedImportConsumed}) to ${busbar.name} import',
                );
                break;
              case EnergyContributionType.busExport:
                totalExp += energyData.adjustedImportConsumed;
                print(
                  'DEBUG: Adding ${connectedBay.name} import (${energyData.adjustedImportConsumed}) to ${busbar.name} export',
                );
                break;
              case EnergyContributionType.none:
                print(
                  'DEBUG: ${connectedBay.name} import not contributing to ${busbar.name}',
                );
                break;
            }

            // ✅ APPLY EXPORT CONTRIBUTION MAPPING
            switch (busbarMap.exportContribution) {
              case EnergyContributionType.busImport:
                totalImp += energyData.adjustedExportConsumed;
                print(
                  'DEBUG: Adding ${connectedBay.name} export (${energyData.adjustedExportConsumed}) to ${busbar.name} import',
                );
                break;
              case EnergyContributionType.busExport:
                totalExp += energyData.adjustedExportConsumed;
                print(
                  'DEBUG: Adding ${connectedBay.name} export (${energyData.adjustedExportConsumed}) to ${busbar.name} export',
                );
                break;
              case EnergyContributionType.none:
                print(
                  'DEBUG: ${connectedBay.name} export not contributing to ${busbar.name}',
                );
                break;
            }
          } else if (energyData != null) {
            // ✅ DEFAULT BEHAVIOR: If no configuration exists, include normally
            totalImp += energyData.adjustedImportConsumed;
            totalExp += energyData.adjustedExportConsumed;
            print(
              'DEBUG: Default mapping for ${connectedBay.name} to ${busbar.name}',
            );
          }
        }
      }

      busEnergySummary[busbar.id] = {
        'totalImp': totalImp,
        'totalExp': totalExp,
        'netConsumption': totalImp - totalExp,
        'connectedBayCount': connectedBayCount.toDouble(),
        'configuredBayCount': configuredBayCount.toDouble(),
      };

      print(
        'DEBUG: Busbar ${busbar.name} summary: Import=$totalImp, Export=$totalExp, Connected=$connectedBayCount, Configured=$configuredBayCount',
      );
    }

    return busEnergySummary;
  }

  List<Bay> _getConnectedBays(Bay busbar, SldController sldController) {
    final List<Bay> connectedBays = [];
    final List<BayConnection> connections = sldController.allConnections;
    for (var connection in connections) {
      Bay? connectedBay;
      if (connection.sourceBayId == busbar.id) {
        connectedBay = sldController.baysMap[connection.targetBayId];
      } else if (connection.targetBayId == busbar.id) {
        connectedBay = sldController.baysMap[connection.sourceBayId];
      }
      if (connectedBay != null && !connectedBays.contains(connectedBay)) {
        connectedBays.add(connectedBay);
      }
    }
    return connectedBays;
  }

  Map<String, double> _calculateAbstractEnergyData(
    Map<String, Map<String, double>> busEnergySummary,
    SldController sldController,
  ) {
    double totalImp = 0.0;
    double totalExp = 0.0;
    for (var voltageData in busEnergySummary.values) {
      totalImp += voltageData['totalImp'] ?? 0.0;
      totalExp += voltageData['totalExp'] ?? 0.0;
    }
    final double difference = totalImp - totalExp;
    final double lossPercentage = totalImp > 0
        ? (difference / totalImp) * 100
        : 0.0;
    return {
      'totalImp': totalImp,
      'totalExp': totalExp,
      'difference': difference,
      'lossPercentage': lossPercentage,
    };
  }

  List<AggregatedFeederEnergyData> _calculateAggregatedFeederData(
    Map<String, BayEnergyData> bayEnergyData,
    SldController sldController,
  ) {
    final List<AggregatedFeederEnergyData> aggregatedData = [];
    final currentSubstation = _substationsMap[substationId];
    final currentSubdivision = currentSubstation != null
        ? _subdivisionsMap[currentSubstation.subdivisionId]
        : null;
    final currentDivision = currentSubdivision != null
        ? _divisionsMap[currentSubdivision.divisionId]
        : null;
    final currentCircle = currentDivision != null
        ? _circlesMap[currentDivision.circleId]
        : null;
    final currentZone = currentCircle != null
        ? _zonesMap[currentCircle.zoneId]
        : null;
    DistributionSubdivision? currentDistSubdivision;
    try {
      currentDistSubdivision = _distributionSubdivisionsMap.values
          .where((distSub) => distSub.substationIds.contains(substationId))
          .firstOrNull;
    } catch (e) {}
    final Map<String, List<Bay>> feederGroups = {};
    for (var bay in sldController.allBays.where(
      (b) => b.bayType.toLowerCase() == 'feeder',
    )) {
      String groupKey = 'default';
      if (bay.name.contains('DIST') || bay.name.contains('Distribution')) {
        groupKey = 'distribution';
      } else if (bay.name.contains('TRANS') ||
          bay.name.contains('Transmission')) {
        groupKey = 'transmission';
      }
      feederGroups.putIfAbsent(groupKey, () => []).add(bay);
    }
    for (var entry in feederGroups.entries) {
      final feeders = entry.value;
      double totalImp = 0.0;
      double totalExp = 0.0;
      for (var feeder in feeders) {
        final energyData = bayEnergyData[feeder.id];
        if (energyData != null) {
          totalImp += energyData.adjustedImportConsumed;
          totalExp += energyData.adjustedExportConsumed;
        }
      }
      if (feeders.isNotEmpty) {
        aggregatedData.add(
          AggregatedFeederEnergyData(
            zoneName: currentZone?.name ?? 'Unknown Zone',
            circleName: currentCircle?.name ?? 'Unknown Circle',
            divisionName: currentDivision?.name ?? 'Unknown Division',
            distributionSubdivisionName:
                currentDistSubdivision?.name ??
                'Unknown Distribution Subdivision',
            importedEnergy: totalImp,
            exportedEnergy: totalExp,
          ),
        );
      }
    }
    return aggregatedData;
  }

  // ✅ UPDATED: Enhanced busbar selection dialog with configuration status
  void showBusbarSelectionDialog(
    BuildContext context,
    SldController sldController,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Busbar Energy Mapping'),
        content: SizedBox(
          width: double.maxFinite,
          height: 400, // ✅ Increased height for better UX
          child: Builder(
            builder: (context) {
              List<Bay> busbars = sldController.allBays
                  .where((bay) => bay.bayType.toLowerCase() == 'busbar')
                  .toList();

              if (busbars.isEmpty) {
                final busEnergyKeys = sldController.busEnergySummary.keys
                    .toSet();
                busbars = sldController.allBays
                    .where((bay) => busEnergyKeys.contains(bay.id))
                    .toList();
              }

              if (busbars.isEmpty) {
                return const Center(child: Text('No busbars found'));
              }

              return ListView.builder(
                itemCount: busbars.length,
                itemBuilder: (context, index) {
                  final busbar = busbars[index];
                  final connectedBays = _getConnectedBays(
                    busbar,
                    sldController,
                  );
                  final nonBusbarBays = connectedBays
                      .where((bay) => bay.bayType != 'Busbar')
                      .length;
                  final configurationStatus = _getBusbarConfigurationStatus(
                    busbar,
                  );

                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    child: ListTile(
                      leading: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: configurationStatus['hasCustomConfig']
                              ? Colors.blue.withOpacity(0.1)
                              : Colors.grey.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          configurationStatus['hasCustomConfig']
                              ? Icons.settings
                              : Icons.settings_outlined,
                          color: configurationStatus['hasCustomConfig']
                              ? Colors.blue
                              : Colors.grey,
                          size: 20,
                        ),
                      ),
                      title: Text(
                        '${busbar.voltageLevel} ${busbar.name}',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Connected bays: $nonBusbarBays'),
                          if (configurationStatus['hasCustomConfig'])
                            Text(
                              'Energy mappings configured',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.blue.shade700,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                        ],
                      ),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                      onTap: () {
                        Navigator.pop(context);
                        _showBusbarConfigurationDialog(
                          context,
                          busbar,
                          sldController,
                        );
                      },
                    ),
                  );
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  // ✅ UPDATED: Get busbar configuration status for energy mapping
  Map<String, dynamic> _getBusbarConfigurationStatus(Bay busbar) {
    final connectedBayIds = _busbarEnergyMaps.keys
        .where((key) => key.startsWith('${busbar.id}-'))
        .map((key) => key.split('-')[1])
        .toList();

    if (connectedBayIds.isEmpty) {
      return {'hasCustomConfig': false, 'totalCount': 0, 'configuredCount': 0};
    }

    return {
      'hasCustomConfig': true,
      'totalCount': connectedBayIds.length,
      'configuredCount': connectedBayIds.length,
    };
  }

  // ✅ UPDATED: Show individual busbar configuration dialog for energy mapping
  void _showBusbarConfigurationDialog(
    BuildContext context,
    Bay busbar,
    SldController sldController,
  ) {
    final connectedBays = _getConnectedBays(
      busbar,
      sldController,
    ).where((bay) => bay.bayType != 'Busbar').toList();

    // Get current configuration
    final currentConfig = <String, BusbarEnergyMap>{};
    for (var bay in connectedBays) {
      final mapKey = '${busbar.id}-${bay.id}';
      final existing = _busbarEnergyMaps[mapKey];
      if (existing != null) {
        currentConfig[mapKey] = existing;
      }
    }

    showDialog(
      context: context,
      builder: (context) => BusbarConfigurationScreen(
        busbar: busbar,
        connectedBays: connectedBays,
        currentConfiguration: currentConfig.isNotEmpty ? currentConfig : null,
        onSaveConfiguration: (configMap) async {
          try {
            // Save each BusbarEnergyMap to Firestore
            await _saveBusbarEnergyMaps(configMap);

            // Trigger configuration change callback
            if (onConfigurationChanged != null) {
              onConfigurationChanged!();
            }

            SnackBarUtils.showSnackBar(
              context,
              'Busbar ${busbar.name} energy mapping saved successfully!',
            );
          } catch (e) {
            SnackBarUtils.showSnackBar(
              context,
              'Failed to save configuration: $e',
              isError: true,
            );
          }
        },
      ),
    );
  }

  // ✅ NEW: Save busbar energy maps (multiple configurations)
  Future<void> _saveBusbarEnergyMaps(
    Map<String, BusbarEnergyMap> configMaps,
  ) async {
    final batch = FirebaseFirestore.instance.batch();

    for (var entry in configMaps.entries) {
      final mapKey = entry.key;
      final energyMap = entry.value;

      // Check if configuration already exists
      final existingMap = _busbarEnergyMaps[mapKey];

      if (existingMap != null) {
        // Update existing configuration
        final docRef = FirebaseFirestore.instance
            .collection('busbarEnergyMaps')
            .doc(existingMap.id);

        batch.update(docRef, energyMap.toFirestore());

        // Update local cache
        _busbarEnergyMaps[mapKey] = energyMap.copyWith(id: existingMap.id);
      } else {
        // Create new configuration
        final newMapRef = FirebaseFirestore.instance
            .collection('busbarEnergyMaps')
            .doc();

        final newMap = energyMap.copyWith(id: newMapRef.id);

        batch.set(newMapRef, newMap.toFirestore());

        // Update local cache
        _busbarEnergyMaps[mapKey] = newMap;
      }
    }

    await batch.commit();
    print('DEBUG: Saved busbar energy maps');
  }

  // ✅ DEPRECATED: Old method kept for backward compatibility
  Future<void> _saveBusbarConfiguration(
    Bay busbar,
    Map<String, bool> inclusionMap,
  ) async {
    // This method is deprecated but kept for backward compatibility
    // Use _saveBusbarEnergyMaps instead
    print('WARNING: Using deprecated _saveBusbarConfiguration method');
  }

  // ✅ NEW: Get current bay energy mapping for a busbar
  Map<String, BusbarEnergyMap> getBayEnergyMappings(
    Bay busbar,
    List<Bay> connectedBays,
  ) {
    final Map<String, BusbarEnergyMap> mappings = {};

    for (var bay in connectedBays) {
      final mapKey = '${busbar.id}-${bay.id}';
      final busbarMap = _busbarEnergyMaps[mapKey];
      if (busbarMap != null) {
        mappings[mapKey] = busbarMap;
      }
    }

    return mappings;
  }

  // ✅ DEPRECATED: Old method kept for backward compatibility
  Map<String, bool> getBayInclusionMap(Bay busbar, List<Bay> connectedBays) {
    // This method is deprecated but kept for backward compatibility
    final Map<String, bool> inclusionMap = {};

    for (var bay in connectedBays) {
      final mapKey = '${busbar.id}-${bay.id}';
      final busbarMap = _busbarEnergyMaps[mapKey];
      // Convert energy mapping to simple inclusion (if any contribution exists)
      bool isIncluded =
          busbarMap != null &&
          (busbarMap.importContribution != EnergyContributionType.none ||
              busbarMap.exportContribution != EnergyContributionType.none);
      inclusionMap[bay.id] = isIncluded;
    }

    return inclusionMap;
  }

  // ✅ NEW: Reset busbar configuration to defaults
  Future<void> resetBusbarConfiguration(Bay busbar) async {
    try {
      final batch = FirebaseFirestore.instance.batch();

      // Find all configurations for this busbar
      final configurationsToDelete = _busbarEnergyMaps.entries
          .where((entry) => entry.key.startsWith('${busbar.id}-'))
          .toList();

      for (var entry in configurationsToDelete) {
        final mapId = entry.value.id;
        final docRef = FirebaseFirestore.instance
            .collection('busbarEnergyMaps')
            .doc(mapId);

        batch.delete(docRef);
        _busbarEnergyMaps.remove(entry.key);
      }

      await batch.commit();
      print('DEBUG: Reset busbar configuration for ${busbar.name}');

      // Trigger configuration change callback
      if (onConfigurationChanged != null) {
        onConfigurationChanged!();
      }
    } catch (e) {
      print('ERROR: Failed to reset busbar configuration: $e');
      rethrow;
    }
  }

  // ✅ NEW: Get all busbar configurations for export/backup
  List<BusbarEnergyMap> getAllBusbarConfigurations() {
    return _busbarEnergyMaps.values.toList();
  }

  // ✅ NEW: Check if a busbar has custom configuration
  bool hasCustomConfiguration(Bay busbar) {
    return _busbarEnergyMaps.keys.any((key) => key.startsWith('${busbar.id}-'));
  }

  void showBaySelectionForAssessment(
    BuildContext context,
    SldController sldController,
  ) {
    final availableBays = sldController.allBays
        .where((bay) => bay.bayType.toLowerCase() != 'busbar')
        .toList();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Bay for Assessment'),
        content: SizedBox(
          width: double.maxFinite,
          height: 300,
          child: ListView.builder(
            itemCount: availableBays.length,
            itemBuilder: (context, index) {
              final bay = availableBays[index];
              return ListTile(
                title: Text(bay.name),
                subtitle: Text(bay.bayType),
                onTap: () {
                  Navigator.pop(context);
                  _showEnergyAssessmentDialog(context, bay, sldController);
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _showEnergyAssessmentDialog(
    BuildContext context,
    Bay bay,
    SldController sldController,
  ) {
    showDialog(
      context: context,
      builder: (context) => EnergyAssessmentDialog(
        bay: bay,
        currentUser: currentUser,
        currentEnergyData: sldController.bayEnergyData[bay.id],
        onSaveAssessment: () {
          loadLiveEnergyData(
            DateTime.now().subtract(const Duration(days: 1)),
            DateTime.now(),
            sldController,
          );
        },
        latestExistingAssessment: sldController.latestAssessmentsPerBay[bay.id],
      ),
    );
  }

  Map<String, Map<String, double>> _parseNestedMap(dynamic data) {
    if (data == null) return {};
    final result = <String, Map<String, double>>{};
    final map = data as Map<String, dynamic>;
    for (var entry in map.entries) {
      result[entry.key] = Map<String, double>.from(entry.value as Map);
    }
    return result;
  }

  Future<void> saveBusbarEnergyMap(BusbarEnergyMap map) async {
    try {
      await FirebaseFirestore.instance
          .collection('busbarEnergyMaps')
          .add(map.toFirestore());
    } catch (e) {
      print('Error saving busbar energy map: $e');
      rethrow;
    }
  }

  Future<void> deleteBusbarEnergyMap(String mapId) async {
    try {
      await FirebaseFirestore.instance
          .collection('busbarEnergyMaps')
          .doc(mapId)
          .delete();
    } catch (e) {
      print('Error deleting busbar energy map: $e');
      rethrow;
    }
  }
}

class ReadingsData {
  final Map<String, LogsheetEntry> startDayReadings;
  final Map<String, LogsheetEntry> endDayReadings;
  final Map<String, LogsheetEntry> previousDayReadings;
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

extension IterableExtensions<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
