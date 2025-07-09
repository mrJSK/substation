// lib/screens/energy_sld_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'dart:math';
import 'package:collection/collection.dart' as collection;

import '../models/bay_model.dart';
import '../models/user_model.dart';
import '../models/reading_models.dart';
import '../models/logsheet_models.dart';
import '../models/bay_connection_model.dart';
import '../utils/snackbar_utils.dart';

// Reusing components from substation_detail_screen.dart
import 'substation_detail_screen.dart'; // To access SingleLineDiagramPainter and BayRenderData

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

  final TransformationController _transformationController =
      TransformationController();

  int _currentPageIndex = 0;

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
      _currentPageIndex = 0;
    });

    try {
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
      // print('DEBUG: Start Day Readings (for $_startDate): $startDayReadings');

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
        // print('DEBUG: End Day Readings (for $_endDate): $endDayReadings');
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
              isGreaterThanOrEqualTo: startOfPreviousDay,
            )
            .where('readingTimestamp', isLessThanOrEqualTo: endOfPreviousDay)
            .get();
        previousDayToStartDateReadings = {
          for (var doc in previousDayToStartDateLogsheetsSnapshot.docs)
            (doc.data() as Map<String, dynamic>)['bayId']:
                LogsheetEntry.fromFirestore(doc),
        };
        // print(
        //   'DEBUG: Previous Day to Start Date Readings (for $previousDay): $previousDayToStartDateReadings',
        // );
      }

      // Initialize temporary storage for busbar flows
      Map<String, Map<String, double>> temporaryBusFlows = {};
      for (var busbar in _allBaysInSubstation.where(
        (b) => b.bayType == 'Busbar',
      )) {
        temporaryBusFlows[busbar.id] = {'import': 0.0, 'export': 0.0};
      }

      // Initialize abstract substation totals here
      double currentAbstractSubstationTotalImp = 0;
      double currentAbstractSubstationTotalExp = 0;

      for (var bay in _allBaysInSubstation) {
        final double? mf = bay.multiplyingFactor;
        double calculatedImpConsumed = 0.0; // Initialize to 0.0
        double calculatedExpConsumed = 0.0; // Initialize to 0.0

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

          // Prefer previous day's document reading if available for previous value
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
            // Fallback to "Previous Day Reading" field in current day's document
            prevImpValForCalculation = double.tryParse(
              currentReadingLogsheet?.values['Previous Day Reading (Import)']
                      ?.toString() ??
                  '',
            );
          }

          if (prevExpValFromPreviousDocument != null) {
            prevExpValForCalculation = prevExpValFromPreviousDocument;
          } else {
            // Fallback to "Previous Day Reading" field in current day's document
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
            ); // Ensure non-negative consumption
          } else if (currImpVal != null && mf != null) {
            calculatedImpConsumed = currImpVal * mf;
          }

          if (currExpVal != null &&
              prevExpValForCalculation != null &&
              mf != null) {
            calculatedExpConsumed = max(
              0.0,
              (currExpVal - prevExpValForCalculation) * mf,
            ); // Ensure non-negative consumption
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

        // --- BUSBAR ABSTRACT CALCULATION (Per your clarified logic) ---
        // Process each bay's energy to correctly add to the connected busbar(s) import/export.
        final connectedBayEnergyData = _bayEnergyData[bay.id];
        if (connectedBayEnergyData == null)
          continue; // Skip if no energy data for this bay

        final List<BayConnection>
        relevantBusConnections = _allConnections.where((c) {
          // Check if current 'bay' is involved and the other end is a 'Busbar'
          final isCurrentBaySource = c.sourceBayId == bay.id;
          final isCurrentBayTarget = c.targetBayId == bay.id;
          final isOtherEndBus =
              (_baysMap[c.sourceBayId]?.bayType == 'Busbar' &&
                  isCurrentBayTarget) ||
              (_baysMap[c.targetBayId]?.bayType == 'Busbar' &&
                  isCurrentBaySource);
          return isOtherEndBus;
        }).toList();

        for (var connection in relevantBusConnections) {
          String? connectedBusId;
          Bay? connectedBus;

          // Determine which end of the connection is the busbar
          if (_baysMap[connection.sourceBayId]?.bayType == 'Busbar') {
            connectedBusId = connection.sourceBayId;
            connectedBus = _baysMap[connection.sourceBayId];
          } else {
            // connection.targetBayId must be the busbar
            connectedBusId = connection.targetBayId;
            connectedBus = _baysMap[connection.targetBayId];
          }

          if (connectedBusId != null && connectedBus != null) {
            temporaryBusFlows.putIfAbsent(
              connectedBusId,
              () => {'import': 0.0, 'export': 0.0},
            );

            if (bay.bayType == 'Line') {
              // Lines connected to a bus:
              // If the line is the SOURCE of the connection to the bus (Line -> Bus), Line's Imp is Bus's Imp. Line's Exp is Bus's Exp.
              // If the line is the TARGET of the connection from the bus (Bus -> Line), Line's Imp is Bus's Exp. Line's Exp is Bus's Imp.
              if (connection.sourceBayId == bay.id) {
                // Line -> Bus
                temporaryBusFlows[connectedBusId]!['import'] =
                    (temporaryBusFlows[connectedBusId]!['import'] ?? 0.0) +
                    (connectedBayEnergyData.impConsumed ?? 0.0);
                temporaryBusFlows[connectedBusId]!['export'] =
                    (temporaryBusFlows[connectedBusId]!['export'] ?? 0.0) +
                    (connectedBayEnergyData.expConsumed ?? 0.0);
              } else {
                // Bus -> Line
                temporaryBusFlows[connectedBusId]!['export'] =
                    (temporaryBusFlows[connectedBusId]!['export'] ?? 0.0) +
                    (connectedBayEnergyData.impConsumed ?? 0.0);
                temporaryBusFlows[connectedBusId]!['import'] =
                    (temporaryBusFlows[connectedBusId]!['import'] ?? 0.0) +
                    (connectedBayEnergyData.expConsumed ?? 0.0);
              }
            } else if (bay.bayType == 'Transformer') {
              // Transformer Import (impConsumed) is from HV side. Transformer Export (expConsumed) is from LV side.
              if (bay.hvBusId == connectedBusId) {
                // This connection is to the HV bus
                // Transformer's HV Imp. is power *leaving* the HV Bus (Bus Export)
                temporaryBusFlows[connectedBusId]!['export'] =
                    (temporaryBusFlows[connectedBusId]!['export'] ?? 0.0) +
                    (connectedBayEnergyData.impConsumed ?? 0.0);
                // Transformer's HV Exp. (if any, e.g. reactive or backfeed) is power *entering* the HV Bus (Bus Import)
                temporaryBusFlows[connectedBusId]!['import'] =
                    (temporaryBusFlows[connectedBusId]!['import'] ?? 0.0) +
                    (connectedBayEnergyData.expConsumed ?? 0.0);
              } else if (bay.lvBusId == connectedBusId) {
                // This connection is to the LV bus
                // IMPORTANT: Total import on the transformer LV side bus is the transformer export energy.
                temporaryBusFlows[connectedBusId]!['import'] =
                    (temporaryBusFlows[connectedBusId]!['import'] ?? 0.0) +
                    (connectedBayEnergyData.expConsumed ??
                        0.0); // LV Bus Import from Transformer Export
                // Transformer's LV Imp. (if any, e.g. reactive or backfeed) is power *leaving* the LV Bus (Bus Export)
                temporaryBusFlows[connectedBusId]!['export'] =
                    (temporaryBusFlows[connectedBusId]!['export'] ?? 0.0) +
                    (connectedBayEnergyData.impConsumed ??
                        0.0); // LV Bus Export to Transformer Import
              }
            } else if (bay.bayType == 'Feeder') {
              // Feeders primarily draw power FROM the bus (are loads).
              // Feeder's Imp is power flowing FROM bus TO feeder => Bus's Export
              temporaryBusFlows[connectedBusId]!['import'] =
                  (temporaryBusFlows[connectedBusId]!['import'] ?? 0.0) +
                  (connectedBayEnergyData.impConsumed ?? 0.0);
              // Feeder's Exp is power flowing FROM feeder TO bus (local generation) => Bus's Import
              temporaryBusFlows[connectedBusId]!['export'] =
                  (temporaryBusFlows[connectedBusId]!['export'] ?? 0.0) +
                  (connectedBayEnergyData.expConsumed ?? 0.0);
            }
          }
        }
      }

      // Finalize bus energy summaries based on the aggregated temporary flows
      for (var busbar in _allBaysInSubstation.where(
        (b) => b.bayType == 'Busbar',
      )) {
        double busTotalImp = temporaryBusFlows[busbar.id]?['export'] ?? 0.0;
        double busTotalExp = temporaryBusFlows[busbar.id]?['import'] ?? 0.0;

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
      // The PDF implies: Substation Import = Import of the highest voltage bus
      //                 Substation Export = Export of the lowest voltage bus

      final highestVoltageBus = _allBaysInSubstation.firstWhereOrNull(
        (b) => b.bayType == 'Busbar',
      );
      final lowestVoltageBus = _allBaysInSubstation.lastWhereOrNull(
        (b) => b.bayType == 'Busbar',
      ); // Assuming last in sorted list is lowest voltage

      currentAbstractSubstationTotalImp =
          (_busEnergySummary[highestVoltageBus?.id]?['totalImp']) ?? 0.0;
      currentAbstractSubstationTotalExp =
          (_busEnergySummary[lowestVoltageBus?.id]?['totalExp']) ?? 0.0;

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
    const double busbarHitboxHeight = 20.0;
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
          if (hvBus != null && lvBus != null) {
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
          }
        }
      } else if (bay.bayType != 'Busbar') {
        final connectionToBus = allConnections.firstWhereOrNull((c) {
          final bool sourceIsBay = c.sourceBayId == bay.id;
          final bool targetIsBay = c.targetBayId == bay.id;
          final bool sourceIsBus = baysMap[c.sourceBayId]?.bayType == 'Busbar';
          final bool targetIsBus = baysMap[c.targetBayId]?.bayType == 'Busbar';
          return (sourceIsBay && targetIsBus) || (targetIsBay && sourceIsBus);
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

      final Bay? currentHvBus = baysMap[hvBusId];
      final Bay? currentLvBus = baysMap[lvBusId];

      if (currentHvBus != null && currentLvBus != null) {
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
      } else {
        debugPrint(
          'Warning: One of the bus IDs (${hvBusId}, ${lvBusId}) in bus pair key ${pairKey} not found in baysMap.',
        );
        continue;
      }

      final double hvBusY = busYPositions[hvBusId]!;
      final double lvBusY = busYPositions[lvBusId]!;

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

      final List<Bay> baysAbove = busbarToConnectedBaysAbove[busbar.id] ?? [];
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

      final List<Bay> baysBelow = busbarToConnectedBaysBelow[busbar.id] ?? [];
      currentX = currentLaneXForOtherBays;
      for (var bay in baysBelow) {
        Offset finalOffset = (bay.xPosition != null && bay.yPosition != null)
            ? Offset(bay.xPosition!, bay.yPosition!)
            : Offset(currentX, busY + 10);

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
    for (int i = 0; i < pageCount; i++) {
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
          : Stack(
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
                                      final busbar = busbarsWithData[index];
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
                                                  fontWeight: FontWeight.bold,
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
