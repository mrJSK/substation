// lib/painters/single_line_diagram_painter.dart
import 'package:flutter/material.dart';
import 'dart:math'; // For atan2, cos, sin, max
import 'package:cloud_firestore/cloud_firestore.dart'; // For Timestamp in BayRenderData
import '../models/bay_model.dart'; // For Bay model
import '../models/bay_connection_model.dart'; // For BayConnection model
import '../models/equipment_model.dart'; // For EquipmentInstance model
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
  final List<EquipmentInstance> equipmentInstances; // Equipment in this bay

  BayRenderData({
    required this.bay,
    required this.rect,
    required this.center,
    required this.topCenter,
    required this.bottomCenter,
    required this.leftCenter,
    required this.rightCenter,
    this.equipmentInstances = const [],
    required Offset textOffset,
    required double busbarLength, // Initialize
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
  final bool debugDrawHitboxes; // Added for debugging
  final String? selectedBayForMovementId; // To highlight the selected bay
  final Map<String, BayEnergyData> bayEnergyData; // NEW: Add energy data
  final Map<String, Map<String, double>> busEnergySummary; // NEW: Require it

  SingleLineDiagramPainter({
    required this.bayRenderDataList,
    required this.bayConnections,
    required this.baysMap,
    required this.createDummyBayRenderData,
    required this.busbarRects,
    required this.busbarConnectionPoints,
    this.debugDrawHitboxes =
        false, // Default to false, but we'll enable in _buildSLDView for testing
    this.selectedBayForMovementId, // Initialize new parameter
    required this.bayEnergyData,
    required this.busEnergySummary, // NEW: Pass it down
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
      return Colors.black; // Default color
    }
  }

  // Helper to get CustomPainter for equipment symbol (similar to SLD screen)
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
        return _GenericIconPainter(color: color); // Generic placeholder
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = Colors.black87
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final thickLinePaint =
        Paint() // New paint for thick lines (for connections)
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
          _drawText(
            canvas,
            '${renderData.bay.voltageLevel} ${renderData.bay.name}',
            Offset(busbarDrawingRect.left - 8, busbarDrawingRect.center.dy),
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
        endPoint =
            targetRenderData.bottomCenter; // Line's bottom (closer to busbar)
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
        endPoint =
            targetRenderData.topCenter; // Feeder's top (closer to busbar)
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
        linePaint, // Use thin linePaint for connections
        connectionDotPaint,
        sourceBay.bayType,
        targetBay.bayType,
        busbarConnectionPoints, // Pass this to the drawing function
        connection.sourceBayId,
        connection.targetBayId,
      );
    }

    // 3. Draw Symbols and Labels (and potentially sub-equipment)
    for (var renderData in bayRenderDataList) {
      final bay = renderData.bay;
      final rect = renderData.rect; // This rect is the tappable rect

      // Check if this bay is currently selected for movement
      final bool isSelectedForMovement = bay.id == selectedBayForMovementId;

      // Draw Bay's main symbol or placeholder AND their names
      if (bay.bayType == 'Transformer') {
        final painter = TransformerIconPainter(
          color: isSelectedForMovement
              ? Colors.green
              : Colors.blue, // Highlight if selected
          equipmentSize: rect.size,
          symbolSize: rect.size,
        );
        canvas.save();
        canvas.translate(rect.topLeft.dx, rect.topLeft.dy);
        painter.paint(canvas, rect.size);
        canvas.restore();

        // Transformer name: HV/LV CapacityMVA T/F, Make
        final String transformerName =
            '${bay.name} T/F, \n${bay.make ?? ''}'; // Modified name to include capacity

        // Calculate size of transformer name to offset subsequent text
        final Size transformerNameSize = _measureText(
          transformerName,
          fontSize: 9, // Must match the font size used for drawing
          isBold: true,
        );

        _drawText(
          canvas,
          transformerName,
          // Position to the left of the transformer symbol
          rect.centerLeft,
          offsetY:
              -transformerNameSize.height / 2 -
              10, // Adjust vertically to position above Imp/Exp/MF
          isBold: true,
          textAlign:
              TextAlign.right, // Align text to the right for a clean block
        );
      } else if (bay.bayType == 'Line') {
        final painter = LineIconPainter(
          color: isSelectedForMovement
              ? Colors.green
              : Colors.black87, // Highlight if selected
          equipmentSize: rect.size,
          symbolSize: rect.size,
        );
        canvas.save();
        canvas.translate(rect.topLeft.dx, rect.topLeft.dy);
        painter.paint(canvas, rect.size);
        canvas.restore();
        // Line name: Voltage Level Line Name Line
        final String lineName = '${bay.voltageLevel} ${bay.name} Line';
        _drawText(
          canvas,
          lineName,
          rect.topCenter,
          offsetY: -12,
          isBold: true,
        ); // Label above the line
      } else if (bay.bayType == 'Feeder') {
        final painter = FeederIconPainter(
          color: isSelectedForMovement
              ? Colors.green
              : Colors.black87, // Highlight if selected
          equipmentSize: rect.size,
          symbolSize: rect.size,
        );
        canvas.save();
        canvas.translate(rect.topLeft.dx, rect.topLeft.dy);
        painter.paint(canvas, rect.size);
        canvas.restore();
        // Feeder name: only the bay.name
        _drawText(
          canvas,
          bay.name,
          rect.bottomCenter,
          offsetY: 4, // Label below the line
          isBold: true,
        );
      } else if (bay.bayType != 'Busbar') {
        // For other non-busbar bays, draw a generic rectangle (or customize further)
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
            ..strokeWidth = isSelectedForMovement
                ? 2.0
                : 1.0, // Thicker border if selected
        );
        _drawText(canvas, bay.name, rect.center, isBold: true);
      }

      // Draw individual equipment within the bay's rectangle (if present in main SLD)
      // Only draw equipment if not moving (selectedBayForMovementId is null for Energy SLD)
      if (renderData.equipmentInstances.isNotEmpty &&
          selectedBayForMovementId == null) {
        // Define spacing and size for sub-equipment icons
        const double subIconSize = 25; // Smaller size for sub-equipment icons
        const double subIconSpacing = 5;

        // Calculate available space within the bay rect for sub-icons
        final double availableWidth = rect.width - (2 * subIconSpacing);
        final double startX = rect.left + subIconSpacing;
        double currentY =
            rect.top +
            (bay.bayType == 'Line' || bay.bayType == 'Feeder'
                ? 20
                : 0); // Start below main symbol/label

        // Filter and sort equipment for display
        final List<EquipmentInstance> sortedEquipment =
            List.from(renderData.equipmentInstances)..sort(
              (a, b) =>
                  (a.positionIndex ?? 999).compareTo(b.positionIndex ?? 999),
            );

        for (var equipment in sortedEquipment) {
          if (currentY + subIconSize > rect.bottom) {
            // Avoid overflowing the bay rectangle vertically
            break;
          }

          final Offset iconTopLeft = Offset(
            startX + (availableWidth - subIconSize) / 2,
            currentY,
          ); // Center horizontally
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

          // Optionally draw a tiny label for the sub-equipment if space allows
          _drawText(
            canvas,
            equipment.symbolKey.split(' ').first,
            subIconRect.bottomCenter,
            offsetY: 2,
            isBold: false,
            textAlign: TextAlign.center,
          );

          currentY += subIconSize + subIconSpacing;
        }
      }

      // Draw energy data beside the bay
      if (bay.bayType == 'Busbar') {
        // For Busbars, use busEnergySummary and position to the right
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
          final double textHeight =
              energyTextFontSize + 2; // Height of one line of text + spacing

          // Position to the right of the busbar
          Offset energyTextTopLeft = Offset(
            busbarRects[bay.id]!.right + 10, // 10 pixels offset from right edge
            busbarRects[bay.id]!.center.dy -
                (textHeight * 1.5), // Center vertically relative to text block
          );

          _drawText(
            canvas,
            importText,
            energyTextTopLeft,
            textAlign: TextAlign.left,
            fontSize: energyTextFontSize,
          );
          _drawText(
            canvas,
            exportText,
            Offset(energyTextTopLeft.dx, energyTextTopLeft.dy + textHeight),
            textAlign: TextAlign.left,
            fontSize: energyTextFontSize,
          );
        }
      } else {
        // Logic for other bay types (Line, Feeder, Transformer etc.)
        final BayEnergyData? energyData = bayEnergyData[bay.id];
        if (energyData != null) {
          const double energyTextFontSize = 9.0;
          // Calculate the height of the transformer's name label first
          final String transformerName = '${bay.name} T/F, ${bay.make ?? ''}';
          final Size transformerNameSize = _measureText(
            transformerName,
            fontSize: 9, // Assuming same font size as used for its rendering
            isBold: true,
          );
          // Adjusted total height for the energy data block (3 lines)
          final double energyBlockHeight = (energyTextFontSize + 2) * 3;

          String importValue = energyData.impConsumed != null
              ? energyData.impConsumed!.toStringAsFixed(2)
              : 'N/A';
          String exportValue = energyData.expConsumed != null
              ? energyData.expConsumed!.toStringAsFixed(2)
              : 'N/A';
          String mfValue = energyData.mf != null
              ? energyData.mf!.toStringAsFixed(2)
              : 'N/A';

          final String combinedText =
              'Imp: $importValue \nExp: $exportValue \nMF: $mfValue';

          Offset
          textCenterOffset; // This will be the center of the combined text block
          TextAlign alignment = TextAlign
              .right; // Default alignment for combined text (for transformer)

          if (bay.bayType == 'Transformer') {
            // New position for the energy data: below the main transformer label, to the left
            textCenterOffset = Offset(
              rect.centerLeft.dx -
                  70, // Align with the left edge of the symbol, plus offset
              rect.centerLeft.dy +
                  transformerNameSize.height / 2 +
                  -5, // Vertically below the name
            );
            alignment = TextAlign.left;
          } else if (bay.bayType == 'Line') {
            // Position above the line's name
            final lineNamePainter = TextPainter(
              text: TextSpan(
                text: '${bay.voltageLevel} ${bay.name} Line',
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
              textDirection: TextDirection.ltr,
            )..layout(maxWidth: 200);

            textCenterOffset = Offset(
              rect.center.dx -
                  (_measureText(
                        combinedText,
                        fontSize: energyTextFontSize,
                      ).width /
                      2), // Centered with the line
              rect.top -
                  lineNamePainter.height -
                  energyBlockHeight - // Use energyBlockHeight for calculation
                  5, // Above line name and icon
            );
            alignment = TextAlign.left;
          } else if (bay.bayType == 'Feeder') {
            // Position below the feeder's name
            final feederNamePainter = TextPainter(
              text: TextSpan(
                text: bay.name,
                style: const TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                ),
              ),
              textDirection: TextDirection.ltr,
            )..layout(maxWidth: 100);

            textCenterOffset = Offset(
              rect.center.dx -
                  (_measureText(
                        combinedText,
                        fontSize: energyTextFontSize,
                      ).width /
                      2), // Centered with the feeder
              rect.bottom +
                  feederNamePainter.height +
                  5, // Below feeder name and icon
            );
            alignment = TextAlign.left;
          } else {
            // Default for other types (Capacitor Bank, Reactor, Bus Coupler, Battery) - right of icon
            textCenterOffset = Offset(
              rect.right +
                  5 +
                  (_measureText(
                        combinedText,
                        fontSize: energyTextFontSize,
                      ).width /
                      2),
              rect.center.dy,
            );
            alignment = TextAlign.center;
          }

          // Draw the combined text
          _drawText(
            canvas,
            combinedText,
            textCenterOffset,
            textAlign: alignment,
            fontSize: energyTextFontSize,
          );
        }
      }
    }

    // DEBUGGING STEP: Draw hitboxes if debugDrawHitboxes is true
    // if (debugDrawHitboxes) {
    //   final debugHitboxPaint = Paint()
    //     ..color = Colors.red
    //         .withOpacity(0.3) // Semi-transparent red
    //     ..style = PaintingStyle.fill;
    //   for (var renderData in bayRenderDataList) {
    //     canvas.drawRect(renderData.rect, debugHitboxPaint);
    //   }
    // }
  }

  // Helper to accurately measure text size
  Size _measureText(String text, {double fontSize = 9, bool isBold = false}) {
    final textPainter =
        TextPainter(
          text: TextSpan(
            text: text,
            style: TextStyle(
              color: Colors.black87, // Match the color used for drawing
              fontSize: fontSize,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          maxLines: 2, // Allow for two lines for transformer name
          textAlign: TextAlign.right, // Match the alignment used for drawing
          textDirection: TextDirection.ltr,
        )..layout(
          minWidth: 0,
          maxWidth: 100, // Max width to match drawing constraints
        );
    return textPainter.size;
  }

  // Moved _drawText to accept font size
  void _drawText(
    Canvas canvas,
    String text,
    Offset position, {
    double offsetY = 0,
    bool isBold = false,
    TextAlign textAlign = TextAlign.center,
    double fontSize = 9, // NEW: Default font size
    double offsetX = 0, // Optional horizontal offset
  }) {
    final textStyle = TextStyle(
      color: Colors.black87,
      fontSize: fontSize, // Use passed font size
      fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
    );
    final textSpan = TextSpan(text: text, style: textStyle);
    final textPainter = TextPainter(
      text: textSpan,
      textAlign: textAlign,
      textDirection: TextDirection.ltr,
    );
    textPainter.layout(
      maxWidth:
          100, // Keep a max width to allow text wrapping if needed for longer names
    );

    double x = position.dx;
    if (textAlign == TextAlign.center) {
      x -= textPainter.width / 2;
    } else if (textAlign == TextAlign.right) {
      x -= textPainter.width;
    }

    textPainter.paint(canvas, Offset(x, position.dy + offsetY));
  }

  // Moved _drawArrowhead into SingleLineDiagramPainter
  void _drawArrowhead(Canvas canvas, Offset p1, Offset p2, Paint paint) {
    const double arrowSize = 6.0;
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

  // Moved _drawConnectionLine into SingleLineDiagramPainter
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
        oldDelegate.bayEnergyData !=
            bayEnergyData || // NEW: Repaint if energy data changes
        oldDelegate.busEnergySummary !=
            busEnergySummary; // NEW: Repaint if bus summary changes
  }
}
