// lib/painters/single_line_diagram_painter.dart
import 'package:flutter/material.dart';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
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
  final Bay bay;
  final Rect rect;
  final Offset center;
  final Offset topCenter;
  final Offset bottomCenter;
  final Offset leftCenter;
  final Offset rightCenter;
  final List<EquipmentInstance> equipmentInstances;
  final Offset textOffset;
  final double
  busbarLength; // Added this property as it was used in constructor but not declared.

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
    required this.busbarLength, // Initialize
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
  final Size? contentBounds; // NEW: Added contentBounds for PDF scaling
  final Offset?
  originOffsetForPdf; // NEW: Added originOffsetForPdf for PDF translation

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
    this.contentBounds, // NEW: Include in constructor
    this.originOffsetForPdf, // NEW: Include in constructor
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

  @override
  void paint(Canvas canvas, Size size) {
    // NEW: Apply scaling and translation for PDF capture
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

      canvas.save();
      canvas.translate(translateX, translateY); // Center the content
      canvas.scale(fitScale); // Scale the content

      if (originOffsetForPdf != null) {
        canvas.translate(
          originOffsetForPdf!.dx,
          originOffsetForPdf!.dy,
        ); // Apply origin shift
      }
    }

    final linePaint = Paint()
      ..color = Colors.black87
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;

    final thickLinePaint = Paint()
      ..color = Colors.black87
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;

    final busbarPaint = Paint()
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke;

    final connectionDotPaint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.fill;

    // 1. Draw Busbars with voltage-based colors
    for (var renderData in bayRenderDataList) {
      if (renderData.bay.bayType == 'Busbar') {
        final busbarDrawingRect = busbarRects[renderData.bay.id];
        if (busbarDrawingRect != null) {
          busbarPaint.color = _getBusbarColor(renderData.bay.voltageLevel);

          canvas.drawLine(
            busbarDrawingRect.centerLeft,
            busbarDrawingRect.centerRight,
            busbarPaint,
          );
          // Busbar name: Voltage Level and Bus Name
          // Use the textOffset from renderData for busbar name
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

    // 2. Draw Connections
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

      // Determine connection points based on bay types and calculated positions
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
      } else if (sourceBay.bayType == 'Busbar' && targetBay.bayType == 'Line') {
        startPoint =
            busbarConnectionPoints[sourceBay.id]?[targetBay.id] ??
            sourceRenderData.center;
        endPoint = targetRenderData.bottomCenter;
      } else if (sourceBay.bayType == 'Line' && targetBay.bayType == 'Busbar') {
        startPoint = sourceRenderData.bottomCenter;
        endPoint =
            busbarConnectionPoints[targetBay.id]?[sourceBay.id] ??
            targetRenderData.center;
      } else if (sourceBay.bayType == 'Busbar' &&
          targetBay.bayType == 'Feeder') {
        startPoint =
            busbarConnectionPoints[sourceBay.id]?[targetBay.id] ??
            sourceRenderData.center;
        endPoint = targetRenderData.topCenter;
      } else if (sourceBay.bayType == 'Feeder' &&
          targetBay.bayType == 'Busbar') {
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

    // 3. Draw Symbols and Labels (and potentially sub-equipment)
    for (var renderData in bayRenderDataList) {
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
            busbarRects[bay.id]!.right - 80,
            busbarRects[bay.id]!.center.dy - (textHeight * 2.5),
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

    if (debugDrawHitboxes) {
      final debugHitboxPaint = Paint()
        ..color = Colors.red.withOpacity(0.3)
        ..style = PaintingStyle.fill;
      for (var renderData in bayRenderDataList) {
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
        oldDelegate.bayRenderDataList != bayRenderDataList ||
        oldDelegate.bayConnections != bayConnections ||
        oldDelegate.baysMap != baysMap ||
        oldDelegate.busbarRects != busbarRects ||
        oldDelegate.busbarConnectionPoints != busbarConnectionPoints ||
        oldDelegate.bayEnergyData != bayEnergyData ||
        oldDelegate.busEnergySummary != busEnergySummary ||
        oldDelegate.contentBounds !=
            contentBounds || // NEW: Repaint if contentBounds changes
        oldDelegate.originOffsetForPdf !=
            originOffsetForPdf; // NEW: Repaint if originOffsetForPdf changes
  }
}
