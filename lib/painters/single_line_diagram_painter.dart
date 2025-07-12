// lib/painters/single_line_diagram_painter.dart
import 'dart:ui' as ui show StrokeJoin, PathMetrics, PathMetric;

import 'package:flutter/material.dart';
import 'dart:math'; // For min/max
import 'package:cloud_firestore/cloud_firestore.dart'; // For Timestamp (if still used, but usually via model)

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

// NEW: Import SLD models and EnergyAccountService for data structures
import '../models/sld_models.dart';
import '../models/bay_model.dart'; // For BayType enum access
import '../services/energy_account_services.dart'; // For BayEnergyData, AggregatedFeederEnergyData, SldRenderData

// NOTE: BayRenderData class definition is now in energy_account_services.dart
// You should remove its definition from here if it exists here to avoid duplication.
// Assuming it is removed from here as per previous refactor.

class _GenericIconPainter extends CustomPainter {
  final Color color;
  final Size equipmentSize; // Needed for consistent signature
  final Size symbolSize; // Needed for consistent signature

  _GenericIconPainter({
    required this.color,
    required this.equipmentSize,
    required this.symbolSize,
  });

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
      oldDelegate.color != color ||
      oldDelegate.equipmentSize != equipmentSize ||
      oldDelegate.symbolSize != symbolSize;
}

class SingleLineDiagramPainter extends CustomPainter {
  // NEW: Directly accept SldData and related energy/bay maps
  final SldData sldData;
  final Map<String, Bay> baysMap; // To get original Bay object for full data
  final Map<String, BayEnergyData> bayEnergyData;
  final Map<String, Map<String, double>> busEnergySummary;
  final ColorScheme colorScheme; // For theme-aware drawing
  final Size? contentBounds; // For PDF scaling/translation
  final Offset? originOffsetForPdf; // For PDF translation

  // Removed: bayRenderDataList, bayConnections, busbarRects, busbarConnectionPoints, createDummyBayRenderData, debugDrawHitboxes, selectedBayForMovementId
  // These are now derived from sldData or are no longer directly used by the painter's logic for drawing.

  SingleLineDiagramPainter({
    required this.sldData,
    required this.baysMap,
    required this.bayEnergyData,
    required this.busEnergySummary,
    required this.colorScheme,
    this.contentBounds,
    this.originOffsetForPdf,
  });

  Color _getBusbarColor(String voltageLevel) {
    final double voltage =
        double.tryParse(voltageLevel.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0;
    final isDarkMode = colorScheme.brightness == Brightness.dark;

    if (voltage >= 765) {
      return isDarkMode ? Colors.red.shade400 : Colors.red.shade700;
    } else if (voltage >= 400) {
      return isDarkMode ? Colors.orange.shade400 : Colors.orange.shade700;
    } else if (voltage >= 220) {
      return isDarkMode ? Colors.blue.shade400 : Colors.blue.shade700;
    } else if (voltage >= 132) {
      return isDarkMode ? Colors.purple.shade400 : Colors.purple.shade700;
    } else if (voltage >= 33) {
      return isDarkMode ? Colors.green.shade400 : Colors.green.shade700;
    } else if (voltage >= 11) {
      return isDarkMode ? Colors.teal.shade400 : Colors.teal.shade700;
    } else {
      return isDarkMode ? Colors.white70 : Colors.black;
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
      case 'earth switch': // Assuming 'ground' maps to 'earth switch'
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
      case 'potential transformer':
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
        // Busbar is drawn directly as a line, not typically via icon painter for its main shape
        return BusbarIconPainter(
          color: color,
          equipmentSize: size,
          symbolSize: size,
        );
      default:
        return _GenericIconPainter(
          color: color,
          equipmentSize: size,
          symbolSize: size,
        );
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    final isDarkMode = colorScheme.brightness == Brightness.dark;
    final defaultLineColor = isDarkMode ? Colors.white70 : Colors.black87;
    final defaultTextColor = isDarkMode ? Colors.white70 : Colors.black87;
    final energyTextColor = isDarkMode
        ? colorScheme.secondary
        : Colors.green.shade700;
    final busSummaryTextColor = isDarkMode
        ? colorScheme.tertiary
        : Colors.purple.shade700;

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
      ..color = defaultLineColor
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;

    final thickLinePaint = Paint()
      ..color = defaultLineColor
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;

    final busbarPaint = Paint()
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke;

    final connectionDotPaint = Paint()
      ..color = defaultLineColor
      ..style = PaintingStyle.fill;

    // 1. Draw SldEdges (Connections) first, so they are behind nodes
    for (var element in sldData.elements.values) {
      if (element is SldEdge) {
        final sourceNode = sldData.nodes[element.sourceNodeId];
        final targetNode = sldData.nodes[element.targetNodeId];
        if (sourceNode == null || targetNode == null) continue;

        final sourcePoint =
            sourceNode.position +
            (sourceNode
                    .connectionPoints[element.sourceConnectionPointId]
                    ?.localOffset ??
                Offset.zero);
        final targetPoint =
            targetNode.position +
            (targetNode
                    .connectionPoints[element.targetConnectionPointId]
                    ?.localOffset ??
                Offset.zero);

        // Use edge's color and thickness
        final currentLinePaint = Paint()
          ..color = element
              .lineColor // Use edge's defined color
          ..strokeWidth = element.lineWidth
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeJoin = _mapSldLineJoinToStrokeJoin(element.lineJoin);

        final Path path = Path();
        path.moveTo(sourcePoint.dx, sourcePoint.dy);
        if (element.pathPoints.isNotEmpty) {
          for (var p in element.pathPoints) {
            path.lineTo(p.dx, p.dy);
          }
        }
        path.lineTo(targetPoint.dx, targetPoint.dy);

        if (element.isDashed) {
          _drawDashedLine(canvas, path, currentLinePaint);
        } else {
          canvas.drawPath(path, currentLinePaint);
        }

        // Draw connection dots if connected to busbar
        if (sourceNode.properties['bayTypeString'] ==
            BayType.Busbar.toString().split('.').last) {
          canvas.drawCircle(sourcePoint, 4.0, connectionDotPaint);
        }
        if (targetNode.properties['bayTypeString'] ==
            BayType.Busbar.toString().split('.').last) {
          canvas.drawCircle(targetPoint, 4.0, connectionDotPaint);
        }

        // Draw arrowheads for transformer connections
        if ((sourceNode.properties['bayTypeString'] ==
                    BayType.Busbar.toString().split('.').last &&
                targetNode.properties['bayTypeString'] ==
                    BayType.Transformer.toString().split('.').last &&
                element.properties['connectionType'] == 'HV_BUS_CONNECTION') ||
            (sourceNode.properties['bayTypeString'] ==
                    BayType.Transformer.toString().split('.').last &&
                targetNode.properties['bayTypeString'] ==
                    BayType.Busbar.toString().split('.').last &&
                element.properties['connectionType'] == 'LV_BUS_CONNECTION')) {
          _drawArrowhead(canvas, sourcePoint, targetPoint, currentLinePaint);
        }
      }
    }

    // 2. Draw SldNodes (Bays and Equipment symbols) and Labels
    for (var element in sldData.elements.values) {
      if (element is SldNode) {
        final bay = baysMap[element.associatedBayId ?? element.id];
        if (bay == null) continue; // Should not happen if data is consistent

        final rect = Rect.fromLTWH(
          element.position.dx,
          element.position.dy,
          element.size.width,
          element.size.height,
        );

        // Use node's properties for drawing colors, fallback to theme
        final nodeFillColor =
            element.fillColor ??
            (isDarkMode
                ? colorScheme.surfaceVariant.withOpacity(0.2)
                : Colors.blue.withOpacity(0.1));
        final nodeStrokeColor =
            element.strokeColor ??
            (isDarkMode ? colorScheme.primary.withOpacity(0.6) : Colors.blue);

        // Draw main bay background/outline (if not busbar, as busbar is a line)
        if (element.properties['bayTypeString'] !=
            BayType.Busbar.toString().split('.').last) {
          canvas.drawRect(
            rect,
            Paint()
              ..color = nodeFillColor
              ..style = PaintingStyle.fill,
          );
          canvas.drawRect(
            rect,
            Paint()
              ..color = nodeStrokeColor
              ..strokeWidth = element.strokeWidth
              ..style = PaintingStyle.stroke,
          );
        }

        // Draw Equipment Symbol (using SymbolKey from SldNode properties)
        final String symbolKey =
            element.properties['symbolKey'] ??
            element.properties['bayTypeString'] ??
            'generic';
        final Color symbolColor = isDarkMode
            ? Colors.white
            : Colors.black87; // Symbol color for PDF
        final CustomPainter symbolPainter = _getSymbolPainter(
          symbolKey,
          symbolColor,
          element.size,
        );

        canvas.save();
        canvas.translate(rect.topLeft.dx, rect.topLeft.dy);
        symbolPainter.paint(canvas, rect.size);
        canvas.restore();

        // Draw Bay/Node Name (main label for the node)
        final String displayName =
            element.properties['bayNameFormatted'] ??
            element.properties['name'] ??
            'N/A';
        final Offset nameTextOffset = Offset(
          (element.properties['textOffsetDx'] as num?)?.toDouble() ??
              (element.size.width / 2),
          (element.properties['textOffsetDy'] as num?)?.toDouble() ?? 0.0,
        );
        _drawText(
          canvas,
          displayName,
          rect.topLeft + nameTextOffset,
          fontSize: 12,
          isBold: true,
          textAlign: TextAlign.center,
          color: defaultTextColor, // Use theme-aware text color
        );

        // Draw Energy Data for Bays
        final BayEnergyData? energyData = bayEnergyData[bay.id];
        if (energyData != null && energyData.impConsumed != null) {
          final String energyText =
              'Imp: ${energyData.impConsumed!.toStringAsFixed(2)} MWH';
          final Offset energyTextOffset = Offset(
            (element.properties['energyTextOffsetDx'] as num?)?.toDouble() ??
                (element.size.width / 2),
            (element.properties['energyTextOffsetDy'] as num?)?.toDouble() ??
                element.size.height,
          );
          _drawText(
            canvas,
            energyText,
            rect.topLeft + energyTextOffset,
            fontSize: 10,
            textAlign: TextAlign.center,
            color: energyTextColor, // Use theme-aware energy text color
          );
        }

        // Draw Busbar specific energy summary
        if (element.properties['bayTypeString'] ==
            BayType.Busbar.toString().split('.').last) {
          final Map<String, double>? busSummary = busEnergySummary[bay.id];
          if (busSummary != null) {
            final String importText =
                'Imp: ${(busSummary['totalImp'] ?? 0.0).toStringAsFixed(2)} MWH';
            final String exportText =
                'Exp: ${(busSummary['totalExp'] ?? 0.0).toStringAsFixed(2)} MWH';
            const double busEnergyTextFontSize = 9.0;
            const double textHeight = busEnergyTextFontSize + 2;

            // Positioning relative to the busbar node's rect (element.position is its top-left)
            Offset busSummaryOffset = Offset(
              rect.right + 10, // To the right of the busbar
              rect.center.dy - textHeight * 2, // Centered vertically
            );

            _drawText(
              canvas,
              importText,
              busSummaryOffset,
              textAlign: TextAlign.left,
              fontSize: busEnergyTextFontSize,
              isBold: true,
              color: busSummaryTextColor,
            );
            _drawText(
              canvas,
              exportText,
              busSummaryOffset.translate(0, textHeight),
              textAlign: TextAlign.left,
              fontSize: busEnergyTextFontSize,
              isBold: true,
              color: busSummaryTextColor,
            );
          }
        }
      } else if (element is SldTextLabel) {
        // Draw standalone text labels
        _drawText(
          canvas,
          element.text,
          element.position, // SldTextLabel's position is its top-left
          fontSize: element.textStyle.fontSize ?? 14,
          isBold: element.textStyle.fontWeight == FontWeight.bold,
          textAlign: element.textAlign,
          color: element.textStyle.color ?? defaultTextColor,
        );
      }
    }

    // NEW: Restore the canvas only if transformations were applied
    if (contentBounds != null) {
      canvas.restore();
    }
  }

  // Helper function to draw text on canvas
  void _drawText(
    Canvas canvas,
    String text,
    Offset position, {
    double offsetY = 0,
    bool isBold = false,
    TextAlign textAlign = TextAlign.center,
    double fontSize = 9,
    double offsetX = 0,
    Color? color, // Make color optional and use default if null
  }) {
    final textStyle = TextStyle(
      color:
          color ??
          (colorScheme.brightness == Brightness.dark
              ? Colors.white
              : Colors.black87), // Dynamic default color
      fontSize: fontSize,
      fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
    );
    final textSpan = TextSpan(text: text, style: textStyle);
    final textPainter = TextPainter(
      text: textSpan,
      textAlign: textAlign,
      textDirection: TextDirection.ltr,
    );
    textPainter.layout(maxWidth: 150); // Set a max width for text wrapping

    double x = position.dx + offsetX;
    if (textAlign == TextAlign.center) {
      x -= textPainter.width / 2;
    } else if (textAlign == TextAlign.right) {
      x -= textPainter.width;
    }

    textPainter.paint(canvas, Offset(x, position.dy + offsetY));
  }

  // Helper for drawing dashed lines
  void _drawDashedLine(Canvas canvas, Path path, Paint paint) {
    const double dashWidth = 8.0;
    const double dashSpace = 4.0;

    final ui.PathMetrics pathMetrics = path.computeMetrics();
    for (final ui.PathMetric metric in pathMetrics) {
      double distance = 0.0;
      while (distance < metric.length) {
        final double start = distance;
        final double end = min(distance + dashWidth, metric.length);
        canvas.drawPath(metric.extractPath(start, end), paint);
        distance += dashWidth + dashSpace;
      }
    }
  }

  // Helper to map our custom SldLineJoin enum to Flutter's ui.StrokeJoin
  ui.StrokeJoin _mapSldLineJoinToStrokeJoin(SldLineJoin sldLineJoin) {
    switch (sldLineJoin) {
      case SldLineJoin.miter:
        return ui.StrokeJoin.miter;
      case SldLineJoin.round:
        return ui.StrokeJoin.round;
      case SldLineJoin.bevel:
        return ui.StrokeJoin.bevel;
    }
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

  @override
  bool shouldRepaint(covariant SingleLineDiagramPainter oldDelegate) {
    // Repaint if SldData changes or theme changes
    return oldDelegate.sldData != sldData ||
        oldDelegate.baysMap != baysMap ||
        oldDelegate.bayEnergyData != bayEnergyData ||
        oldDelegate.busEnergySummary != busEnergySummary ||
        oldDelegate.colorScheme != colorScheme ||
        oldDelegate.contentBounds != contentBounds ||
        oldDelegate.originOffsetForPdf != originOffsetForPdf;
  }
}
