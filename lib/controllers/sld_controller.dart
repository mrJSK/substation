// lib/controllers/sld_controller.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:collection/collection.dart'; // For firstWhereOrNull, etc.
import 'dart:math';
import '../models/assessment_model.dart';

import '../models/bay_model.dart';
import '../models/bay_connection_model.dart';
import '../models/equipment_model.dart';
import '../painters/single_line_diagram_painter.dart'; // For BayRenderData
import '../screens/subdivision_dashboard_tabs/energy_sld_screen.dart'; // For BayEnergyData (temporary, will refactor later)
import '../enums/movement_mode.dart'; // This enum might need to be moved to a shared location

class SldController extends ChangeNotifier {
  final String substationId;
  final TransformationController transformationController;

  // Core SLD Data
  List<Bay> _allBays = [];
  Map<String, Bay> _baysMap = {}; // For quick lookup
  List<BayConnection> _allConnections = [];
  Map<String, List<EquipmentInstance>> _equipmentByBayId = {};

  // UI State for SLD Layout
  String? _selectedBayForMovementId;
  MovementMode _movementMode = MovementMode.bay;
  // Local adjustments that are NOT yet saved to Firestore
  Map<String, Offset> _localBayPositions = {};
  Map<String, Offset> _localTextOffsets = {};
  Map<String, double> _localBusbarLengths = {};
  Map<String, Offset> _localEnergyReadingOffsets = {};
  Map<String, double> _localEnergyReadingFontSizes = {};
  Map<String, bool> _localEnergyReadingIsBold = {};

  // Energy Data (for Energy SLD screen)
  Map<String, BayEnergyData> _bayEnergyData = {};
  Map<String, Map<String, double>> _busEnergySummary = {};
  Map<String, dynamic> _abstractEnergyData = {};
  List<AggregatedFeederEnergyData> _aggregatedFeederEnergyData = [];
  Map<String, Assessment> _latestAssessmentsPerBay = {};

  // Computed Render Data (derived from core data + local adjustments)
  List<BayRenderData> _bayRenderDataList = [];
  Map<String, Rect> _finalBayRects = {};
  Map<String, Rect> _busbarRects = {};
  Map<String, Map<String, Offset>> _busbarConnectionPoints = {};

  // Constants for rendering/layout
  static const double _symbolWidth = 40;
  static const double _symbolHeight = 40;
  static const double _horizontalSpacing = 100;
  static const double _verticalBusbarSpacing = 200;
  static const double _topPadding = 80;
  static const double _sidePadding = 100;
  static const double _busbarHitboxHeight = 20.0;
  static const double _lineFeederHeight = 100.0;

  // Constructor
  SldController({
    required this.substationId,
    required this.transformationController,
  }) {
    _listenToSldData();
  }

  // Getters for UI to consume
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

  // Energy Data Getters
  Map<String, BayEnergyData> get bayEnergyData => _bayEnergyData;
  Map<String, Map<String, double>> get busEnergySummary => _busEnergySummary;
  Map<String, dynamic> get abstractEnergyData => _abstractEnergyData;
  List<AggregatedFeederEnergyData> get aggregatedFeederEnergyData =>
      _aggregatedFeederEnergyData;
  Map<String, Assessment> get latestAssessmentsPerBay =>
      _latestAssessmentsPerBay;

  // --- Data Loading and Listener Setup ---

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
          _updateLocalBayPropertiesFromFirestore(); // Sync local with Firestore on update
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
          _rebuildSldRenderData(); // Rebuild because equipment can affect appearance (e.g., icons)
        });
  }

  /// When Firestore data updates, sync our local maps if we are not actively moving an item.
  /// This method now intelligently skips zero/default positions from Firestore
  /// so that auto-layout can take precedence for unpositioned items.
  void _updateLocalBayPropertiesFromFirestore() {
    // Only update local properties from Firestore if no item is currently selected for manual movement.
    // If an item is selected, its local values are managed by movement functions.
    if (_selectedBayForMovementId == null) {
      _localBayPositions.clear(); // Clear existing to prevent stale data
      _localTextOffsets.clear();
      _localBusbarLengths.clear();
      _localEnergyReadingOffsets.clear();
      _localEnergyReadingFontSizes.clear();
      _localEnergyReadingIsBold.clear();

      for (var bay in _allBays) {
        // Only set local position if it's explicitly saved and not a default '0.0'
        if (bay.xPosition != null &&
            bay.xPosition! != 0.0 &&
            bay.yPosition != null &&
            bay.yPosition! != 0.0) {
          _localBayPositions[bay.id] = Offset(bay.xPosition!, bay.yPosition!);
        }

        if (bay.textOffset != null &&
            (bay.textOffset!.dx != 0.0 || bay.textOffset!.dy != 0.0)) {
          _localTextOffsets[bay.id] = bay.textOffset!;
        }

        // For busbar length, only use saved value if it's not the default minimum
        if (bay.bayType == 'Busbar' &&
            bay.busbarLength != null &&
            bay.busbarLength! > (_symbolWidth * 2 - 1)) {
          // Check against a value slightly less than default calculated min
          _localBusbarLengths[bay.id] = bay.busbarLength!;
        }

        if (bay.energyReadingOffset != null &&
            (bay.energyReadingOffset!.dx != 0.0 ||
                bay.energyReadingOffset!.dy != 0.0)) {
          _localEnergyReadingOffsets[bay.id] = bay.energyReadingOffset!;
        }
        if (bay.energyReadingFontSize != null &&
            bay.energyReadingFontSize! != 9.0) {
          // Default font size is 9.0
          _localEnergyReadingFontSizes[bay.id] = bay.energyReadingFontSize!;
        }
        if (bay.energyReadingIsBold != null) {
          // Boolean can be false default, so check if not null
          _localEnergyReadingIsBold[bay.id] = bay.energyReadingIsBold!;
        }
      }
    }
  }

  // --- SLD Layout and Rendering Logic (Moved from _buildSLDView and _buildBayRenderDataList) ---

  void _rebuildSldRenderData() {
    // IMPORTANT FIX: Create a new list instance to force painter to repaint.
    List<BayRenderData> newBayRenderDataList = [];

    _finalBayRects.clear();
    _busbarRects.clear();
    _busbarConnectionPoints.clear();

    final List<Bay> busbars = _allBays
        .where((b) => b.bayType == 'Busbar')
        .toList();

    // Sort busbars by voltage level
    busbars.sort((a, b) {
      double getV(String v) => _getVoltageLevelValue(v);
      return getV(b.voltageLevel).compareTo(getV(a.voltageLevel));
    });

    // Determine Y positions for busbars (auto-layout or use saved/local adjusted)
    final Map<String, double> busYPositions = {};
    double currentYForAutoLayout = _topPadding;
    for (int i = 0; i < busbars.length; i++) {
      final String busbarId = busbars[i].id;
      final Bay currentBusbar = busbars[i]; // Get the actual Bay object

      double yPos;
      // 1. Prioritize local unsaved changes (if bay is being dragged)
      if (_selectedBayForMovementId == busbarId &&
          _localBayPositions.containsKey(busbarId)) {
        yPos = _localBayPositions[busbarId]!.dy;
      }
      // 2. Then, use saved Firestore yPosition, ONLY IF it's not null AND not 0.0
      else if (currentBusbar.yPosition != null &&
          currentBusbar.yPosition! != 0.0) {
        yPos = currentBusbar.yPosition!;
      }
      // 3. Otherwise, use auto-calculated position
      else {
        yPos = currentYForAutoLayout;
      }

      busYPositions[busbarId] = yPos;
      currentYForAutoLayout += _verticalBusbarSpacing;
    }

    // Identify connected bays for auto-layout calculations
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
            // Feeder
            busbarToConnectedBaysBelow
                .putIfAbsent(connectedBusId, () => [])
                .add(bay);
          }
        }
      }
    }

    // Sort connected bays alphabetically for consistent layout
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

    // First pass: Calculate positions for Transformers as they connect two busbars
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
        // Ensure HV is always first for consistent keying
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
          if (_localBayPositions.containsKey(tf.id) &&
              _selectedBayForMovementId == tf.id) {
            bayPosition = _localBayPositions[tf.id]!;
          } else if (tf.xPosition != null && tf.yPosition != null) {
            bayPosition = Offset(tf.xPosition!, tf.yPosition!);
          } else {
            bayPosition = Offset(
              nextTransformerX + _symbolWidth / 2,
              (hvBusY + lvBusY) / 2,
            );
          }
          _localBayPositions.putIfAbsent(
            tf.id,
            () => bayPosition,
          ); // Ensure local map is populated

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

    // Second pass: Process busbars to determine their layout first, including connections
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
        _symbolWidth * 2, // Minimum width
      );

      final double currentBusbarLength;
      if (_localBusbarLengths.containsKey(busbar.id) &&
          _selectedBayForMovementId == busbar.id) {
        currentBusbarLength = _localBusbarLengths[busbar.id]!;
      } else if (busbar.busbarLength != null) {
        // Only use saved busbarLength if it's not the default minimum value
        if (busbar.busbarLength! > (_symbolWidth * 2 - 1)) {
          currentBusbarLength = busbar.busbarLength!;
        } else {
          currentBusbarLength = calculatedBusbarWidth;
        }
      } else {
        currentBusbarLength = calculatedBusbarWidth;
      }
      _localBusbarLengths.putIfAbsent(busbar.id, () => currentBusbarLength);

      final double busbarX;
      if (_localBayPositions.containsKey(busbar.id) &&
          _selectedBayForMovementId == busbar.id) {
        busbarX = _localBayPositions[busbar.id]!.dx;
      } else if (busbar.xPosition != null && busbar.xPosition! != 0.0) {
        // Explicitly ignore 0.0 for xPosition
        busbarX = busbar.xPosition!;
      } else {
        busbarX = _sidePadding + currentBusbarLength / 2;
      }
      _localBayPositions.putIfAbsent(busbar.id, () => Offset(busbarX, busY));

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

    // Third pass: Position Lines and Feeders
    for (var bay in _allBays) {
      if (bay.bayType == 'Line' || bay.bayType == 'Feeder') {
        if (_finalBayRects.containsKey(bay.id))
          continue; // Already placed if part of transformer group (unlikely for line/feeder)

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

            if (_localBayPositions.containsKey(bay.id) &&
                _selectedBayForMovementId == bay.id) {
              bayPosition = _localBayPositions[bay.id]!;
            } else if (bay.xPosition != null && bay.yPosition != null) {
              bayPosition = Offset(bay.xPosition!, bay.yPosition!);
            } else {
              // Auto-layout logic for lines/feeders
              double bayY;
              if (bay.bayType == 'Line') {
                bayY =
                    busbarTappableRect.center.dy -
                    _lineFeederHeight / 2 -
                    50; // Position above busbar
              } else {
                // Feeder
                bayY =
                    busbarTappableRect.center.dy +
                    _lineFeederHeight / 2 +
                    50; // Position below busbar
              }

              // Find an available X position
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
            _localBayPositions.putIfAbsent(
              bay.id,
              () => bayPosition,
            ); // Ensure local map is populated

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
        // Handle other generic bays not connected to busbars, if any
        if (_finalBayRects.containsKey(bay.id)) continue;

        Offset bayPosition;
        if (_localBayPositions.containsKey(bay.id) &&
            _selectedBayForMovementId == bay.id) {
          bayPosition = _localBayPositions[bay.id]!;
        } else if (bay.xPosition != null && bay.yPosition != null) {
          bayPosition = Offset(bay.xPosition!, bay.yPosition!);
        } else {
          bayPosition = Offset(
            maxOverallXForCanvas + _horizontalSpacing,
            _topPadding + 500,
          ); // Default fallback
        }
        _localBayPositions.putIfAbsent(bay.id, () => bayPosition);

        final newRect = Rect.fromCenter(
          center: bayPosition,
          width: _symbolWidth,
          height: _symbolHeight,
        );
        _finalBayRects[bay.id] = newRect;
        maxOverallXForCanvas = max(maxOverallXForCanvas, newRect.right);
      }
    }

    // Populate newBayRenderDataList with calculated/adjusted positions
    for (var bay in _allBays) {
      final Rect? rect = _finalBayRects[bay.id];
      if (rect != null) {
        // Use local adjustments if present, otherwise saved values
        Offset currentTextOffset =
            _localTextOffsets[bay.id] ?? bay.textOffset ?? Offset.zero;
        _localTextOffsets.putIfAbsent(
          bay.id,
          () => currentTextOffset,
        ); // Ensure populated

        Offset currentEnergyReadingOffset =
            _localEnergyReadingOffsets[bay.id] ??
            bay.energyReadingOffset ??
            Offset.zero;
        _localEnergyReadingOffsets.putIfAbsent(
          bay.id,
          () => currentEnergyReadingOffset,
        );

        double currentEnergyReadingFontSize =
            _localEnergyReadingFontSizes[bay.id] ??
            bay.energyReadingFontSize ??
            9.0;
        _localEnergyReadingFontSizes.putIfAbsent(
          bay.id,
          () => currentEnergyReadingFontSize,
        );

        bool currentEnergyReadingIsBold =
            _localEnergyReadingIsBold[bay.id] ??
            bay.energyReadingIsBold ??
            false;
        _localEnergyReadingIsBold.putIfAbsent(
          bay.id,
          () => currentEnergyReadingIsBold,
        );

        newBayRenderDataList.add(
          // Add to the new list instance
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

    // Calculate busbar connection points based on final bay positions
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

    _bayRenderDataList =
        newBayRenderDataList; // Assign the new list to the private member

    notifyListeners();
  }

  // Helper for `SingleLineDiagramPainter`
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

  // Helper for voltage level parsing
  double _getVoltageLevelValue(String voltageLevel) {
    final regex = RegExp(r'(\d+(\.\d+)?)');
    final match = regex.firstMatch(voltageLevel);
    if (match != null) {
      return double.tryParse(match.group(1)!) ?? 0.0;
    }
    return 0.0;
  }

  // --- Interaction / Movement Logic ---

  void setSelectedBayForMovement(
    String? bayId, {
    MovementMode mode = MovementMode.bay,
  }) {
    if (_selectedBayForMovementId == bayId) {
      // If already selected, maybe just change mode
      setMovementMode(mode);
    } else {
      _selectedBayForMovementId = bayId;
      _movementMode = mode;
      if (bayId != null) {
        // Initialize local adjustment maps from current rendered data or saved data
        final Bay? bay = _baysMap[bayId];
        if (bay != null) {
          // Get the current rendered position from _finalBayRects or _bayRenderDataList
          final BayRenderData? renderData = _bayRenderDataList.firstWhereOrNull(
            (data) => data.bay.id == bayId,
          );
          Offset initialPosition;
          if (renderData != null &&
              (bay.xPosition == null ||
                  bay.yPosition == null ||
                  bay.xPosition == 0.0 ||
                  bay.yPosition == 0.0)) {
            // Use the rendered position from _finalBayRects if no saved position or position is (0,0)
            initialPosition = renderData.rect.center;
          } else {
            // Use saved position from Firestore if available and non-zero
            initialPosition = Offset(bay.xPosition ?? 0, bay.yPosition ?? 0);
          }
          _localBayPositions[bay.id] = initialPosition;
          _localTextOffsets[bay.id] = bay.textOffset ?? Offset.zero;
          _localBusbarLengths[bay.id] = bay.busbarLength ?? 100.0;
          _localEnergyReadingOffsets[bay.id] =
              bay.energyReadingOffset ?? Offset.zero;
          _localEnergyReadingFontSizes[bay.id] =
              bay.energyReadingFontSize ?? 9.0;
          _localEnergyReadingIsBold[bay.id] = bay.energyReadingIsBold ?? false;
        }
      } else {
        // If unselecting, clear local adjustments to revert to saved state unless saved
        _localBayPositions.clear();
        _localTextOffsets.clear();
        _localBusbarLengths.clear();
        _localEnergyReadingOffsets.clear();
        _localEnergyReadingFontSizes.clear();
        _localEnergyReadingIsBold.clear();
      }
      _rebuildSldRenderData(); // Rebuild to reflect selection and local adjustments
    }
    notifyListeners();
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
    _rebuildSldRenderData(); // Rebuild to show movement
  }

  void adjustBusbarLength(double change) {
    if (_selectedBayForMovementId == null) return;
    final currentLength =
        _localBusbarLengths[_selectedBayForMovementId!] ?? 200.0;
    _localBusbarLengths[_selectedBayForMovementId!] = max(
      20.0,
      currentLength + change,
    );
    _rebuildSldRenderData(); // Rebuild to show length change
  }

  void adjustEnergyReadingFontSize(double change) {
    if (_selectedBayForMovementId == null) return;
    final currentFontSize =
        _localEnergyReadingFontSizes[_selectedBayForMovementId!] ?? 9.0;
    _localEnergyReadingFontSizes[_selectedBayForMovementId!] = max(
      5.0,
      min(20.0, currentFontSize + change),
    );
    _rebuildSldRenderData(); // Rebuild to show font size change
  }

  void toggleEnergyReadingBold() {
    if (_selectedBayForMovementId == null) return;
    _localEnergyReadingIsBold[_selectedBayForMovementId!] =
        !(_localEnergyReadingIsBold[_selectedBayForMovementId!] ?? false);
    _rebuildSldRenderData(); // Rebuild to show bold change
  }

  /// Saves the current local adjustments for the selected bay to Firestore.
  Future<bool> saveSelectedBayLayoutChanges() async {
    // Changed return type from Future<void> to Future<bool>
    if (_selectedBayForMovementId == null)
      return false; // Return false if no bay is selected

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
        // After saving, clear local adjustments to ensure next read picks up from Firestore
        _localBayPositions.remove(bayId);
        _localTextOffsets.remove(bayId);
        _localBusbarLengths.remove(bayId);
        _localEnergyReadingOffsets.remove(bayId);
        _localEnergyReadingFontSizes.remove(bayId);
        _localEnergyReadingIsBold.remove(bayId);
        setSelectedBayForMovement(null); // Deselect
        // _rebuildSldRenderData() will be called by Firestore listener on update
        return true; // Return true on successful save
      }
    } catch (e) {
      print('Error saving layout changes: $e');
      return false; // Return false on error
    }
    return false; // Return false if no updates were made (updateData was empty)
  }

  void cancelLayoutChanges() {
    setSelectedBayForMovement(null); // Deselect and clear local adjustments
    // _rebuildSldRenderData() will be called automatically due to _selectedBayForMovementId being null,
    // which triggers _updateLocalBayPropertiesFromFirestore to sync from the current Firestore data.
  }

  // --- Energy Data Specific Logic (to be called by Energy SLD Screen) ---

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
    notifyListeners();
  }
}
