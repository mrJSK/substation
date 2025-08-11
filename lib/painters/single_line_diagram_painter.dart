// lib/painters/single_line_diagram_painter.dart
import 'package:flutter/material.dart';
import 'dart:math';
import 'dart:ui' as ui;
import '../models/bay_connection_model.dart';
import '../models/bay_model.dart';
import '../models/energy_readings_data.dart';
import '../models/equipment_model.dart';

// Equipment Icons
import '../equipment_icons/transformer_icon.dart';
import '../equipment_icons/line_icon.dart';
import '../equipment_icons/feeder_icon.dart';
import '../equipment_icons/busbar_icon.dart';
import '../equipment_icons/circuit_breaker_icon.dart';
import '../equipment_icons/ct_icon.dart';
import '../equipment_icons/ground_icon.dart';
import '../equipment_icons/isolator_icon.dart';
import '../equipment_icons/pt_icon.dart';

// BayRenderData - Enhanced to work with unified model
class BayRenderData {
  final Bay bay;
  final Rect rect;
  final Offset center;
  final Offset topCenter;
  final Offset bottomCenter;
  final Offset leftCenter;
  final Offset rightCenter;
  final List<EquipmentInstance> equipmentInstances;
  final Offset textOffset;
  final double busbarLength;
  final Offset energyReadingOffset;
  final double energyReadingFontSize;
  final bool energyReadingIsBold;

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
    this.energyReadingOffset = Offset.zero,
    this.energyReadingFontSize = 9.0,
    this.energyReadingIsBold = false,
  });

  // Convenience getters for energy data access
  String get bayId => bay.id;
  String get bayName => bay.name;
  String get bayType => bay.bayType;
  String get voltageLevel => bay.voltageLevel;
}

// Add this class for equipment color scheme compatibility
class EquipmentPainter {
  static const Map<String, List<Color>> equipmentColorScheme = {
    'Transformer': [Color(0xFFD32F2F)], // Red for transformers
    'Line': [Color(0xFF1565C0)], // Blue for lines
    'Feeder': [Color(0xFF2E7D32)], // Green for feeders
    'Busbar': [Color(0xFF424242)], // Grey for busbars
  };
}

// Optimized Generic Icon Painter
class _GenericIconPainter extends CustomPainter {
  final Color color;
  final Size iconSize;

  _GenericIconPainter({required this.color, required this.iconSize});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..isAntiAlias = true;

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

    // Draw X pattern
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
      oldDelegate.color != color || oldDelegate.iconSize != iconSize;
}

class SingleLineDiagramPainter extends CustomPainter {
  final List<BayRenderData> bayRenderDataList;
  final List<BayConnection> bayConnections;
  final Map<String, Bay> baysMap;
  final BayRenderData Function() createDummyBayRenderData;
  final Map<String, Rect> busbarRects;
  final Map<String, Map<String, Offset>> busbarConnectionPoints;
  final bool debugDrawHitboxes;
  final String? selectedBayForMovementId;
  final Map<String, BayEnergyData> bayEnergyData;
  final Map<String, Map<String, double>> busEnergySummary;
  final Size? contentBounds;
  final Offset? originOffsetForPdf;
  final bool showEnergyReadings;

  // Theme colors
  final Color defaultBayColor;
  final Color defaultLineFeederColor;
  final Color transformerColor;
  final Color connectionLineColor;

  // Updated spacing constants to match controller
  static const double symbolWidth = 40;
  static const double symbolHeight = 40;
  static const double horizontalSpacing = 120;
  static const double verticalBusbarSpacing = 250;
  static const double lineFeederHeight = 100.0;
  static const double equipmentSpacing = 15.0;

  // Performance optimization: Pre-computed paint objects
  static final Paint _busbarPaint = Paint()
    ..strokeWidth = 3.0
    ..style = PaintingStyle.stroke
    ..isAntiAlias = true;

  SingleLineDiagramPainter({
    required this.bayRenderDataList,
    required this.bayConnections,
    required this.baysMap,
    this.showEnergyReadings = true,
    required this.createDummyBayRenderData,
    required this.busbarRects,
    required this.busbarConnectionPoints,
    this.debugDrawHitboxes = false,
    this.selectedBayForMovementId,
    required this.bayEnergyData,
    required this.busEnergySummary,
    this.contentBounds,
    this.originOffsetForPdf,
    required this.defaultBayColor,
    required this.defaultLineFeederColor,
    required this.transformerColor,
    required this.connectionLineColor,
  });

  // 🔥 CRITICAL FIX: Add hitTest method for gesture detection
  @override
  bool? hitTest(Offset position) {
    print('DEBUG: Hit test at position: $position');

    // Check if position hits any bay
    for (var renderData in bayRenderDataList) {
      if (renderData.rect.contains(position)) {
        print(
          'DEBUG: Hit detected for ${renderData.bay.name} (${renderData.bay.bayType})',
        );
        return true;
      }
    }

    print('DEBUG: No hit detected');
    return false; // Return false instead of null for precise control
  }

  // Optimized voltage level color mapping with caching
  static final Map<String, Color> _voltageColorCache = <String, Color>{};

  Color _getBusbarColor(String voltageLevel) {
    if (_voltageColorCache.containsKey(voltageLevel)) {
      return _voltageColorCache[voltageLevel]!;
    }

    final double voltage =
        double.tryParse(voltageLevel.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0;

    Color color;
    if (voltage >= 765) {
      color = Colors.red.shade700;
    } else if (voltage >= 400) {
      color = Colors.orange.shade700;
    } else if (voltage >= 220) {
      color = Colors.blue.shade700;
    } else if (voltage >= 132) {
      color = Colors.purple.shade700;
    } else if (voltage >= 33) {
      color = Colors.green.shade700;
    } else if (voltage >= 11) {
      color = Colors.teal.shade700;
    } else {
      color = Colors.black;
    }

    _voltageColorCache[voltageLevel] = color;
    return color;
  }

  // Enhanced symbol painter factory with error handling
  CustomPainter _getSymbolPainter(String symbolKey, Color color, Size size) {
    try {
      switch (symbolKey.toLowerCase()) {
        case 'transformer':
          return TransformerIconPainter(
            color: color,
            equipmentSize: size,
            symbolSize: size,
          );
        case 'circuit breaker':
        case 'cb':
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
        case 'isolator':
          return IsolatorIconPainter(
            color: color,
            equipmentSize: size,
            symbolSize: size,
          );
        case 'ground':
        case 'earthing':
          return GroundIconPainter(
            color: color,
            equipmentSize: size,
            symbolSize: size,
          );
        case 'voltage transformer':
        case 'potential transformer':
        case 'pt':
        case 'vt':
          return PotentialTransformerIconPainter(
            color: color,
            equipmentSize: size,
            symbolSize: size,
          );
        case 'line':
        case 'transmission line':
          return LineIconPainter(
            color: color,
            equipmentSize: size,
            symbolSize: size,
          );
        case 'feeder':
        case 'distribution feeder':
          return FeederIconPainter(
            color: color,
            equipmentSize: size,
            symbolSize: size,
          );
        case 'busbar':
        case 'bus':
          return BusbarIconPainter(
            color: color,
            equipmentSize: size,
            symbolSize: size,
          );
        default:
          return _GenericIconPainter(color: color, iconSize: size);
      }
    } catch (e) {
      print('Warning: Failed to create icon for $symbolKey, using generic: $e');
      return _GenericIconPainter(color: color, iconSize: size);
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    print('DEBUG: Painter paint method called');
    print('DEBUG: showEnergyReadings = $showEnergyReadings');
    print('DEBUG: bayEnergyData.length = ${bayEnergyData.length}');
    print('DEBUG: bayRenderDataList.length = ${bayRenderDataList.length}');

    // Save the canvas state before any transformations
    canvas.save();

    // Apply transformations for PDF generation and content bounds
    _applyCanvasTransformations(canvas, size);

    // Draw debug bounds if enabled
    if (debugDrawHitboxes) {
      _drawDebugBounds(canvas, size);
    }

    // Performance: Group drawing operations for better GPU batching
    _drawBusbars(canvas);
    _drawConnections(canvas);
    _drawBaySymbolsAndLabels(canvas);
    _drawEquipmentInstances(canvas);

    // Draw energy readings conditionally
    if (showEnergyReadings) {
      _drawEnergyReadings(canvas);
    }

    // Draw debug hitboxes last (overlay) - ENHANCED
    if (debugDrawHitboxes) {
      _drawEnhancedDebugHitboxes(canvas);
    }

    // Restore the canvas state
    canvas.restore();
  }

  void _applyCanvasTransformations(Canvas canvas, Size size) {
    if (contentBounds != null &&
        contentBounds!.width > 0 &&
        contentBounds!.height > 0) {
      final double scaleX = size.width / contentBounds!.width;
      final double scaleY = size.height / contentBounds!.height;
      final double fitScale = min(scaleX, scaleY);

      final double scaledContentWidth = contentBounds!.width * fitScale;
      final double scaledContentHeight = contentBounds!.height * fitScale;

      final double translateX = (size.width - scaledContentWidth) / 2;
      final double translateY = (size.height - scaledContentHeight) / 2;

      canvas.translate(translateX, translateY);
      canvas.scale(fitScale);

      if (originOffsetForPdf != null) {
        canvas.translate(originOffsetForPdf!.dx, originOffsetForPdf!.dy);
      }
    }
  }

  void _drawDebugBounds(Canvas canvas, Size size) {
    if (contentBounds == null) return;

    final boundsPaint = Paint()
      ..color = Colors.blue.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;

    canvas.drawRect(
      Rect.fromLTWH(0, 0, contentBounds!.width, contentBounds!.height),
      boundsPaint,
    );

    final widgetBoundsPaint = Paint()
      ..color = Colors.orange.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;

    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      widgetBoundsPaint,
    );
  }

  void _drawBusbars(Canvas canvas) {
    for (var renderData in bayRenderDataList) {
      if (renderData.bayType != 'Busbar') continue;

      final busbarRect = renderData.rect;
      _busbarPaint.color = _getBusbarColor(renderData.voltageLevel);

      // Draw busbar line with proper length
      final busbarLength = renderData.busbarLength > 0
          ? renderData.busbarLength
          : busbarRect.width;

      final busbarStart = Offset(
        busbarRect.center.dx - busbarLength / 2,
        busbarRect.center.dy,
      );
      final busbarEnd = Offset(
        busbarRect.center.dx + busbarLength / 2,
        busbarRect.center.dy,
      );

      canvas.drawLine(busbarStart, busbarEnd, _busbarPaint);

      // Draw busbar label with voltage-based positioning
      _drawText(
        canvas,
        '${renderData.voltageLevel} ${renderData.bayName}',
        Offset(busbarStart.dx - 8, busbarRect.center.dy) +
            renderData.textOffset,
        textAlign: TextAlign.right,
        textColor: _getBusbarColor(renderData.voltageLevel),
        isBold: true,
      );
    }
  }

  // NEW: Draw equipment instances for each bay
  void _drawEquipmentInstances(Canvas canvas) {
    for (var renderData in bayRenderDataList) {
      if (renderData.equipmentInstances.isEmpty) continue;

      _drawBayEquipment(canvas, renderData);
    }
  }

  // UPDATED: Equipment instance colors to match parent bay
  void _drawBayEquipment(Canvas canvas, BayRenderData renderData) {
    final equipmentList = renderData.equipmentInstances;
    if (equipmentList.isEmpty) return;

    final equipmentSize = Size(20, 20);
    // Use the same color as the parent bay for consistency
    final equipmentColor = _getEquipmentDisplayColor(
      renderData.bayId,
      renderData.bayType,
    );

    for (int i = 0; i < equipmentList.length; i++) {
      final equipment = equipmentList[i];

      Offset equipmentPosition = _calculateEquipmentPosition(
        renderData,
        i,
        equipmentList.length,
        equipmentSize,
      );

      canvas.save();
      canvas.translate(equipmentPosition.dx, equipmentPosition.dy);

      final equipmentPainter = _getSymbolPainter(
        equipment.symbolKey,
        equipmentColor.withOpacity(0.7), // Use consistent color
        equipmentSize,
      );

      equipmentPainter.paint(canvas, equipmentSize);
      canvas.restore();

      _drawText(
        canvas,
        equipment.equipmentTypeName,
        equipmentPosition.translate(0, equipmentSize.height + 2),
        fontSize: 7,
        textAlign: TextAlign.center,
        textColor: equipmentColor.withOpacity(0.8), // Consistent text color
      );
    }
  }

  Offset _calculateEquipmentPosition(
    BayRenderData renderData,
    int index,
    int totalEquipment,
    Size equipmentSize,
  ) {
    final bayRect = renderData.rect;

    switch (renderData.bayType) {
      case 'Transformer':
        return Offset(
          bayRect.right + 10,
          bayRect.top + (index * (equipmentSize.height + equipmentSpacing)),
        );
      case 'Line':
        return Offset(
          bayRect.left + (index * (equipmentSize.width + equipmentSpacing)),
          bayRect.top - equipmentSize.height - 5,
        );
      case 'Feeder':
        return Offset(
          bayRect.left + (index * (equipmentSize.width + equipmentSpacing)),
          bayRect.bottom + 5,
        );
      default:
        return Offset(
          bayRect.right + 5,
          bayRect.center.dy +
              (index * equipmentSpacing) -
              (totalEquipment * equipmentSpacing / 2),
        );
    }
  }

  void _drawConnections(Canvas canvas) {
    for (var connection in bayConnections) {
      final sourceBay = baysMap[connection.sourceBayId];
      final targetBay = baysMap[connection.targetBayId];
      if (sourceBay == null || targetBay == null) continue;

      final sourceRenderData = _findRenderData(sourceBay.id);
      final targetRenderData = _findRenderData(targetBay.id);
      if (sourceRenderData == null || targetRenderData == null) continue;

      final connectionPoints = _calculateConnectionPoints(
        sourceBay,
        targetBay,
        sourceRenderData,
        targetRenderData,
      );

      _drawConnectionLine(
        canvas,
        connectionPoints.start,
        connectionPoints.end,
        sourceBay.bayType,
        targetBay.bayType,
        connection.sourceBayId,
        connection.targetBayId,
      );
    }
  }

  void _drawBaySymbolsAndLabels(Canvas canvas) {
    for (var renderData in bayRenderDataList) {
      if (renderData.bayType == 'Busbar') continue;

      final bool isSelectedForMovement =
          renderData.bayId == selectedBayForMovementId;

      _drawBaySymbol(canvas, renderData, isSelectedForMovement);
      _drawBayLabel(canvas, renderData, isSelectedForMovement);
    }
  }

  // NEW: Method to get consistent equipment display colors
  Color _getEquipmentDisplayColor(String bayId, String bayType) {
    // For equipment connected to busbars, use busbar colors
    final connectedBusbar = _findConnectedBusbar(bayId);
    if (connectedBusbar != null) {
      return _getBusbarColor(connectedBusbar.voltageLevel);
    }

    // Fallback to equipment-specific colors
    switch (bayType) {
      case 'Transformer':
        return const Color(0xFFD32F2F); // Red for transformers
      case 'Line':
        return const Color(0xFF1565C0); // Blue for lines
      case 'Feeder':
        return const Color(0xFF2E7D32); // Green for feeders
      default:
        return defaultBayColor;
    }
  }

  // NEW: Helper method to find connected busbar
  Bay? _findConnectedBusbar(String bayId) {
    for (var connection in bayConnections) {
      if (connection.sourceBayId == bayId) {
        final targetBay = baysMap[connection.targetBayId];
        if (targetBay?.bayType == 'Busbar') {
          return targetBay;
        }
      } else if (connection.targetBayId == bayId) {
        final sourceBay = baysMap[connection.sourceBayId];
        if (sourceBay?.bayType == 'Busbar') {
          return sourceBay;
        }
      }
    }
    return null;
  }

  void _drawBaySymbol(
    Canvas canvas,
    BayRenderData renderData,
    bool isSelected,
  ) {
    final rect = renderData.rect;
    final bayType = renderData.bayType;

    Color color;
    if (isSelected) {
      color = Colors.green;
    } else {
      // Use the same color logic as connections for consistency
      color = _getEquipmentDisplayColor(renderData.bayId, bayType);
    }

    canvas.save();
    canvas.translate(rect.topLeft.dx, rect.topLeft.dy);

    try {
      final painter = _getSymbolPainter(bayType, color, rect.size);
      painter.paint(canvas, rect.size);
    } catch (e) {
      print('Error drawing symbol for ${renderData.bayName}: $e');
      _drawFallbackSymbol(canvas, rect.size, color);
    }

    canvas.restore();
  }

  // UPDATED: Bay label colors to match equipment colors
  void _drawBayLabel(Canvas canvas, BayRenderData renderData, bool isSelected) {
    final rect = renderData.rect;
    final bayType = renderData.bayType;
    final bayName = renderData.bayName;
    final voltageLevel = renderData.voltageLevel;

    String label;
    Offset labelPosition;
    double offsetY = 0;
    TextAlign textAlign = TextAlign.center;

    // Use consistent color for labels
    Color labelColor = isSelected
        ? Colors.green
        : _getEquipmentDisplayColor(renderData.bayId, bayType);

    switch (bayType) {
      case 'Transformer':
        label = '$bayName T/F\n${renderData.bay.make ?? ''}';
        labelPosition = rect.centerLeft + renderData.textOffset;
        offsetY =
            -_measureText(label, fontSize: 9, isBold: true).height / 2 - 20;
        textAlign = TextAlign.right;
        break;
      case 'Line':
        label = '$voltageLevel $bayName Line';
        labelPosition = rect.topCenter + renderData.textOffset;
        offsetY = -12;
        break;
      case 'Feeder':
        label = bayName;
        labelPosition = rect.bottomCenter + renderData.textOffset;
        offsetY = 4;
        break;
      default:
        label = bayName;
        labelPosition = rect.center + renderData.textOffset;
        _drawGenericBayBackground(canvas, rect, isSelected);
        labelColor = defaultBayColor; // Keep default for generic bays
    }

    _drawText(
      canvas,
      label,
      labelPosition,
      offsetY: offsetY,
      isBold: true,
      textAlign: textAlign,
      textColor: labelColor, // Use consistent color
    );
  }

  void _drawGenericBayBackground(Canvas canvas, Rect rect, bool isSelected) {
    canvas.drawRect(
      rect,
      Paint()
        ..color = isSelected
            ? Colors.lightGreen.shade100
            : defaultBayColor.withOpacity(0.1),
    );

    canvas.drawRect(
      rect,
      Paint()
        ..color = isSelected ? Colors.green : defaultBayColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = isSelected ? 2.0 : 1.0,
    );
  }

  void _drawEnergyReadings(Canvas canvas) {
    if (bayEnergyData.isEmpty) return;

    for (var renderData in bayRenderDataList) {
      if (renderData.bayType == 'Busbar') {
        _drawBusbarEnergyReading(canvas, renderData);
      } else {
        _drawBayEnergyReading(canvas, renderData);
      }
    }
  }

  void _drawBusbarEnergyReading(Canvas canvas, BayRenderData renderData) {
    final busSummary = busEnergySummary[renderData.bayId];
    if (busSummary == null) return;

    final totalImp = busSummary['totalImp'] ?? 0.0;
    final totalExp = busSummary['totalExp'] ?? 0.0;

    final importText = 'Imp: ${totalImp.toStringAsFixed(2)} MWH';
    final exportText = 'Exp: ${totalExp.toStringAsFixed(2)} MWH';

    final rect = renderData.rect;
    final readingOffset = renderData.energyReadingOffset;
    final fontSize = renderData.energyReadingFontSize;
    final isBold = renderData.energyReadingIsBold;
    final textHeight = fontSize + 2;

    Offset energyTextTopLeft =
        Offset(rect.right - 80, rect.center.dy - (textHeight * 2.5)) +
        readingOffset;

    _drawText(
      canvas,
      importText,
      energyTextTopLeft,
      textAlign: TextAlign.left,
      fontSize: fontSize,
      isBold: isBold,
      textColor: Colors.blue.shade900,
    );

    _drawText(
      canvas,
      exportText,
      Offset(energyTextTopLeft.dx, energyTextTopLeft.dy + textHeight),
      textAlign: TextAlign.left,
      fontSize: fontSize,
      isBold: isBold,
      textColor: Colors.blue.shade900,
    );
  }

  void _drawBayEnergyReading(Canvas canvas, BayRenderData renderData) {
    final energyData = bayEnergyData[renderData.bayId];
    if (energyData == null) return;

    final readingOffset = renderData.energyReadingOffset;
    final fontSize = renderData.energyReadingFontSize;
    final isBold = renderData.energyReadingIsBold;
    const lineHeight = 1.2;
    const valueOffsetFromLabel = 40.0;

    Offset baseTextOffset = _calculateEnergyReadingPosition(renderData);
    baseTextOffset = baseTextOffset + readingOffset;

    _drawText(
      canvas,
      'Readings:',
      baseTextOffset,
      fontSize: fontSize,
      isBold: true,
      textColor: defaultBayColor,
    );

    final readings = _prepareReadingData(energyData);
    final consumed = _prepareConsumedData(energyData);

    _drawReadingEntries(
      canvas,
      readings,
      baseTextOffset,
      fontSize,
      lineHeight,
      valueOffsetFromLabel,
      isBold,
      1,
    );

    _drawReadingEntries(
      canvas,
      consumed,
      baseTextOffset,
      fontSize,
      lineHeight,
      valueOffsetFromLabel,
      isBold,
      readings.length + 1,
    );

    if (energyData.hasAssessment) {
      _drawAssessmentIndicator(canvas, baseTextOffset, fontSize);
    }
  }

  Offset _calculateEnergyReadingPosition(BayRenderData renderData) {
    final rect = renderData.rect;

    switch (renderData.bayType) {
      case 'Transformer':
        return Offset(rect.centerLeft.dx - 70, rect.center.dy - 10);
      case 'Line':
        return Offset(rect.center.dx - 75, rect.top + 10);
      case 'Feeder':
        return Offset(rect.center.dx - 70, rect.bottom - 40);
      default:
        return Offset(rect.right + 15, rect.center.dy - 20);
    }
  }

  List<Map<String, String?>> _prepareReadingData(BayEnergyData energyData) {
    return [
      {
        'label': 'P.Imp:',
        'value': energyData.previousImportReading.toStringAsFixed(2),
      },
      {'label': 'C.Imp:', 'value': energyData.importReading.toStringAsFixed(2)},
      {
        'label': 'P.Exp:',
        'value': energyData.previousExportReading.toStringAsFixed(2),
      },
      {'label': 'C.Exp:', 'value': energyData.exportReading.toStringAsFixed(2)},
      {'label': 'MF:', 'value': energyData.multiplierFactor.toStringAsFixed(2)},
    ];
  }

  List<Map<String, String?>> _prepareConsumedData(BayEnergyData energyData) {
    return [
      {
        'label': 'Imp(C):',
        'value': energyData.adjustedImportConsumed.toStringAsFixed(2),
      },
      {
        'label': 'Exp(C):',
        'value': energyData.adjustedExportConsumed.toStringAsFixed(2),
      },
    ];
  }

  void _drawReadingEntries(
    Canvas canvas,
    List<Map<String, String?>> entries,
    Offset baseOffset,
    double fontSize,
    double lineHeight,
    double valueOffset,
    bool isBold,
    int startRow,
  ) {
    for (int i = 0; i < entries.length; i++) {
      final rowIndex = startRow + i;
      final yOffset = rowIndex * lineHeight * fontSize;

      _drawText(
        canvas,
        entries[i]['label']!,
        baseOffset.translate(0, yOffset),
        fontSize: fontSize,
        isBold: true,
        textAlign: TextAlign.left,
        textColor: defaultBayColor,
      );

      _drawText(
        canvas,
        entries[i]['value'] ?? 'N/A',
        baseOffset.translate(valueOffset, yOffset),
        fontSize: fontSize,
        isBold: isBold,
        textAlign: TextAlign.left,
        textColor: defaultBayColor,
      );
    }
  }

  void _drawAssessmentIndicator(
    Canvas canvas,
    Offset baseOffset,
    double fontSize,
  ) {
    final TextPainter assessmentIndicatorPainter = TextPainter(
      text: TextSpan(
        text: '*',
        style: TextStyle(
          color: Colors.red,
          fontSize: fontSize + 2,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: ui.TextDirection.ltr,
    )..layout();

    assessmentIndicatorPainter.paint(
      canvas,
      Offset(
        baseOffset.dx - assessmentIndicatorPainter.width - 2,
        baseOffset.dy,
      ),
    );
  }

  // 🔥 ENHANCED DEBUG HITBOXES - Complete replacement for the simple version
  void _drawEnhancedDebugHitboxes(Canvas canvas) {
    if (!debugDrawHitboxes) return;

    final debugPaint = Paint()
      ..color = Colors.red.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    final fillPaint = Paint()
      ..color = Colors.red.withOpacity(0.1)
      ..style = PaintingStyle.fill;

    for (var renderData in bayRenderDataList) {
      // Draw hitbox outline
      canvas.drawRect(renderData.rect, debugPaint);

      // Fill hitbox with transparent color
      canvas.drawRect(renderData.rect, fillPaint);

      // Draw bay type label for debugging
      final textPainter = TextPainter(
        text: TextSpan(
          text: '${renderData.bay.bayType}\n${renderData.bay.name}',
          style: const TextStyle(
            color: Colors.red,
            fontSize: 8,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: ui.TextDirection.ltr,
      )..layout();

      textPainter.paint(canvas, renderData.rect.topLeft + const Offset(2, 2));
    }
  }

  // Helper methods
  BayRenderData? _findRenderData(String bayId) {
    try {
      return bayRenderDataList.firstWhere((d) => d.bayId == bayId);
    } catch (e) {
      return null;
    }
  }

  ({Offset start, Offset end}) _calculateConnectionPoints(
    Bay sourceBay,
    Bay targetBay,
    BayRenderData sourceRenderData,
    BayRenderData targetRenderData,
  ) {
    Offset startPoint;
    Offset endPoint;

    if (sourceBay.bayType == 'Busbar' && targetBay.bayType == 'Transformer') {
      startPoint =
          busbarConnectionPoints[sourceBay.id]?[targetBay.id] ??
          Offset(
            targetRenderData.rect.center.dx,
            sourceRenderData.rect.center.dy,
          );
      endPoint = targetRenderData.topCenter;
    } else if (sourceBay.bayType == 'Transformer' &&
        targetBay.bayType == 'Busbar') {
      startPoint = sourceRenderData.bottomCenter;
      endPoint =
          busbarConnectionPoints[targetBay.id]?[sourceBay.id] ??
          Offset(
            sourceRenderData.rect.center.dx,
            targetRenderData.rect.center.dy,
          );
    } else if (sourceBay.bayType == 'Busbar' && targetBay.bayType == 'Line') {
      startPoint =
          busbarConnectionPoints[sourceBay.id]?[targetBay.id] ??
          Offset(
            targetRenderData.rect.center.dx,
            sourceRenderData.rect.center.dy,
          );
      endPoint = targetRenderData.bottomCenter;
    } else if (sourceBay.bayType == 'Line' && targetBay.bayType == 'Busbar') {
      startPoint = sourceRenderData.bottomCenter;
      endPoint =
          busbarConnectionPoints[targetBay.id]?[sourceBay.id] ??
          Offset(
            sourceRenderData.rect.center.dx,
            targetRenderData.rect.center.dy,
          );
    } else if (sourceBay.bayType == 'Busbar' && targetBay.bayType == 'Feeder') {
      startPoint =
          busbarConnectionPoints[sourceBay.id]?[targetBay.id] ??
          Offset(
            targetRenderData.rect.center.dx,
            sourceRenderData.rect.center.dy,
          );
      endPoint = targetRenderData.topCenter;
    } else if (sourceBay.bayType == 'Feeder' && targetBay.bayType == 'Busbar') {
      startPoint = sourceRenderData.topCenter;
      endPoint =
          busbarConnectionPoints[targetBay.id]?[sourceBay.id] ??
          Offset(
            sourceRenderData.rect.center.dx,
            targetRenderData.rect.center.dy,
          );
    } else {
      startPoint = sourceRenderData.bottomCenter;
      endPoint = targetRenderData.topCenter;
    }

    return (start: startPoint, end: endPoint);
  }

  Color _getBayTypeColor(String bayType) {
    switch (bayType) {
      case 'Transformer':
        return transformerColor;
      case 'Line':
      case 'Feeder':
        return defaultLineFeederColor;
      default:
        return defaultBayColor;
    }
  }

  void _drawFallbackSymbol(Canvas canvas, Size size, Color color) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    canvas.drawRect(
      Rect.fromCenter(
        center: Offset(size.width / 2, size.height / 2),
        width: size.width * 0.8,
        height: size.height * 0.8,
      ),
      paint,
    );
  }

  // Optimized text measurement with caching
  static final Map<String, Size> _textSizeCache = <String, Size>{};

  Size _measureText(String text, {double fontSize = 9, bool isBold = false}) {
    final key = '$text|$fontSize|$isBold';
    if (_textSizeCache.containsKey(key)) {
      return _textSizeCache[key]!;
    }

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
      textDirection: ui.TextDirection.ltr,
    )..layout(minWidth: 0, maxWidth: 500);

    final size = textPainter.size;
    _textSizeCache[key] = size;
    return size;
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
    Color textColor = Colors.black87,
  }) {
    final textStyle = TextStyle(
      color: textColor,
      fontSize: fontSize,
      fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
    );

    final textSpan = TextSpan(text: text, style: textStyle);
    final textPainter = TextPainter(
      text: textSpan,
      textAlign: textAlign,
      textDirection: ui.TextDirection.ltr,
    );

    textPainter.layout(maxWidth: 500);

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

  // UPDATED: Connection color method to be more explicit
  Color _getConnectionColor(
    String sourceBayType,
    String targetBayType,
    String sourceBayId,
    String targetBayId,
  ) {
    // Priority 1: If connecting to a busbar, use the busbar's voltage-based color
    if (sourceBayType == 'Busbar') {
      final sourceBay = baysMap[sourceBayId];
      if (sourceBay != null) {
        return _getBusbarColor(sourceBay.voltageLevel);
      }
    }

    if (targetBayType == 'Busbar') {
      final targetBay = baysMap[targetBayId];
      if (targetBay != null) {
        return _getBusbarColor(targetBay.voltageLevel);
      }
    }

    // Priority 2: For equipment-to-equipment connections, use a neutral color
    // or the color of the higher priority equipment
    if (sourceBayType == 'Transformer' || targetBayType == 'Transformer') {
      return const Color(0xFFD32F2F); // Red for transformer connections
    } else if (sourceBayType == 'Line' || targetBayType == 'Line') {
      return const Color(0xFF1565C0); // Blue for line connections
    } else if (sourceBayType == 'Feeder' || targetBayType == 'Feeder') {
      return const Color(0xFF2E7D32); // Green for feeder connections
    }

    // Priority 3: Fallback to theme color
    return connectionLineColor;
  }

  // FIXED CONNECTION LINE DRAWING METHOD
  void _drawConnectionLine(
    Canvas canvas,
    Offset startPoint,
    Offset endPoint,
    String sourceBayType,
    String targetBayType,
    String sourceBayId,
    String targetBayId,
  ) {
    // Get the appropriate color for the connection
    Color connectionColor = _getConnectionColor(
      sourceBayType,
      targetBayType,
      sourceBayId,
      targetBayId,
    );

    // Create a paint with the dynamic color
    final connectionPaint = Paint()
      ..color = connectionColor
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;

    canvas.drawLine(startPoint, endPoint, connectionPaint);

    // Draw connection dots with matching color
    final connectionDotPaint = Paint()
      ..color = connectionColor
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    if (sourceBayType == 'Busbar' && targetBayType != 'Busbar') {
      final busConnectionPoint =
          busbarConnectionPoints[sourceBayId]?[targetBayId];
      if (busConnectionPoint != null) {
        canvas.drawCircle(busConnectionPoint, 4.0, connectionDotPaint);
      }
    } else if (targetBayType == 'Busbar' && sourceBayType != 'Busbar') {
      final busConnectionPoint =
          busbarConnectionPoints[targetBayId]?[sourceBayId];
      if (busConnectionPoint != null) {
        canvas.drawCircle(busConnectionPoint, 4.0, connectionDotPaint);
      }
    }

    // Draw arrowheads with matching color for transformers
    if ((sourceBayType == 'Busbar' && targetBayType == 'Transformer') ||
        (sourceBayType == 'Transformer' && targetBayType == 'Busbar')) {
      _drawArrowhead(canvas, startPoint, endPoint, connectionPaint);
    }
  }

  @override
  bool shouldRepaint(covariant SingleLineDiagramPainter oldDelegate) {
    // Only repaint if actually necessary
    return oldDelegate.bayRenderDataList != bayRenderDataList ||
        oldDelegate.bayConnections != bayConnections ||
        oldDelegate.baysMap != baysMap ||
        oldDelegate.busbarRects != busbarRects ||
        oldDelegate.busbarConnectionPoints != busbarConnectionPoints ||
        oldDelegate.selectedBayForMovementId != selectedBayForMovementId ||
        oldDelegate.bayEnergyData != bayEnergyData ||
        oldDelegate.busEnergySummary != busEnergySummary ||
        oldDelegate.showEnergyReadings != showEnergyReadings ||
        oldDelegate.debugDrawHitboxes != debugDrawHitboxes ||
        // Only check bounds/colors if they actually changed
        (oldDelegate.contentBounds?.width != contentBounds?.width ||
            oldDelegate.contentBounds?.height != contentBounds?.height) ||
        oldDelegate.defaultBayColor != defaultBayColor ||
        oldDelegate.defaultLineFeederColor != defaultLineFeederColor ||
        oldDelegate.transformerColor != transformerColor ||
        oldDelegate.connectionLineColor != connectionLineColor;
  }
}
