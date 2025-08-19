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
  final VoidCallback? onConfigurationChanged;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Single source of truth for energy maps
  Map<String, BusbarEnergyMap> _busbarEnergyMaps = {};
  Map<String, BusbarEnergyMap> _substationEnergyMaps = {};

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
    this.onConfigurationChanged,
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

      // Fixed: Use typed helper for double maps
      final Map<String, Map<String, double>> savedBusEnergySummary =
          _parseNestedDoubleMap(sldParameters['busEnergySummary']);

      final Map<String, dynamic> savedAbstractEnergyData =
          Map<String, dynamic>.from(sldParameters['abstractEnergyData'] ?? {});

      final List<AggregatedFeederEnergyData> savedAggregatedFeederEnergyData =
          [];

      if (sldParameters.containsKey('aggregatedFeederEnergyData')) {
        final aggregatedDataList =
            sldParameters['aggregatedFeederEnergyData'] as List<dynamic>;
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
        _firestore.collection('zones').get(),
        _firestore.collection('circles').get(),
        _firestore.collection('divisions').get(),
        _firestore.collection('subdivisions').get(),
        _firestore.collection('substations').get(),
        _firestore.collection('distributionZones').get(),
        _firestore.collection('distributionCircles').get(),
        _firestore.collection('distributionDivisions').get(),
        _firestore.collection('distributionSubdivisions').get(),
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

  /// Single load method for busbar energy maps - builds consistent keys
  Future<void> _loadBusbarEnergyMaps() async {
    try {
      print('🔍 DEBUG: Loading energy maps for substation: $substationId');
      final snapshot = await _firestore
          .collection('busbarEnergyMaps')
          .where('substationId', isEqualTo: substationId)
          .get();

      print(
        '🔍 DEBUG: Found ${snapshot.docs.length} energy map documents in Firestore',
      );

      // Clear maps before loading
      _busbarEnergyMaps.clear();
      _substationEnergyMaps.clear();

      for (var doc in snapshot.docs) {
        final map = BusbarEnergyMap.fromFirestore(doc);

        if (map.isSubstationMapping) {
          final key = 'SUBSTATION-${map.connectedBayId}';
          _substationEnergyMaps[key] = map;
          print('🔍 DEBUG: Added substation mapping: $key');
        } else {
          final key = '${map.busbarId}-${map.connectedBayId}';
          _busbarEnergyMaps[key] = map;
          print(
            '🔍 DEBUG: Added busbar mapping: $key → Import: ${map.importContribution}, Export: ${map.exportContribution}',
          );
        }
      }

      print(
        '🔍 DEBUG: Final loaded busbar maps count: ${_busbarEnergyMaps.length}',
      );
      print(
        '🔍 DEBUG: Final loaded substation maps count: ${_substationEnergyMaps.length}',
      );
    } catch (e) {
      print('❌ ERROR: Failed to load energy maps: $e');
      rethrow;
    }
  }

  // Deterministic document ID generators
  String _getBusbarEnergyMapDocId(String busbarId, String connectedBayId) {
    return '${substationId}_${busbarId}_${connectedBayId}';
  }

  String _getSubstationEnergyMapDocId(String busbarId) {
    return '${substationId}_SUBSTATION_${busbarId}';
  }

  /// Save busbar selections for one busbar (UI delegate method)
  Future<void> saveBusbarSelections(
    Bay busbar,
    Map<String, Map<String, EnergyContributionType>> selections,
  ) async {
    final batch = _firestore.batch();

    // Process selections for this busbar only
    for (var entry in selections.entries) {
      final bayId = entry.key;
      final imp = entry.value['imp'] ?? EnergyContributionType.none;
      final exp = entry.value['exp'] ?? EnergyContributionType.none;

      final docId = _getBusbarEnergyMapDocId(busbar.id, bayId);
      final docRef = _firestore.collection('busbarEnergyMaps').doc(docId);

      if (imp == EnergyContributionType.none &&
          exp == EnergyContributionType.none) {
        // Delete if both are none
        batch.delete(docRef);
        _busbarEnergyMaps.remove('${busbar.id}-$bayId');
      } else {
        // Upsert with deterministic ID
        final map = BusbarEnergyMap.forBusbar(
          substationId: substationId,
          busbarId: busbar.id,
          connectedBayId: bayId,
          modifiedBy: currentUser.uid,
          importContribution: imp,
          exportContribution: exp,
        ).copyWith(id: docId, lastModified: DateTime.now());

        batch.set(docRef, map.toFirestore(), SetOptions(merge: true));
        _busbarEnergyMaps['${busbar.id}-$bayId'] = map;
      }
    }

    await batch.commit();
    print('🔥 DEBUG: Saved busbar selections for busbar ${busbar.name}');

    if (onConfigurationChanged != null) onConfigurationChanged!();
  }

  /// Save substation selections (UI delegate method)
  Future<void> saveSubstationSelections(
    Map<String, Map<String, EnergyContributionType>> selections,
  ) async {
    final batch = _firestore.batch();

    for (var entry in selections.entries) {
      final busbarId = entry.key;
      final imp = entry.value['imp'] ?? EnergyContributionType.busImport;
      final exp = entry.value['exp'] ?? EnergyContributionType.busExport;

      final docId = _getSubstationEnergyMapDocId(busbarId);
      final docRef = _firestore.collection('busbarEnergyMaps').doc(docId);

      if (imp == EnergyContributionType.none &&
          exp == EnergyContributionType.none) {
        batch.delete(docRef);
        _substationEnergyMaps.remove('SUBSTATION-$busbarId');
      } else {
        final map = BusbarEnergyMap.forSubstation(
          substationId: substationId,
          busbarId: busbarId,
          modifiedBy: currentUser.uid,
          importContribution: imp,
          exportContribution: exp,
        ).copyWith(id: docId, lastModified: DateTime.now());

        batch.set(docRef, map.toFirestore(), SetOptions(merge: true));
        _substationEnergyMaps['SUBSTATION-$busbarId'] = map;
      }
    }

    await batch.commit();
    print('🔥 DEBUG: Saved substation selections');

    if (onConfigurationChanged != null) onConfigurationChanged!();
  }

  /// Get bay energy mappings for UI initialization
  Map<String, BusbarEnergyMap> getBayEnergyMappings(
    Bay busbar,
    List<Bay> connectedBays,
  ) {
    final Map<String, BusbarEnergyMap> result = {};
    for (var bay in connectedBays) {
      final key = '${busbar.id}-${bay.id}';
      if (_busbarEnergyMaps.containsKey(key)) {
        result[bay.id] = _busbarEnergyMaps[key]!;
      }
    }
    return result;
  }

  /// Get substation energy mappings for UI initialization
  Map<String, BusbarEnergyMap> getSubstationEnergyMappings() {
    final Map<String, BusbarEnergyMap> result = {};
    _substationEnergyMaps.forEach((key, value) {
      final busbarId = key.substring('SUBSTATION-'.length);
      result[busbarId] = value;
    });
    return result;
  }

  /// Check if busbar has custom configuration
  bool hasCustomConfiguration(Bay busbar) {
    return _busbarEnergyMaps.keys.any((key) => key.startsWith('${busbar.id}-'));
  }

  /// Check if substation has custom configuration
  bool hasSubstationCustomConfiguration() {
    return _substationEnergyMaps.isNotEmpty;
  }

  /// Get bay inclusion map for UI
  Map<String, bool> getBayInclusionMap(Bay busbar, List<Bay> connectedBays) {
    final Map<String, bool> inclusionMap = {};

    for (var bay in connectedBays) {
      final key = '${busbar.id}-${bay.id}';
      final map = _busbarEnergyMaps[key];
      final included =
          (map != null &&
          (map.importContribution != EnergyContributionType.none ||
              map.exportContribution != EnergyContributionType.none));
      inclusionMap[bay.id] = included;
    }
    return inclusionMap;
  }

  /// Reset busbar configuration using deterministic ID
  Future<void> resetBusbarConfiguration(Bay busbar) async {
    try {
      final batch = _firestore.batch();

      final keysToDelete = _busbarEnergyMaps.keys
          .where((key) => key.startsWith('${busbar.id}-'))
          .toList();

      for (var key in keysToDelete) {
        final map = _busbarEnergyMaps[key];
        if (map != null) {
          final docRef = _firestore.collection('busbarEnergyMaps').doc(map.id);
          batch.delete(docRef);
          _busbarEnergyMaps.remove(key);
        }
      }

      await batch.commit();
      print('DEBUG: Reset busbar configuration for ${busbar.name}');

      if (onConfigurationChanged != null) onConfigurationChanged!();
    } catch (e) {
      print('ERROR: Failed to reset busbar configuration: $e');
      rethrow;
    }
  }

  /// Reset substation configuration
  Future<void> resetSubstationConfiguration() async {
    try {
      final batch = _firestore.batch();

      final keysToDelete = _substationEnergyMaps.keys.toList();

      for (var key in keysToDelete) {
        final map = _substationEnergyMaps[key];
        if (map != null) {
          final docRef = _firestore.collection('busbarEnergyMaps').doc(map.id);
          batch.delete(docRef);
          _substationEnergyMaps.remove(key);
        }
      }

      await batch.commit();
      print('DEBUG: Reset substation configuration');

      if (onConfigurationChanged != null) onConfigurationChanged!();
    } catch (e) {
      print('ERROR: Failed to reset substation configuration: $e');
      rethrow;
    }
  }

  /// Energy calculation methods - NO DEFAULTS, only explicit mappings
  /// Fixed: Return type is now Map<String, Map<String, double>>
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
      int configuredBayCount = 0;

      // Find all bays explicitly mapped to this busbar
      Iterable<String> mappedBayKeys = _busbarEnergyMaps.keys.where(
        (key) => key.startsWith('${busbar.id}-'),
      );

      for (var key in mappedBayKeys) {
        final busbarMap = _busbarEnergyMaps[key];
        final bayId = key.substring(key.indexOf('-') + 1);
        final energyData = bayEnergyData[bayId];

        if (busbarMap != null && energyData != null) {
          configuredBayCount++;

          // Apply exactly what was configured in the mapping
          if (busbarMap.importContribution ==
              EnergyContributionType.busImport) {
            totalImp += energyData.adjustedImportConsumed;
          } else if (busbarMap.importContribution ==
              EnergyContributionType.busExport) {
            totalExp += energyData.adjustedImportConsumed;
          }

          if (busbarMap.exportContribution ==
              EnergyContributionType.busImport) {
            totalImp += energyData.adjustedExportConsumed;
          } else if (busbarMap.exportContribution ==
              EnergyContributionType.busExport) {
            totalExp += energyData.adjustedExportConsumed;
          }

          print(
            '✅ Applied $bayId to ${busbar.name} with '
            'Import mapping=${busbarMap.importContribution} and '
            'Export mapping=${busbarMap.exportContribution}',
          );
        }
      }

      final losses = totalImp - totalExp;
      final lossPercentage = totalImp > 0 ? (losses / totalImp) * 100 : 0.0;

      busEnergySummary[busbar.id] = {
        'totalImp': totalImp,
        'totalExp': totalExp,
        'netConsumption': losses,
        'lossPercentage': lossPercentage,
        'configuredBayCount': configuredBayCount.toDouble(),
      };

      print(
        '🎯 FINAL: ${busbar.name} → Import=$totalImp, Export=$totalExp, '
        'Loss%=${lossPercentage.toStringAsFixed(2)}%',
      );
    }

    return busEnergySummary;
  }

  /// Fixed: Parameter type is now Map<String, Map<String, double>>
  Map<String, dynamic> _calculateAbstractEnergyData(
    Map<String, Map<String, double>> busEnergySummary,
    SldController sldController,
  ) {
    double totalImp = 0.0;
    double totalExp = 0.0;

    // ONLY include if explicit substation mappings exist
    if (_substationEnergyMaps.isNotEmpty) {
      for (var busbarData in busEnergySummary.entries) {
        final busbarId = busbarData.key;
        final summary = busbarData.value;

        final substationMapKey = 'SUBSTATION-$busbarId';
        final substationMap = _substationEnergyMaps[substationMapKey];

        // ONLY include if explicit mapping exists
        if (substationMap != null) {
          final busbarImp = summary['totalImp'] ?? 0.0;
          final busbarExp = summary['totalExp'] ?? 0.0;

          if (substationMap.importContribution ==
              EnergyContributionType.busImport) {
            totalImp += busbarImp;
          } else if (substationMap.importContribution ==
              EnergyContributionType.busExport) {
            totalExp += busbarImp;
          }

          if (substationMap.exportContribution ==
              EnergyContributionType.busImport) {
            totalImp += busbarExp;
          } else if (substationMap.exportContribution ==
              EnergyContributionType.busExport) {
            totalExp += busbarExp;
          }

          print(
            '✅ Applied Busbar $busbarId to Substation: Import mapping=${substationMap.importContribution}, Export mapping=${substationMap.exportContribution}',
          );
        }
      }
    }
    // NO else clause - no default inclusion

    final difference = totalImp - totalExp;
    final lossPercentage = totalImp > 0 ? (difference / totalImp) * 100 : 0.0;

    print(
      '🎯 FINAL SUBSTATION: Import=$totalImp, Export=$totalExp, Loss%=${lossPercentage.toStringAsFixed(2)}%',
    );

    return {
      'totalImp': totalImp,
      'totalExp': totalExp,
      'difference': difference,
      'lossPercentage': lossPercentage,
    };
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

  /// UI orchestration - keep dialog opening in service
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
          height: 400,
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

                  final hasConfig = hasCustomConfiguration(busbar);

                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    child: ListTile(
                      leading: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: hasConfig
                              ? Colors.blue.withOpacity(0.1)
                              : Colors.grey.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          hasConfig ? Icons.settings : Icons.settings_outlined,
                          color: hasConfig ? Colors.blue : Colors.grey,
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
                          if (hasConfig)
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

  void _showBusbarConfigurationDialog(
    BuildContext context,
    Bay busbar,
    SldController sldController,
  ) {
    final connectedBays = _getConnectedBays(
      busbar,
      sldController,
    ).where((bay) => bay.bayType != 'Busbar').toList();

    final currentBusbarMappings = getBayEnergyMappings(busbar, connectedBays);
    final currentSubstationMappings = getSubstationEnergyMappings();

    showDialog(
      context: context,
      builder: (context) => BusbarConfigurationScreen(
        busbar: busbar,
        connectedBays: connectedBays,
        allSubstationBays: sldController.allBays,
        currentConfiguration: currentBusbarMappings,
        substationConfiguration: currentSubstationMappings,
        onSaveConfiguration: (busbarSelections, substationSelections) async {
          try {
            // busbarSelections is already Map<String, Map<String, EnergyContributionType>>
            // No need for conversion - just pass them directly to the service

            await saveBusbarSelections(busbar, busbarSelections);

            if (substationSelections != null &&
                substationSelections.isNotEmpty) {
              await saveSubstationSelections(substationSelections);
            }

            SnackBarUtils.showSnackBar(
              context,
              'Energy mapping configurations saved successfully!',
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

  // Rest of the methods remain the same...
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

      final query = _firestore
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

        final prevSnapshot = await _firestore
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

      final snapshot = await _firestore
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

  BayEnergyData _calculateBayEnergyData(
    Bay bay,
    DateTime startDate,
    DateTime endDate,
    ReadingsData readings, {
    Assessment? assessment,
  }) {
    final double mf = bay.multiplyingFactor ?? 1.0;

    if (startDate.isAtSameMomentAs(endDate)) {
      // ✅ SINGLE DAY LOGIC
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
          // Use separate previous day entry
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
          // Use embedded previous day readings
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
      // ✅ RANGE LOGIC
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

  // Helper methods for parsing data with correct types
  Map<String, Map<String, dynamic>> _parseNestedMap(dynamic data) {
    if (data == null) return {};
    final result = <String, Map<String, dynamic>>{};
    final map = data as Map;
    for (var entry in map.entries) {
      result[entry.key] = Map<String, dynamic>.from(entry.value as Map);
    }
    return result;
  }

  /// NEW: Helper for parsing double maps specifically
  Map<String, Map<String, double>> _parseNestedDoubleMap(dynamic data) {
    if (data == null) return {};
    final result = <String, Map<String, double>>{};
    final map = data as Map;
    for (var entry in map.entries) {
      final innerMap = entry.value as Map;
      result[entry.key] = Map<String, double>.from(innerMap);
    }
    return result;
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

/// Fixed: busEnergySummary is now typed as Map<String, Map<String, double>>
class CalculatedEnergyData {
  final Map<String, BayEnergyData> bayEnergyData;
  final Map<String, Map<String, double>> busEnergySummary;
  final Map<String, dynamic> abstractEnergyData;
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
