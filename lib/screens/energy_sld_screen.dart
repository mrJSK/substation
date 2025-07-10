// lib/screens/energy_sld_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'dart:math';
import 'package:collection/collection.dart'; // This import is correct for extension methods like firstWhereOrNull

import '../models/bay_model.dart';
import '../models/user_model.dart';
import '../models/reading_models.dart';
import '../models/logsheet_models.dart';
import '../models/bay_connection_model.dart';
import '../models/busbar_energy_map.dart';
import '../models/hierarchy_models.dart'; // Import hierarchy models for both transmission and distribution
import '../utils/snackbar_utils.dart';

import '../painters/single_line_diagram_painter.dart';

// Data model for energy data associated with a bay (remains unchanged)
class BayEnergyData {
  final String bayName;
  final double? prevImp;
  final double? currImp;
  final double? prevExp;
  final double? currExp;
  final double? mf;
  final double? impConsumed;
  final double? expConsumed;

  BayEnergyData({
    required this.bayName,
    this.prevImp,
    this.currImp,
    this.prevExp,
    this.currExp,
    this.mf,
    this.impConsumed,
    this.expConsumed,
  });
}

// REMOVED: FeederEnergyTableData (per-feeder data with all details is no longer directly displayed)
// Instead, we'll aggregate data into a new model directly.

// NEW: Data model for Aggregated Feeder Energy Table
class AggregatedFeederEnergyData {
  final String zoneName;
  final String circleName;
  final String divisionName;
  final String distributionSubdivisionName; // New aggregate level
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

  // Unique key for grouping
  String get uniqueKey =>
      '$zoneName-$circleName-$divisionName-$distributionSubdivisionName';
}

// Data model for rendering the SLD with energy data (remains unchanged)
class SldRenderData {
  final List<BayRenderData> bayRenderDataList;
  final Map<String, Rect> finalBayRects;
  final Map<String, Rect> busbarRects;
  final Map<String, Map<String, Offset>> busbarConnectionPoints;
  final Map<String, BayEnergyData> bayEnergyData;
  final Map<String, Map<String, double>> busEnergySummary;

  SldRenderData({
    required this.bayRenderDataList,
    required this.finalBayRects,
    required this.busbarRects,
    required this.busbarConnectionPoints,
    required this.bayEnergyData,
    required this.busEnergySummary,
  });
}

class EnergySldScreen extends StatefulWidget {
  final String substationId;
  final String substationName;
  final AppUser currentUser;

  const EnergySldScreen({
    super.key,
    required this.substationId,
    required this.substationName,
    required this.currentUser,
  });

  @override
  State<EnergySldScreen> createState() => _EnergySldScreenState();
}

class _EnergySldScreenState extends State<EnergySldScreen> {
  bool _isLoading = true;
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 1));
  DateTime _endDate = DateTime.now();

  List<Bay> _allBaysInSubstation = [];
  Map<String, Bay> _baysMap = {};
  List<BayConnection> _allConnections = [];

  Map<String, BayEnergyData> _bayEnergyData = {};
  Map<String, double> _abstractEnergyData = {};
  Map<String, Map<String, double>> _busEnergySummary = {};
  Map<String, BusbarEnergyMap> _busbarEnergyMaps = {};

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

  // UPDATED: List for aggregated feeder table data
  List<AggregatedFeederEnergyData> _aggregatedFeederEnergyData = [];

  final TransformationController _transformationController =
      TransformationController();

  int _currentPageIndex = 0; // For busbar/abstract page view
  int _feederTablePageIndex = 0; // For feeder table page view

  @override
  void initState() {
    super.initState();
    print(
      'DEBUG: EnergySldScreen initState - substationId: ${widget.substationId}',
    );
    if (widget.substationId.isNotEmpty) {
      _loadEnergyData();
    } else {
      _isLoading = false;
    }
  }

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  // Helper function to extract numerical voltage value for sorting
  double _getVoltageLevelValue(String voltageLevel) {
    // Extracts numbers (and decimals) from a string like "132kV"
    final regex = RegExp(r'(\d+(\.\d+)?)');
    final match = regex.firstMatch(voltageLevel);
    if (match != null) {
      return double.tryParse(match.group(1)!) ?? 0.0;
    }
    return 0.0; // Default if no number is found
  }

  Future<void> _loadEnergyData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _bayEnergyData.clear();
      _abstractEnergyData.clear();
      _busEnergySummary.clear();
      _allBaysInSubstation.clear();
      _baysMap.clear();
      _allConnections.clear();
      _busbarEnergyMaps.clear();
      _aggregatedFeederEnergyData.clear(); // UPDATED: Clear aggregated list
      _currentPageIndex = 0;
      _feederTablePageIndex = 0;
    });

    try {
      // Fetch ALL Hierarchy Data (Transmission and Distribution)
      await _fetchTransmissionHierarchyData();
      await _fetchDistributionHierarchyData();

      final baysSnapshot = await FirebaseFirestore.instance
          .collection('bays')
          .where('substationId', isEqualTo: widget.substationId)
          .orderBy('name')
          .get();
      _allBaysInSubstation = baysSnapshot.docs
          .map((doc) => Bay.fromFirestore(doc))
          .toList();

      // Sort bays by voltage level (highest to lowest) to ensure consistent layout and abstract calculation priority
      _allBaysInSubstation.sort((a, b) {
        final double voltageA = _getVoltageLevelValue(a.voltageLevel);
        final double voltageB = _getVoltageLevelValue(b.voltageLevel);
        return voltageB.compareTo(voltageA); // Descending order
      });

      _baysMap = {for (var bay in _allBaysInSubstation) bay.id: bay};

      final connectionsSnapshot = await FirebaseFirestore.instance
          .collection('bay_connections')
          .where('substationId', isEqualTo: widget.substationId)
          .get();
      _allConnections = connectionsSnapshot.docs
          .map((doc) => BayConnection.fromFirestore(doc))
          .toList();

      // Fetch BusbarEnergyMap configurations
      final busbarEnergyMapsSnapshot = await FirebaseFirestore.instance
          .collection('busbarEnergyMaps')
          .where('substationId', isEqualTo: widget.substationId)
          .get();
      _busbarEnergyMaps = {
        for (var doc in busbarEnergyMapsSnapshot.docs)
          '${doc['busbarId']}-${doc['connectedBayId']}':
              BusbarEnergyMap.fromFirestore(doc),
      };

      final startOfStartDate = DateTime(
        _startDate.year,
        _startDate.month,
        _startDate.day,
      );
      final endOfStartDate = DateTime(
        _startDate.year,
        _startDate.month,
        _startDate.day,
        23,
        59,
        59,
        999,
      );

      final startOfEndDate = DateTime(
        _endDate.year,
        _endDate.month,
        _endDate.day,
      );
      final endOfEndDate = DateTime(
        _endDate.year,
        _endDate.month,
        _endDate.day,
        23,
        59,
        59,
        999,
      );

      Map<String, LogsheetEntry> startDayReadings = {};
      Map<String, LogsheetEntry> endDayReadings = {};
      Map<String, LogsheetEntry> previousDayToStartDateReadings = {};

      final startDayLogsheetsSnapshot = await FirebaseFirestore.instance
          .collection('logsheetEntries')
          .where('substationId', isEqualTo: widget.substationId)
          .where('frequency', isEqualTo: 'daily')
          .where('readingTimestamp', isGreaterThanOrEqualTo: startOfStartDate)
          .where('readingTimestamp', isLessThanOrEqualTo: endOfStartDate)
          .get();
      startDayReadings = {
        for (var doc in startDayLogsheetsSnapshot.docs)
          (doc.data() as Map<String, dynamic>)['bayId']:
              LogsheetEntry.fromFirestore(doc),
      };

      if (!_startDate.isAtSameMomentAs(_endDate)) {
        final endDayLogsheetsSnapshot = await FirebaseFirestore.instance
            .collection('logsheetEntries')
            .where('substationId', isEqualTo: widget.substationId)
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
        final previousDay = _startDate.subtract(const Duration(days: 1));
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

        final previousDayToStartDateLogsheetsSnapshot = await FirebaseFirestore
            .instance
            .collection('logsheetEntries')
            .where('substationId', isEqualTo: widget.substationId)
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

      // Calculate energy for each bay first
      for (var bay in _allBaysInSubstation) {
        final double? mf = bay.multiplyingFactor;
        double calculatedImpConsumed = 0.0;
        double calculatedExpConsumed = 0.0;

        if (_startDate.isAtSameMomentAs(_endDate)) {
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
          } else if (currImpVal != null && mf != null) {
            calculatedImpConsumed = currImpVal * mf;
          }

          if (currExpVal != null &&
              prevExpValForCalculation != null &&
              mf != null) {
            calculatedExpConsumed = max(
              0.0,
              (currExpVal - prevExpValForCalculation) * mf,
            );
          } else if (currExpVal != null && mf != null) {
            calculatedExpConsumed = currExpVal * mf;
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
          );
        } else {
          final startReading = startDayReadings[bay.id];
          final endReading = endDayReadings[bay.id];

          final double? startImpVal = double.tryParse(
            startReading?.values['Current Day Reading (Import)']?.toString() ??
                '',
          );
          final double? startExpVal = double.tryParse(
            startReading?.values['Current Day Reading (Export)']?.toString() ??
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
          );
        }
      }

      // Initialize temporary storage for busbar flows using the new mapping
      Map<String, Map<String, double>> temporaryBusFlows = {};
      for (var busbar in _allBaysInSubstation.where(
        (b) => b.bayType == 'Busbar',
      )) {
        temporaryBusFlows[busbar.id] = {'import': 0.0, 'export': 0.0};
      }

      // Calculate busbar energy based on BusbarEnergyMap
      for (var entry in _busbarEnergyMaps.values) {
        final Bay? connectedBay = _baysMap[entry.connectedBayId];
        final BayEnergyData? connectedBayEnergy =
            _bayEnergyData[entry.connectedBayId];

        if (connectedBay != null &&
            connectedBayEnergy != null &&
            temporaryBusFlows.containsKey(entry.busbarId)) {
          // Add bay's import to busbar based on configuration
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

          // Add bay's export to busbar based on configuration
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

      // Finalize bus energy summaries based on the aggregated temporary flows
      for (var busbar in _allBaysInSubstation.where(
        (b) => b.bayType == 'Busbar',
      )) {
        double busTotalImp = temporaryBusFlows[busbar.id]?['import'] ?? 0.0;
        double busTotalExp = temporaryBusFlows[busbar.id]?['export'] ?? 0.0;

        double busDifference = busTotalImp - busTotalExp;
        double busLossPercentage = 0.0;
        if (busTotalImp > 0) {
          // Avoid division by zero
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

      // --- FINAL SUBSTATION ABSTRACT CALCULATION (Directly from Bus Abstracts as per PDF) ---
      final highestVoltageBus = _allBaysInSubstation.firstWhereOrNull(
        (b) => b.bayType == 'Busbar',
      );
      final lowestVoltageBus = _allBaysInSubstation.lastWhereOrNull(
        (b) => b.bayType == 'Busbar',
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
          currentAbstractSubstationTotalImp - currentAbstractSubstationTotalExp;
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

      // UPDATED: Aggregate feeder energy data by Distribution Hierarchy
      // Use a temporary map to sum values
      final Map<String, AggregatedFeederEnergyData> tempAggregatedData = {};

      for (var bay in _allBaysInSubstation) {
        if (bay.bayType == 'Feeder') {
          final energyData = _bayEnergyData[bay.id];
          if (energyData != null) {
            // Retrieve Distribution Hierarchy details for grouping
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

            // Get or create the aggregated entry
            final aggregatedEntry = tempAggregatedData.putIfAbsent(
              groupKey,
              () => AggregatedFeederEnergyData(
                zoneName: zoneName,
                circleName: circleName,
                divisionName: divisionName,
                distributionSubdivisionName: distSubdivisionName,
              ),
            );

            // Add energies
            aggregatedEntry.importedEnergy += (energyData.impConsumed ?? 0.0);
            aggregatedEntry.exportedEnergy += (energyData.expConsumed ?? 0.0);
          }
        }
      }

      _aggregatedFeederEnergyData = tempAggregatedData.values.toList();

      // Sort the aggregated data for consistent display and visual merging
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
    } catch (e) {
      print("Error loading energy data: $e");
      if (mounted) {
        SnackBarUtils.showSnackBar(
          context,
          'Failed to load energy data: $e',
          isError: true,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Helper to fetch all Transmission hierarchy data needed for lookup (remains unchanged)
  Future<void> _fetchTransmissionHierarchyData() async {
    _zonesMap.clear();
    _circlesMap.clear();
    _divisionsMap.clear();
    _subdivisionsMap.clear();
    _substationsMap.clear();

    final zonesSnapshot = await FirebaseFirestore.instance
        .collection('zones')
        .get();
    _zonesMap = {
      for (var doc in zonesSnapshot.docs) doc.id: Zone.fromFirestore(doc),
    };

    final circlesSnapshot = await FirebaseFirestore.instance
        .collection('circles')
        .get();
    _circlesMap = {
      for (var doc in circlesSnapshot.docs) doc.id: Circle.fromFirestore(doc),
    };

    final divisionsSnapshot = await FirebaseFirestore.instance
        .collection('divisions')
        .get();
    _divisionsMap = {
      for (var doc in divisionsSnapshot.docs)
        doc.id: Division.fromFirestore(doc),
    };

    final subdivisionsSnapshot = await FirebaseFirestore.instance
        .collection('subdivisions')
        .get();
    _subdivisionsMap = {
      for (var doc in subdivisionsSnapshot.docs)
        doc.id: Subdivision.fromFirestore(doc),
    };

    final substationsSnapshot = await FirebaseFirestore.instance
        .collection('substations')
        .get();
    _substationsMap = {
      for (var doc in substationsSnapshot.docs)
        doc.id: Substation.fromFirestore(doc),
    };
  }

  // UPDATED: Helper to fetch all Distribution hierarchy data needed for lookup including Subdivision
  Future<void> _fetchDistributionHierarchyData() async {
    _distributionZonesMap.clear();
    _distributionCirclesMap.clear();
    _distributionDivisionsMap.clear();
    _distributionSubdivisionsMap.clear();

    final zonesSnapshot = await FirebaseFirestore.instance
        .collection('distributionZones')
        .get();
    _distributionZonesMap = {
      for (var doc in zonesSnapshot.docs)
        doc.id: DistributionZone.fromFirestore(doc),
    };

    final circlesSnapshot = await FirebaseFirestore.instance
        .collection('distributionCircles')
        .get();
    _distributionCirclesMap = {
      for (var doc in circlesSnapshot.docs)
        doc.id: DistributionCircle.fromFirestore(doc),
    };

    final divisionsSnapshot = await FirebaseFirestore.instance
        .collection('distributionDivisions')
        .get();
    _distributionDivisionsMap = {
      for (var doc in divisionsSnapshot.docs)
        doc.id: DistributionDivision.fromFirestore(doc),
    };

    final subdivisionsSnapshot = await FirebaseFirestore.instance
        .collection('distributionSubdivisions')
        .get();
    _distributionSubdivisionsMap = {
      for (var doc in subdivisionsSnapshot.docs)
        doc.id: DistributionSubdivision.fromFirestore(doc),
    };
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(), // Only allow past and current dates
      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
    );

    if (picked != null &&
        (picked.start != _startDate || picked.end != _endDate)) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
      await _loadEnergyData();
    }
  }

  // Method to handle saving a single BusbarEnergyMap (remains unchanged)
  Future<void> _saveBusbarEnergyMap(BusbarEnergyMap map) async {
    try {
      if (map.id == null) {
        // Create new
        await FirebaseFirestore.instance
            .collection('busbarEnergyMaps')
            .add(map.toFirestore());
      } else {
        // Update existing
        await FirebaseFirestore.instance
            .collection('busbarEnergyMaps')
            .doc(map.id)
            .update(map.toFirestore());
      }
      await _loadEnergyData(); // Reload data to reflect changes
    } catch (e) {
      print('Error saving BusbarEnergyMap: $e');
      if (mounted) {
        SnackBarUtils.showSnackBar(
          context,
          'Failed to save energy map: $e',
          isError: true,
        );
      }
    }
  }

  // Method to handle deleting a single BusbarEnergyMap (remains unchanged)
  Future<void> _deleteBusbarEnergyMap(String mapId) async {
    try {
      await FirebaseFirestore.instance
          .collection('busbarEnergyMaps')
          .doc(mapId)
          .delete();
      await _loadEnergyData(); // Reload data to reflect changes
    } catch (e) {
      print('Error deleting BusbarEnergyMap: $e');
      if (mounted) {
        SnackBarUtils.showSnackBar(
          context,
          'Failed to delete energy map: $e',
          isError: true,
        );
      }
    }
  }

  // Method to show the busbar selection dialog (remains unchanged)
  void _showBusbarSelectionDialog() {
    final List<Bay> busbars = _allBaysInSubstation
        .where((bay) => bay.bayType == 'Busbar')
        .toList();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Select Busbar'),
          content: busbars.isEmpty
              ? const Text('No busbars found in this substation.')
              : SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: busbars.map((busbar) {
                      return ListTile(
                        title: Text('${busbar.voltageLevel} ${busbar.name}'),
                        onTap: () {
                          Navigator.pop(context); // Close selection dialog
                          _showBusbarEnergyAssignmentDialog(
                            busbar,
                          ); // Open assignment dialog
                        },
                      );
                    }).toList(),
                  ),
                ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  // Method to show the busbar energy assignment dialog (now called from selection dialog) (remains unchanged)
  void _showBusbarEnergyAssignmentDialog(Bay busbar) {
    // Filter connections to find bays connected to this specific busbar
    final List<Bay> connectedBays = _allConnections
        .where(
          (conn) =>
              conn.sourceBayId == busbar.id || conn.targetBayId == busbar.id,
        )
        .map((conn) {
          final String otherBayId = conn.sourceBayId == busbar.id
              ? conn.targetBayId
              : conn.sourceBayId;
          return _baysMap[otherBayId];
        })
        .whereType<Bay>() // Filter out nulls
        .where((bay) => bay.bayType != 'Busbar') // Exclude other busbars
        .toList();

    // Prepare current maps for the dialog, only those relevant to this busbar
    final Map<String, BusbarEnergyMap> currentBusbarMaps = {};
    _busbarEnergyMaps.forEach((key, value) {
      if (value.busbarId == busbar.id) {
        currentBusbarMaps[value.connectedBayId] = value;
      }
    });

    showDialog(
      context: context,
      builder: (context) => _BusbarEnergyAssignmentDialog(
        busbar: busbar,
        connectedBays: connectedBays,
        currentUser: widget.currentUser,
        currentMaps: currentBusbarMaps,
        onSaveMap: _saveBusbarEnergyMap,
        onDeleteMap: _deleteBusbarEnergyMap,
      ),
    );
  }

  SldRenderData _buildBayRenderDataList(
    List<Bay> allBays,
    Map<String, Bay> baysMap,
    List<BayConnection> allConnections,
    Map<String, BayEnergyData> bayEnergyData,
    Map<String, Map<String, double>> busEnergySummary,
  ) {
    final List<BayRenderData> bayRenderDataList = [];
    final Map<String, Rect> finalBayRects = {};
    final Map<String, Rect> busbarRects = {};
    final Map<String, Map<String, Offset>> busbarConnectionPoints = {};

    const double symbolWidth = 60;
    const double symbolHeight = 60;
    const double horizontalSpacing = 100;
    const double verticalBusbarSpacing = 200;
    const double topPadding = 80;
    const double sidePadding = 100;
    const double busbarHitboxHeight = 50.0;
    const double lineFeederHeight = 40.0;

    final List<Bay> busbars = allBays
        .where((b) => b.bayType == 'Busbar')
        .toList();
    busbars.sort((a, b) {
      double getV(String v) =>
          double.tryParse(v.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0;
      return getV(b.voltageLevel).compareTo(getV(a.voltageLevel));
    });

    final Map<String, double> busYPositions = {};
    for (int i = 0; i < busbars.length; i++) {
      busYPositions[busbars[i].id] = topPadding + i * verticalBusbarSpacing;
    }

    final Map<String, List<Bay>> busbarToConnectedBaysAbove = {};
    final Map<String, List<Bay>> busbarToConnectedBaysBelow = {};
    final Map<String, Map<String, List<Bay>>> transformersByBusPair = {};

    for (var bay in allBays) {
      if (!['Busbar', 'Transformer', 'Line', 'Feeder'].contains(bay.bayType)) {
        continue;
      }

      if (bay.bayType == 'Transformer') {
        if (bay.hvBusId != null && bay.lvBusId != null) {
          final hvBus = baysMap[bay.hvBusId];
          final lvBus = baysMap[bay.lvBusId];
          if (hvBus != null &&
              lvBus != null &&
              hvBus.bayType == 'Busbar' &&
              lvBus.bayType == 'Busbar') {
            final double hvVoltage = _getVoltageLevelValue(hvBus.voltageLevel);
            final double lvVoltage = _getVoltageLevelValue(lvBus.voltageLevel);

            String key = "";
            if (hvVoltage > lvVoltage) {
              key = "${hvBus.id}-${lvBus.id}";
            } else {
              key = "${lvBus.id}-${hvBus.id}";
            }
            transformersByBusPair
                .putIfAbsent(key, () => {})
                .putIfAbsent(hvBus.id, () => [])
                .add(bay);
          } else {
            debugPrint(
              'Transformer ${bay.name} (${bay.id}) linked to non-busbar or missing bus: HV=${bay.hvBusId}, LV=${bay.lvBusId}',
            );
          }
        }
      } else if (bay.bayType != 'Busbar') {
        final connectionToBus = allConnections.firstWhereOrNull((c) {
          final bool sourceIsBay = c.sourceBayId == bay.id;
          final bool targetIsBay = c.targetBayId == bay.id;
          final bool sourceIsBus = baysMap[c.sourceBayId]?.bayType == 'Busbar';
          final bool targetIsBus = baysMap[c.targetBayId]?.bayType == 'Busbar';
          return (sourceIsBay && targetIsBay) || (targetIsBay && sourceIsBus);
        });

        if (connectionToBus != null) {
          final String connectedBusId =
              baysMap[connectionToBus.sourceBayId]?.bayType == 'Busbar'
              ? connectionToBus.sourceBayId
              : connectionToBus.targetBayId;

          if (bay.bayType == 'Line') {
            busbarToConnectedBaysAbove
                .putIfAbsent(connectedBusId, () => [])
                .add(bay);
          } else {
            busbarToConnectedBaysBelow
                .putIfAbsent(connectedBusId, () => [])
                .add(bay);
          }
        }
      }
    }

    busbarToConnectedBaysAbove.forEach(
      (key, value) => value.sort((a, b) => a.name.compareTo(b.name)),
    );
    busbarToConnectedBaysBelow.forEach(
      (key, value) => value.sort((a, b) => a.name.compareTo(b.name)),
    );
    transformersByBusPair.forEach((pairKey, transformersMap) {
      transformersMap.forEach((busId, transformers) {
        transformers.sort((a, b) => a.name.compareTo(b.name));
      });
    });

    double maxOverallXForCanvas = sidePadding;
    double nextTransformerX = sidePadding;
    final List<Bay> placedTransformers = [];

    for (var busPairEntry in transformersByBusPair.entries) {
      final String pairKey = busPairEntry.key;
      final Map<String, List<Bay>> transformersForPair = busPairEntry.value;

      List<String> busIdsInPair = pairKey.split('-');
      String hvBusId = busIdsInPair[0];
      String lvBusId = busIdsInPair[1];

      // NEW: Add null check for busYPositions
      if (!busYPositions.containsKey(hvBusId) ||
          !busYPositions.containsKey(lvBusId)) {
        debugPrint(
          'Skipping transformer group for pair $pairKey: One or both bus IDs not found in busYPositions. This should ideally not happen if data is clean.',
        );
        continue; // Skip this transformer group if bus position is unknown
      }

      final Bay? currentHvBus = baysMap[hvBusId];
      final Bay? currentLvBus = baysMap[lvBusId];

      if (currentHvBus == null || currentLvBus == null) {
        debugPrint(
          'Skipping transformer group for pair $pairKey: One or both bus objects not found in baysMap. This should ideally not happen if data is clean.',
        );
        continue; // Should ideally not happen if busYPositions check passes, but extra safety
      }

      final double hvVoltageValue = _getVoltageLevelValue(
        currentHvBus.voltageLevel,
      );
      final double lvVoltageValue = _getVoltageLevelValue(
        currentLvBus.voltageLevel,
      );

      if (hvVoltageValue < lvVoltageValue) {
        String temp = hvBusId;
        hvBusId = lvBusId;
        lvBusId = temp;
      }

      final double hvBusY = busYPositions[hvBusId]!; // Now safe due to check
      final double lvBusY = busYPositions[lvBusId]!; // Now safe due to check

      final List<Bay> transformers =
          transformersForPair[hvBusId] ?? transformersForPair[lvBusId] ?? [];
      for (var tf in transformers) {
        if (!placedTransformers.contains(tf)) {
          Offset finalOffset = (tf.xPosition != null && tf.yPosition != null)
              ? Offset(tf.xPosition!, tf.yPosition!)
              : Offset(
                  nextTransformerX + symbolWidth / 2,
                  (hvBusY + lvBusY) / 2,
                );

          final tfRect = Rect.fromCenter(
            center: finalOffset,
            width: symbolWidth,
            height: symbolHeight,
          );
          finalBayRects[tf.id] = tfRect;
          nextTransformerX += horizontalSpacing;
          placedTransformers.add(tf);
          maxOverallXForCanvas = max(maxOverallXForCanvas, tfRect.right);
        }
      }
    }

    double currentLaneXForOtherBays = nextTransformerX;

    for (var busbar in busbars) {
      final double busY = busYPositions[busbar.id]!;

      final List<Bay> baysAbove = List.from(
        busbarToConnectedBaysAbove[busbar.id] ?? [],
      );
      double currentX = currentLaneXForOtherBays;
      for (var bay in baysAbove) {
        Offset finalOffset = (bay.xPosition != null && bay.yPosition != null)
            ? Offset(bay.xPosition!, bay.yPosition!)
            : Offset(currentX, busY - lineFeederHeight - 10);

        final bayRect = Rect.fromLTWH(
          finalOffset.dx,
          finalOffset.dy,
          symbolWidth,
          lineFeederHeight,
        );
        finalBayRects[bay.id] = bayRect;
        currentX += horizontalSpacing;
      }
      maxOverallXForCanvas = max(maxOverallXForCanvas, currentX);

      final List<Bay> baysBelow = List.from(
        busbarToConnectedBaysBelow[busbar.id] ?? [],
      );
      currentX = currentLaneXForOtherBays;
      for (var bay in baysBelow) {
        Offset finalOffset = (bay.xPosition != null && bay.yPosition != null)
            ? Offset(bay.xPosition!, bay.yPosition!)
            : Offset(currentX, busY + 10);

        final bayRect = Rect.fromLTWH(
          finalOffset.dx,
          finalOffset
              .dy, // CORRECTED: Changed from finalBayRects[bay.id]!.top to finalOffset.dy
          symbolWidth,
          lineFeederHeight,
        );
        finalBayRects[bay.id] = bayRect;
        currentX += horizontalSpacing;
      }
      maxOverallXForCanvas = max(maxOverallXForCanvas, currentX);
    }

    for (var busbar in busbars) {
      final double busY = busYPositions[busbar.id]!;
      double maxConnectedBayX = sidePadding;

      allBays.where((b) => b.bayType != 'Busbar').forEach((bay) {
        if (bay.bayType == 'Transformer') {
          if ((bay.hvBusId == busbar.id || bay.lvBusId == busbar.id) &&
              finalBayRects.containsKey(bay.id)) {
            maxConnectedBayX = max(
              maxConnectedBayX,
              finalBayRects[bay.id]!.right,
            );
          }
        } else {
          final connectionToBus = allConnections.firstWhereOrNull((c) {
            return (c.sourceBayId == bay.id && c.targetBayId == busbar.id) ||
                (c.targetBayId == bay.id && c.sourceBayId == busbar.id);
          });
          if (connectionToBus != null && finalBayRects.containsKey(bay.id)) {
            maxConnectedBayX = max(
              maxConnectedBayX,
              finalBayRects[bay.id]!.right,
            );
          }
        }
      });

      final double effectiveBusWidth = max(
        maxConnectedBayX - sidePadding + horizontalSpacing,
        symbolWidth * 2,
      ).toDouble();

      final Rect drawingRect = Rect.fromLTWH(
        sidePadding,
        busY,
        effectiveBusWidth,
        0,
      );
      busbarRects[busbar.id] = drawingRect;

      final Rect tappableRect = Rect.fromCenter(
        center: Offset(sidePadding + effectiveBusWidth / 2, busY),
        width: effectiveBusWidth,
        height: busbarHitboxHeight,
      );
      finalBayRects[busbar.id] = tappableRect;
    }

    final List<String> allowedVisualBayTypes = [
      'Busbar',
      'Transformer',
      'Line',
      'Feeder',
    ];

    for (var bay in allBays) {
      if (!allowedVisualBayTypes.contains(bay.bayType)) {
        continue;
      }
      final Rect? rect = finalBayRects[bay.id];
      if (rect != null) {
        bayRenderDataList.add(
          BayRenderData(
            bay: bay,
            rect: rect,
            center: rect.center,
            topCenter: rect.topCenter,
            bottomCenter: rect.bottomCenter,
            leftCenter: rect.centerLeft,
            rightCenter: rect.centerRight,
          ),
        );
      }
    }

    for (var connection in allConnections) {
      final Bay? sourceBay = baysMap[connection.sourceBayId];
      final Bay? targetBay = baysMap[connection.targetBayId];
      if (sourceBay == null || targetBay == null) continue;

      if (!allowedVisualBayTypes.contains(sourceBay.bayType) ||
          !allowedVisualBayTypes.contains(targetBay.bayType)) {
        continue;
      }

      if (sourceBay.bayType == 'Busbar' && targetBay.bayType == 'Transformer') {
        final Rect? targetRect = finalBayRects[targetBay.id];
        final double? busY = busYPositions[sourceBay.id];
        if (targetRect != null && busY != null) {
          busbarConnectionPoints.putIfAbsent(
            sourceBay.id,
            () => {},
          )[targetBay.id] = Offset(
            targetRect.center.dx,
            busY,
          );
        }
      } else if (targetBay.bayType == 'Busbar' &&
          sourceBay.bayType == 'Transformer') {
        final Rect? sourceRect = finalBayRects[sourceBay.id];
        final double? busY = busYPositions[targetBay.id];
        if (sourceRect != null && busY != null) {
          busbarConnectionPoints.putIfAbsent(
            targetBay.id,
            () => {},
          )[sourceBay.id] = Offset(
            sourceRect.center.dx,
            busY,
          );
        }
      } else if (sourceBay.bayType == 'Busbar' &&
          targetBay.bayType != 'Busbar') {
        final Rect? targetRect = finalBayRects[targetBay.id];
        final double? busY = busYPositions[sourceBay.id];
        if (targetRect != null && busY != null) {
          busbarConnectionPoints.putIfAbsent(
            sourceBay.id,
            () => {},
          )[targetBay.id] = Offset(
            targetRect.center.dx,
            busY,
          );
        }
      } else if (targetBay.bayType == 'Busbar' &&
          sourceBay.bayType != 'Busbar') {
        final sourceRect = finalBayRects[sourceBay.id];
        final double? busY = busYPositions[targetBay.id];
        if (sourceRect != null && busY != null) {
          busbarConnectionPoints.putIfAbsent(
            targetBay.id,
            () => {},
          )[sourceBay.id] = Offset(
            sourceRect.center.dx,
            busY,
          );
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
    );
  }

  BayRenderData _createDummyBayRenderData() {
    return BayRenderData(
      bay: Bay(
        id: 'dummy',
        name: '',
        substationId: '',
        voltageLevel: '',
        bayType: '',
        createdBy: '',
        createdAt: Timestamp.now(),
      ),
      rect: Rect.zero,
      center: Offset.zero,
      topCenter: Offset.zero,
      bottomCenter: Offset.zero,
      leftCenter: Offset.zero,
      rightCenter: Offset.zero,
    );
  }

  Widget _buildPageIndicator(int pageCount, int currentPage) {
    List<Widget> indicators = [];
    final actualPageCount = pageCount > 0 ? pageCount : 1;
    for (int i = 0; i < actualPageCount; i++) {
      indicators.add(
        Container(
          width: 8.0,
          height: 8.0,
          margin: const EdgeInsets.symmetric(horizontal: 4.0),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: currentPage == i ? Colors.blue : Colors.grey,
          ),
        ),
      );
    }
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: indicators,
    );
  }

  @override
  Widget build(BuildContext context) {
    String dateRangeText;
    if (_startDate.isAtSameMomentAs(_endDate)) {
      dateRangeText = DateFormat('dd-MMM-yyyy').format(_startDate);
    } else {
      dateRangeText =
          '${DateFormat('dd-MMM-yyyy').format(_startDate)} to ${DateFormat('dd-MMM-yyyy').format(_endDate)}';
    }

    if (widget.substationId.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Text(
            'Please select a substation to view energy SLD.',
            textAlign: TextAlign.center,
            style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey),
          ),
        ),
      );
    }

    final SldRenderData sldRenderData = _buildBayRenderDataList(
      _allBaysInSubstation,
      _baysMap,
      _allConnections,
      _bayEnergyData,
      _busEnergySummary,
    );

    final double canvasWidth = max(
      MediaQuery.of(context).size.width,
      (sldRenderData.bayRenderDataList.isNotEmpty
              ? sldRenderData.bayRenderDataList
                    .map((e) => e.rect.right + 100)
                    .reduce(max)
              : 0) +
          50,
    );
    final double canvasHeight = max(
      MediaQuery.of(context).size.height,
      (sldRenderData.bayRenderDataList.isNotEmpty
              ? sldRenderData.bayRenderDataList
                    .map((e) => e.rect.bottom + 100)
                    .reduce(max)
              : 0) +
          50,
    );

    const double abstractCardWidth = 400;
    const double abstractCardHeight = 200;
    const double feederTableHeight = 300; // Height for the feeder table

    final List<Bay> busbarsWithData = _allBaysInSubstation
        .where(
          (bay) =>
              bay.bayType == 'Busbar' && _busEnergySummary.containsKey(bay.id),
        )
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Energy Account: ${widget.substationName} ($dateRangeText)',
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today),
            onPressed: () => _selectDate(context),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: Stack(
                    children: [
                      InteractiveViewer(
                        transformationController: _transformationController,
                        boundaryMargin: const EdgeInsets.all(double.infinity),
                        minScale: 0.1,
                        maxScale: 4.0,
                        constrained: false,
                        child: CustomPaint(
                          size: Size(canvasWidth, canvasHeight),
                          painter: SingleLineDiagramPainter(
                            bayRenderDataList: sldRenderData.bayRenderDataList,
                            bayConnections: _allConnections,
                            baysMap: _baysMap,
                            createDummyBayRenderData: _createDummyBayRenderData,
                            busbarRects: sldRenderData.busbarRects,
                            busbarConnectionPoints:
                                sldRenderData.busbarConnectionPoints,
                            debugDrawHitboxes: false,
                            selectedBayForMovementId: null,
                            bayEnergyData: sldRenderData.bayEnergyData,
                            busEnergySummary: sldRenderData.busEnergySummary,
                          ),
                        ),
                      ),
                      Align(
                        alignment: Alignment.bottomRight,
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: SizedBox(
                            width: abstractCardWidth,
                            height: abstractCardHeight,
                            child: Card(
                              elevation: 4,
                              child: Padding(
                                padding: const EdgeInsets.all(12.0),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: PageView.builder(
                                        itemCount: busbarsWithData.length + 1,
                                        onPageChanged: (index) {
                                          setState(() {
                                            _currentPageIndex = index;
                                          });
                                        },
                                        itemBuilder: (context, index) {
                                          if (index == busbarsWithData.length) {
                                            // Last page is the Abstract of Substation
                                            return Column(
                                              mainAxisSize: MainAxisSize.min,
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  'Abstract of Substation',
                                                  style: Theme.of(
                                                    context,
                                                  ).textTheme.titleSmall,
                                                ),
                                                const Divider(),
                                                _buildEnergyRow(
                                                  'Total Import',
                                                  _abstractEnergyData['totalImp'],
                                                  'MWH',
                                                  isAbstract: true,
                                                ),
                                                _buildEnergyRow(
                                                  'Total Export',
                                                  _abstractEnergyData['totalExp'],
                                                  'MWH',
                                                  isAbstract: true,
                                                ),
                                                _buildEnergyRow(
                                                  'Difference',
                                                  _abstractEnergyData['difference'],
                                                  'MWH',
                                                  isAbstract: true,
                                                ),
                                                _buildEnergyRow(
                                                  'Loss Percentage',
                                                  _abstractEnergyData['lossPercentage'],
                                                  '%',
                                                  isAbstract: true,
                                                ),
                                              ],
                                            );
                                          } else {
                                            // Busbar Abstract Pages
                                            final busbar =
                                                busbarsWithData[index];
                                            final busSummary =
                                                _busEnergySummary[busbar.id];
                                            return Column(
                                              mainAxisSize: MainAxisSize.min,
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  'Abstract of Busbar:',
                                                  style: Theme.of(
                                                    context,
                                                  ).textTheme.titleSmall,
                                                ),
                                                Text(
                                                  '${busbar.voltageLevel} ${busbar.name}',
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .bodyMedium
                                                      ?.copyWith(
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                ),
                                                const Divider(),
                                                _buildEnergyRow(
                                                  'Import',
                                                  busSummary?['totalImp'],
                                                  'MWH',
                                                ),
                                                _buildEnergyRow(
                                                  'Export',
                                                  busSummary?['totalExp'],
                                                  'MWH',
                                                ),
                                                _buildEnergyRow(
                                                  'Difference',
                                                  busSummary?['difference'],
                                                  'MWH',
                                                ),
                                                _buildEnergyRow(
                                                  'Loss',
                                                  busSummary?['lossPercentage'],
                                                  '%',
                                                ),
                                              ],
                                            );
                                          }
                                        },
                                      ),
                                    ),
                                    _buildPageIndicator(
                                      busbarsWithData.length + 1,
                                      _currentPageIndex,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Feeder Energy Table Section
                Container(
                  height: feederTableHeight,
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    children: [
                      Text(
                        'Feeder Energy Supplied by Distribution Hierarchy',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const Divider(),
                      Expanded(
                        child: PageView.builder(
                          itemCount:
                              (_aggregatedFeederEnergyData.length / 5)
                                  .ceil()
                                  .toInt() +
                              (_aggregatedFeederEnergyData.isEmpty ? 1 : 0),
                          onPageChanged: (index) {
                            setState(() {
                              _feederTablePageIndex = index;
                            });
                          },
                          itemBuilder: (context, pageIndex) {
                            if (_aggregatedFeederEnergyData.isEmpty) {
                              return const Center(
                                child: Text(
                                  'No aggregated feeder energy data available for this date range.',
                                ),
                              );
                            }

                            final int startIndex = pageIndex * 5;
                            final int endIndex = (startIndex + 5).clamp(
                              0,
                              _aggregatedFeederEnergyData.length,
                            );
                            final List<AggregatedFeederEnergyData>
                            currentPageData = _aggregatedFeederEnergyData
                                .sublist(startIndex, endIndex);

                            // Keep track of previous values for merging cells
                            AggregatedFeederEnergyData? previousRowData;

                            return SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: DataTable(
                                columns: const [
                                  DataColumn(label: Text('D-Zone')),
                                  DataColumn(label: Text('D-Circle')),
                                  DataColumn(label: Text('D-Division')),
                                  DataColumn(label: Text('D-Subdivision')),
                                  DataColumn(label: Text('Import (MWH)')),
                                  DataColumn(label: Text('Export (MWH)')),
                                ],
                                rows: currentPageData.mapIndexed((index, data) {
                                  // Determine if current cell should be merged
                                  final bool mergeZone =
                                      index > 0 &&
                                      data.zoneName ==
                                          previousRowData?.zoneName;
                                  final bool mergeCircle =
                                      mergeZone &&
                                      data.circleName ==
                                          previousRowData?.circleName;
                                  final bool mergeDivision =
                                      mergeCircle &&
                                      data.divisionName ==
                                          previousRowData?.divisionName;
                                  final bool mergeSubdivision =
                                      mergeDivision &&
                                      data.distributionSubdivisionName ==
                                          previousRowData
                                              ?.distributionSubdivisionName;

                                  // Update previousRowData for the next iteration
                                  previousRowData = data;

                                  return DataRow(
                                    cells: [
                                      DataCell(
                                        Text(mergeZone ? '' : data.zoneName),
                                      ),
                                      DataCell(
                                        Text(
                                          mergeCircle ? '' : data.circleName,
                                        ),
                                      ),
                                      DataCell(
                                        Text(
                                          mergeDivision
                                              ? ''
                                              : data.divisionName,
                                        ),
                                      ),
                                      DataCell(
                                        Text(
                                          mergeSubdivision
                                              ? ''
                                              : data.distributionSubdivisionName,
                                        ),
                                      ),
                                      DataCell(
                                        Text(
                                          data.importedEnergy.toStringAsFixed(
                                            2,
                                          ),
                                        ),
                                      ),
                                      DataCell(
                                        Text(
                                          data.exportedEnergy.toStringAsFixed(
                                            2,
                                          ),
                                        ),
                                      ),
                                    ],
                                  );
                                }).toList(),
                              ),
                            );
                          },
                        ),
                      ),
                      if (_aggregatedFeederEnergyData.isNotEmpty)
                        _buildPageIndicator(
                          (_aggregatedFeederEnergyData.length / 5)
                              .ceil()
                              .toInt(),
                          _feederTablePageIndex,
                        ),
                    ],
                  ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showBusbarSelectionDialog,
        child: const Icon(Icons.settings_input_antenna),
        tooltip: 'Configure Busbar Energy',
      ),
    );
  }

  Widget _buildEnergyRow(
    String label,
    double? value,
    String unit, {
    bool isAbstract = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label + ':',
            style: isAbstract
                ? Theme.of(context).textTheme.titleSmall
                : Theme.of(context).textTheme.bodySmall,
          ),
          Text(
            value != null ? '${value.toStringAsFixed(2)} $unit' : 'N/A',
            style: isAbstract
                ? Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)
                : Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

// Dialog for configuring busbar energy contributions (remains unchanged)
class _BusbarEnergyAssignmentDialog extends StatefulWidget {
  final Bay busbar;
  final List<Bay> connectedBays;
  final AppUser currentUser;
  final Map<String, BusbarEnergyMap>
  currentMaps; // Existing maps for this busbar
  final Function(BusbarEnergyMap)
  onSaveMap; // Callback to save/update a single map
  final Function(String) onDeleteMap; // Callback to delete a map

  const _BusbarEnergyAssignmentDialog({
    required this.busbar,
    required this.connectedBays,
    required this.currentUser,
    required this.currentMaps,
    required this.onSaveMap,
    required this.onDeleteMap,
  });

  @override
  __BusbarEnergyAssignmentDialogState createState() =>
      __BusbarEnergyAssignmentDialogState();
}

class __BusbarEnergyAssignmentDialogState
    extends State<_BusbarEnergyAssignmentDialog> {
  // Key: connectedBayId, Value: {import: EnergyContributionType, export: EnergyContributionType, originalMapId: String?}
  final Map<String, Map<String, dynamic>> _bayContributionSelections = {};
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    for (var bay in widget.connectedBays) {
      final existingMap =
          widget.currentMaps[bay.id]; // Use bay.id as key in currentMaps
      _bayContributionSelections[bay.id] = {
        'import':
            existingMap?.importContribution ?? EnergyContributionType.none,
        'export':
            existingMap?.exportContribution ?? EnergyContributionType.none,
        'originalMapId': existingMap?.id,
      };
    }
  }

  Future<void> _saveAllContributions() async {
    setState(() => _isSaving = true);
    try {
      for (var bayId in _bayContributionSelections.keys) {
        final selection = _bayContributionSelections[bayId]!;
        final originalMapId = selection['originalMapId'] as String?;
        final importContrib = selection['import'] as EnergyContributionType;
        final exportContrib = selection['export'] as EnergyContributionType;

        if (importContrib == EnergyContributionType.none &&
            exportContrib == EnergyContributionType.none) {
          if (originalMapId != null) {
            // If both are 'none' and there was an existing map, delete it
            widget.onDeleteMap(originalMapId);
          }
        } else {
          // Save or update the map
          final newMap = BusbarEnergyMap(
            id: originalMapId, // Will be null for new maps, used for updates
            substationId: widget.busbar.substationId,
            busbarId: widget.busbar.id,
            connectedBayId: bayId,
            importContribution: importContrib,
            exportContribution: exportContrib,
            createdBy: originalMapId != null
                ? widget.currentUser.uid
                : widget.currentUser.uid,
            createdAt: originalMapId != null
                ? Timestamp.now()
                : Timestamp.now(), // For new maps, use now. For existing, use now for lastModifiedAt in toFirestore
            lastModifiedAt: Timestamp.now(), // Always update last modified
          );
          widget.onSaveMap(newMap);
        }
      }
      if (mounted) {
        SnackBarUtils.showSnackBar(context, 'Busbar energy assignments saved!');
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        SnackBarUtils.showSnackBar(
          context,
          'Failed to save assignments: $e',
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Assign Energy Flow for ${widget.busbar.name}'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Configure how energy from connected bays contributes to this busbar\'s import/export.',
            ),
            const SizedBox(height: 16),
            if (widget.connectedBays.isEmpty)
              const Text('No bays connected to this busbar.'),
            ...widget.connectedBays.map((bay) {
              final currentSelection = _bayContributionSelections[bay.id]!;
              return Card(
                margin: const EdgeInsets.symmetric(vertical: 8),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${bay.name} (${bay.bayType})',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 8),
                      // Import Contribution
                      DropdownButtonFormField<EnergyContributionType>(
                        decoration: const InputDecoration(
                          labelText: 'Bay Import contributes to Busbar:',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        value: currentSelection['import'],
                        items: EnergyContributionType.values.map((type) {
                          return DropdownMenuItem(
                            value: type,
                            child: Text(
                              type
                                  .toString()
                                  .split('.')
                                  .last
                                  .replaceAll('bus', 'Bus '),
                            ),
                          );
                        }).toList(),
                        onChanged: (newValue) {
                          setState(() {
                            currentSelection['import'] = newValue;
                          });
                        },
                      ),
                      const SizedBox(height: 8),
                      // Export Contribution
                      DropdownButtonFormField<EnergyContributionType>(
                        decoration: const InputDecoration(
                          labelText: 'Bay Export contributes to Busbar:',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        value: currentSelection['export'],
                        items: EnergyContributionType.values.map((type) {
                          return DropdownMenuItem(
                            value: type,
                            child: Text(
                              type
                                  .toString()
                                  .split('.')
                                  .last
                                  .replaceAll('bus', 'Bus '),
                            ),
                          );
                        }).toList(),
                        onChanged: (newValue) {
                          setState(() {
                            currentSelection['export'] = newValue;
                          });
                        },
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isSaving ? null : _saveAllContributions,
          child: _isSaving
              ? const CircularProgressIndicator(strokeWidth: 2)
              : const Text('Save Assignments'),
        ),
      ],
    );
  }
}
