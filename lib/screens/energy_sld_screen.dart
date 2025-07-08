// lib/screens/energy_sld_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'dart:math';
import 'package:collection/collection.dart'
    as collection; // Modified import to use a prefix

import '../models/bay_model.dart';
import '../models/user_model.dart';
import '../models/reading_models.dart';
import '../models/logsheet_models.dart';
import '../models/bay_connection_model.dart';
import '../utils/snackbar_utils.dart';

// Reusing components from substation_detail_screen.dart
import 'substation_detail_screen.dart'; // To access SingleLineDiagramPainter and BayRenderData

// NEW: BayEnergyData class moved to top-level
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

// NEW: SldRenderData class to encapsulate all rendering data
class SldRenderData {
  final List<BayRenderData> bayRenderDataList;
  final Map<String, Rect> finalBayRects;
  final Map<String, Rect> busbarRects;
  final Map<String, Map<String, Offset>> busbarConnectionPoints;
  final Map<String, BayEnergyData> bayEnergyData; // NEW: Add energy data
  final Map<String, Map<String, double>>
  busEnergySummary; // NEW: Add bus summary

  SldRenderData({
    required this.bayRenderDataList,
    required this.finalBayRects,
    required this.busbarRects,
    required this.busbarConnectionPoints,
    required this.bayEnergyData,
    required this.busEnergySummary, // NEW
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
  DateTime _startDate = DateTime.now().subtract(
    const Duration(days: 1),
  ); // Default to yesterday
  DateTime _endDate = DateTime.now(); // Default to today

  List<Bay> _allBaysInSubstation = [];
  Map<String, Bay> _baysMap = {};
  List<BayConnection> _allConnections = [];

  Map<String, BayEnergyData> _bayEnergyData = {};
  Map<String, double> _abstractEnergyData = {};
  Map<String, Map<String, double>> _busEnergySummary =
      {}; // NEW state variable for bus totals

  final TransformationController _transformationController =
      TransformationController();

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

  Future<void> _loadEnergyData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _bayEnergyData.clear();
      _abstractEnergyData.clear();
      _busEnergySummary.clear(); // Clear bus summary
      _allBaysInSubstation.clear();
      _baysMap.clear();
      _allConnections.clear();
    });

    try {
      // 1. Fetch Bays
      final baysSnapshot = await FirebaseFirestore.instance
          .collection('bays')
          .where('substationId', isEqualTo: widget.substationId)
          .orderBy('name')
          .get();
      _allBaysInSubstation = baysSnapshot.docs
          .map((doc) => Bay.fromFirestore(doc))
          .toList();
      _baysMap = {for (var bay in _allBaysInSubstation) bay.id: bay};

      // 2. Fetch Connections
      final connectionsSnapshot = await FirebaseFirestore.instance
          .collection('bay_connections')
          .where('substationId', isEqualTo: widget.substationId)
          .get();
      _allConnections = connectionsSnapshot.docs
          .map((doc) => BayConnection.fromFirestore(doc))
          .toList();

      // 3. Fetch Logsheet Entries based on date range
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
      Map<String, LogsheetEntry> previousDayToStartDateReadings =
          {}; // For single day calculation

      // Fetch readings for Start Date
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
      print('DEBUG: Start Day Readings (for $_startDate): $startDayReadings');

      // Fetch readings for End Date
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
        print('DEBUG: End Day Readings (for $_endDate): $endDayReadings');
      } else {
        // If start date == end date, endDayReadings is just startDayReadings
        endDayReadings = startDayReadings;

        // Also fetch previous day's reading for single day calculation
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
        print(
          'DEBUG: Previous Day to Start Date Readings (for $previousDay): $previousDayToStartDateReadings',
        );
      }

      // 4. Process data for each bay
      double abstractSubstationTotalImp =
          0; // Renamed from totalImp for clarity
      double abstractSubstationTotalExp =
          0; // Renamed from totalExp for clarity

      Map<String, double> tempBusImports = {}; // Temp storage for bus imports
      Map<String, double> tempBusExports = {}; // Temp storage for bus exports

      for (var bay in _allBaysInSubstation) {
        final double? mf = bay.multiplyingFactor;
        double? calculatedImpConsumed;
        double? calculatedExpConsumed;

        if (_startDate.isAtSameMomentAs(_endDate)) {
          // Case: Single Day Consumption
          final currentReadingLogsheet =
              endDayReadings[bay
                  .id]; // This is the reading for the selected single day
          final previousReadingLogsheetDocument =
              previousDayToStartDateReadings[bay
                  .id]; // Document from day before selected single day

          print('DEBUG: Single Day Calculation for Bay: ${bay.name}');
          print(
            'DEBUG: Current Reading (${DateFormat('dd-MMM-yyyy').format(_endDate)}): $currentReadingLogsheet',
          );
          print(
            'DEBUG: Previous Reading Document (${DateFormat('dd-MMM-yyyy').format(_endDate.subtract(const Duration(days: 1)))}): $previousReadingLogsheetDocument',
          );

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

          // First, try to get previous day's value from the *previous day's document*
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
            // If no previous day's *document*, try to get "Previous Day Reading" *field* from current day's document
            prevImpValForCalculation = double.tryParse(
              currentReadingLogsheet?.values['Previous Day Reading (Import)']
                      ?.toString() ??
                  '',
            );
            if (prevImpValForCalculation != null) {
              print(
                'DEBUG: Used "Previous Day Reading (Import)" field from current day\'s logsheet for ${bay.name}',
              );
            }
          }

          if (prevExpValFromPreviousDocument != null) {
            prevExpValForCalculation = prevExpValFromPreviousDocument;
          } else {
            // If no previous day's *document*, try to get "Previous Day Reading" *field* from current day's document
            prevExpValForCalculation = double.tryParse(
              currentReadingLogsheet?.values['Previous Day Reading (Export)']
                      ?.toString() ??
                  '',
            );
            if (prevExpValForCalculation != null) {
              print(
                'DEBUG: Used "Previous Day Reading (Export)" field from current day\'s logsheet for ${bay.name}',
              );
            }
          }

          print(
            'DEBUG: currImpVal: $currImpVal, prevImpValForCalculation: $prevImpValForCalculation',
          );
          print(
            'DEBUG: currExpVal: $currExpVal, prevExpValForCalculation: $prevExpValForCalculation',
          );

          if (currImpVal != null &&
              prevImpValForCalculation != null &&
              mf != null) {
            calculatedImpConsumed =
                (currImpVal - prevImpValForCalculation) * mf;
          } else if (currImpVal != null && mf != null) {
            // Fallback if no prev reading at all
            calculatedImpConsumed = currImpVal * mf;
            print(
              'DEBUG: No sufficient previous reading for ${bay.name}, showing current * MF as consumption.',
            );
          }

          if (currExpVal != null &&
              prevExpValForCalculation != null &&
              mf != null) {
            calculatedExpConsumed =
                (currExpVal - prevExpValForCalculation) * mf;
          } else if (currExpVal != null && mf != null) {
            // Fallback
            calculatedExpConsumed = currExpVal * mf;
            print(
              'DEBUG: No sufficient previous reading for ${bay.name}, showing current * MF as consumption.',
            );
          }
          print(
            'DEBUG: calculatedImpConsumed for ${bay.name}: $calculatedImpConsumed',
          );
          print(
            'DEBUG: calculatedExpConsumed for ${bay.name}: $calculatedExpConsumed',
          );

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
          // Case: Period Consumption
          final startReading = startDayReadings[bay.id];
          final endReading = endDayReadings[bay.id];

          print('DEBUG: Period Calculation for Bay: ${bay.name}');
          print(
            'DEBUG: Start Reading (${DateFormat('dd-MMM-yyyy').format(_startDate)}): $startReading',
          );
          print(
            'DEBUG: End Reading (${DateFormat('dd-MMM-yyyy').format(_endDate)}): $endReading',
          );

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

          print('DEBUG: startImpVal: $startImpVal, endImpVal: $endImpVal');
          print('DEBUG: startExpVal: $startExpVal, endExpVal: $endExpVal');

          if (startImpVal != null && endImpVal != null && mf != null) {
            calculatedImpConsumed = (endImpVal - startImpVal) * mf;
          }
          if (startExpVal != null && endExpVal != null && mf != null) {
            calculatedExpConsumed = (endExpVal - startExpVal) * mf;
          }
          print(
            'DEBUG: calculatedImpConsumed for ${bay.name}: $calculatedImpConsumed',
          );
          print(
            'DEBUG: calculatedExpConsumed for ${bay.name}: $calculatedExpConsumed',
          );

          _bayEnergyData[bay.id] = BayEnergyData(
            bayName: bay.name,
            prevImp: startImpVal, // For display, prev is start of period
            currImp: endImpVal, // For display, curr is end of period
            prevExp: startExpVal,
            currExp: endExpVal,
            mf: mf,
            impConsumed: calculatedImpConsumed,
            expConsumed: calculatedExpConsumed,
          );
        }

        // Aggregate for Abstract Substation Data (only for Lines and Feeders)
        if (bay.bayType == 'Line' || bay.bayType == 'Feeder') {
          if (calculatedImpConsumed != null)
            abstractSubstationTotalImp += calculatedImpConsumed;
          if (calculatedExpConsumed != null)
            abstractSubstationTotalExp += calculatedExpConsumed;
        }
      }

      // Populate _busEnergySummary
      for (var busbar in _allBaysInSubstation.where(
        (b) => b.bayType == 'Busbar',
      )) {
        double busTotalImp = 0.0;
        double busTotalExp = 0.0;

        // Find bays connected to this busbar
        for (var connection in _allConnections) {
          String? connectedBayId;
          bool isSourceToBus =
              false; // True if current bay is source, bus is target
          bool isTargetToBus =
              false; // True if current bay is target, bus is source

          if (connection.sourceBayId == busbar.id) {
            connectedBayId = connection.targetBayId;
            isSourceToBus = true;
          } else if (connection.targetBayId == busbar.id) {
            connectedBayId = connection.sourceBayId;
            isTargetToBus = true;
          }

          if (connectedBayId != null) {
            final connectedBay = _baysMap[connectedBayId];
            if (connectedBay != null &&
                (connectedBay.bayType == 'Line' ||
                    connectedBay.bayType == 'Feeder' ||
                    connectedBay.bayType == 'Transformer')) {
              final connectedBayEnergyData = _bayEnergyData[connectedBayId];

              if (connectedBayEnergyData != null) {
                // Determine directionality relative to the bus for import/export
                // Simplified logic: If a bay imports, it adds to bus import. If it exports, it adds to bus export.
                // This might need more complex power flow logic depending on exact definitions.
                if (connectedBayEnergyData.impConsumed != null &&
                    connectedBayEnergyData.impConsumed! > 0) {
                  busTotalImp += connectedBayEnergyData.impConsumed!;
                }
                if (connectedBayEnergyData.expConsumed != null &&
                    connectedBayEnergyData.expConsumed! > 0) {
                  busTotalExp += connectedBayEnergyData.expConsumed!;
                }
              }
            }
          }
        }
        _busEnergySummary[busbar.id] = {
          'totalImp': busTotalImp,
          'totalExp': busTotalExp,
        };
        print(
          'DEBUG: Bus Energy Summary for ${busbar.name}: Imp=${busTotalImp}, Exp=${busTotalExp}',
        );
      }

      // 5. Calculate Abstract Data for overall substation
      double difference =
          abstractSubstationTotalImp - abstractSubstationTotalExp;
      double lossPercentage = 0;
      if (abstractSubstationTotalImp > 0) {
        lossPercentage = (difference / abstractSubstationTotalImp) * 100;
      }

      _abstractEnergyData = {
        'totalImp': abstractSubstationTotalImp,
        'totalExp': abstractSubstationTotalExp,
        'difference': difference,
        'lossPercentage': lossPercentage,
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

  // Modified to return SldRenderData, now also takes bayEnergyData and busEnergySummary
  SldRenderData _buildBayRenderDataList(
    List<Bay> allBays,
    Map<String, Bay> baysMap,
    List<BayConnection> allConnections,
    Map<String, BayEnergyData> bayEnergyData,
    Map<String, Map<String, double>> busEnergySummary, // NEW
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
      // Filter to only include the required bay types for the energy SLD visual
      if (!['Busbar', 'Transformer', 'Line', 'Feeder'].contains(bay.bayType)) {
        continue; // Skip other bay types from visual layout
      }

      if (bay.bayType == 'Transformer') {
        if (bay.hvBusId != null && bay.lvBusId != null) {
          final hvBus = baysMap[bay.hvBusId];
          final lvBus = baysMap[bay.lvBusId];
          if (hvBus != null && lvBus != null) {
            final double hvVoltage =
                double.tryParse(
                  hvBus.voltageLevel.replaceAll(RegExp(r'[^0-9.]'), ''),
                ) ??
                0;
            final double lvVoltage =
                double.tryParse(
                  lvBus.voltageLevel.replaceAll(RegExp(r'[^0-9.]'), ''),
                ) ??
                0;

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
        final double hvVoltageValue =
            double.tryParse(
              currentHvBus.voltageLevel.replaceAll(RegExp(r'[^0-9.]'), ''),
            ) ??
            0;
        final double lvVoltageValue =
            double.tryParse(
              currentLvBus.voltageLevel.replaceAll(RegExp(r'[^0-9.]'), ''),
            ) ??
            0;

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

    // After all layout calculations, populate bayRenderDataList
    // ONLY for the allowed bay types
    final List<String> allowedVisualBayTypes = [
      'Busbar',
      'Transformer',
      'Line',
      'Feeder',
    ];

    for (var bay in allBays) {
      if (!allowedVisualBayTypes.contains(bay.bayType)) {
        continue; // Skip adding other bay types to the render list
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
            // equipmentInstances will be empty for Energy SLD as it's not managed here
          ),
        );
      }
    }

    // Recalculate busbar connection points based on their new fixed X positions
    for (var connection in allConnections) {
      final Bay? sourceBay = baysMap[connection.sourceBayId];
      final Bay? targetBay = baysMap[connection.targetBayId];
      if (sourceBay == null || targetBay == null) continue;

      // Only add connection points if both source and target bays are allowed types
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
      busEnergySummary: busEnergySummary, // Pass the bus summary
    );
  }

  // Dummy function for SingleLineDiagramPainter
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
      _busEnergySummary, // Pass bus summary
    );

    double contentMaxX = sldRenderData.bayRenderDataList.isNotEmpty
        ? sldRenderData.bayRenderDataList
              .map((e) => e.rect.right + 100) // Add padding to the right
              .reduce(max)
        : 0;
    double contentMaxY = sldRenderData.bayRenderDataList.isNotEmpty
        ? sldRenderData.bayRenderDataList
              .map((e) => e.rect.bottom + 100) // Add padding below
              .reduce(max)
        : 0;

    const double abstractCardHeightEstimate = 180;
    contentMaxY = max(contentMaxY, abstractCardHeightEstimate + 50);

    double canvasWidth = max(
      MediaQuery.of(context).size.width,
      contentMaxX + 50,
    );
    double canvasHeight = max(
      MediaQuery.of(context).size.height,
      contentMaxY + 50,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Energy Account: ${widget.substationName} ($dateRangeText)',
        ), // Updated title
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
                      busEnergySummary:
                          sldRenderData.busEnergySummary, // Pass bus summary
                    ),
                  ),
                ),
                // Overlay for Abstract Data
                Align(
                  alignment: Alignment.bottomRight,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Card(
                      elevation: 4,
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Abstract of Substation',
                              style: Theme.of(context).textTheme.titleMedium,
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
