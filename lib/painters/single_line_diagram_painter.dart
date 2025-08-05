// lib/painters/single_line_diagram_painter.dart
import 'package:flutter/material.dart';
import 'dart:math';
import 'dart:ui' as ui; // Import ui for TextDirection
import '../models/bay_connection_model.dart';
import '../models/bay_model.dart';
import '../models/energy_readings_data.dart';
import '../models/equipment_model.dart';
import '../screens/subdivision_dashboard_tabs/energy_sld_screen.dart'; // Ensure this import is correct for BayEnergyData

// Equipment Icons - Make sure these files exist and contain the CustomPainter implementations
import '../equipment_icons/transformer_icon.dart';
import '../equipment_icons/line_icon.dart';
import '../equipment_icons/feeder_icon.dart';
import '../equipment_icons/busbar_icon.dart';
import '../equipment_icons/circuit_breaker_icon.dart';
import '../equipment_icons/ct_icon.dart';
import '../equipment_icons/ground_icon.dart';
import '../equipment_icons/isolator_icon.dart';
import '../equipment_icons/pt_icon.dart';

// BayRenderData remains the same - it's the data payload for rendering
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
}

// Generic Icon Painter (as provided in your snippet)
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
  final List<BayRenderData> bayRenderDataList;
  final List<BayConnection> bayConnections;
  final Map<String, Bay> baysMap;
  final BayRenderData Function() createDummyBayRenderData;
  final Map<String, Rect> busbarRects;
  final Map<String, Map<String, Offset>> busbarConnectionPoints;
  final bool debugDrawHitboxes; // Keep this true for testing the bounding box
  final String? selectedBayForMovementId;
  final Map<String, BayEnergyData> bayEnergyData;
  final Map<String, Map<String, double>> busEnergySummary;
  final Size? contentBounds;
  final Offset? originOffsetForPdf;
  final Color defaultBayColor;
  final Color defaultLineFeederColor;
  final Color transformerColor;
  final Color connectionLineColor;

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

  @override
  void paint(Canvas canvas, Size size) {
    // Save the canvas state before any transformations
    canvas.save();

    if (contentBounds != null &&
        contentBounds!.width > 0 &&
        contentBounds!.height > 0) {
      final double scaleX = size.width / contentBounds!.width;
      final double scaleY = size.height / contentBounds!.height;
      final double fitScale = min(
        scaleX,
        scaleY,
      ); // This should be 1.0 if size == contentBounds

      final double scaledContentWidth = contentBounds!.width * fitScale;
      final double scaledContentHeight = contentBounds!.height * fitScale;

      final double translateX = (size.width - scaledContentWidth) / 2;
      final double translateY = (size.height - scaledContentHeight) / 2;

      // Apply centering translation first
      canvas.translate(translateX, translateY);
      // Apply scaling based on fitScale (should be 1.0)
      canvas.scale(fitScale);

      // Apply the origin offset for PDF, if provided.
      // This shifts the content so the minX/minY of the content becomes (0,0) on the new canvas.
      if (originOffsetForPdf != null) {
        canvas.translate(originOffsetForPdf!.dx, originOffsetForPdf!.dy);
      }
    }

    // --- TEMPORARY DEBUG DRAWING: Visualize the contentBounds ---
    // This rectangle should fill the entire canvas if contentBounds == size,
    // or be centered if size > contentBounds due to fitScale.
    if (debugDrawHitboxes && contentBounds != null) {
      final Paint boundsPaint = Paint()
        ..color = Colors.blue
            .withOpacity(0.3) // Semi-transparent blue
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.0;
      // Draw the rectangle that the content *should* fill.
      // After originOffsetForPdf, the top-left of the content should be at (0,0)
      canvas.drawRect(
        Rect.fromLTWH(0, 0, contentBounds!.width, contentBounds!.height),
        boundsPaint,
      );
      // Also draw the bounds of the actual CustomPaint widget (the 'size' argument)
      final Paint widgetBoundsPaint = Paint()
        ..color = Colors.orange
            .withOpacity(0.3) // Semi-transparent orange
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.0;
      canvas.drawRect(
        Rect.fromLTWH(0, 0, size.width, size.height),
        widgetBoundsPaint,
      );
    }
    // --- END TEMPORARY DEBUG DRAWING ---

    final linePaint = Paint()
      ..color = connectionLineColor
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;

    final busbarPaint = Paint()
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke;

    final connectionDotPaint = Paint()
      ..color = connectionLineColor
      ..style = PaintingStyle.fill;

    // Draw busbars first
    for (var renderData in bayRenderDataList) {
      if (renderData.bay.bayType == 'Busbar') {
        final busbarRect = renderData.rect;
        busbarPaint.color = _getBusbarColor(renderData.bay.voltageLevel);

        canvas.drawLine(
          busbarRect.centerLeft,
          busbarRect.centerRight,
          busbarPaint,
        );
        _drawText(
          canvas,
          '${renderData.bay.voltageLevel} ${renderData.bay.name}',
          Offset(busbarRect.left - 8, busbarRect.center.dy) +
              renderData.textOffset,
          textAlign: TextAlign.right,
          textColor: defaultBayColor,
        );
      }
    }

    // Draw connections
    for (var connection in bayConnections) {
      final sourceBay = baysMap[connection.sourceBayId];
      final targetBay = baysMap[connection.targetBayId];
      if (sourceBay == null || targetBay == null) continue;

      final sourceRenderData = bayRenderDataList.firstWhere(
        (d) => d.bay.id == sourceBay.id,
        orElse: createDummyBayRenderData,
      );
      final targetRenderData = bayRenderDataList.firstWhere(
        (d) => d.bay.id == targetBay.id,
        orElse: createDummyBayRenderData,
      );
      if (sourceRenderData.bay.id == 'dummy' ||
          targetRenderData.bay.id == 'dummy')
        continue;

      Offset startPoint;
      Offset endPoint;

      // Transformer connections: Ensure line goes from center of busbar to center of transformer top/bottom
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
      } else if (sourceBay.bayType == 'Busbar' &&
          targetBay.bayType == 'Feeder') {
        startPoint =
            busbarConnectionPoints[sourceBay.id]?[targetBay.id] ??
            sourceRenderData.rect.center;
        endPoint = targetRenderData.topCenter;
      } else if (sourceBay.bayType == 'Feeder' &&
          targetBay.bayType == 'Busbar') {
        startPoint = sourceRenderData.topCenter;
        endPoint =
            busbarConnectionPoints[targetBay.id]?[sourceBay.id] ??
            targetRenderData.rect.center;
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

    // Draw Bay Symbols and Names for non-busbar bays
    for (var renderData in bayRenderDataList) {
      final bay = renderData.bay;
      final rect = renderData.rect;

      final bool isSelectedForMovement = bay.id == selectedBayForMovementId;

      if (debugDrawHitboxes) {
        // Draw the bay's hitbox in red
        canvas.drawRect(
          rect,
          Paint()
            ..color = Colors.red.withOpacity(0.3)
            ..style = PaintingStyle.fill,
        );
      }

      if (bay.bayType == 'Transformer') {
        final painter = TransformerIconPainter(
          color: isSelectedForMovement ? Colors.green : transformerColor,
          equipmentSize: rect.size,
          symbolSize: rect.size,
        );
        canvas.save();
        canvas.translate(rect.topLeft.dx, rect.topLeft.dy);
        painter.paint(canvas, rect.size);
        canvas.restore();

        final String transformerName = '${bay.name} T/F, \n${bay.make ?? ''}';

        _drawText(
          canvas,
          transformerName,
          rect.centerLeft + renderData.textOffset,
          offsetY:
              -_measureText(transformerName, fontSize: 9, isBold: true).height /
                  2 -
              20,
          isBold: true,
          textAlign: TextAlign.right,
          textColor: defaultBayColor,
        );
      } else if (bay.bayType == 'Line') {
        final painter = LineIconPainter(
          color: isSelectedForMovement ? Colors.green : defaultLineFeederColor,
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
          textColor: defaultBayColor,
        );
      } else if (bay.bayType == 'Feeder') {
        final painter = FeederIconPainter(
          color: isSelectedForMovement ? Colors.green : defaultLineFeederColor,
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
          textColor: defaultBayColor,
        );
      } else if (bay.bayType != 'Busbar') {
        canvas.drawRect(
          rect,
          Paint()
            ..color = isSelectedForMovement
                ? Colors.lightGreen.shade100
                : defaultBayColor.withOpacity(0.1),
        );
        canvas.drawRect(
          rect,
          Paint()
            ..color = isSelectedForMovement ? Colors.green : defaultBayColor
            ..style = PaintingStyle.stroke
            ..strokeWidth = isSelectedForMovement ? 2.0 : 1.0,
        );
        _drawText(
          canvas,
          bay.name,
          rect.center + renderData.textOffset,
          isBold: true,
          textColor: defaultBayColor,
        );
      }

      // Draw Energy Reading Text
      if (bayEnergyData.isNotEmpty) {
        // Only draw if energy data is provided
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

            final Offset readingOffset = renderData.energyReadingOffset;
            final double readingFontSize = renderData.energyReadingFontSize;
            final bool readingIsBold = renderData.energyReadingIsBold;

            final double textHeight = readingFontSize + 2;

            Offset energyTextTopLeft =
                Offset(rect.right - 80, rect.center.dy - (textHeight * 2.5)) +
                readingOffset;

            _drawText(
              canvas,
              importText,
              energyTextTopLeft,
              textAlign: TextAlign.left,
              fontSize: readingFontSize,
              isBold: readingIsBold,
              textColor: Colors.blue.shade900,
            );
            _drawText(
              canvas,
              exportText,
              Offset(energyTextTopLeft.dx, energyTextTopLeft.dy + textHeight),
              textAlign: TextAlign.left,
              fontSize: readingFontSize,
              isBold: readingIsBold,
              textColor: Colors.blue.shade900,
            );
          }
        } else {
          // Energy reading for non-busbar bays
          final BayEnergyData? energyData = bayEnergyData[bay.id];
          if (energyData != null) {
            final Offset readingOffset = renderData.energyReadingOffset;
            final double readingFontSize = renderData.energyReadingFontSize;
            final bool readingIsBold = renderData.energyReadingIsBold;
            final bool labelsAreBold = renderData.energyReadingIsBold;

            final double lineHeight = 1.2;
            final double valueOffsetFromLabel = 40;

            Offset baseTextOffset;
            TextAlign alignment = TextAlign.left;

            if (bay.bayType == 'Transformer') {
              baseTextOffset = Offset(
                rect.centerLeft.dx - 70,
                rect.center.dy - 10,
              );
            } else if (bay.bayType == 'Line') {
              baseTextOffset = Offset(rect.center.dx - 75, rect.top + 10);
            } else if (bay.bayType == 'Feeder') {
              baseTextOffset = Offset(rect.center.dx - 70, rect.bottom - 40);
            } else {
              baseTextOffset = Offset(rect.right + 15, rect.center.dy - 20);
            }

            baseTextOffset = baseTextOffset + readingOffset;

            _drawText(
              canvas,
              'Readings:',
              baseTextOffset,
              fontSize: readingFontSize,
              isBold: labelsAreBold,
              textAlign: alignment,
              textColor: defaultBayColor,
            );

            final List<Map<String, String?>> readings = [
              {
                'label': 'P.Imp:',
                'value': energyData.prevImp?.toStringAsFixed(2),
              },
              {
                'label': 'C.Imp:',
                'value': energyData.currImp?.toStringAsFixed(2),
              },
              {
                'label': 'P.Exp:',
                'value': energyData.prevExp?.toStringAsFixed(2),
              },
              {
                'label': 'C.Exp:',
                'value': energyData.currExp?.toStringAsFixed(2),
              },
              {'label': 'MF:', 'value': energyData.mf?.toStringAsFixed(2)},
            ];

            final List<Map<String, String?>> consumed = [
              {
                'label': 'Imp(C):',
                'value': energyData.impConsumed?.toStringAsFixed(2),
              },
              {
                'label': 'Exp(C):',
                'value': energyData.expConsumed?.toStringAsFixed(2),
              },
            ];

            for (int i = 0; i < readings.length; i++) {
              _drawText(
                canvas,
                readings[i]['label']!,
                baseTextOffset.translate(
                  0,
                  (i + 1) * lineHeight * readingFontSize,
                ),
                fontSize: readingFontSize,
                isBold: labelsAreBold,
                textAlign: alignment,
                textColor: defaultBayColor,
              );
              _drawText(
                canvas,
                readings[i]['value'] ?? 'N/A',
                baseTextOffset.translate(
                  valueOffsetFromLabel,
                  (i + 1) * lineHeight * readingFontSize,
                ),
                fontSize: readingFontSize,
                isBold: readingIsBold,
                textAlign: alignment,
                textColor: defaultBayColor,
              );
            }

            for (int i = 0; i < consumed.length; i++) {
              _drawText(
                canvas,
                consumed[i]['label']!,
                baseTextOffset.translate(
                  0,
                  (readings.length + i + 1) * lineHeight * readingFontSize,
                ),
                fontSize: readingFontSize,
                isBold: labelsAreBold,
                textAlign: alignment,
                textColor: defaultBayColor,
              );
              _drawText(
                canvas,
                consumed[i]['value'] ?? 'N/A',
                baseTextOffset.translate(
                  valueOffsetFromLabel,
                  (readings.length + i + 1) * lineHeight * readingFontSize,
                ),
                fontSize: readingFontSize,
                isBold: readingIsBold,
                textAlign: alignment,
                textColor: defaultBayColor,
              );
            }

            if (energyData.hasAssessment) {
              final TextPainter assessmentIndicatorPainter = TextPainter(
                text: TextSpan(
                  text: '*',
                  style: TextStyle(
                    color: Colors.red,
                    fontSize: readingFontSize + 2,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                textDirection: ui.TextDirection.ltr, // Use ui.TextDirection
              )..layout();
              assessmentIndicatorPainter.paint(
                canvas,
                Offset(
                  baseTextOffset.dx - assessmentIndicatorPainter.width - 2,
                  baseTextOffset.dy,
                ),
              );
            }
          }
        }
      }
    }

    // This debug drawing is for the individual bay hitboxes.
    // The contentBounds drawing is above.
    if (debugDrawHitboxes) {
      final debugHitboxPaint = Paint()
        ..color = Colors.red.withOpacity(0.3)
        ..style = PaintingStyle.fill;
      for (var renderData in bayRenderDataList) {
        canvas.drawRect(renderData.rect, debugHitboxPaint);
      }
    }

    // Restore the canvas state saved at the beginning of the paint method
    canvas.restore();
  }

  // Adjusted maxWidth in _measureText for testing
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
      textDirection: ui.TextDirection.ltr, // Use ui.TextDirection
    )..layout(minWidth: 0, maxWidth: 500); // Increased maxWidth for testing
    return textPainter.size;
  }

  // Adjusted maxWidth in _drawText for testing
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
      textDirection: ui.TextDirection.ltr, // Use ui.TextDirection
    );
    textPainter.layout(maxWidth: 500); // Increased maxWidth for testing

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
    // This repaint logic is crucial for performance.
    // We should repaint if core data changes or if selected bay/movement mode changes.
    // Using `ListEquality` for `bayRenderDataList` would be too slow.
    // Instead, rely on `notifyListeners()` in SldController to trigger rebuild.
    // The painter only needs to know if the inputs provided to it have changed.
    return oldDelegate.bayRenderDataList !=
            bayRenderDataList || // Reference equality is sufficient if list is rebuilt
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
