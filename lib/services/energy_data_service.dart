// lib/services/energy_data_service.dart

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:substation_manager/screens/busbar_configuration_screen.dart';

import '../models/bay_connection_model.dart';
import '../models/user_model.dart';
import '../models/saved_sld_model.dart';
import '../models/bay_model.dart';
import '../models/assessment_model.dart';
import '../models/busbar_energy_map.dart';
import '../models/logsheet_models.dart';
import '../models/hierarchy_models.dart';
import '../models/energy_readings_data.dart';
import '../controllers/sld_controller.dart';
import '../widgets/energy_assessment_dialog.dart';
import '../utils/snackbar_utils.dart';

class EnergyDataService {
  final String substationId;
  final AppUser currentUser;

  Map<String, BusbarEnergyMap> _busbarEnergyMaps = {};
  List<Assessment> allAssessmentsForDisplay = [];
  List<Map<String, dynamic>> loadedAssessmentsSummary = [];

  // Hierarchy maps
  Map<String, Zone> _zonesMap = {};
  Map<String, Circle> _circlesMap = {};
  Map<String, Division> _divisionsMap = {};
  Map<String, Subdivision> _subdivisionsMap = {};
  Map<String, Substation> _substationsMap = {};

  // Distribution hierarchy maps
  Map<String, DistributionZone> _distributionZonesMap = {};
  Map<String, DistributionCircle> _distributionCirclesMap = {};
  Map<String, DistributionDivision> _distributionDivisionsMap = {};
  Map<String, DistributionSubdivision> _distributionSubdivisionsMap = {};

  EnergyDataService({required this.substationId, required this.currentUser});

  Future<void> loadFromSavedSld(
    SavedSld savedSld,
    SldController sldController,
  ) async {
    try {
      loadedAssessmentsSummary = savedSld.assessmentsSummary;

      // Parse saved SLD parameters
      final sldParameters = savedSld.sldParameters;

      // Extract bay energy data from saved parameters
      final Map<String, BayEnergyData> savedBayEnergyData = {};
      if (sldParameters.containsKey('bayEnergyData')) {
        final bayEnergyDataMap =
            sldParameters['bayEnergyData'] as Map<String, dynamic>;
        for (var entry in bayEnergyDataMap.entries) {
          final bayId = entry.key;
          final bay = sldController.baysMap[bayId];
          if (bay != null) {
            // ✅ FIXED: Use bayObject instead of bay and bayId
            savedBayEnergyData[entry.key] = BayEnergyData.fromMap(
              entry.value as Map<String, dynamic>,
              bayObject: bay, // Changed from 'bay:' to 'bayObject:'
              // Removed bayId parameter as it's not needed
            );
          }
        }
      }

      // Extract other energy data from saved parameters
      final Map<String, Map<String, double>> savedBusEnergySummary =
          _parseNestedMap(sldParameters['busEnergySummary']);

      final Map<String, double> savedAbstractEnergyData =
          Map<String, double>.from(sldParameters['abstractEnergyData'] ?? {});

      // Extract and convert aggregated feeder energy data
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

      // Update controller with saved energy data
      sldController.updateEnergyData(
        bayEnergyData: savedBayEnergyData,
        busEnergySummary: savedBusEnergySummary,
        abstractEnergyData: savedAbstractEnergyData,
        aggregatedFeederEnergyData: savedAggregatedFeederEnergyData,
        latestAssessmentsPerBay: {},
      );

      // Convert assessments summary to Assessment objects
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

      // Fetch readings for the date range
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

      // Group readings by bay and get start/end readings
      final Map<String, List<LogsheetEntry>> readingsByBay = {};
      for (var doc in snapshot.docs) {
        final entry = LogsheetEntry.fromFirestore(doc);
        readingsByBay.putIfAbsent(entry.bayId, () => []).add(entry);
      }

      // Get first and last readings for each bay
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

      return ReadingsData(
        startDayReadings: startDayReadings,
        endDayReadings: endDayReadings,
        previousDayReadings: {},
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
            'assessmentTimestamp',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startOfStartDate),
          )
          .where(
            'assessmentTimestamp',
            isLessThanOrEqualTo: Timestamp.fromDate(endOfEndDate),
          )
          .orderBy('assessmentTimestamp', descending: true)
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
        (a, b) => b.assessmentTimestamp.compareTo(a.assessmentTimestamp),
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

    // Calculate energy data for each bay
    for (var bay in sldController.allBays) {
      final energyData = _calculateBayEnergyData(
        bay,
        startDate,
        endDate,
        readings,
      );

      // Apply assessments if available
      final assessment = sldController.latestAssessmentsPerBay[bay.id];
      if (assessment != null) {
        calculatedBayEnergyData[bay.id] = BayEnergyData(
          bay: bay,
          bayId: bay.id,
          bayName: bay.name,
          prevImp: energyData.prevImp,
          currImp: energyData.currImp,
          prevExp: energyData.prevExp,
          currExp: energyData.currExp,
          mf: energyData.mf,
          impConsumed:
              (energyData.impConsumed ?? 0.0) +
              (assessment.importAdjustment ?? 0.0),
          expConsumed:
              (energyData.expConsumed ?? 0.0) +
              (assessment.exportAdjustment ?? 0.0),
          hasAssessment: true,
        );
      } else {
        calculatedBayEnergyData[bay.id] = energyData;
      }
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

  BayEnergyData _calculateBayEnergyData(
    Bay bay,
    DateTime startDate,
    DateTime endDate,
    ReadingsData readings,
  ) {
    final double mf = bay.multiplyingFactor ?? 1.0;

    final startReading = readings.startDayReadings[bay.id];
    final endReading = readings.endDayReadings[bay.id];

    double prevImp = 0.0;
    double currImp = 0.0;
    double prevExp = 0.0;
    double currExp = 0.0;

    if (startReading != null) {
      prevImp =
          _extractDoubleValue(startReading.values['Import Energy']) ?? 0.0;
      prevExp =
          _extractDoubleValue(startReading.values['Export Energy']) ?? 0.0;
    }

    if (endReading != null) {
      currImp = _extractDoubleValue(endReading.values['Import Energy']) ?? 0.0;
      currExp = _extractDoubleValue(endReading.values['Export Energy']) ?? 0.0;
    }

    double impConsumed = math.max(0, (currImp - prevImp) * mf);
    double expConsumed = math.max(0, (currExp - prevExp) * mf);

    return BayEnergyData(
      bay: bay,
      bayId: bay.id,
      bayName: bay.name,
      prevImp: prevImp,
      currImp: currImp,
      prevExp: prevExp,
      currExp: currExp,
      mf: mf,
      impConsumed: impConsumed,
      expConsumed: expConsumed,
      hasAssessment: false,
    );
  }

  double? _extractDoubleValue(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  Map<String, Map<String, double>> _calculateBusEnergySummary(
    Map<String, BayEnergyData> bayEnergyData,
    SldController sldController,
  ) {
    final Map<String, Map<String, double>> busEnergySummary = {};

    // Get all busbar bays from the SLD
    final List<Bay> busbarBays = sldController.allBays
        .where((bay) => bay.bayType == 'Busbar')
        .toList();

    for (var busbar in busbarBays) {
      double totalImp = 0.0;
      double totalExp = 0.0;
      int connectedBayCount = 0;

      // Find all bays connected to this busbar
      final List<Bay> connectedBays = _getConnectedBays(busbar, sldController);

      // Sum up energy consumption from all connected bays
      for (var connectedBay in connectedBays) {
        // Skip the busbar itself and only include non-busbar bays
        if (connectedBay.bayType != 'Busbar') {
          final energyData = bayEnergyData[connectedBay.id];
          if (energyData != null) {
            // Use impConsumed and expConsumed for the connected bays
            totalImp += energyData.impConsumed ?? 0.0;
            totalExp += energyData.expConsumed ?? 0.0;
            connectedBayCount++;
          }
        }
      }

      // Use busbar bay ID as the key (this is what the painter expects)
      busEnergySummary[busbar.id] = {
        'totalImp': totalImp,
        'totalExp': totalExp,
        'netConsumption': totalImp - totalExp,
        'connectedBayCount': connectedBayCount.toDouble(),
      };
    }

    return busEnergySummary;
  }

  // Updated helper method with correct property access
  List<Bay> _getConnectedBays(Bay busbar, SldController sldController) {
    final List<Bay> connectedBays = [];

    // Use the correct property name from SldController
    List<BayConnection> connections = sldController.allConnections;

    // Check all bay connections to find bays connected to this busbar
    for (var connection in connections) {
      Bay? connectedBay;

      // If busbar is the source, add the target bay
      if (connection.sourceBayId == busbar.id) {
        connectedBay = sldController.baysMap[connection.targetBayId];
      }
      // If busbar is the target, add the source bay
      else if (connection.targetBayId == busbar.id) {
        connectedBay = sldController.baysMap[connection.sourceBayId];
      }

      // Add the connected bay if it exists and isn't already in the list
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
      totalImp += voltageData['totalImport'] ?? 0.0;
      totalExp += voltageData['totalExport'] ?? 0.0;
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

    // Get hierarchy information
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

    final currentDistSubdivision = _distributionSubdivisionsMap.values.firstWhere(
      (distSub) => distSub.substationIds.contains(substationId),
      orElse: () => DistributionSubdivision(
        id: '',
        name: 'Unknown Distribution Subdivision',
        distributionDivisionId: '', // ✅ required
        // optional fields—pass empty strings or omit if your constructor marks them nullable
        description: '',
        landmark: '',
        contactNumber: '',
        contactPerson: '',
        contactDesignation: '',
      ),
    );

    // Group feeders
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
          totalImp += energyData.impConsumed ?? 0.0;
          totalExp += energyData.expConsumed ?? 0.0;
        }
      }

      if (feeders.isNotEmpty) {
        aggregatedData.add(
          AggregatedFeederEnergyData(
            zoneName: currentZone?.name ?? 'Unknown Zone',
            circleName: currentCircle?.name ?? 'Unknown Circle',
            divisionName: currentDivision?.name ?? 'Unknown Division',
            distributionSubdivisionName: currentDistSubdivision.name,
            importedEnergy: totalImp,
            exportedEnergy: totalExp,
          ),
        );
      }
    }

    return aggregatedData;
  }

  void showBusbarSelectionDialog(
    BuildContext context,
    SldController sldController,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Busbar Configuration'),
        content: SizedBox(
          width: double.maxFinite,
          height: 300,
          child: Builder(
            builder: (context) {
              // Find busbars using the passed sldController directly
              List<Bay> busbars = sldController.allBays
                  .where((bay) => bay.bayType.toLowerCase() == 'busbar')
                  .toList();

              // If empty, use bays that have energy summaries
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
                  return ListTile(
                    title: Text('${busbar.voltageLevel} ${busbar.name}'),
                    subtitle: Text('ID: ${busbar.id}'),
                    onTap: () {
                      Navigator.pop(context);
                      // Get connected bays for this busbar
                      final connectedBays = _getConnectedBays(
                        busbar,
                        sldController,
                      );

                      // Show busbar configuration dialog
                      showDialog(
                        context: context,
                        builder: (context) => BusbarConfigurationScreen(
                          busbar: busbar,
                          connectedBays: connectedBays,
                          onSaveConfiguration: (inclusionMap) {
                            // Handle the configuration save
                            print(
                              'Busbar ${busbar.id} configuration: $inclusionMap',
                            );
                            // Update your energy calculation logic based on inclusionMap
                          },
                        ),
                      );
                    },
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
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // Handle busbar selection
            },
            child: const Text('Select'),
          ),
        ],
      ),
    );
  }

  // Helper method to get connected bays (you'll need to implement this based on your connection logic)
  // (Removed duplicate and unused _getConnectedBays method to fix naming conflict)

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
          // Refresh energy data after assessment
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

  // Utility methods
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

// Helper data classes
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
