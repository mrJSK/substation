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
import '../enums/movement_mode.dart';

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

  List<Bay> _allBays = [];
  Map<String, Bay> _baysMap = {};
  List<BayConnection> _allConnections = [];
  Map<String, List<EquipmentInstance>> _equipmentByBayId = {};

  String? _selectedBayForMovementId;
  MovementMode _movementMode = MovementMode.bay;

  Map<String, Offset> _localBayPositions = {};
  Map<String, Offset> _localTextOffsets = {};
  Map<String, double> _localBusbarLengths = {};
  Map<String, Offset> _localEnergyReadingOffsets = {};
  Map<String, double> _localEnergyReadingFontSizes = {};
  Map<String, bool> _localEnergyReadingIsBold = {};

  Map<String, Offset> _originalBayPositions = {};
  Map<String, Offset> _originalTextOffsets = {};
  Map<String, double> _originalBusbarLengths = {};
  Map<String, Offset> _originalEnergyReadingOffsets = {};
  Map<String, double> _originalEnergyReadingFontSizes = {};
  Map<String, bool> _originalEnergyReadingIsBold = {};

  Map<String, BayEnergyData> _bayEnergyData = {};
  Map<String, Map<String, double>> _busEnergySummary = {};
  Map<String, dynamic> _abstractEnergyData = {};
  List<AggregatedFeederEnergyData> _aggregatedFeederEnergyData = [];
  Map<String, Assessment> _latestAssessmentsPerBay = {};

  List<BayRenderData> _bayRenderDataList = [];
  Map<String, Rect> _finalBayRects = {};
  Map<String, Rect> _busbarRects = {};
  Map<String, Map<String, Offset>> _busbarConnectionPoints = {};

  static const double _symbolWidth = 40;
  static const double _symbolHeight = 40;
  static const double _horizontalSpacing = 100;
  static const double _verticalBusbarSpacing = 200;
  static const double _topPadding = 80;
  static const double _sidePadding = 100;
  static const double _busbarHitboxHeight = 20.0;
  static const double _lineFeederHeight = 100.0;

  SldController({
    required this.substationId,
    required this.transformationController,
  }) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_isInitialized) {
        _initializeController();
      }
    });
  }

  void _initializeController() {
    print('DEBUG: Initializing SLD Controller for substation: $substationId');
    _isInitialized = true;
    _listenToSldData();
  }

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

  Map<String, BayEnergyData> get bayEnergyData => _bayEnergyData;
  Map<String, Map<String, double>> get busEnergySummary => _busEnergySummary;
  Map<String, dynamic> get abstractEnergyData => _abstractEnergyData;
  List<AggregatedFeederEnergyData> get aggregatedFeederEnergyData =>
      _aggregatedFeederEnergyData;
  Map<String, Assessment> get latestAssessmentsPerBay =>
      _latestAssessmentsPerBay;

  bool hasUnsavedChanges() {
    return _localBayPositions.isNotEmpty ||
        _localTextOffsets.isNotEmpty ||
        _localBusbarLengths.isNotEmpty ||
        _localEnergyReadingOffsets.isNotEmpty ||
        _localEnergyReadingFontSizes.isNotEmpty ||
        _localEnergyReadingIsBold.isNotEmpty;
  }

  Future<bool> saveAllPendingChanges() async {
    if (!hasUnsavedChanges()) return true;

    try {
      print('DEBUG: Saving all pending changes to Firestore...');

      WriteBatch batch = FirebaseFirestore.instance.batch();

      Set<String> bayIdsToUpdate = {};
      bayIdsToUpdate.addAll(_localBayPositions.keys);
      bayIdsToUpdate.addAll(_localTextOffsets.keys);
      bayIdsToUpdate.addAll(_localBusbarLengths.keys);
      bayIdsToUpdate.addAll(_localEnergyReadingOffsets.keys);
      bayIdsToUpdate.addAll(_localEnergyReadingFontSizes.keys);
      bayIdsToUpdate.addAll(_localEnergyReadingIsBold.keys);

      print(
        'DEBUG: Updating ${bayIdsToUpdate.length} bays with layout changes',
      );

      for (String bayId in bayIdsToUpdate) {
        DocumentReference bayRef = FirebaseFirestore.instance
            .collection('bays')
            .doc(bayId);
        Map<String, dynamic> updateData = {};

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
          batch.update(bayRef, updateData);
        }
      }

      await batch.commit();
      print('DEBUG: Successfully saved all changes to Firestore');

      _clearAllLocalChanges();

      return true;
    } catch (e) {
      print('ERROR: Failed to save all pending changes: $e');
      return false;
    }
  }

  void cancelLayoutChanges() {
    print(
      'DEBUG: Canceling all layout changes and reverting to original values',
    );

    _clearAllLocalChanges();

    _updateLocalBayPropertiesFromFirestore();
    _safeRebuildSldRenderData();
  }

  void _clearAllLocalChanges() {
    _localBayPositions.clear();
    _localTextOffsets.clear();
    _localBusbarLengths.clear();
    _localEnergyReadingOffsets.clear();
    _localEnergyReadingFontSizes.clear();
    _localEnergyReadingIsBold.clear();

    _originalBayPositions.clear();
    _originalTextOffsets.clear();
    _originalBusbarLengths.clear();
    _originalEnergyReadingOffsets.clear();
    _originalEnergyReadingFontSizes.clear();
    _originalEnergyReadingIsBold.clear();

    _selectedBayForMovementId = null;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      notifyListeners();
    });
  }

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

  void calculateBusEnergySummaries() {
    _busEnergySummary.clear();

    final List<Bay> busbarBays = _allBays
        .where((bay) => bay.bayType == 'Busbar')
        .toList();

    for (var busbar in busbarBays) {
      double totalImp = 0.0;
      double totalExp = 0.0;
      int connectedBayCount = 0;

      final List<Bay> connectedBays = _getConnectedBays(busbar);

      for (var connectedBay in connectedBays) {
        if (connectedBay.bayType != 'Busbar') {
          final energyData = _bayEnergyData[connectedBay.id];
          if (energyData != null) {
            totalImp += energyData.adjustedImportConsumed;
            totalExp += energyData.adjustedExportConsumed;
            connectedBayCount++;
          }
        }
      }

      _busEnergySummary[busbar.id] = {
        'totalImp': totalImp,
        'totalExp': totalExp,
        'netConsumption': totalImp - totalExp,
        'connectedBayCount': connectedBayCount.toDouble(),
      };
    }

    _calculateAbstractEnergyData();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      notifyListeners();
    });
  }

  List<Bay> _getConnectedBays(Bay busbar) {
    final List<Bay> connectedBays = [];

    for (var connection in _allConnections) {
      Bay? connectedBay;

      if (connection.sourceBayId == busbar.id) {
        connectedBay = _baysMap[connection.targetBayId];
      } else if (connection.targetBayId == busbar.id) {
        connectedBay = _baysMap[connection.sourceBayId];
      }

      if (connectedBay != null && !connectedBays.contains(connectedBay)) {
        connectedBays.add(connectedBay);
      }
    }

    return connectedBays;
  }

  void _calculateAbstractEnergyData() {
    double totalImp = 0.0;
    double totalExp = 0.0;

    for (var voltageData in _busEnergySummary.values) {
      totalImp += voltageData['totalImp'] ?? 0.0;
      totalExp += voltageData['totalExp'] ?? 0.0;
    }

    final double difference = totalImp - totalExp;
    final double lossPercentage = totalImp > 0
        ? (difference / totalImp) * 100
        : 0.0;

    _abstractEnergyData = {
      'totalImp': totalImp,
      'totalExp': totalExp,
      'difference': difference,
      'lossPercentage': lossPercentage,
    };
  }

  void _listenToSldData() {
    print(
      'DEBUG: Starting to listen to SLD data for substation: $substationId',
    );

    FirebaseFirestore.instance
        .collection('bays')
        .where('substationId', isEqualTo: substationId)
        .snapshots()
        .listen(
          (snapshot) {
            print(
              'DEBUG: Received ${snapshot.docs.length} bays from Firestore',
            );

            _allBays = snapshot.docs
                .map((doc) => Bay.fromFirestore(doc))
                .toList();
            _baysMap = {for (var bay in _allBays) bay.id: bay};

            print('DEBUG: Processed ${_allBays.length} bays');

            if (!hasUnsavedChanges()) {
              _updateLocalBayPropertiesFromFirestore();
            }

            _safeRebuildSldRenderData();
          },
          onError: (error) {
            print('ERROR: Failed to load bays: $error');
          },
        );

    FirebaseFirestore.instance
        .collection('bay_connections')
        .where('substationId', isEqualTo: substationId)
        .snapshots()
        .listen(
          (snapshot) {
            print(
              'DEBUG: Received ${snapshot.docs.length} connections from Firestore',
            );

            _allConnections = snapshot.docs
                .map((doc) => BayConnection.fromFirestore(doc))
                .toList();

            _safeRebuildSldRenderData();
          },
          onError: (error) {
            print('ERROR: Failed to load connections: $error');
          },
        );

    FirebaseFirestore.instance
        .collection('equipmentInstances')
        .where('substationId', isEqualTo: substationId)
        .snapshots()
        .listen(
          (snapshot) {
            print(
              'DEBUG: Received ${snapshot.docs.length} equipment instances from Firestore',
            );

            _equipmentByBayId.clear();
            for (var eq in snapshot.docs.map(
              (doc) => EquipmentInstance.fromFirestore(doc),
            )) {
              _equipmentByBayId.putIfAbsent(eq.bayId, () => []).add(eq);
            }

            _safeRebuildSldRenderData();
          },
          onError: (error) {
            print('ERROR: Failed to load equipment: $error');
          },
        );
  }

  void _safeRebuildSldRenderData() {
    if (!_isInitialized) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _rebuildSldRenderData();
    });
  }

  Future<void> debugFirestoreData() async {
    try {
      print('DEBUG: Checking Firestore data for substationId: $substationId');

      final baysSnapshot = await FirebaseFirestore.instance
          .collection('bays')
          .where('substationId', isEqualTo: substationId)
          .get();

      print('DEBUG: Firestore query found ${baysSnapshot.docs.length} bays');

      if (baysSnapshot.docs.isEmpty) {
        print(
          'DEBUG: No bays found in Firestore for substationId: $substationId',
        );

        final allBaysSnapshot = await FirebaseFirestore.instance
            .collection('bays')
            .limit(5)
            .get();

        print('DEBUG: Total bays in database: ${allBaysSnapshot.docs.length}');
        for (var doc in allBaysSnapshot.docs) {
          final data = doc.data();
          print(
            'DEBUG: Bay substationId: ${data['substationId']}, name: ${data['name']}',
          );
        }
      } else {
        print('DEBUG: Found bays for substation:');
        for (var doc in baysSnapshot.docs.take(3)) {
          final data = doc.data();
          print('  - ${data['name']} (${data['bayType']})');
        }
      }
    } catch (e) {
      print('ERROR: Debug Firestore query failed: $e');
    }
  }

  void _updateLocalBayPropertiesFromFirestore() {
    _originalBayPositions.clear();
    _originalTextOffsets.clear();
    _originalBusbarLengths.clear();
    _originalEnergyReadingOffsets.clear();
    _originalEnergyReadingFontSizes.clear();
    _originalEnergyReadingIsBold.clear();

    for (var bay in _allBays) {
      if (bay.xPosition != null && bay.yPosition != null) {
        _originalBayPositions[bay.id] = Offset(bay.xPosition!, bay.yPosition!);
      }
      if (bay.textOffset != null) {
        _originalTextOffsets[bay.id] = bay.textOffset!;
      }
      if (bay.busbarLength != null) {
        _originalBusbarLengths[bay.id] = bay.busbarLength!;
      }
      if (bay.energyReadingOffset != null) {
        _originalEnergyReadingOffsets[bay.id] = bay.energyReadingOffset!;
      }
      if (bay.energyReadingFontSize != null) {
        _originalEnergyReadingFontSizes[bay.id] = bay.energyReadingFontSize!;
      }
      if (bay.energyReadingIsBold != null) {
        _originalEnergyReadingIsBold[bay.id] = bay.energyReadingIsBold!;
      }

      if (!_localBayPositions.containsKey(bay.id)) {
        if (bay.xPosition != null &&
            bay.xPosition! != 0.0 &&
            bay.yPosition != null &&
            bay.yPosition! != 0.0) {
          _localBayPositions[bay.id] = Offset(bay.xPosition!, bay.yPosition!);
        }
      }

      if (!_localTextOffsets.containsKey(bay.id)) {
        if (bay.textOffset != null &&
            (bay.textOffset!.dx != 0.0 || bay.textOffset!.dy != 0.0)) {
          _localTextOffsets[bay.id] = bay.textOffset!;
        }
      }

      if (!_localBusbarLengths.containsKey(bay.id)) {
        if (bay.bayType == 'Busbar' &&
            bay.busbarLength != null &&
            bay.busbarLength! > (_symbolWidth * 2 - 1)) {
          _localBusbarLengths[bay.id] = bay.busbarLength!;
        }
      }

      if (!_localEnergyReadingOffsets.containsKey(bay.id)) {
        if (bay.energyReadingOffset != null &&
            (bay.energyReadingOffset!.dx != 0.0 ||
                bay.energyReadingOffset!.dy != 0.0)) {
          _localEnergyReadingOffsets[bay.id] = bay.energyReadingOffset!;
        }
      }

      if (!_localEnergyReadingFontSizes.containsKey(bay.id)) {
        if (bay.energyReadingFontSize != null &&
            bay.energyReadingFontSize! != 9.0) {
          _localEnergyReadingFontSizes[bay.id] = bay.energyReadingFontSize!;
        }
      }

      if (!_localEnergyReadingIsBold.containsKey(bay.id)) {
        if (bay.energyReadingIsBold != null) {
          _localEnergyReadingIsBold[bay.id] = bay.energyReadingIsBold!;
        }
      }
    }
  }

  void _rebuildSldRenderData() {
    List<BayRenderData> newBayRenderDataList = [];

    _finalBayRects.clear();
    _busbarRects.clear();
    _busbarConnectionPoints.clear();

    final List<Bay> busbars = _allBays
        .where((b) => b.bayType == 'Busbar')
        .toList();

    busbars.sort((a, b) {
      double getV(String v) => _getVoltageLevelValue(v);
      return getV(b.voltageLevel).compareTo(getV(a.voltageLevel));
    });

    final Map<String, double> busYPositions = {};
    double currentYForAutoLayout = _topPadding;
    for (int i = 0; i < busbars.length; i++) {
      final String busbarId = busbars[i].id;
      final Bay currentBusbar = busbars[i];

      double yPos;
      if (_localBayPositions.containsKey(busbarId)) {
        yPos = _localBayPositions[busbarId]!.dy;
      } else if (currentBusbar.yPosition != null &&
          currentBusbar.yPosition! != 0.0) {
        yPos = currentBusbar.yPosition!;
      } else {
        yPos = currentYForAutoLayout;
      }

      busYPositions[busbarId] = yPos;
      currentYForAutoLayout += _verticalBusbarSpacing;
    }

    final Map<String, List<Bay>> busbarToConnectedBaysAbove = {};
    final Map<String, List<Bay>> busbarToConnectedBaysBelow = {};
    final Map<String, Map<String, List<Bay>>> transformersByBusPair = {};

    for (var bay in _allBays) {
      if (!['Busbar', 'Transformer', 'Line', 'Feeder'].contains(bay.bayType)) {
        continue;
      }

      if (bay.bayType == 'Transformer') {
        if (bay.hvBusId != null && bay.lvBusId != null) {
          final hvBus = _baysMap[bay.hvBusId];
          final lvBus = _baysMap[bay.lvBusId];
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
          }
        }
      } else if (bay.bayType != 'Busbar') {
        final connectionToBus = _allConnections.firstWhereOrNull((c) {
          final bool sourceIsBay = c.sourceBayId == bay.id;
          final bool targetIsBay = c.targetBayId == bay.id;
          final bool sourceIsBus = _baysMap[c.sourceBayId]?.bayType == 'Busbar';
          final bool targetIsBus = _baysMap[c.targetBayId]?.bayType == 'Busbar';
          return (sourceIsBay && targetIsBus) || (targetIsBay && sourceIsBus);
        });

        if (connectionToBus != null) {
          final String connectedBusId =
              _baysMap[connectionToBus.sourceBayId]?.bayType == 'Busbar'
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

    double maxOverallXForCanvas = _sidePadding;
    double nextTransformerX = _sidePadding;
    final List<Bay> placedTransformers = [];

    for (var busPairEntry in transformersByBusPair.entries) {
      final String pairKey = busPairEntry.key;
      final Map<String, List<Bay>> transformersForPair = busPairEntry.value;

      List<String> busIdsInPair = pairKey.split('-');
      String hvBusId = busIdsInPair[0];
      String lvBusId = busIdsInPair[1];

      if (!busYPositions.containsKey(hvBusId) ||
          !busYPositions.containsKey(lvBusId)) {
        continue;
      }

      final Bay? currentHvBus = _baysMap[hvBusId];
      final Bay? currentLvBus = _baysMap[lvBusId];

      if (currentHvBus == null || currentLvBus == null) {
        continue;
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

      final double hvBusY = busYPositions[hvBusId]!;
      final double lvBusY = busYPositions[lvBusId]!;

      final List<Bay> transformers =
          transformersForPair[hvBusId] ?? transformersForPair[lvBusId] ?? [];
      for (var tf in transformers) {
        if (!placedTransformers.contains(tf)) {
          Offset bayPosition;
          if (_localBayPositions.containsKey(tf.id)) {
            bayPosition = _localBayPositions[tf.id]!;
          } else if (tf.xPosition != null &&
              tf.yPosition != null &&
              tf.xPosition! != 0.0 &&
              tf.yPosition! != 0.0) {
            bayPosition = Offset(tf.xPosition!, tf.yPosition!);
          } else {
            bayPosition = Offset(
              nextTransformerX + _symbolWidth / 2,
              (hvBusY + lvBusY) / 2,
            );
          }

          _localBayPositions[tf.id] = bayPosition;

          final tfRect = Rect.fromCenter(
            center: bayPosition,
            width: _symbolWidth,
            height: _symbolHeight,
          );
          _finalBayRects[tf.id] = tfRect;
          nextTransformerX += _horizontalSpacing;
          placedTransformers.add(tf);
          maxOverallXForCanvas = max(maxOverallXForCanvas, tfRect.right);
        }
      }
    }

    for (var busbar in busbars) {
      final double busY = busYPositions[busbar.id]!;
      double maxConnectedBayX = _sidePadding;

      for (var bay in _allBays) {
        if (bay.id == busbar.id) continue;

        bool isConnected = false;
        if (bay.bayType == 'Transformer') {
          if (bay.hvBusId == busbar.id || bay.lvBusId == busbar.id) {
            isConnected = true;
          }
        } else {
          if (_allConnections.any(
            (c) =>
                (c.sourceBayId == bay.id && c.targetBayId == busbar.id) ||
                (c.targetBayId == bay.id && c.sourceBayId == busbar.id),
          )) {
            isConnected = true;
          }
        }

        if (isConnected && _finalBayRects.containsKey(bay.id)) {
          maxConnectedBayX = max(
            maxConnectedBayX,
            _finalBayRects[bay.id]!.right,
          );
        }
      }

      final double calculatedBusbarWidth = max(
        maxConnectedBayX - _sidePadding + _horizontalSpacing,
        _symbolWidth * 2,
      );

      final double currentBusbarLength;
      if (_localBusbarLengths.containsKey(busbar.id)) {
        currentBusbarLength = _localBusbarLengths[busbar.id]!;
      } else if (busbar.busbarLength != null &&
          busbar.busbarLength! > (_symbolWidth * 2 - 1)) {
        currentBusbarLength = busbar.busbarLength!;
      } else {
        currentBusbarLength = calculatedBusbarWidth;
      }

      _localBusbarLengths[busbar.id] = currentBusbarLength;

      final double busbarX;
      if (_localBayPositions.containsKey(busbar.id)) {
        busbarX = _localBayPositions[busbar.id]!.dx;
      } else if (busbar.xPosition != null && busbar.xPosition! != 0.0) {
        busbarX = busbar.xPosition!;
      } else {
        busbarX = _sidePadding + currentBusbarLength / 2;
      }

      _localBayPositions[busbar.id] = Offset(busbarX, busY);

      final Offset busbarCenter = Offset(busbarX, busY);
      final Rect unifiedBusbarRect = Rect.fromCenter(
        center: busbarCenter,
        width: currentBusbarLength,
        height: _busbarHitboxHeight,
      );

      _finalBayRects[busbar.id] = unifiedBusbarRect;
      _busbarRects[busbar.id] = unifiedBusbarRect;
      maxOverallXForCanvas = max(maxOverallXForCanvas, unifiedBusbarRect.right);
    }

    for (var bay in _allBays) {
      if (bay.bayType == 'Line' || bay.bayType == 'Feeder') {
        if (_finalBayRects.containsKey(bay.id)) continue;

        final connectionToBus = _allConnections.firstWhereOrNull((c) {
          return (c.sourceBayId == bay.id &&
                  _baysMap[c.targetBayId]?.bayType == 'Busbar') ||
              (c.targetBayId == bay.id &&
                  _baysMap[c.sourceBayId]?.bayType == 'Busbar');
        });

        if (connectionToBus != null) {
          String connectedBusId =
              _baysMap[connectionToBus.sourceBayId]?.bayType == 'Busbar'
              ? connectionToBus.sourceBayId
              : connectionToBus.targetBayId;

          final busbarTappableRect = _finalBayRects[connectedBusId];
          if (busbarTappableRect != null) {
            final List<Bay> baysConnectedToThisBus = [
              ...(busbarToConnectedBaysAbove[connectedBusId] ?? []),
              ...(busbarToConnectedBaysBelow[connectedBusId] ?? []),
            ];

            baysConnectedToThisBus.sort((a, b) => a.name.compareTo(b.name));

            Map<String, double> currentBayXPositionsInLane = {};
            for (var b in baysConnectedToThisBus) {
              if (_finalBayRects.containsKey(b.id)) {
                currentBayXPositionsInLane[b.id] =
                    _finalBayRects[b.id]!.center.dx;
              }
            }

            double nextX = busbarTappableRect.left + _symbolWidth / 2;
            Offset bayPosition;

            if (_localBayPositions.containsKey(bay.id)) {
              bayPosition = _localBayPositions[bay.id]!;
            } else if (bay.xPosition != null &&
                bay.yPosition != null &&
                bay.xPosition! != 0.0 &&
                bay.yPosition! != 0.0) {
              bayPosition = Offset(bay.xPosition!, bay.yPosition!);
            } else {
              double bayY;
              if (bay.bayType == 'Line') {
                bayY =
                    busbarTappableRect.center.dy - _lineFeederHeight / 2 - 50;
              } else {
                bayY =
                    busbarTappableRect.center.dy + _lineFeederHeight / 2 + 50;
              }

              double foundX = nextX;
              bool slotFound = false;
              while (!slotFound) {
                bool overlaps = false;
                for (var placedX in currentBayXPositionsInLane.values) {
                  if ((foundX - placedX).abs() <
                      (_symbolWidth + _horizontalSpacing) / 2) {
                    overlaps = true;
                    break;
                  }
                }
                if (!overlaps) {
                  slotFound = true;
                } else {
                  foundX += _horizontalSpacing;
                }
              }
              bayPosition = Offset(foundX, bayY);
            }

            _localBayPositions[bay.id] = bayPosition;

            final newRect = Rect.fromCenter(
              center: bayPosition,
              width: _symbolWidth,
              height: _lineFeederHeight,
            );
            _finalBayRects[bay.id] = newRect;
            maxOverallXForCanvas = max(maxOverallXForCanvas, newRect.right);
          }
        }
      } else if (!['Busbar', 'Transformer'].contains(bay.bayType)) {
        if (_finalBayRects.containsKey(bay.id)) continue;

        Offset bayPosition;
        if (_localBayPositions.containsKey(bay.id)) {
          bayPosition = _localBayPositions[bay.id]!;
        } else if (bay.xPosition != null &&
            bay.yPosition != null &&
            bay.xPosition! != 0.0 &&
            bay.yPosition! != 0.0) {
          bayPosition = Offset(bay.xPosition!, bay.yPosition!);
        } else {
          bayPosition = Offset(
            maxOverallXForCanvas + _horizontalSpacing,
            _topPadding + 500,
          );
        }

        _localBayPositions[bay.id] = bayPosition;

        final newRect = Rect.fromCenter(
          center: bayPosition,
          width: _symbolWidth,
          height: _symbolHeight,
        );
        _finalBayRects[bay.id] = newRect;
        maxOverallXForCanvas = max(maxOverallXForCanvas, newRect.right);
      }
    }

    for (var bay in _allBays) {
      final Rect? rect = _finalBayRects[bay.id];
      if (rect != null) {
        Offset currentTextOffset =
            _localTextOffsets[bay.id] ?? bay.textOffset ?? Offset.zero;
        Offset currentEnergyReadingOffset =
            _localEnergyReadingOffsets[bay.id] ??
            bay.energyReadingOffset ??
            Offset.zero;
        double currentEnergyReadingFontSize =
            _localEnergyReadingFontSizes[bay.id] ??
            bay.energyReadingFontSize ??
            9.0;
        bool currentEnergyReadingIsBold =
            _localEnergyReadingIsBold[bay.id] ??
            bay.energyReadingIsBold ??
            false;

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
            textOffset: currentTextOffset,
            busbarLength: _localBusbarLengths[bay.id] ?? 0.0,
            energyReadingOffset: currentEnergyReadingOffset,
            energyReadingFontSize: currentEnergyReadingFontSize,
            energyReadingIsBold: currentEnergyReadingIsBold,
          ),
        );
      }
    }

    for (var connection in _allConnections) {
      final sourceBay = _baysMap[connection.sourceBayId];
      final targetBay = _baysMap[connection.targetBayId];
      if (sourceBay == null || targetBay == null) continue;

      final List<String> allowedConnectionTypes = [
        'Busbar',
        'Transformer',
        'Line',
        'Feeder',
      ];
      if (!allowedConnectionTypes.contains(sourceBay.bayType) ||
          !allowedConnectionTypes.contains(targetBay.bayType)) {
        continue;
      }

      final Rect? sourceRect = _finalBayRects[sourceBay.id];
      final Rect? targetRect = _finalBayRects[targetBay.id];
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

    _bayRenderDataList = newBayRenderDataList;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_isInitialized) {
        notifyListeners();
      }
    });
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
    final regex = RegExp(r'(\d+(\.\d+)?)');
    final match = regex.firstMatch(voltageLevel);
    if (match != null) {
      return double.tryParse(match.group(1)!) ?? 0.0;
    }
    return 0.0;
  }

  void setSelectedBayForMovement(
    String? bayId, {
    MovementMode mode = MovementMode.bay,
  }) {
    if (_selectedBayForMovementId == bayId) {
      setMovementMode(mode);
    } else {
      _selectedBayForMovementId = bayId;
      _movementMode = mode;

      if (bayId != null) {
        final Bay? bay = _baysMap[bayId];
        if (bay != null) {
          if (!_localBayPositions.containsKey(bayId)) {
            final BayRenderData? renderData = _bayRenderDataList
                .firstWhereOrNull((data) => data.bay.id == bayId);
            if (renderData != null) {
              _localBayPositions[bay.id] = renderData.rect.center;
            } else if (bay.xPosition != null && bay.yPosition != null) {
              _localBayPositions[bay.id] = Offset(
                bay.xPosition!,
                bay.yPosition!,
              );
            }
          }

          if (!_localTextOffsets.containsKey(bayId)) {
            _localTextOffsets[bay.id] = bay.textOffset ?? Offset.zero;
          }
          if (!_localBusbarLengths.containsKey(bayId)) {
            _localBusbarLengths[bay.id] = bay.busbarLength ?? 100.0;
          }
          if (!_localEnergyReadingOffsets.containsKey(bayId)) {
            _localEnergyReadingOffsets[bay.id] =
                bay.energyReadingOffset ?? Offset.zero;
          }
          if (!_localEnergyReadingFontSizes.containsKey(bayId)) {
            _localEnergyReadingFontSizes[bay.id] =
                bay.energyReadingFontSize ?? 9.0;
          }
          if (!_localEnergyReadingIsBold.containsKey(bayId)) {
            _localEnergyReadingIsBold[bay.id] =
                bay.energyReadingIsBold ?? false;
          }
        }
      }

      _safeRebuildSldRenderData();
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      notifyListeners();
    });
  }

  void setMovementMode(MovementMode mode) {
    _movementMode = mode;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      notifyListeners();
    });
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
    _safeRebuildSldRenderData();
  }

  void adjustBusbarLength(double change) {
    if (_selectedBayForMovementId == null) return;
    final currentLength =
        _localBusbarLengths[_selectedBayForMovementId!] ?? 200.0;
    _localBusbarLengths[_selectedBayForMovementId!] = max(
      20.0,
      currentLength + change,
    );
    _safeRebuildSldRenderData();
  }

  void adjustEnergyReadingFontSize(double change) {
    if (_selectedBayForMovementId == null) return;
    final currentFontSize =
        _localEnergyReadingFontSizes[_selectedBayForMovementId!] ?? 9.0;
    _localEnergyReadingFontSizes[_selectedBayForMovementId!] = max(
      5.0,
      min(20.0, currentFontSize + change),
    );
    _safeRebuildSldRenderData();
  }

  void toggleEnergyReadingBold() {
    if (_selectedBayForMovementId == null) return;
    _localEnergyReadingIsBold[_selectedBayForMovementId!] =
        !(_localEnergyReadingIsBold[_selectedBayForMovementId!] ?? false);
    _safeRebuildSldRenderData();
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
    print('DEBUG: Disposing SLD Controller for substation: $substationId');
    _isInitialized = false;
    super.dispose();
  }
}
