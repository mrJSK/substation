// lib/controllers/sld_controller.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:collection/collection.dart';
import 'dart:math';

import '../models/assessment_model.dart';
import '../models/bay_model.dart';
import '../models/bay_connection_model.dart';
import '../models/energy_readings_data.dart';
import '../models/equipment_model.dart';
import '../painters/single_line_diagram_painter.dart';
import '../screens/subdivision_dashboard_tabs/energy_sld_screen.dart';
import '../enums/movement_mode.dart';

class SldController extends ChangeNotifier {
  final String substationId;
  final TransformationController transformationController;

  // Core SLD Data
  List<Bay> _allBays = [];
  Map<String, Bay> _baysMap = {};
  List<BayConnection> _allConnections = [];
  Map<String, List<EquipmentInstance>> _equipmentByBayId = {};

  // UI State for SLD Layout
  String? _selectedBayForMovementId;
  MovementMode _movementMode = MovementMode.bay;
  Map<String, Offset> _localBayPositions = {};
  Map<String, Offset> _localTextOffsets = {};
  Map<String, double> _localBusbarLengths = {};
  Map<String, Offset> _localEnergyReadingOffsets = {};
  Map<String, double> _localEnergyReadingFontSizes = {};
  Map<String, bool> _localEnergyReadingIsBold = {};

  // Energy Data (for Energy SLD screen) - CRITICAL FIX
  Map<String, BayEnergyData> _bayEnergyData = {};
  Map<String, Map<String, double>> _busEnergySummary = {};
  Map<String, dynamic> _abstractEnergyData = {};
  List<AggregatedFeederEnergyData> _aggregatedFeederEnergyData = [];
  Map<String, Assessment> _latestAssessmentsPerBay = {};

  // Computed Render Data
  List<BayRenderData> _bayRenderDataList = [];
  Map<String, Rect> _finalBayRects = {};
  Map<String, Rect> _busbarRects = {};
  Map<String, Map<String, Offset>> _busbarConnectionPoints = {};

  // Layout Constants - RESTORED FROM OLD CODE
  static const double _symbolWidth = 40;
  static const double _symbolHeight = 40;
  static const double _horizontalSpacing = 80; // Reduced for better spacing
  static const double _verticalBusbarSpacing = 150; // Adjusted spacing
  static const double _topPadding = 60;
  static const double _sidePadding = 80;
  static const double _busbarHitboxHeight = 20.0;
  static const double _lineFeederHeight = 100.0;

  SldController({
    required this.substationId,
    required this.transformationController,
  }) {
    _listenToSldData();
  }

  // Getters
  List<Bay> get allBays => _allBays;
  Map<String, Bay> get baysMap => _baysMap;
  List<BayConnection> get allConnections => _allConnections;
  Map<String, List<EquipmentInstance>> get equipmentByBayId =>
      _equipmentByBayId;
  String? get selectedBayForMovementId => _selectedBayForMovementId;
  MovementMode get movementMode => _movementMode;
  List<BayRenderData> get bayRenderDataList => _bayRenderDataList;
  Map<String, Rect> get finalBayRects => _finalBayRects;
  Map<String, Rect> get busbarRects => _busbarRects;
  Map<String, Map<String, Offset>> get busbarConnectionPoints =>
      _busbarConnectionPoints;

  // Energy Data Getters - CRITICAL FIX
  Map<String, BayEnergyData> get bayEnergyData => _bayEnergyData;
  Map<String, Map<String, double>> get busEnergySummary => _busEnergySummary;
  Map<String, dynamic> get abstractEnergyData => _abstractEnergyData;
  List<AggregatedFeederEnergyData> get aggregatedFeederEnergyData =>
      _aggregatedFeederEnergyData;
  Map<String, Assessment> get latestAssessmentsPerBay =>
      _latestAssessmentsPerBay;

  void _listenToSldData() {
    FirebaseFirestore.instance
        .collection('bays')
        .where('substationId', isEqualTo: substationId)
        .snapshots()
        .listen((snapshot) {
          _allBays = snapshot.docs
              .map((doc) => Bay.fromFirestore(doc))
              .toList();
          _baysMap = {for (var bay in _allBays) bay.id: bay};
          _updateLocalBayPropertiesFromFirestore();
          _rebuildSldRenderData();
        });

    FirebaseFirestore.instance
        .collection('bay_connections')
        .where('substationId', isEqualTo: substationId)
        .snapshots()
        .listen((snapshot) {
          _allConnections = snapshot.docs
              .map((doc) => BayConnection.fromFirestore(doc))
              .toList();
          _rebuildSldRenderData();
        });

    FirebaseFirestore.instance
        .collection('equipmentInstances')
        .where('substationId', isEqualTo: substationId)
        .snapshots()
        .listen((snapshot) {
          _equipmentByBayId.clear();
          for (var eq in snapshot.docs.map(
            (doc) => EquipmentInstance.fromFirestore(doc),
          )) {
            _equipmentByBayId.putIfAbsent(eq.bayId, () => []).add(eq);
          }
          _rebuildSldRenderData();
        });
  }

  // RESTORED: Proper automatic busbar placement by voltage level
  void _rebuildSldRenderData() {
    List<BayRenderData> newBayRenderDataList = [];

    _finalBayRects.clear();
    _busbarRects.clear();
    _busbarConnectionPoints.clear();

    // CRITICAL FIX: Sort busbars by voltage level (highest to lowest)
    final List<Bay> busbars = _allBays
        .where((b) => b.bayType == 'Busbar')
        .toList();

    busbars.sort((a, b) {
      double getVoltage(String v) => _getVoltageLevelValue(v);
      return getVoltage(
        b.voltageLevel,
      ).compareTo(getVoltage(a.voltageLevel)); // Descending order
    });

    // AUTOMATIC BUSBAR PLACEMENT: Fixed vertical positioning
    final Map<String, double> busYPositions = {};
    double currentAutoY = _topPadding;

    for (int i = 0; i < busbars.length; i++) {
      final Bay busbar = busbars[i];
      double yPos;

      // Only use saved position if it's valid (not 0.0 and not null)
      if (_selectedBayForMovementId == busbar.id &&
          _localBayPositions.containsKey(busbar.id)) {
        yPos = _localBayPositions[busbar.id]!.dy;
      } else if (busbar.yPosition != null && busbar.yPosition! > 0.0) {
        yPos = busbar.yPosition!;
      } else {
        yPos = currentAutoY; // Use auto-calculated position
      }

      busYPositions[busbar.id] = yPos;
      currentAutoY +=
          _verticalBusbarSpacing; // Always increment for next busbar
    }

    // Calculate connections and positions for other bays
    final Map<String, List<Bay>> busbarToConnectedBaysAbove = {};
    final Map<String, List<Bay>> busbarToConnectedBaysBelow = {};
    final Map<String, List<Bay>> busbarToTransformers = {};

    for (var bay in _allBays) {
      if (bay.bayType == 'Transformer') {
        // Find connected busbars for transformers
        final connections = _allConnections
            .where((c) => c.sourceBayId == bay.id || c.targetBayId == bay.id)
            .toList();

        for (var conn in connections) {
          final connectedBayId = conn.sourceBayId == bay.id
              ? conn.targetBayId
              : conn.sourceBayId;
          final connectedBay = _baysMap[connectedBayId];

          if (connectedBay?.bayType == 'Busbar') {
            busbarToTransformers.putIfAbsent(connectedBayId, () => []).add(bay);
          }
        }
      } else if (bay.bayType == 'Line' || bay.bayType == 'Feeder') {
        // Find connected busbars for lines/feeders
        final connections = _allConnections
            .where((c) => c.sourceBayId == bay.id || c.targetBayId == bay.id)
            .toList();

        for (var conn in connections) {
          final connectedBayId = conn.sourceBayId == bay.id
              ? conn.targetBayId
              : conn.sourceBayId;
          final connectedBay = _baysMap[connectedBayId];

          if (connectedBay?.bayType == 'Busbar') {
            if (bay.bayType == 'Line') {
              busbarToConnectedBaysAbove
                  .putIfAbsent(connectedBayId, () => [])
                  .add(bay);
            } else {
              busbarToConnectedBaysBelow
                  .putIfAbsent(connectedBayId, () => [])
                  .add(bay);
            }
          }
        }
      }
    }

    // Sort connected bays for consistent layout
    busbarToConnectedBaysAbove.values.forEach(
      (list) => list.sort((a, b) => a.name.compareTo(b.name)),
    );
    busbarToConnectedBaysBelow.values.forEach(
      (list) => list.sort((a, b) => a.name.compareTo(b.name)),
    );
    busbarToTransformers.values.forEach(
      (list) => list.sort((a, b) => a.name.compareTo(b.name)),
    );

    double maxOverallX = _sidePadding;

    // Place transformers first (between busbars)
    double transformerX = _sidePadding;
    for (var busbarEntry in busbarToTransformers.entries) {
      final busbarId = busbarEntry.key;
      final transformers = busbarEntry.value;
      final busbarY = busYPositions[busbarId] ?? _topPadding;

      for (var transformer in transformers) {
        Offset position;
        if (_selectedBayForMovementId == transformer.id &&
            _localBayPositions.containsKey(transformer.id)) {
          position = _localBayPositions[transformer.id]!;
        } else if (transformer.xPosition != null &&
            transformer.yPosition != null &&
            transformer.xPosition! > 0 &&
            transformer.yPosition! > 0) {
          position = Offset(transformer.xPosition!, transformer.yPosition!);
        } else {
          position = Offset(
            transformerX + _symbolWidth / 2,
            busbarY + _verticalBusbarSpacing / 2,
          );
        }

        _localBayPositions[transformer.id] = position;
        final rect = Rect.fromCenter(
          center: position,
          width: _symbolWidth,
          height: _symbolHeight,
        );
        _finalBayRects[transformer.id] = rect;

        transformerX += _horizontalSpacing;
        maxOverallX = max(maxOverallX, rect.right);
      }
    }

    // Place busbars with proper length calculation
    for (var busbar in busbars) {
      final busbarY = busYPositions[busbar.id]!;

      // Calculate busbar length based on connected elements
      double busbarLength = _symbolWidth * 2; // Minimum length
      double maxConnectedX = _sidePadding;

      // Check all connected elements to determine busbar length
      for (var rectEntry in _finalBayRects.entries) {
        final bayId = rectEntry.key;
        final rect = rectEntry.value;
        final bay = _baysMap[bayId];

        if (bay != null && _isConnectedToBusbar(bay.id, busbar.id)) {
          maxConnectedX = max(maxConnectedX, rect.right);
        }
      }

      if (maxConnectedX > _sidePadding) {
        busbarLength = max(
          busbarLength,
          maxConnectedX - _sidePadding + _horizontalSpacing,
        );
      }

      // Use local length if manually adjusted
      if (_localBusbarLengths.containsKey(busbar.id)) {
        busbarLength = _localBusbarLengths[busbar.id]!;
      } else if (busbar.busbarLength != null &&
          busbar.busbarLength! > _symbolWidth * 2) {
        busbarLength = busbar.busbarLength!;
      }

      _localBusbarLengths[busbar.id] = busbarLength;

      double busbarX;
      if (_selectedBayForMovementId == busbar.id &&
          _localBayPositions.containsKey(busbar.id)) {
        busbarX = _localBayPositions[busbar.id]!.dx;
      } else if (busbar.xPosition != null && busbar.xPosition! > 0) {
        busbarX = busbar.xPosition!;
      } else {
        busbarX = _sidePadding + busbarLength / 2;
      }

      _localBayPositions[busbar.id] = Offset(busbarX, busbarY);

      final busbarRect = Rect.fromCenter(
        center: Offset(busbarX, busbarY),
        width: busbarLength,
        height: _busbarHitboxHeight,
      );

      _finalBayRects[busbar.id] = busbarRect;
      _busbarRects[busbar.id] = busbarRect;
      maxOverallX = max(maxOverallX, busbarRect.right);
    }

    // Place lines and feeders with automatic positioning
    for (var busbarEntry in busbarToConnectedBaysAbove.entries) {
      final busbarId = busbarEntry.key;
      final lines = busbarEntry.value;
      final busbarRect = _finalBayRects[busbarId];

      if (busbarRect != null) {
        double lineX = busbarRect.left + _symbolWidth / 2;

        for (var line in lines) {
          Offset position;
          if (_selectedBayForMovementId == line.id &&
              _localBayPositions.containsKey(line.id)) {
            position = _localBayPositions[line.id]!;
          } else if (line.xPosition != null &&
              line.yPosition != null &&
              line.xPosition! > 0 &&
              line.yPosition! > 0) {
            position = Offset(line.xPosition!, line.yPosition!);
          } else {
            position = Offset(
              lineX,
              busbarRect.center.dy - _lineFeederHeight - 30,
            );
          }

          _localBayPositions[line.id] = position;
          final rect = Rect.fromCenter(
            center: position,
            width: _symbolWidth,
            height: _lineFeederHeight,
          );
          _finalBayRects[line.id] = rect;

          lineX += _horizontalSpacing;
          maxOverallX = max(maxOverallX, rect.right);
        }
      }
    }

    for (var busbarEntry in busbarToConnectedBaysBelow.entries) {
      final busbarId = busbarEntry.key;
      final feeders = busbarEntry.value;
      final busbarRect = _finalBayRects[busbarId];

      if (busbarRect != null) {
        double feederX = busbarRect.left + _symbolWidth / 2;

        for (var feeder in feeders) {
          Offset position;
          if (_selectedBayForMovementId == feeder.id &&
              _localBayPositions.containsKey(feeder.id)) {
            position = _localBayPositions[feeder.id]!;
          } else if (feeder.xPosition != null &&
              feeder.yPosition != null &&
              feeder.xPosition! > 0 &&
              feeder.yPosition! > 0) {
            position = Offset(feeder.xPosition!, feeder.yPosition!);
          } else {
            position = Offset(
              feederX,
              busbarRect.center.dy + _lineFeederHeight + 30,
            );
          }

          _localBayPositions[feeder.id] = position;
          final rect = Rect.fromCenter(
            center: position,
            width: _symbolWidth,
            height: _lineFeederHeight,
          );
          _finalBayRects[feeder.id] = rect;

          feederX += _horizontalSpacing;
          maxOverallX = max(maxOverallX, rect.right);
        }
      }
    }

    // Build render data with energy integration
    for (var bay in _allBays) {
      final Rect? rect = _finalBayRects[bay.id];
      if (rect != null) {
        Offset textOffset =
            _localTextOffsets[bay.id] ?? bay.textOffset ?? Offset.zero;
        Offset energyOffset =
            _localEnergyReadingOffsets[bay.id] ??
            bay.energyReadingOffset ??
            Offset.zero;
        double energyFontSize =
            _localEnergyReadingFontSizes[bay.id] ??
            bay.energyReadingFontSize ??
            9.0;
        bool energyBold =
            _localEnergyReadingIsBold[bay.id] ??
            bay.energyReadingIsBold ??
            false;

        _localTextOffsets.putIfAbsent(bay.id, () => textOffset);
        _localEnergyReadingOffsets.putIfAbsent(bay.id, () => energyOffset);
        _localEnergyReadingFontSizes.putIfAbsent(bay.id, () => energyFontSize);
        _localEnergyReadingIsBold.putIfAbsent(bay.id, () => energyBold);

        newBayRenderDataList.add(
          BayRenderData(
            bay: bay,
            rect: rect,
            center: rect.center,
            topCenter: rect.topCenter,
            bottomCenter: rect.bottomCenter,
            leftCenter: rect.centerLeft,
            rightCenter: rect.centerRight,
            equipmentInstances: _equipmentByBayId[bay.id] ?? [],
            textOffset: textOffset,
            busbarLength: _localBusbarLengths[bay.id] ?? 0.0,
            energyReadingOffset: energyOffset,
            energyReadingFontSize: energyFontSize,
            energyReadingIsBold: energyBold,
          ),
        );
      }
    }

    // Calculate connection points
    _calculateConnectionPoints();

    _bayRenderDataList = newBayRenderDataList;
    notifyListeners();
  }

  // Helper methods
  double _getVoltageLevelValue(String voltageLevel) {
    final regex = RegExp(r'(\d+(\.\d+)?)');
    final match = regex.firstMatch(voltageLevel);
    return match != null ? double.tryParse(match.group(1)!) ?? 0.0 : 0.0;
  }

  bool _isConnectedToBusbar(String bayId, String busbarId) {
    return _allConnections.any(
      (c) =>
          (c.sourceBayId == bayId && c.targetBayId == busbarId) ||
          (c.targetBayId == bayId && c.sourceBayId == busbarId),
    );
  }

  void _calculateConnectionPoints() {
    for (var connection in _allConnections) {
      final sourceBay = _baysMap[connection.sourceBayId];
      final targetBay = _baysMap[connection.targetBayId];
      if (sourceBay == null || targetBay == null) continue;

      final sourceRect = _finalBayRects[sourceBay.id];
      final targetRect = _finalBayRects[targetBay.id];
      if (sourceRect == null || targetRect == null) continue;

      Offset startPoint;
      Offset endPoint;

      if (sourceBay.bayType == 'Busbar' && targetBay.bayType == 'Transformer') {
        startPoint = Offset(targetRect.center.dx, sourceRect.center.dy);
        endPoint = targetRect.topCenter;
      } else if (sourceBay.bayType == 'Transformer' &&
          targetBay.bayType == 'Busbar') {
        startPoint = sourceRect.bottomCenter;
        endPoint = Offset(sourceRect.center.dx, targetRect.center.dy);
      } else if (sourceBay.bayType == 'Busbar' && targetBay.bayType == 'Line') {
        startPoint = Offset(targetRect.center.dx, sourceRect.center.dy);
        endPoint = targetRect.bottomCenter;
      } else if (sourceBay.bayType == 'Line' && targetBay.bayType == 'Busbar') {
        startPoint = sourceRect.bottomCenter;
        endPoint = Offset(sourceRect.center.dx, targetRect.center.dy);
      } else if (sourceBay.bayType == 'Busbar' &&
          targetBay.bayType == 'Feeder') {
        startPoint = Offset(targetRect.center.dx, sourceRect.center.dy);
        endPoint = targetRect.topCenter;
      } else if (sourceBay.bayType == 'Feeder' &&
          targetBay.bayType == 'Busbar') {
        startPoint = sourceRect.topCenter;
        endPoint = Offset(sourceRect.center.dx, targetRect.center.dy);
      } else {
        startPoint = sourceRect.bottomCenter;
        endPoint = targetRect.topCenter;
      }

      _busbarConnectionPoints.putIfAbsent(
        sourceBay.id,
        () => {},
      )[targetBay.id] = startPoint;
      _busbarConnectionPoints.putIfAbsent(
        targetBay.id,
        () => {},
      )[sourceBay.id] = endPoint;
    }
  }

  // CRITICAL FIX: Energy data update method
  void updateEnergyData({
    required Map<String, BayEnergyData> bayEnergyData,
    required Map<String, Map<String, double>> busEnergySummary,
    required Map<String, dynamic> abstractEnergyData,
    required List<AggregatedFeederEnergyData> aggregatedFeederEnergyData,
    required Map<String, Assessment> latestAssessmentsPerBay,
  }) {
    _bayEnergyData = bayEnergyData;
    _busEnergySummary = busEnergySummary;
    _abstractEnergyData = abstractEnergyData;
    _aggregatedFeederEnergyData = aggregatedFeederEnergyData;
    _latestAssessmentsPerBay = latestAssessmentsPerBay;

    // Rebuild to integrate energy data
    _rebuildSldRenderData();
    notifyListeners();
  }

  // Other helper methods...
  void _updateLocalBayPropertiesFromFirestore() {
    if (_selectedBayForMovementId == null) {
      _localBayPositions.clear();
      _localTextOffsets.clear();
      _localBusbarLengths.clear();
      _localEnergyReadingOffsets.clear();
      _localEnergyReadingFontSizes.clear();
      _localEnergyReadingIsBold.clear();

      for (var bay in _allBays) {
        if (bay.xPosition != null &&
            bay.xPosition! > 0.0 &&
            bay.yPosition != null &&
            bay.yPosition! > 0.0) {
          _localBayPositions[bay.id] = Offset(bay.xPosition!, bay.yPosition!);
        }

        if (bay.textOffset != null &&
            (bay.textOffset!.dx != 0.0 || bay.textOffset!.dy != 0.0)) {
          _localTextOffsets[bay.id] = bay.textOffset!;
        }

        if (bay.bayType == 'Busbar' &&
            bay.busbarLength != null &&
            bay.busbarLength! > (_symbolWidth * 2 - 1)) {
          _localBusbarLengths[bay.id] = bay.busbarLength!;
        }

        if (bay.energyReadingOffset != null &&
            (bay.energyReadingOffset!.dx != 0.0 ||
                bay.energyReadingOffset!.dy != 0.0)) {
          _localEnergyReadingOffsets[bay.id] = bay.energyReadingOffset!;
        }

        if (bay.energyReadingFontSize != null &&
            bay.energyReadingFontSize! != 9.0) {
          _localEnergyReadingFontSizes[bay.id] = bay.energyReadingFontSize!;
        }

        if (bay.energyReadingIsBold != null) {
          _localEnergyReadingIsBold[bay.id] = bay.energyReadingIsBold!;
        }
      }
    }
  }

  // Movement and interaction methods
  void setSelectedBayForMovement(
    String? bayId, {
    MovementMode mode = MovementMode.bay,
  }) {
    _selectedBayForMovementId = bayId;
    _movementMode = mode;
    if (bayId != null) {
      final Bay? bay = _baysMap[bayId];
      if (bay != null) {
        final BayRenderData? renderData = _bayRenderDataList.firstWhereOrNull(
          (data) => data.bay.id == bayId,
        );
        Offset initialPosition = renderData?.rect.center ?? Offset.zero;

        _localBayPositions[bay.id] = initialPosition;
        _localTextOffsets[bay.id] = bay.textOffset ?? Offset.zero;
        _localBusbarLengths[bay.id] = bay.busbarLength ?? 100.0;
        _localEnergyReadingOffsets[bay.id] =
            bay.energyReadingOffset ?? Offset.zero;
        _localEnergyReadingFontSizes[bay.id] = bay.energyReadingFontSize ?? 9.0;
        _localEnergyReadingIsBold[bay.id] = bay.energyReadingIsBold ?? false;
      }
    }
    _rebuildSldRenderData();
  }

  void setMovementMode(MovementMode mode) {
    _movementMode = mode;
    notifyListeners();
  }

  void moveSelectedItem(double dx, double dy) {
    if (_selectedBayForMovementId == null) return;

    if (_movementMode == MovementMode.bay) {
      final currentOffset =
          _localBayPositions[_selectedBayForMovementId!] ?? Offset.zero;
      _localBayPositions[_selectedBayForMovementId!] = Offset(
        currentOffset.dx + dx,
        currentOffset.dy + dy,
      );
    } else if (_movementMode == MovementMode.text) {
      final currentOffset =
          _localTextOffsets[_selectedBayForMovementId!] ?? Offset.zero;
      _localTextOffsets[_selectedBayForMovementId!] = Offset(
        currentOffset.dx + dx,
        currentOffset.dy + dy,
      );
    } else if (_movementMode == MovementMode.energyText) {
      final currentOffset =
          _localEnergyReadingOffsets[_selectedBayForMovementId!] ?? Offset.zero;
      _localEnergyReadingOffsets[_selectedBayForMovementId!] = Offset(
        currentOffset.dx + dx,
        currentOffset.dy + dy,
      );
    }
    _rebuildSldRenderData();
    notifyListeners();
  }

  void adjustBusbarLength(double change) {
    if (_selectedBayForMovementId == null) return;
    final currentLength =
        _localBusbarLengths[_selectedBayForMovementId!] ?? 200.0;
    _localBusbarLengths[_selectedBayForMovementId!] = max(
      50.0,
      currentLength + change,
    );
    _rebuildSldRenderData();
    notifyListeners();
  }

  void adjustEnergyReadingFontSize(double change) {
    if (_selectedBayForMovementId == null) return;
    final currentFontSize =
        _localEnergyReadingFontSizes[_selectedBayForMovementId!] ?? 9.0;
    _localEnergyReadingFontSizes[_selectedBayForMovementId!] = max(
      5.0,
      min(20.0, currentFontSize + change),
    );
    _rebuildSldRenderData();
    notifyListeners();
  }

  void toggleEnergyReadingBold() {
    if (_selectedBayForMovementId == null) return;
    _localEnergyReadingIsBold[_selectedBayForMovementId!] =
        !(_localEnergyReadingIsBold[_selectedBayForMovementId!] ?? false);
    _rebuildSldRenderData();
    notifyListeners();
  }

  Future<bool> saveSelectedBayLayoutChanges() async {
    if (_selectedBayForMovementId == null) return false;

    final bayId = _selectedBayForMovementId!;
    try {
      final updateData = <String, dynamic>{};

      if (_localBayPositions.containsKey(bayId)) {
        updateData['xPosition'] = _localBayPositions[bayId]!.dx;
        updateData['yPosition'] = _localBayPositions[bayId]!.dy;
      }
      if (_localTextOffsets.containsKey(bayId)) {
        updateData['textOffset'] = {
          'dx': _localTextOffsets[bayId]!.dx,
          'dy': _localTextOffsets[bayId]!.dy,
        };
      }
      if (_localBusbarLengths.containsKey(bayId)) {
        updateData['busbarLength'] = _localBusbarLengths[bayId];
      }
      if (_localEnergyReadingOffsets.containsKey(bayId)) {
        updateData['energyReadingOffset'] = {
          'dx': _localEnergyReadingOffsets[bayId]!.dx,
          'dy': _localEnergyReadingOffsets[bayId]!.dy,
        };
      }
      if (_localEnergyReadingFontSizes.containsKey(bayId)) {
        updateData['energyReadingFontSize'] =
            _localEnergyReadingFontSizes[bayId];
      }
      if (_localEnergyReadingIsBold.containsKey(bayId)) {
        updateData['energyReadingIsBold'] = _localEnergyReadingIsBold[bayId];
      }

      if (updateData.isNotEmpty) {
        await FirebaseFirestore.instance
            .collection('bays')
            .doc(bayId)
            .update(updateData);

        _localBayPositions.remove(bayId);
        _localTextOffsets.remove(bayId);
        _localBusbarLengths.remove(bayId);
        _localEnergyReadingOffsets.remove(bayId);
        _localEnergyReadingFontSizes.remove(bayId);
        _localEnergyReadingIsBold.remove(bayId);

        _rebuildSldRenderData();
        notifyListeners();
        return true;
      }
    } catch (e) {
      print('Error saving layout changes: $e');
      return false;
    }
    return false;
  }

  Future<bool> saveAllPendingChanges() async {
    try {
      Set<String> affectedBayIds = {
        ..._localBayPositions.keys,
        ..._localTextOffsets.keys,
        ..._localBusbarLengths.keys,
        ..._localEnergyReadingOffsets.keys,
        ..._localEnergyReadingFontSizes.keys,
        ..._localEnergyReadingIsBold.keys,
      };

      if (affectedBayIds.isEmpty) return true;

      final batch = FirebaseFirestore.instance.batch();

      for (String bayId in affectedBayIds) {
        final updateData = <String, dynamic>{};

        if (_localBayPositions.containsKey(bayId)) {
          updateData['xPosition'] = _localBayPositions[bayId]!.dx;
          updateData['yPosition'] = _localBayPositions[bayId]!.dy;
        }

        if (_localTextOffsets.containsKey(bayId)) {
          updateData['textOffset'] = {
            'dx': _localTextOffsets[bayId]!.dx,
            'dy': _localTextOffsets[bayId]!.dy,
          };
        }

        if (_localBusbarLengths.containsKey(bayId)) {
          updateData['busbarLength'] = _localBusbarLengths[bayId];
        }

        if (_localEnergyReadingOffsets.containsKey(bayId)) {
          updateData['energyReadingOffset'] = {
            'dx': _localEnergyReadingOffsets[bayId]!.dx,
            'dy': _localEnergyReadingOffsets[bayId]!.dy,
          };
        }

        if (_localEnergyReadingFontSizes.containsKey(bayId)) {
          updateData['energyReadingFontSize'] =
              _localEnergyReadingFontSizes[bayId];
        }

        if (_localEnergyReadingIsBold.containsKey(bayId)) {
          updateData['energyReadingIsBold'] = _localEnergyReadingIsBold[bayId];
        }

        if (updateData.isNotEmpty) {
          final bayRef = FirebaseFirestore.instance
              .collection('bays')
              .doc(bayId);
          batch.update(bayRef, updateData);
        }
      }

      await batch.commit();
      _clearAllLocalAdjustments();
      _rebuildSldRenderData();
      notifyListeners();
      return true;
    } catch (e) {
      print('Error saving all pending changes: $e');
      return false;
    }
  }

  void _clearAllLocalAdjustments() {
    _localBayPositions.clear();
    _localTextOffsets.clear();
    _localBusbarLengths.clear();
    _localEnergyReadingOffsets.clear();
    _localEnergyReadingFontSizes.clear();
    _localEnergyReadingIsBold.clear();
    _selectedBayForMovementId = null;
    _movementMode = MovementMode.bay;
    _updateLocalBayPropertiesFromFirestore();
    _rebuildSldRenderData();
  }

  void cancelLayoutChanges() {
    _clearAllLocalAdjustments();
  }

  bool hasUnsavedChanges() {
    return _localBayPositions.isNotEmpty ||
        _localTextOffsets.isNotEmpty ||
        _localBusbarLengths.isNotEmpty ||
        _localEnergyReadingOffsets.isNotEmpty ||
        _localEnergyReadingFontSizes.isNotEmpty ||
        _localEnergyReadingIsBold.isNotEmpty;
  }

  BayRenderData createDummyBayRenderData() {
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
      equipmentInstances: const [],
      textOffset: Offset.zero,
      busbarLength: 0.0,
      energyReadingOffset: Offset.zero,
      energyReadingFontSize: 9.0,
      energyReadingIsBold: false,
    );
  }

  @override
  void dispose() {
    super.dispose();
  }
}
