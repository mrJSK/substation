// lib/painters/single_line_diagram_painter.dart
import 'package:flutter/material.dart';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:collection/collection.dart'; // Import for .firstWhereOrNull
import '../models/bay_model.dart';
import '../models/bay_connection_model.dart';
import '../models/equipment_model.dart';
import '../screens/energy_sld_screen.dart'; // For BayEnergyData

// Import your custom equipment icon painters
import '../equipment_icons/transformer_icon.dart';
import '../equipment_icons/line_icon.dart';
import '../equipment_icons/feeder_icon.dart';
import '../equipment_icons/busbar_icon.dart';
import '../equipment_icons/circuit_breaker_icon.dart';
import '../equipment_icons/ct_icon.dart';
import '../equipment_icons/disconnector_icon.dart';
import '../equipment_icons/ground_icon.dart';
import '../equipment_icons/isolator_icon.dart';
import '../equipment_icons/pt_icon.dart';

class BayRenderData {
  final Bay bay; // The core Bay data
  final Rect rect; // Rendered position and size
  final Offset center;
  final Offset topCenter;
  final Offset bottomCenter;
  final Offset leftCenter;
  final Offset rightCenter;
  final List<EquipmentInstance> equipmentInstances;
  final Offset textOffset; // The calculated offset for this render
  final double busbarLength; // The calculated length for this render

  BayRenderData({
    required this.bay,
    required this.rect,
    required this.center,
    required this.topCenter,
    required this.bottomCenter,
    required this.leftCenter,
    required this.rightCenter,
    this.equipmentInstances = const [],
    required this.textOffset,
    required this.busbarLength,
  });
}

class _GenericIconPainter extends CustomPainter {
  final Color color;
  _GenericIconPainter({required this.color});
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    final double centerX = size.width / 2;
    final double centerY = size.height / 2;
    final double halfWidth = size.width / 3;
    final double halfHeight = size.height / 3;
    canvas.drawRect(
      Rect.fromCenter(
        center: Offset(centerX, centerY),
        width: halfWidth * 2,
        height: halfHeight * 2,
      ),
      paint,
    );
    canvas.drawLine(
      Offset(centerX - halfWidth, centerY - halfHeight),
      Offset(centerX + halfWidth, centerY + halfHeight),
      paint,
    );
    canvas.drawLine(
      Offset(centerX + halfWidth, centerY - halfHeight),
      Offset(centerX - halfWidth, centerY + halfHeight),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _GenericIconPainter oldDelegate) =>
      oldDelegate.color != color;
}

class SingleLineDiagramPainter extends CustomPainter {
  final List<Bay> allBays; // Raw bay data
  final List<BayConnection> bayConnections;
  final Map<String, Bay> baysMap;
  final BayRenderData Function() createDummyBayRenderData; // For orElse
  final bool debugDrawHitboxes;
  final String? selectedBayForMovementId;
  final Map<String, Offset>
  currentBayPositions; // Live positions from screen state (for overriding saved)
  final Map<String, Offset>
  currentTextOffsets; // Live text offsets from screen state (for overriding saved)
  final Map<String, double>
  currentBusbarLengths; // Live busbar lengths from screen state (for overriding saved)
  final Map<String, BayEnergyData> bayEnergyData; // From EnergySldScreen
  final Map<String, Map<String, double>>
  busEnergySummary; // From EnergySldScreen
  final Size? contentBounds; // For PDF scaling
  final Offset? originOffsetForPdf; // For PDF translation

  // Callback to return calculated Rects and render data list to the calling screen
  final Function(
    Map<String, Rect> finalBayRects,
    Map<String, Rect> busbarRects,
    Map<String, Map<String, Offset>> busbarConnectionPoints,
    List<BayRenderData> bayRenderDataList,
  )?
  onLayoutCalculated;

  // New parameter to receive persisted layout data
  final Map<String, Map<String, double>> savedBayLayoutParameters;

  SingleLineDiagramPainter({
    required this.allBays,
    required this.bayConnections,
    required this.baysMap,
    required this.createDummyBayRenderData,
    this.debugDrawHitboxes = false,
    this.selectedBayForMovementId,
    required this.currentBayPositions,
    required this.currentTextOffsets,
    required this.currentBusbarLengths,
    required this.bayEnergyData,
    required this.busEnergySummary,
    this.contentBounds,
    this.originOffsetForPdf,
    this.onLayoutCalculated,
    required this.savedBayLayoutParameters, // NEW: added this parameter
  });

  Color _getBusbarColor(String voltageLevel) {
    final double voltage =
        double.tryParse(voltageLevel.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0;

    if (voltage >= 765) {
      return Colors.red.shade700;
    } else if (voltage >= 400) {
      return Colors.orange.shade700;
    } else if (voltage >= 220) {
      return Colors.blue.shade700;
    } else if (voltage >= 132) {
      return Colors.purple.shade700;
    } else if (voltage >= 33) {
      return Colors.green.shade700;
    } else if (voltage >= 11) {
      return Colors.teal.shade700;
    } else {
      return Colors.black;
    }
  }

  CustomPainter _getSymbolPainter(String symbolKey, Color color, Size size) {
    switch (symbolKey.toLowerCase()) {
      case 'transformer':
        return TransformerIconPainter(
          color: color,
          equipmentSize: size,
          symbolSize: size,
        );
      case 'circuit breaker':
        return CircuitBreakerIconPainter(
          color: color,
          equipmentSize: size,
          symbolSize: size,
        );
      case 'current transformer':
      case 'ct':
        return CurrentTransformerIconPainter(
          color: color,
          equipmentSize: size,
          symbolSize: size,
        );
      case 'disconnector':
        return DisconnectorIconPainter(
          color: color,
          equipmentSize: size,
          symbolSize: size,
        );
      case 'ground':
        return GroundIconPainter(
          color: color,
          equipmentSize: size,
          symbolSize: size,
        );
      case 'isolator':
        return IsolatorIconPainter(
          color: color,
          equipmentSize: size,
          symbolSize: size,
        );
      case 'voltage transformer':
      case 'pt':
        return PotentialTransformerIconPainter(
          color: color,
          equipmentSize: size,
          symbolSize: size,
        );
      case 'line':
        return LineIconPainter(
          color: color,
          equipmentSize: size,
          symbolSize: size,
        );
      case 'feeder':
        return FeederIconPainter(
          color: color,
          equipmentSize: size,
          symbolSize: size,
        );
      case 'busbar':
        return BusbarIconPainter(
          color: color,
          equipmentSize: size,
          symbolSize: size,
        );
      default:
        return _GenericIconPainter(color: color);
    }
  }

  // Helper to get voltage value from string, needed for sorting and colors
  double _getVoltageLevelValue(String voltageLevel) {
    final regex = RegExp(r'(\d+(\.\d+)?)');
    final match = regex.firstMatch(voltageLevel);
    if (match != null) {
      return double.tryParse(match.group(1)!) ?? 0.0;
    }
    return 0.0;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final Map<String, Rect> finalBayRects = {};
    final Map<String, Rect> busbarRects = {};
    final Map<String, Map<String, Offset>> busbarConnectionPoints = {};
    final List<BayRenderData> renderDataList = [];

    const double symbolWidth = 60;
    const double symbolHeight = 60;
    const double horizontalSpacing = 100;
    const double verticalBusbarSpacing = 200;
    const double topPadding = 80;
    const double sidePadding = 100;
    const double busbarHitboxHeight = 50.0;
    const double lineFeederHeight = 70.0;

    final List<Bay> busbars = allBays
        .where((b) => b.bayType == 'Busbar')
        .toList();
    busbars.sort(
      (a, b) => _getVoltageLevelValue(
        b.voltageLevel,
      ).compareTo(_getVoltageLevelValue(a.voltageLevel)),
    );

    final Map<String, double> initialBusYPositions = {};
    for (int i = 0; i < busbars.length; i++) {
      initialBusYPositions[busbars[i].id] =
          topPadding + i * verticalBusbarSpacing;
    }

    // Initialize calculated positions/offsets/lengths, prioritizing live editing state, then saved state, then defaults.
    final Map<String, Offset> calculatedBayPositions = {};
    final Map<String, Offset> calculatedTextOffsets = {};
    final Map<String, double> calculatedBusbarLengths = {};

    for (var bay in allBays) {
      // Initialize bay position
      if (currentBayPositions.containsKey(bay.id)) {
        calculatedBayPositions[bay.id] = currentBayPositions[bay.id]!;
      } else if (savedBayLayoutParameters.containsKey(bay.id) &&
          savedBayLayoutParameters[bay.id]!['x'] != null &&
          savedBayLayoutParameters[bay.id]!['y'] != null) {
        calculatedBayPositions[bay.id] = Offset(
          savedBayLayoutParameters[bay.id]!['x']!,
          savedBayLayoutParameters[bay.id]!['y']!,
        );
      } else {
        // Will be set below by auto-layout if still not found
        calculatedBayPositions[bay.id] = Offset.zero; // Placeholder
      }

      // Initialize text offset
      if (currentTextOffsets.containsKey(bay.id)) {
        calculatedTextOffsets[bay.id] = currentTextOffsets[bay.id]!;
      } else if (savedBayLayoutParameters.containsKey(bay.id) &&
          savedBayLayoutParameters[bay.id]!['textOffsetDx'] != null &&
          savedBayLayoutParameters[bay.id]!['textOffsetDy'] != null) {
        calculatedTextOffsets[bay.id] = Offset(
          savedBayLayoutParameters[bay.id]!['textOffsetDx']!,
          savedBayLayoutParameters[bay.id]!['textOffsetDy']!,
        );
      } else {
        calculatedTextOffsets[bay.id] = Offset.zero; // Default
      }

      // Initialize busbar length
      if (bay.bayType == 'Busbar') {
        if (currentBusbarLengths.containsKey(bay.id)) {
          calculatedBusbarLengths[bay.id] = currentBusbarLengths[bay.id]!;
        } else if (savedBayLayoutParameters.containsKey(bay.id) &&
            savedBayLayoutParameters[bay.id]!['busbarLength'] != null) {
          calculatedBusbarLengths[bay.id] =
              savedBayLayoutParameters[bay.id]!['busbarLength']!;
        } else {
          // Will be set by auto-layout below
          calculatedBusbarLengths[bay.id] = 200.0; // Default
        }
      }
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
          }
        }
      } else if (bay.bayType != 'Busbar') {
        final connectionToBus = bayConnections.firstWhereOrNull((c) {
          final bool sourceIsBay = c.sourceBayId == bay.id;
          final bool targetIsBay = c.targetBayId == bay.id;
          final bool sourceIsBus = baysMap[c.sourceBayId]?.bayType == 'Busbar';
          final bool targetIsBus = baysMap[c.targetBayId]?.bayType == 'Busbar';
          return (sourceIsBay && targetIsBus) || (targetIsBay && sourceIsBus);
        });

        if (connectionToBus != null) {
          String connectedBusId =
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

    // Auto-layout logic (if positions not provided by currentBayPositions or savedBayLayoutParameters)
    // 1. Position Busbars (Y position fixed, X position to be determined by connected bays later)
    for (var busbar in busbars) {
      if (calculatedBayPositions[busbar.id]?.dx == 0 &&
          calculatedBayPositions[busbar.id]?.dy == 0) {
        calculatedBayPositions[busbar.id] = Offset(
          0,
          initialBusYPositions[busbar.id]!,
        );
      }
    }

    // 2. Position Transformers
    for (var busPairEntry in transformersByBusPair.entries) {
      List<String> busIdsInPair = busPairEntry.key.split('-');
      String hvBusId = busIdsInPair[0];
      String lvBusId = busIdsInPair[1];

      final double hvBusY = calculatedBayPositions[hvBusId]!.dy;
      final double lvBusY = calculatedBayPositions[lvBusId]!.dy;

      final List<Bay> transformers = busPairEntry.value.values
          .expand((list) => list)
          .toList();
      for (var tf in transformers) {
        if (!placedTransformers.contains(tf)) {
          if (calculatedBayPositions[tf.id]?.dx == 0 &&
              calculatedBayPositions[tf.id]?.dy == 0) {
            calculatedBayPositions[tf.id] = Offset(
              nextTransformerX + symbolWidth / 2,
              (hvBusY + lvBusY) / 2,
            );
          }
          nextTransformerX += horizontalSpacing;
          placedTransformers.add(tf);
          maxOverallXForCanvas = max(
            maxOverallXForCanvas,
            calculatedBayPositions[tf.id]!.dx + symbolWidth / 2,
          );
        }
      }
    }

    // 3. Position Lines and Feeders relative to busbars
    double currentLaneXForOtherBays = max(maxOverallXForCanvas, sidePadding);

    for (var busbar in busbars) {
      final double busY = calculatedBayPositions[busbar.id]!.dy;

      double currentX = currentLaneXForOtherBays;
      for (var bay in busbarToConnectedBaysAbove[busbar.id] ?? []) {
        if (calculatedBayPositions[bay.id]?.dx == 0 &&
            calculatedBayPositions[bay.id]?.dy == 0) {
          calculatedBayPositions[bay.id] = Offset(
            currentX,
            busY - lineFeederHeight - 10,
          );
        }
        currentX += horizontalSpacing;
      }
      maxOverallXForCanvas = max(maxOverallXForCanvas, currentX);

      currentX = currentLaneXForOtherBays;
      for (var bay in busbarToConnectedBaysBelow[busbar.id] ?? []) {
        if (calculatedBayPositions[bay.id]?.dx == 0 &&
            calculatedBayPositions[bay.id]?.dy == 0) {
          calculatedBayPositions[bay.id] = Offset(currentX, busY + 10);
        }
        currentX += horizontalSpacing;
      }
      maxOverallXForCanvas = max(maxOverallXForCanvas, currentX);
    }

    // 4. Finalize Busbar Lengths and X positions based on connected bays
    for (var busbar in busbars) {
      final double busY = calculatedBayPositions[busbar.id]!.dy;
      double maxConnectedBayXCoordinate = sidePadding;

      allBays.where((b) => b.bayType != 'Busbar').forEach((bay) {
        Offset? connectedBayPos = calculatedBayPositions[bay.id];
        if (connectedBayPos == null) return;

        bool isConnected = false;
        if (bay.bayType == 'Transformer') {
          if ((bay.hvBusId == busbar.id || bay.lvBusId == busbar.id)) {
            isConnected = true;
          }
        } else {
          isConnected = bayConnections.any(
            (c) =>
                (c.sourceBayId == bay.id && c.targetBayId == busbar.id) ||
                (c.targetBayId == bay.id && c.sourceBayId == busbar.id),
          );
        }

        if (isConnected) {
          maxConnectedBayXCoordinate = max(
            maxConnectedBayXCoordinate,
            connectedBayPos.dx + symbolWidth / 2,
          );
        }
      });

      final double autoCalculatedBusbarWidth = max(
        maxConnectedBayXCoordinate - sidePadding + horizontalSpacing,
        symbolWidth * 2,
      ).toDouble();

      // Prioritize currentBusbarLengths, then saved, then auto-calculated
      calculatedBusbarLengths.putIfAbsent(
        busbar.id,
        () => autoCalculatedBusbarWidth,
      );

      double finalBusbarLength = calculatedBusbarLengths[busbar.id]!;
      // Adjust busbar X position based on its final length (centered)
      final double busbarCenterX = sidePadding + finalBusbarLength / 2;
      calculatedBayPositions[busbar.id] = Offset(busbarCenterX, busY);

      busbarRects[busbar.id] = Rect.fromLTWH(
        sidePadding,
        busY,
        finalBusbarLength,
        0,
      );

      finalBayRects[busbar.id] = Rect.fromCenter(
        center: calculatedBayPositions[busbar.id]!,
        width: finalBusbarLength,
        height: busbarHitboxHeight,
      );
    }

    // 5. Build the final BayRenderData list using the calculated positions
    for (var bay in allBays) {
      if (!['Busbar', 'Transformer', 'Line', 'Feeder'].contains(bay.bayType)) {
        continue;
      }

      final Offset? finalBayPos = calculatedBayPositions[bay.id];
      if (finalBayPos == null) continue;

      Rect rect;
      if (bay.bayType == 'Busbar') {
        rect = finalBayRects[bay.id]!;
      } else {
        rect = Rect.fromLTWH(
          finalBayPos.dx - symbolWidth / 2,
          finalBayPos.dy - symbolHeight / 2,
          symbolWidth,
          symbolHeight,
        );
        finalBayRects[bay.id] = rect;
      }

      renderDataList.add(
        BayRenderData(
          bay: bay, // Pass the original bay model
          rect: rect,
          center: calculatedBayPositions[bay.id]!,
          topCenter: Offset(rect.center.dx, rect.top),
          bottomCenter: Offset(rect.center.dx, rect.bottom),
          leftCenter: Offset(rect.left, rect.center.dy),
          rightCenter: Offset(rect.right, rect.center.dy),
          equipmentInstances:
              [], // Placeholder; equip. data would be passed separately
          textOffset: calculatedTextOffsets[bay.id] ?? Offset.zero,
          busbarLength: calculatedBusbarLengths[bay.id] ?? 0.0,
        ),
      );
    }

    // 6. Calculate Busbar Connection Points
    for (var connection in bayConnections) {
      final sourceBay = baysMap[connection.sourceBayId];
      final targetBay = baysMap[connection.targetBayId];
      if (sourceBay == null || targetBay == null) continue;

      if (![
            'Busbar',
            'Transformer',
            'Line',
            'Feeder',
          ].contains(sourceBay.bayType) ||
          ![
            'Busbar',
            'Transformer',
            'Line',
            'Feeder',
          ].contains(targetBay.bayType)) {
        continue;
      }

      final Offset? sourceBayPos = calculatedBayPositions[sourceBay.id];
      final Offset? targetBayPos = calculatedBayPositions[targetBay.id];

      if (sourceBayPos == null || targetBayPos == null) continue;

      if (sourceBay.bayType == 'Busbar' && targetBay.bayType == 'Transformer') {
        busbarConnectionPoints.putIfAbsent(
          sourceBay.id,
          () => {},
        )[targetBay.id] = Offset(
          targetBayPos.dx,
          sourceBayPos.dy,
        );
      } else if (targetBay.bayType == 'Busbar' &&
          sourceBay.bayType == 'Transformer') {
        busbarConnectionPoints.putIfAbsent(
          targetBay.id,
          () => {},
        )[sourceBay.id] = Offset(
          sourceBayPos.dx,
          targetBayPos.dy,
        );
      } else if (sourceBay.bayType == 'Busbar' &&
          targetBay.bayType != 'Busbar') {
        busbarConnectionPoints.putIfAbsent(
          sourceBay.id,
          () => {},
        )[targetBay.id] = Offset(
          targetBayPos.dx,
          sourceBayPos.dy,
        );
      } else if (targetBay.bayType == 'Busbar' &&
          sourceBay.bayType != 'Busbar') {
        busbarConnectionPoints.putIfAbsent(
          targetBay.id,
          () => {},
        )[sourceBay.id] = Offset(
          sourceBayPos.dx,
          targetBayPos.dy,
        );
      }
    }

    // Call the callback to return the calculated layout data to the screen
    onLayoutCalculated?.call(
      finalBayRects,
      busbarRects,
      busbarConnectionPoints,
      renderDataList,
    );

    // --- Start Drawing ---
    double translateX = 0;
    double translateY = 0;
    double scale = 1;

    if (contentBounds != null &&
        contentBounds!.width > 0 &&
        contentBounds!.height > 0) {
      final double scaleX = size.width / contentBounds!.width;
      final double scaleY = size.height / contentBounds!.height;
      scale = min(scaleX, scaleY);

      final double scaledContentWidth = contentBounds!.width * scale;
      final double scaledContentHeight = contentBounds!.height * scale;

      translateX = (size.width - scaledContentWidth) / 2;
      translateY = (size.height - scaledContentHeight) / 2;

      canvas.save();
      canvas.translate(translateX, translateY);
      canvas.scale(scale);

      if (originOffsetForPdf != null) {
        canvas.translate(originOffsetForPdf!.dx, originOffsetForPdf!.dy);
      }
    }

    final linePaint = Paint()
      ..color = Colors.black87
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;

    final busbarPaint = Paint()
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke;

    final connectionDotPaint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.fill;

    // Draw Busbars
    for (var renderData in renderDataList) {
      if (renderData.bay.bayType == 'Busbar') {
        final busbarDrawingRect = busbarRects[renderData.bay.id];
        if (busbarDrawingRect != null) {
          busbarPaint.color = _getBusbarColor(renderData.bay.voltageLevel);

          canvas.drawLine(
            busbarDrawingRect.centerLeft,
            busbarDrawingRect.centerRight,
            busbarPaint,
          );
          _drawText(
            canvas,
            '${renderData.bay.voltageLevel} ${renderData.bay.name}',
            Offset(busbarDrawingRect.left - 8, busbarDrawingRect.center.dy) +
                renderData.textOffset,
            textAlign: TextAlign.right,
          );
        }
      }
    }

    // Draw Connections
    for (var connection in bayConnections) {
      final sourceBay = baysMap[connection.sourceBayId];
      final targetBay = baysMap[connection.targetBayId];
      if (sourceBay == null || targetBay == null) continue;

      final sourceRenderData = renderDataList.firstWhere(
        (d) => d.bay.id == sourceBay.id,
        orElse: createDummyBayRenderData,
      );
      final targetRenderData = renderDataList.firstWhere(
        (d) => d.bay.id == targetBay.id,
        orElse: createDummyBayRenderData,
      );
      if (sourceRenderData.bay.id == 'dummy' ||
          targetRenderData.bay.id == 'dummy')
        continue;

      Offset startPoint;
      Offset endPoint;

      // Use the calculated connection points
      if (sourceBay.bayType == 'Busbar' && targetBay.bayType == 'Transformer') {
        startPoint =
            busbarConnectionPoints[sourceBay.id]?[targetBay.id] ??
            sourceRenderData.center;
        endPoint = targetRenderData.topCenter;
      } else if (sourceBay.bayType == 'Transformer' &&
          targetBay.bayType == 'Busbar') {
        startPoint = sourceRenderData.bottomCenter;
        endPoint =
            busbarConnectionPoints[targetBay.id]?[sourceBay.id] ??
            targetRenderData.center;
      } else if (sourceBay.bayType == 'Busbar' &&
          targetBay.bayType != 'Busbar') {
        startPoint =
            busbarConnectionPoints[sourceBay.id]?[targetBay.id] ??
            sourceRenderData.center;
        endPoint = targetRenderData.bottomCenter;
      } else if (targetBay.bayType == 'Busbar' &&
          sourceBay.bayType != 'Busbar') {
        startPoint = sourceRenderData.topCenter;
        endPoint =
            busbarConnectionPoints[targetBay.id]?[sourceBay.id] ??
            targetRenderData.center;
      } else {
        startPoint = sourceRenderData.bottomCenter;
        endPoint = targetRenderData.topCenter;
      }

      _drawConnectionLine(
        canvas,
        startPoint,
        endPoint,
        linePaint,
        connectionDotPaint,
        sourceBay.bayType,
        targetBay.bayType,
        busbarConnectionPoints,
        connection.sourceBayId,
        connection.targetBayId,
      );
    }

    // Draw Symbols and Labels (and potentially sub-equipment)
    for (var renderData in renderDataList) {
      final bay = renderData.bay;
      final rect = renderData.rect;

      final bool isSelectedForMovement = bay.id == selectedBayForMovementId;

      if (bay.bayType == 'Transformer') {
        final painter = TransformerIconPainter(
          color: isSelectedForMovement ? Colors.green : Colors.blue,
          equipmentSize: rect.size,
          symbolSize: rect.size,
        );
        canvas.save();
        canvas.translate(rect.topLeft.dx, rect.topLeft.dy);
        painter.paint(canvas, rect.size);
        canvas.restore();

        final String transformerName = '${bay.name} T/F, \n${bay.make ?? ''}';

        final Size transformerNameSize = _measureText(
          transformerName,
          fontSize: 9,
          isBold: true,
        );

        _drawText(
          canvas,
          transformerName,
          rect.centerLeft + renderData.textOffset,
          offsetY: -transformerNameSize.height / 2 - 20,
          isBold: true,
          textAlign: TextAlign.right,
        );
      } else if (bay.bayType == 'Line') {
        final painter = LineIconPainter(
          color: isSelectedForMovement ? Colors.green : Colors.black87,
          equipmentSize: rect.size,
          symbolSize: rect.size,
        );
        canvas.save();
        canvas.translate(rect.topLeft.dx, rect.topLeft.dy);
        painter.paint(canvas, rect.size);
        canvas.restore();
        final String lineName = '${bay.voltageLevel} ${bay.name} Line';
        _drawText(
          canvas,
          lineName,
          rect.topCenter + renderData.textOffset,
          offsetY: -12,
          isBold: true,
        );
      } else if (bay.bayType == 'Feeder') {
        final painter = FeederIconPainter(
          color: isSelectedForMovement ? Colors.green : Colors.black87,
          equipmentSize: rect.size,
          symbolSize: rect.size,
        );
        canvas.save();
        canvas.translate(rect.topLeft.dx, rect.topLeft.dy);
        painter.paint(canvas, rect.size);
        canvas.restore();
        _drawText(
          canvas,
          bay.name,
          rect.bottomCenter + renderData.textOffset,
          offsetY: 4,
          isBold: true,
        );
      } else if (bay.bayType != 'Busbar') {
        canvas.drawRect(
          rect,
          Paint()
            ..color = isSelectedForMovement
                ? Colors.lightGreen.shade100
                : Colors.orange.shade100
            ..style = PaintingStyle.fill,
        );
        canvas.drawRect(
          rect,
          Paint()
            ..color = isSelectedForMovement ? Colors.green : Colors.black
            ..style = PaintingStyle.stroke
            ..strokeWidth = isSelectedForMovement ? 2.0 : 1.0,
        );
        _drawText(
          canvas,
          bay.name,
          rect.center + renderData.textOffset,
          isBold: true,
        );
      }

      if (renderData.equipmentInstances.isNotEmpty &&
          selectedBayForMovementId == null) {
        const double subIconSize = 25;
        const double subIconSpacing = 5;

        final double availableWidth = rect.width - (2 * subIconSpacing);
        final double startX = rect.left + subIconSpacing;
        double currentY =
            rect.top +
            (bay.bayType == 'Line' || bay.bayType == 'Feeder' ? 20 : 0);

        final List<EquipmentInstance> sortedEquipment =
            List.from(renderData.equipmentInstances)..sort(
              (a, b) =>
                  (a.positionIndex ?? 999).compareTo(b.positionIndex ?? 999),
            );

        for (var equipment in sortedEquipment) {
          if (currentY + subIconSize > rect.bottom) {
            break;
          }

          final Offset iconTopLeft = Offset(
            startX + (availableWidth - subIconSize) / 2,
            currentY,
          );
          final Rect subIconRect = Rect.fromLTWH(
            iconTopLeft.dx,
            iconTopLeft.dy,
            subIconSize,
            subIconSize,
          );

          final subPainter = _getSymbolPainter(
            equipment.symbolKey,
            Colors.black87,
            subIconRect.size,
          );
          canvas.save();
          canvas.translate(subIconRect.topLeft.dx, subIconRect.topLeft.dy);
          subPainter.paint(canvas, subIconRect.size);
          canvas.restore();

          _drawText(
            canvas,
            equipment.symbolKey.split(' ').first,
            subIconRect.bottomCenter,
            offsetY: 2,
            isBold: true,
            textAlign: TextAlign.center,
          );

          currentY += subIconSize + subIconSpacing;
        }
      }

      // Draw energy data beside the bay
      if (bayEnergyData.isNotEmpty) {
        if (bay.bayType == 'Busbar') {
          final Map<String, double>? busSummary = busEnergySummary[bay.id];
          if (busSummary != null) {
            final double? totalImp = busSummary['totalImp'];
            final double? totalExp = busSummary['totalExp'];

            final String importText = totalImp != null
                ? 'Imp: ${totalImp.toStringAsFixed(2)} MWH'
                : 'Imp: N/A MWH';
            final String exportText = totalExp != null
                ? 'Exp: ${totalExp.toStringAsFixed(2)} MWH'
                : 'Exp: N/A MWH';

            const double energyTextFontSize = 9.0;
            final double textHeight = energyTextFontSize + 2;

            Offset energyTextTopLeft = Offset(
              (busbarRects[bay.id]?.right ?? rect.right) -
                  80, // Use calculated busbarRect.right
              (busbarRects[bay.id]?.center.dy ?? rect.center.dy) -
                  (textHeight * 2.5),
            );

            _drawText(
              canvas,
              importText,
              energyTextTopLeft,
              textAlign: TextAlign.left,
              fontSize: energyTextFontSize,
              isBold: true,
            );
            _drawText(
              canvas,
              exportText,
              Offset(energyTextTopLeft.dx, energyTextTopLeft.dy + textHeight),
              textAlign: TextAlign.left,
              fontSize: energyTextFontSize,
              isBold: true,
            );
          }
        } else {
          final BayEnergyData? energyData = bayEnergyData[bay.id];
          if (energyData != null) {
            const double energyTextFontSize = 9.0;
            const double lineHeight = 1.2;
            const double valueOffsetFromLabel = 40;

            Offset baseTextOffset;
            TextAlign alignment = TextAlign.left;

            if (bay.bayType == 'Transformer') {
              baseTextOffset = Offset(
                rect.centerLeft.dx - 60,
                rect.center.dy - 5,
              );
            } else if (bay.bayType == 'Line') {
              baseTextOffset = Offset(rect.center.dx - 75, rect.top + 10);
            } else if (bay.bayType == 'Feeder') {
              baseTextOffset = Offset(rect.center.dx - 70, rect.bottom - 35);
            } else {
              baseTextOffset = Offset(rect.right + 15, rect.center.dy - 20);
            }

            _drawText(
              canvas,
              'Readings:',
              baseTextOffset.translate(0, 0),
              fontSize: energyTextFontSize,
              isBold: true,
              textAlign: alignment,
            );

            _drawText(
              canvas,
              'P.Imp:',
              baseTextOffset.translate(0, 1 * lineHeight * energyTextFontSize),
              fontSize: energyTextFontSize,
              textAlign: alignment,
            );
            _drawText(
              canvas,
              energyData.prevImp?.toStringAsFixed(2) ?? 'N/A',
              baseTextOffset.translate(
                valueOffsetFromLabel,
                1 * lineHeight * energyTextFontSize,
              ),
              fontSize: energyTextFontSize,
              textAlign: alignment,
            );

            _drawText(
              canvas,
              'C.Imp:',
              baseTextOffset.translate(0, 2 * lineHeight * energyTextFontSize),
              fontSize: energyTextFontSize,
              textAlign: alignment,
            );
            _drawText(
              canvas,
              energyData.currImp?.toStringAsFixed(2) ?? 'N/A',
              baseTextOffset.translate(
                valueOffsetFromLabel,
                2 * lineHeight * energyTextFontSize,
              ),
              fontSize: energyTextFontSize,
              textAlign: alignment,
            );

            _drawText(
              canvas,
              'P.Exp:',
              baseTextOffset.translate(0, 3 * lineHeight * energyTextFontSize),
              fontSize: energyTextFontSize,
              textAlign: alignment,
            );
            _drawText(
              canvas,
              energyData.prevExp?.toStringAsFixed(2) ?? 'N/A',
              baseTextOffset.translate(
                valueOffsetFromLabel,
                3 * lineHeight * energyTextFontSize,
              ),
              fontSize: energyTextFontSize,
              textAlign: alignment,
            );

            _drawText(
              canvas,
              'C.Exp:',
              baseTextOffset.translate(0, 4 * lineHeight * energyTextFontSize),
              fontSize: energyTextFontSize,
              textAlign: alignment,
            );
            _drawText(
              canvas,
              energyData.currExp?.toStringAsFixed(2) ?? 'N/A',
              baseTextOffset.translate(
                valueOffsetFromLabel,
                4 * lineHeight * energyTextFontSize,
              ),
              fontSize: energyTextFontSize,
              textAlign: alignment,
            );

            _drawText(
              canvas,
              'MF:',
              baseTextOffset.translate(0, 5 * lineHeight * energyTextFontSize),
              fontSize: energyTextFontSize,
              textAlign: alignment,
            );
            _drawText(
              canvas,
              energyData.mf?.toStringAsFixed(2) ?? 'N/A',
              baseTextOffset.translate(
                valueOffsetFromLabel,
                5 * lineHeight * energyTextFontSize,
              ),
              fontSize: energyTextFontSize,
              textAlign: alignment,
            );

            _drawText(
              canvas,
              'Imp(C):',
              baseTextOffset.translate(0, 6 * lineHeight * energyTextFontSize),
              fontSize: energyTextFontSize,
              textAlign: alignment,
              isBold: true,
            );
            _drawText(
              canvas,
              energyData.impConsumed?.toStringAsFixed(2) ?? 'N/A',
              baseTextOffset.translate(
                valueOffsetFromLabel,
                6 * lineHeight * energyTextFontSize,
              ),
              fontSize: energyTextFontSize,
              textAlign: alignment,
            );

            _drawText(
              canvas,
              'Exp(C):',
              baseTextOffset.translate(0, 7 * lineHeight * energyTextFontSize),
              fontSize: energyTextFontSize,
              textAlign: alignment,
              isBold: true,
            );
            _drawText(
              canvas,
              energyData.expConsumed?.toStringAsFixed(2) ?? 'N/A',
              baseTextOffset.translate(
                valueOffsetFromLabel,
                7 * lineHeight * energyTextFontSize,
              ),
              fontSize: energyTextFontSize,
              textAlign: alignment,
              isBold: true,
            );
          }
        }
      }
    }

    if (debugDrawHitboxes) {
      final debugHitboxPaint = Paint()
        ..color = Colors.red.withOpacity(0.3)
        ..style = PaintingStyle.fill;
      for (var renderData in renderDataList) {
        canvas.drawRect(renderData.rect, debugHitboxPaint);
      }
    }

    // NEW: Restore the canvas only if transformations were applied
    if (contentBounds != null) {
      canvas.restore();
    }
  }

  Size _measureText(String text, {double fontSize = 9, bool isBold = false}) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: Colors.black87,
          fontSize: fontSize,
          fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      maxLines: 2,
      textAlign: TextAlign.right,
      textDirection: TextDirection.ltr,
    )..layout(minWidth: 0, maxWidth: 100);
    return textPainter.size;
  }

  void _drawText(
    Canvas canvas,
    String text,
    Offset position, {
    double offsetY = 0,
    bool isBold = false,
    TextAlign textAlign = TextAlign.center,
    double fontSize = 9,
    double offsetX = 0,
  }) {
    final textStyle = TextStyle(
      color: Colors.black87,
      fontSize: fontSize,
      fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
    );
    final textSpan = TextSpan(text: text, style: textStyle);
    final textPainter = TextPainter(
      text: textSpan,
      textAlign: textAlign,
      textDirection: TextDirection.ltr,
    );
    textPainter.layout(maxWidth: 100);

    double x = position.dx + offsetX;
    if (textAlign == TextAlign.center) {
      x -= textPainter.width / 2;
    } else if (textAlign == TextAlign.right) {
      x -= textPainter.width;
    }

    textPainter.paint(canvas, Offset(x, position.dy + offsetY));
  }

  void _drawArrowhead(Canvas canvas, Offset p1, Offset p2, Paint paint) {
    const double arrowSize = 10.0;
    final double angle = atan2(p2.dy - p1.dy, p2.dx - p1.dx);
    final Path path = Path();
    path.moveTo(p2.dx, p2.dy);
    path.lineTo(
      p2.dx - arrowSize * cos(angle - pi / 6),
      p2.dy - arrowSize * sin(angle - pi / 6),
    );
    path.lineTo(
      p2.dx - arrowSize * cos(angle + pi / 6),
      p2.dy - arrowSize * sin(angle + pi / 6),
    );
    path.close();
    canvas.drawPath(
      path,
      Paint()
        ..color = paint.color
        ..style = PaintingStyle.fill,
    );
  }

  void _drawConnectionLine(
    Canvas canvas,
    Offset startPoint,
    Offset endPoint,
    Paint linePaint,
    Paint dotPaint,
    String sourceBayType,
    String targetBayType,
    Map<String, Map<String, Offset>> busbarConnectionPoints,
    String sourceBayId,
    String targetBayId,
  ) {
    canvas.drawLine(startPoint, endPoint, linePaint);

    if (sourceBayType == 'Busbar' && targetBayType != 'Busbar') {
      final busConnectionPoint =
          busbarConnectionPoints[sourceBayId]?[targetBayId];
      if (busConnectionPoint != null) {
        canvas.drawCircle(busConnectionPoint, 4.0, dotPaint);
      }
    } else if (targetBayType == 'Busbar' && sourceBayType != 'Busbar') {
      final busConnectionPoint =
          busbarConnectionPoints[targetBayId]?[sourceBayId];
      if (busConnectionPoint != null) {
        canvas.drawCircle(busConnectionPoint, 4.0, dotPaint);
      }
    }

    if ((sourceBayType == 'Busbar' && targetBayType == 'Transformer') ||
        (sourceBayType == 'Transformer' && targetBayType == 'Busbar')) {
      _drawArrowhead(canvas, startPoint, endPoint, linePaint);
    }
  }

  @override
  bool shouldRepaint(covariant SingleLineDiagramPainter oldDelegate) {
    return oldDelegate.selectedBayForMovementId != selectedBayForMovementId ||
        oldDelegate.allBays != allBays ||
        oldDelegate.bayConnections != bayConnections ||
        oldDelegate.baysMap != baysMap ||
        oldDelegate.currentBayPositions !=
            currentBayPositions || // New comparison
        oldDelegate.currentTextOffsets !=
            currentTextOffsets || // New comparison
        oldDelegate.currentBusbarLengths !=
            currentBusbarLengths || // New comparison
        oldDelegate.bayEnergyData != bayEnergyData ||
        oldDelegate.busEnergySummary != busEnergySummary ||
        oldDelegate.contentBounds !=
            contentBounds || // NEW: Repaint if contentBounds changes
        oldDelegate.originOffsetForPdf !=
            originOffsetForPdf || // NEW: Repaint if originOffsetForPdf changes
        oldDelegate.savedBayLayoutParameters !=
            savedBayLayoutParameters; // NEW: Repaint if saved layout changes
  }
}
