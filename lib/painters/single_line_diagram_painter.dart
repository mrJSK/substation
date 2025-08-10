// lib/painters/single_line_diagram_painter.dart
import 'package:flutter/material.dart';
import 'dart:math';
import 'dart:ui' as ui;
import '../models/bay_connection_model.dart';
import '../models/bay_model.dart';
import '../models/energy_readings_data.dart'; // Now uses the unified model
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
      ..isAntiAlias = true; // Performance: enable anti-aliasing

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
  final Map<String, BayEnergyData> bayEnergyData; // Now uses unified model
  final Map<String, Map<String, double>> busEnergySummary;
  final Size? contentBounds;
  final Offset? originOffsetForPdf;

  // Theme colors
  final Color defaultBayColor;
  final Color defaultLineFeederColor;
  final Color transformerColor;
  final Color connectionLineColor;

  // Performance optimization: Pre-computed paint objects
  static final Paint _linePaint = Paint()
    ..strokeWidth = 2.5
    ..style = PaintingStyle.stroke
    ..isAntiAlias = true;

  static final Paint _busbarPaint = Paint()
    ..strokeWidth = 3.0
    ..style = PaintingStyle.stroke
    ..isAntiAlias = true;

  static final Paint _connectionDotPaint = Paint()
    ..style = PaintingStyle.fill
    ..isAntiAlias = true;

  SingleLineDiagramPainter({
    required this.bayRenderDataList,
    required this.bayConnections,
    required this.baysMap,
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

  // Optimized voltage level color mapping with caching
  static final Map<String, Color> _voltageColorCache = <String, Color>{};

  Color _getBusbarColor(String voltageLevel) {
    // Cache voltage colors for performance
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
      // Fallback to generic icon if specific icon fails
      print('Warning: Failed to create icon for $symbolKey, using generic: $e');
      return _GenericIconPainter(color: color, iconSize: size);
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    // Save the canvas state before any transformations
    canvas.save();

    // Apply transformations for PDF generation and content bounds
    _applyCanvasTransformations(canvas, size);

    // Update paint colors
    _linePaint.color = connectionLineColor;
    _connectionDotPaint.color = connectionLineColor;

    // Draw debug bounds if enabled
    if (debugDrawHitboxes) {
      _drawDebugBounds(canvas, size);
    }

    // Performance: Group drawing operations for better GPU batching
    _drawBusbars(canvas);
    _drawConnections(canvas);
    _drawBaySymbolsAndLabels(canvas);
    _drawEnergyReadings(canvas); // Updated to use new model

    // Draw debug hitboxes last (overlay)
    if (debugDrawHitboxes) {
      _drawDebugHitboxes(canvas);
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

      // Apply centering translation first
      canvas.translate(translateX, translateY);
      // Apply scaling based on fitScale
      canvas.scale(fitScale);

      // Apply the origin offset for PDF, if provided
      if (originOffsetForPdf != null) {
        canvas.translate(originOffsetForPdf!.dx, originOffsetForPdf!.dy);
      }
    }
  }

  void _drawDebugBounds(Canvas canvas, Size size) {
    if (contentBounds == null) return;

    // Content bounds in blue
    final boundsPaint = Paint()
      ..color = Colors.blue.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;

    canvas.drawRect(
      Rect.fromLTWH(0, 0, contentBounds!.width, contentBounds!.height),
      boundsPaint,
    );

    // Widget bounds in orange
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

      // Draw busbar line
      canvas.drawLine(
        busbarRect.centerLeft,
        busbarRect.centerRight,
        _busbarPaint,
      );

      // Draw busbar label
      _drawText(
        canvas,
        '${renderData.voltageLevel} ${renderData.bayName}',
        Offset(busbarRect.left - 8, busbarRect.center.dy) +
            renderData.textOffset,
        textAlign: TextAlign.right,
        textColor: defaultBayColor,
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
      if (renderData.bayType == 'Busbar') continue; // Already handled

      final bool isSelectedForMovement =
          renderData.bayId == selectedBayForMovementId;

      _drawBaySymbol(canvas, renderData, isSelectedForMovement);
      _drawBayLabel(canvas, renderData, isSelectedForMovement);
    }
  }

  void _drawBaySymbol(
    Canvas canvas,
    BayRenderData renderData,
    bool isSelected,
  ) {
    final rect = renderData.rect;
    final bayType = renderData.bayType;
    final color = isSelected ? Colors.green : _getBayTypeColor(bayType);

    canvas.save();
    canvas.translate(rect.topLeft.dx, rect.topLeft.dy);

    try {
      final painter = _getSymbolPainter(bayType, color, rect.size);
      painter.paint(canvas, rect.size);
    } catch (e) {
      // Fallback drawing
      print('Error drawing symbol for ${renderData.bayName}: $e');
      _drawFallbackSymbol(canvas, rect.size, color);
    }

    canvas.restore();
  }

  void _drawBayLabel(Canvas canvas, BayRenderData renderData, bool isSelected) {
    final rect = renderData.rect;
    final bayType = renderData.bayType;
    final bayName = renderData.bayName;
    final voltageLevel = renderData.voltageLevel;

    String label;
    Offset labelPosition;
    double offsetY = 0;
    TextAlign textAlign = TextAlign.center;

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
        // Draw background for generic bays
        _drawGenericBayBackground(canvas, rect, isSelected);
    }

    _drawText(
      canvas,
      label,
      labelPosition,
      offsetY: offsetY,
      isBold: true,
      textAlign: textAlign,
      textColor: defaultBayColor,
    );
  }

  void _drawGenericBayBackground(Canvas canvas, Rect rect, bool isSelected) {
    // Fill
    canvas.drawRect(
      rect,
      Paint()
        ..color = isSelected
            ? Colors.lightGreen.shade100
            : defaultBayColor.withOpacity(0.1),
    );

    // Border
    canvas.drawRect(
      rect,
      Paint()
        ..color = isSelected ? Colors.green : defaultBayColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = isSelected ? 2.0 : 1.0,
    );
  }

  // Updated to use unified BayEnergyData model
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

  // Enhanced bay energy reading using unified model
  void _drawBayEnergyReading(Canvas canvas, BayRenderData renderData) {
    final energyData = bayEnergyData[renderData.bayId];
    if (energyData == null) return;

    final readingOffset = renderData.energyReadingOffset;
    final fontSize = renderData.energyReadingFontSize;
    final isBold = renderData.energyReadingIsBold;
    const lineHeight = 1.2;
    const valueOffsetFromLabel = 40.0;

    // Calculate base position based on bay type
    Offset baseTextOffset = _calculateEnergyReadingPosition(renderData);
    baseTextOffset = baseTextOffset + readingOffset;

    // Draw "Readings:" header
    _drawText(
      canvas,
      'Readings:',
      baseTextOffset,
      fontSize: fontSize,
      isBold: true,
      textColor: defaultBayColor,
    );

    // Prepare reading data using new unified model
    final readings = _prepareReadingData(energyData);
    final consumed = _prepareConsumedData(energyData);

    // Draw readings
    _drawReadingEntries(
      canvas,
      readings,
      baseTextOffset,
      fontSize,
      lineHeight,
      valueOffsetFromLabel,
      isBold,
      1, // Start from row 1 (after header)
    );

    // Draw consumed values
    _drawReadingEntries(
      canvas,
      consumed,
      baseTextOffset,
      fontSize,
      lineHeight,
      valueOffsetFromLabel,
      isBold,
      readings.length + 1, // Start after readings
    );

    // Draw assessment indicator if present
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

  // Updated to use unified model properties
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

  // Updated to use unified model properties
  List<Map<String, String?>> _prepareConsumedData(BayEnergyData energyData) {
    return [
      {
        'label': 'Imp(C):',
        'value': energyData.adjustedImportConsumed.toStringAsFixed(
          2,
        ), // Uses adjustment
      },
      {
        'label': 'Exp(C):',
        'value': energyData.adjustedExportConsumed.toStringAsFixed(
          2,
        ), // Uses adjustment
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

      // Draw label
      _drawText(
        canvas,
        entries[i]['label']!,
        baseOffset.translate(0, yOffset),
        fontSize: fontSize,
        isBold: true,
        textAlign: TextAlign.left,
        textColor: defaultBayColor,
      );

      // Draw value
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
    final indicatorPaint = Paint()
      ..color = Colors.red
      ..style = PaintingStyle.fill;

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

  void _drawDebugHitboxes(Canvas canvas) {
    final debugPaint = Paint()
      ..color = Colors.red.withOpacity(0.3)
      ..style = PaintingStyle.fill;

    for (var renderData in bayRenderDataList) {
      canvas.drawRect(renderData.rect, debugPaint);
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

    // Enhanced connection logic
    if (sourceBay.bayType == 'Busbar' && targetBay.bayType == 'Transformer') {
      startPoint =
          busbarConnectionPoints[sourceBay.id]?[targetBay.id] ??
          sourceRenderData.rect.center;
      endPoint = targetRenderData.topCenter;
    } else if (sourceBay.bayType == 'Transformer' &&
        targetBay.bayType == 'Busbar') {
      startPoint = sourceRenderData.bottomCenter;
      endPoint =
          busbarConnectionPoints[targetBay.id]?[sourceBay.id] ??
          targetRenderData.rect.center;
    } else if (sourceBay.bayType == 'Busbar' && targetBay.bayType == 'Line') {
      startPoint =
          busbarConnectionPoints[sourceBay.id]?[targetBay.id] ??
          sourceRenderData.rect.center;
      endPoint = targetRenderData.bottomCenter;
    } else if (sourceBay.bayType == 'Line' && targetBay.bayType == 'Busbar') {
      startPoint = sourceRenderData.bottomCenter;
      endPoint =
          busbarConnectionPoints[targetBay.id]?[sourceBay.id] ??
          targetRenderData.rect.center;
    } else if (sourceBay.bayType == 'Busbar' && targetBay.bayType == 'Feeder') {
      startPoint =
          busbarConnectionPoints[sourceBay.id]?[targetBay.id] ??
          sourceRenderData.rect.center;
      endPoint = targetRenderData.topCenter;
    } else if (sourceBay.bayType == 'Feeder' && targetBay.bayType == 'Busbar') {
      startPoint = sourceRenderData.topCenter;
      endPoint =
          busbarConnectionPoints[targetBay.id]?[sourceBay.id] ??
          targetRenderData.rect.center;
    } else {
      // Default connection points
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

  void _drawConnectionLine(
    Canvas canvas,
    Offset startPoint,
    Offset endPoint,
    String sourceBayType,
    String targetBayType,
    String sourceBayId,
    String targetBayId,
  ) {
    // Draw the main connection line
    canvas.drawLine(startPoint, endPoint, _linePaint);

    // Draw connection dots for busbar connections
    if (sourceBayType == 'Busbar' && targetBayType != 'Busbar') {
      final busConnectionPoint =
          busbarConnectionPoints[sourceBayId]?[targetBayId];
      if (busConnectionPoint != null) {
        canvas.drawCircle(busConnectionPoint, 4.0, _connectionDotPaint);
      }
    } else if (targetBayType == 'Busbar' && sourceBayType != 'Busbar') {
      final busConnectionPoint =
          busbarConnectionPoints[targetBayId]?[sourceBayId];
      if (busConnectionPoint != null) {
        canvas.drawCircle(busConnectionPoint, 4.0, _connectionDotPaint);
      }
    }

    // Draw arrowheads for transformer connections
    if ((sourceBayType == 'Busbar' && targetBayType == 'Transformer') ||
        (sourceBayType == 'Transformer' && targetBayType == 'Busbar')) {
      _drawArrowhead(canvas, startPoint, endPoint, _linePaint);
    }
  }

  @override
  bool shouldRepaint(covariant SingleLineDiagramPainter oldDelegate) {
    // Comprehensive repaint logic for performance optimization
    return oldDelegate.bayRenderDataList != bayRenderDataList ||
        oldDelegate.bayConnections != bayConnections ||
        oldDelegate.baysMap != baysMap ||
        oldDelegate.busbarRects != busbarRects ||
        oldDelegate.busbarConnectionPoints != busbarConnectionPoints ||
        oldDelegate.debugDrawHitboxes != debugDrawHitboxes ||
        oldDelegate.selectedBayForMovementId != selectedBayForMovementId ||
        oldDelegate.bayEnergyData != bayEnergyData ||
        oldDelegate.busEnergySummary != busEnergySummary ||
        oldDelegate.contentBounds != contentBounds ||
        oldDelegate.originOffsetForPdf != originOffsetForPdf ||
        oldDelegate.defaultBayColor != defaultBayColor ||
        oldDelegate.defaultLineFeederColor != defaultLineFeederColor ||
        oldDelegate.transformerColor != transformerColor ||
        oldDelegate.connectionLineColor != connectionLineColor;
  }
}
