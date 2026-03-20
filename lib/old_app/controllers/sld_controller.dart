// lib/controllers/sld_controller.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:collection/collection.dart';
import 'dart:math' as math;
import '../models/assessment_model.dart';
import '../models/bay_model.dart';
import '../models/bay_connection_model.dart';
import '../models/energy_readings_data.dart';
import '../models/equipment_model.dart';
import '../painters/single_line_diagram_painter.dart';

class SldController extends ChangeNotifier {
  final String substationId;
  final TransformationController transformationController;

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  bool _showEnergyReadings = true;
  bool get showEnergyReadings => _showEnergyReadings;

  void setShowEnergyReadings(bool show) {
    _showEnergyReadings = show;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      notifyListeners();
    });
  }

  // Core SLD Data
  List<Bay> _allBays = [];
  Map<String, Bay> _baysMap = {};
  List<BayConnection> _allConnections = [];
  Map<String, List<EquipmentInstance>> _equipmentByBayId = {};

  // Energy Data
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

  // Layout constants
  static const double _symbolWidth = 40;
  static const double _symbolHeight = 40;
  static const double _horizontalSpacing = 120;
  static const double _verticalBusbarSpacing = 120;
  static const double _topPadding = 100;
  static const double _sidePadding = 120;
  static const double _busbarHitboxHeight = 20.0;
  static const double _lineFeederHeight = 50.0;

  SldController({
    required this.substationId,
    required this.transformationController,
  }) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_isInitialized) _initializeController();
    });
  }

  void _initializeController() {
    _isInitialized = true;
    _listenToSldData();
  }

  // Getters
  List<Bay> get allBays => _allBays;
  Map<String, Bay> get baysMap => _baysMap;
  List<BayConnection> get allConnections => _allConnections;
  Map<String, List<EquipmentInstance>> get equipmentByBayId =>
      _equipmentByBayId;

  List<BayRenderData> get bayRenderDataList => _bayRenderDataList;
  Map<String, Rect> get finalBayRects => _finalBayRects;
  Map<String, Rect> get busbarRects => _busbarRects;
  Map<String, Map<String, Offset>> get busbarConnectionPoints =>
      _busbarConnectionPoints;

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
        .listen(
          (snapshot) {
            _allBays =
                snapshot.docs.map((doc) => Bay.fromFirestore(doc)).toList();
            _baysMap = {for (var bay in _allBays) bay.id: bay};
            _safeRebuildSldRenderData();
          },
          onError: (error) => print('ERROR: Failed to load bays: $error'),
        );

    FirebaseFirestore.instance
        .collection('bay_connections')
        .where('substationId', isEqualTo: substationId)
        .snapshots()
        .listen(
          (snapshot) {
            _allConnections = snapshot.docs
                .map((doc) => BayConnection.fromFirestore(doc))
                .toList();
            _safeRebuildSldRenderData();
          },
          onError: (error) =>
              print('ERROR: Failed to load connections: $error'),
        );

    FirebaseFirestore.instance
        .collection('equipmentInstances')
        .where('substationId', isEqualTo: substationId)
        .snapshots()
        .listen(
          (snapshot) {
            _equipmentByBayId.clear();
            for (var eq in snapshot.docs
                .map((doc) => EquipmentInstance.fromFirestore(doc))) {
              _equipmentByBayId.putIfAbsent(eq.bayId, () => []).add(eq);
            }
            _safeRebuildSldRenderData();
          },
          onError: (error) => print('ERROR: Failed to load equipment: $error'),
        );
  }

  void _safeRebuildSldRenderData() {
    if (!_isInitialized) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _rebuildSldRenderData();
    });
  }

  /// Pure auto-layout: positions all bays evenly in tiers based on type.
  /// Lines (incomers) → HV Busbar → Transformers → LV Busbar → Feeders
  void _rebuildSldRenderData() {
    _finalBayRects.clear();
    _busbarRects.clear();
    _busbarConnectionPoints.clear();

    // 1. Sort busbars: highest voltage at top
    final List<Bay> busbars = _allBays
        .where((b) => b.bayType == 'Busbar')
        .toList()
      ..sort(
        (a, b) => _getVoltageLevelValue(b.voltageLevel)
            .compareTo(_getVoltageLevelValue(a.voltageLevel)),
      );

    // 2. Group connected bays by their busbar
    final Map<String, List<Bay>> linesAboveBus = {};
    final Map<String, List<Bay>> feedersBelow = {};
    final Map<String, List<Bay>> transformersByHvBus = {};

    for (final bay in _allBays) {
      if (bay.bayType == 'Transformer') {
        final hvBusId = _resolveHvBusId(bay);
        if (hvBusId != null) {
          transformersByHvBus.putIfAbsent(hvBusId, () => []).add(bay);
        }
      } else if (bay.bayType == 'Line' || bay.bayType == 'Feeder') {
        final connectedBusId = _findConnectedBusId(bay.id);
        if (connectedBusId != null) {
          if (bay.bayType == 'Line') {
            linesAboveBus.putIfAbsent(connectedBusId, () => []).add(bay);
          } else {
            feedersBelow.putIfAbsent(connectedBusId, () => []).add(bay);
          }
        }
      }
    }

    // Sort alphabetically for deterministic layout
    for (final list in [
      ...linesAboveBus.values,
      ...feedersBelow.values,
      ...transformersByHvBus.values,
    ]) {
      list.sort((a, b) => a.name.compareTo(b.name));
    }

    // 3. Compute busbar widths: wide enough to space all connected bays evenly
    final Map<String, double> busbarWidths = {};
    for (final bus in busbars) {
      final maxCount = [
        linesAboveBus[bus.id]?.length ?? 0,
        feedersBelow[bus.id]?.length ?? 0,
        transformersByHvBus[bus.id]?.length ?? 0,
      ].reduce(math.max);
      busbarWidths[bus.id] = math.max(
        (maxCount + 1) * _horizontalSpacing,
        _symbolWidth * 3,
      );
    }

    // 4. Compute busbar Y positions (space above each for its lines)
    final Map<String, double> busYPositions = {};
    double currentY = _topPadding + _lineFeederHeight + 60;
    for (int i = 0; i < busbars.length; i++) {
      busYPositions[busbars[i].id] = currentY;
      if (i < busbars.length - 1) {
        // Gap = feeders below current bus + gap + lines above next bus
        currentY +=
            _lineFeederHeight + 60 + _verticalBusbarSpacing + _lineFeederHeight + 60;
      }
    }

    // 5. Place busbars
    for (final bus in busbars) {
      final double busY = busYPositions[bus.id]!;
      final double busLen = busbarWidths[bus.id]!;
      final Rect busRect = Rect.fromCenter(
        center: Offset(_sidePadding + busLen / 2, busY),
        width: busLen,
        height: _busbarHitboxHeight,
      );
      _finalBayRects[bus.id] = busRect;
      _busbarRects[bus.id] = busRect;
    }

    // 6. Place lines above busbars (evenly spaced across busbar width)
    for (final bus in busbars) {
      final lines = linesAboveBus[bus.id] ?? [];
      if (lines.isEmpty) continue;
      final busRect = _finalBayRects[bus.id]!;
      final spacing = busRect.width / (lines.length + 1);
      for (int i = 0; i < lines.length; i++) {
        _finalBayRects[lines[i].id] = Rect.fromCenter(
          center: Offset(
            busRect.left + (i + 1) * spacing,
            busRect.top - _lineFeederHeight - 60,
          ),
          width: _symbolWidth,
          height: _lineFeederHeight,
        );
      }
    }

    // 7. Place feeders below busbars (evenly spaced across busbar width)
    for (final bus in busbars) {
      final feeders = feedersBelow[bus.id] ?? [];
      if (feeders.isEmpty) continue;
      final busRect = _finalBayRects[bus.id]!;
      final spacing = busRect.width / (feeders.length + 1);
      for (int i = 0; i < feeders.length; i++) {
        _finalBayRects[feeders[i].id] = Rect.fromCenter(
          center: Offset(
            busRect.left + (i + 1) * spacing,
            busRect.bottom + _lineFeederHeight + 60,
          ),
          width: _symbolWidth,
          height: _lineFeederHeight,
        );
      }
    }

    // 8. Place transformers between HV and LV busbars (evenly spaced)
    for (final bus in busbars) {
      final transformers = transformersByHvBus[bus.id] ?? [];
      if (transformers.isEmpty) continue;
      final busRect = _finalBayRects[bus.id];
      if (busRect == null) continue;
      final spacing = busRect.width / (transformers.length + 1);
      final double hvY = busYPositions[bus.id]!;
      for (int i = 0; i < transformers.length; i++) {
        final tf = transformers[i];
        final lvBusId = _resolveLvBusId(tf);
        final double lvY = lvBusId != null
            ? (busYPositions[lvBusId] ?? hvY + _verticalBusbarSpacing)
            : hvY + _verticalBusbarSpacing;
        _finalBayRects[tf.id] = Rect.fromCenter(
          center: Offset(
            busRect.left + (i + 1) * spacing,
            (hvY + lvY) / 2,
          ),
          width: _symbolWidth,
          height: _symbolHeight,
        );
      }
    }

    // 9. Handle remaining bay types (fallback row)
    double maxX = _sidePadding;
    for (final rect in _finalBayRects.values) {
      maxX = math.max(maxX, rect.right);
    }
    int unknownIndex = 0;
    for (final bay in _allBays) {
      if (!_finalBayRects.containsKey(bay.id)) {
        _finalBayRects[bay.id] = Rect.fromCenter(
          center: Offset(
            maxX + (unknownIndex + 1) * _horizontalSpacing,
            _topPadding + 500,
          ),
          width: _symbolWidth,
          height: _symbolHeight,
        );
        unknownIndex++;
      }
    }

    // 10. Build BayRenderData list
    final List<BayRenderData> newRenderDataList = [];
    for (final bay in _allBays) {
      final rect = _finalBayRects[bay.id];
      if (rect == null) continue;
      newRenderDataList.add(
        BayRenderData(
          bay: bay,
          rect: rect,
          center: rect.center,
          topCenter: rect.topCenter,
          bottomCenter: rect.bottomCenter,
          leftCenter: rect.centerLeft,
          rightCenter: rect.centerRight,
          equipmentInstances: _equipmentByBayId[bay.id] ?? [],
          textOffset: Offset.zero,
          busbarLength:
              _busbarRects.containsKey(bay.id) ? rect.width : 0.0,
          energyReadingOffset: Offset.zero,
          energyReadingFontSize: 9.0,
          energyReadingIsBold: false,
        ),
      );
    }

    _calculateAllConnectionPoints();
    _bayRenderDataList = newRenderDataList;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_isInitialized) notifyListeners();
    });
  }

  /// Returns the HV (higher voltage) bus ID for a transformer.
  String? _resolveHvBusId(Bay transformer) {
    if (transformer.hvBusId == null) return null;
    if (transformer.lvBusId == null) return transformer.hvBusId;
    final hvV = _getVoltageLevelValue(
      _baysMap[transformer.hvBusId]?.voltageLevel ?? '',
    );
    final lvV = _getVoltageLevelValue(
      _baysMap[transformer.lvBusId]?.voltageLevel ?? '',
    );
    return hvV >= lvV ? transformer.hvBusId : transformer.lvBusId;
  }

  /// Returns the LV (lower voltage) bus ID for a transformer.
  String? _resolveLvBusId(Bay transformer) {
    if (transformer.lvBusId == null) return null;
    if (transformer.hvBusId == null) return transformer.lvBusId;
    final hvV = _getVoltageLevelValue(
      _baysMap[transformer.hvBusId]?.voltageLevel ?? '',
    );
    final lvV = _getVoltageLevelValue(
      _baysMap[transformer.lvBusId]?.voltageLevel ?? '',
    );
    return hvV >= lvV ? transformer.lvBusId : transformer.hvBusId;
  }

  /// Finds the busbar ID connected to a given Line or Feeder bay.
  String? _findConnectedBusId(String bayId) {
    final conn = _allConnections.firstWhereOrNull(
      (c) =>
          (c.sourceBayId == bayId &&
              _baysMap[c.targetBayId]?.bayType == 'Busbar') ||
          (c.targetBayId == bayId &&
              _baysMap[c.sourceBayId]?.bayType == 'Busbar'),
    );
    if (conn == null) return null;
    return _baysMap[conn.sourceBayId]?.bayType == 'Busbar'
        ? conn.sourceBayId
        : conn.targetBayId;
  }

  void _calculateAllConnectionPoints() {
    _busbarConnectionPoints.clear();

    for (var connection in _allConnections) {
      final sourceBay = _baysMap[connection.sourceBayId];
      final targetBay = _baysMap[connection.targetBayId];
      if (sourceBay == null || targetBay == null) continue;

      const allowedTypes = ['Busbar', 'Transformer', 'Line', 'Feeder'];
      if (!allowedTypes.contains(sourceBay.bayType) ||
          !allowedTypes.contains(targetBay.bayType)) continue;

      final Rect? sourceRect = _finalBayRects[sourceBay.id];
      final Rect? targetRect = _finalBayRects[targetBay.id];
      if (sourceRect == null || targetRect == null) continue;

      Offset startPoint;
      Offset endPoint;

      if (sourceBay.bayType == 'Busbar' &&
          targetBay.bayType == 'Transformer') {
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

      _busbarConnectionPoints
          .putIfAbsent(sourceBay.id, () => {})[targetBay.id] = startPoint;
      _busbarConnectionPoints
          .putIfAbsent(targetBay.id, () => {})[sourceBay.id] = endPoint;
    }
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

  double _getVoltageLevelValue(String voltageLevel) {
    final cleaned = voltageLevel.replaceAll(RegExp(r'[^0-9.]'), '');
    return cleaned.isEmpty ? 0.0 : (double.tryParse(cleaned) ?? 0.0);
  }

  // Energy data methods
  void setBayEnergyData(String bayId, BayEnergyData energyData) {
    _bayEnergyData[bayId] = energyData;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      notifyListeners();
    });
  }

  void clearEnergyData() {
    _bayEnergyData.clear();
    _busEnergySummary.clear();
    _abstractEnergyData.clear();
    _aggregatedFeederEnergyData.clear();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      notifyListeners();
    });
  }

  void updateEnergyData({
    required Map<String, BayEnergyData> bayEnergyData,
    required Map<String, Map<String, double>> busEnergySummary,
    required Map<String, dynamic> abstractEnergyData,
    required List<AggregatedFeederEnergyData> aggregatedFeederEnergyData,
    required Map<String, Assessment> latestAssessmentsPerBay,
  }) {
    _bayEnergyData = Map.from(bayEnergyData);
    _busEnergySummary = Map.from(busEnergySummary);
    _abstractEnergyData = Map.from(abstractEnergyData);
    _aggregatedFeederEnergyData = List.from(aggregatedFeederEnergyData);
    _latestAssessmentsPerBay = Map.from(latestAssessmentsPerBay);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _isInitialized = false;
    super.dispose();
  }
}
