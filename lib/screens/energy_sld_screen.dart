// lib/screens/energy_sld_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'dart:math';

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
  DateTime _selectedDate = DateTime.now();

  List<Bay> _allBaysInSubstation = [];
  Map<String, Bay> _baysMap = {};
  List<BayConnection> _allConnections = [];

  // Data for energy tables
  Map<String, BayEnergyData> _bayEnergyData = {};
  Map<String, double> _abstractEnergyData = {}; // Sum of imp/exp, diff, loss

  final TransformationController _transformationController =
      TransformationController();

  @override
  void initState() {
    super.initState();
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

      // 3. Fetch Logsheet Entries for current and previous day
      final currentDay = _selectedDate;
      final previousDay = _selectedDate.subtract(const Duration(days: 1));

      final startOfCurrentDay = DateTime(
        currentDay.year,
        currentDay.month,
        currentDay.day,
      );
      final endOfCurrentDay = DateTime(
        currentDay.year,
        currentDay.month,
        currentDay.day,
        23,
        59,
        59,
        999,
      );

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

      // Fetch all daily readings for current and previous day
      final currentDayLogsheetsSnapshot = await FirebaseFirestore.instance
          .collection('logsheetEntries')
          .where('substationId', isEqualTo: widget.substationId)
          .where('frequency', isEqualTo: 'daily')
          .where('readingTimestamp', isGreaterThanOrEqualTo: startOfCurrentDay)
          .where('readingTimestamp', isLessThanOrEqualTo: endOfCurrentDay)
          .get();

      final previousDayLogsheetsSnapshot = await FirebaseFirestore.instance
          .collection('logsheetEntries')
          .where('substationId', isEqualTo: widget.substationId)
          .where('frequency', isEqualTo: 'daily')
          .where('readingTimestamp', isGreaterThanOrEqualTo: startOfPreviousDay)
          .where('readingTimestamp', isLessThanOrEqualTo: endOfPreviousDay)
          .get();

      Map<String, LogsheetEntry> currentDayReadings = {
        for (var doc in currentDayLogsheetsSnapshot.docs)
          (doc.data() as Map<String, dynamic>)['bayId']:
              LogsheetEntry.fromFirestore(doc),
      };

      Map<String, LogsheetEntry> previousDayReadings = {
        for (var doc in previousDayLogsheetsSnapshot.docs)
          (doc.data() as Map<String, dynamic>)['bayId']:
              LogsheetEntry.fromFirestore(doc),
      };

      // 4. Process data for each bay
      double totalImp = 0;
      double totalExp = 0;
      double totalPreviousImp = 0;
      double totalPreviousExp = 0;

      for (var bay in _allBaysInSubstation) {
        final currentReading = currentDayReadings[bay.id];
        final previousReading = previousDayReadings[bay.id];

        // Retrieve values for 'Previous Day Reading (Import/Export)' and 'Current Day Reading (Import/Export)'
        // These are the names defined in the default reading templates.
        final double? currImpVal =
            (currentReading?.values['Current Day Reading (Import)'] as num?)
                ?.toDouble();
        final double? currExpVal =
            (currentReading?.values['Current Day Reading (Export)'] as num?)
                ?.toDouble();
        final double? prevImpVal =
            (previousReading?.values['Current Day Reading (Import)'] as num?)
                ?.toDouble(); // Get current day's reading from previous day's logsheet for previous reading
        final double? prevExpVal =
            (previousReading?.values['Current Day Reading (Export)'] as num?)
                ?.toDouble(); // Get current day's reading from previous day's logsheet for previous reading

        final double? mf = bay.multiplyingFactor;

        double? impConsumed;
        double? expConsumed;

        if (currImpVal != null && prevImpVal != null && mf != null) {
          impConsumed = (currImpVal - prevImpVal) * mf;
        }
        if (currExpVal != null && prevExpVal != null && mf != null) {
          expConsumed = (currExpVal - prevExpVal) * mf;
        }

        _bayEnergyData[bay.id] = BayEnergyData(
          bayName: bay.name,
          prevImp: prevImpVal,
          currImp: currImpVal,
          prevExp: prevExpVal,
          currExp: currExpVal,
          mf: mf,
          impConsumed: impConsumed,
          expConsumed: expConsumed,
        );

        if (impConsumed != null) totalImp += impConsumed;
        if (expConsumed != null) totalExp += expConsumed;
      }

      // 5. Calculate Abstract Data
      double difference = totalImp - totalExp;
      double lossPercentage = 0;
      if (totalImp > 0) {
        lossPercentage = (difference / totalImp) * 100;
      }

      _abstractEnergyData = {
        'totalImp': totalImp,
        'totalExp': totalExp,
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
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(), // Only allow past and current dates
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
      await _loadEnergyData();
    }
  }

  // Re-use logic for creating BayRenderDataList and busbar positions
  List<BayRenderData> _buildBayRenderDataList(
    List<Bay> allBays,
    Map<String, Bay> baysMap,
    List<BayConnection> allConnections,
  ) {
    final List<BayRenderData> bayRenderDataList = [];
    final Map<String, Rect> finalBayRects = {};
    final Map<String, Rect> busbarRects =
        {}; // Used by painter for drawing busbar lines
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

    final Map<String, List<Bay>> busbarToConnectedBaysAbove = {}; // Lines
    final Map<String, List<Bay>> busbarToConnectedBaysBelow =
        {}; // Feeders, others
    final Map<String, Map<String, List<Bay>>> transformersByBusPair = {};

    for (var bay in allBays) {
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

    for (var bay in allBays) {
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

    // Recalculate busbar connection points for transformers based on their new fixed X positions
    for (var connection in allConnections) {
      final Bay? sourceBay = _baysMap[connection.sourceBayId];
      final Bay? targetBay = _baysMap[connection.targetBayId];
      if (sourceBay == null || targetBay == null) continue;

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
    return bayRenderDataList;
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

    final List<BayRenderData> currentBayRenderDataList =
        _buildBayRenderDataList(
          _allBaysInSubstation,
          _baysMap,
          _allConnections,
        );

    // Reconstruct busbarRects and busbarConnectionPoints for the painter
    final Map<String, Rect> busbarRects = {};
    final Map<String, Map<String, Offset>> busbarConnectionPoints = {};
    final Map<String, double> busYPositions = {}; // Needed for busbar layout

    double currentY = 80;
    final List<Bay> busbars = _allBaysInSubstation
        .where((b) => b.bayType == 'Busbar')
        .toList();
    busbars.sort((a, b) {
      double getV(String v) =>
          double.tryParse(v.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0;
      return getV(b.voltageLevel).compareTo(getV(a.voltageLevel));
    });

    for (var busbar in busbars) {
      busYPositions[busbar.id] = currentY;
      currentY += 200; // Vertical spacing between busbars

      // For the painter, we need the actual drawing rect of the busbar.
      // This part is derived from the SLD layout logic in substation_detail_screen.
      // We assume a certain width for the busbar visually.
      const double busbarVisualWidth = 500; // Placeholder for visual width
      const double sidePadding = 100;
      busbarRects[busbar.id] = Rect.fromLTWH(
        sidePadding,
        busYPositions[busbar.id]!,
        busbarVisualWidth,
        0, // line, not a rect
      );
    }

    // Populate busbarConnectionPoints (this is complex in the original, simplified here)
    for (var conn in _allConnections) {
      final sourceBay = _baysMap[conn.sourceBayId];
      final targetBay = _baysMap[conn.targetBayId];
      if (sourceBay == null || targetBay == null) continue;

      // Logic to determine connection points on busbars, similar to SubstationDetailScreen
      // This is a simplified version and might need exact replication from _buildSLDView's logic
      // if precise connection rendering is critical.
      if (sourceBay.bayType == 'Busbar' && targetBay.bayType != 'Busbar') {
        final targetBayRenderData = currentBayRenderDataList.firstWhereOrNull(
          (d) => d.bay.id == targetBay.id,
        );
        if (targetBayRenderData != null &&
            busYPositions.containsKey(sourceBay.id)) {
          busbarConnectionPoints.putIfAbsent(
            sourceBay.id,
            () => {},
          )[targetBay.id] = Offset(
            targetBayRenderData.rect.center.dx,
            busYPositions[sourceBay.id]!,
          );
        }
      } else if (targetBay.bayType == 'Busbar' &&
          sourceBay.bayType != 'Busbar') {
        final sourceBayRenderData = currentBayRenderDataList.firstWhereOrNull(
          (d) => d.bay.id == sourceBay.id,
        );
        if (sourceBayRenderData != null &&
            busYPositions.containsKey(targetBay.id)) {
          busbarConnectionPoints.putIfAbsent(
            targetBay.id,
            () => {},
          )[sourceBay.id] = Offset(
            sourceBayRenderData.rect.center.dx,
            busYPositions[targetBay.id]!,
          );
        }
      }
    }

    double canvasWidth =
        MediaQuery.of(context).size.width * 0.6; // SLD takes 60%
    double canvasHeight = MediaQuery.of(context).size.height; // Fill height

    return Scaffold(
      appBar: AppBar(
        title: Text('Energy Account: ${widget.substationName}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today),
            onPressed: () => _selectDate(context),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Row(
              children: [
                // SLD View (Left Half)
                Expanded(
                  flex: 3, // Takes 60% of width
                  child: InteractiveViewer(
                    transformationController: _transformationController,
                    boundaryMargin: const EdgeInsets.all(double.infinity),
                    minScale: 0.1,
                    maxScale: 4.0,
                    constrained: false,
                    child: CustomPaint(
                      size: Size(canvasWidth, canvasHeight),
                      painter: SingleLineDiagramPainter(
                        bayRenderDataList: currentBayRenderDataList,
                        bayConnections: _allConnections,
                        baysMap: _baysMap,
                        createDummyBayRenderData: _createDummyBayRenderData,
                        busbarRects: busbarRects,
                        busbarConnectionPoints: busbarConnectionPoints,
                        debugDrawHitboxes: false, // Set to false for production
                        selectedBayForMovementId: null, // No movement here
                      ),
                    ),
                  ),
                ),
                // Energy Tables (Right Half)
                Expanded(
                  flex: 2, // Takes 40% of width
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Daily Energy Data for ${DateFormat('dd-MMM-yyyy').format(_selectedDate)}',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 16),
                        // Individual Bay Energy Tables
                        _bayEnergyData.isEmpty
                            ? const Center(
                                child: Text(
                                  'No energy data found for this date.',
                                ),
                              )
                            : ListView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: _bayEnergyData.length,
                                itemBuilder: (context, index) {
                                  final bayId = _bayEnergyData.keys.elementAt(
                                    index,
                                  );
                                  final data = _bayEnergyData[bayId]!;
                                  return Card(
                                    margin: const EdgeInsets.symmetric(
                                      vertical: 8.0,
                                    ),
                                    elevation: 2,
                                    child: Padding(
                                      padding: const EdgeInsets.all(12.0),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            data.bayName,
                                            style: Theme.of(context)
                                                .textTheme
                                                .titleMedium
                                                ?.copyWith(
                                                  fontWeight: FontWeight.bold,
                                                ),
                                          ),
                                          const Divider(),
                                          _buildEnergyRow(
                                            'Previous Import',
                                            data.prevImp,
                                            'MWH',
                                          ),
                                          _buildEnergyRow(
                                            'Current Import',
                                            data.currImp,
                                            'MWH',
                                          ),
                                          _buildEnergyRow(
                                            'Import Consumed',
                                            data.impConsumed,
                                            'MWH',
                                          ),
                                          const SizedBox(height: 8),
                                          _buildEnergyRow(
                                            'Previous Export',
                                            data.prevExp,
                                            'MWH',
                                          ),
                                          _buildEnergyRow(
                                            'Current Export',
                                            data.currExp,
                                            'MWH',
                                          ),
                                          _buildEnergyRow(
                                            'Export Consumed',
                                            data.expConsumed,
                                            'MWH',
                                          ),
                                          const SizedBox(height: 8),
                                          _buildEnergyRow(
                                            'Multiplying Factor',
                                            data.mf,
                                            '',
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                        const SizedBox(height: 24),
                        // Abstract Table
                        Text(
                          'Abstract of Substation',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 16),
                        Card(
                          elevation: 2,
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
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
                      ],
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
                ? Theme.of(context).textTheme.titleMedium
                : Theme.of(context).textTheme.bodyLarge,
          ),
          Text(
            value != null ? '${value.toStringAsFixed(2)} $unit' : 'N/A',
            style: isAbstract
                ? Theme.of(
                    context,
                  ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)
                : Theme.of(
                    context,
                  ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
