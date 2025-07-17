// lib/equipment_icons/line_icon.dart (Revised for "arrow base at end of line" and pointing upwards)

import 'package:flutter/material.dart';
import 'dart:math';

// Assuming EquipmentPainter is defined in transformer_icon.dart
import 'package:substation_manager/equipment_icons/transformer_icon.dart';

class LineIconPainter extends EquipmentPainter {
  LineIconPainter({
    required super.color,
    super.strokeWidth = 2.5,
    required super.equipmentSize,
    required Size symbolSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final lineBodyPaint =
        Paint() // Paint for the main line body
          ..color = color
          ..strokeWidth = strokeWidth
          ..style = PaintingStyle.stroke;

    final arrowheadFillPaint =
        Paint() // Paint specifically for filling the arrowhead
          ..color = color
          ..style = PaintingStyle.fill;

    final double centerX = size.width / 2;

    const double arrowHeight = 10.0; // Height of the arrowhead
    const double arrowBaseWidth = 10.0; // Width of the arrowhead base

    // The line should end just before the arrowhead starts
    final double lineStartY =
        size.height * 0.1 + arrowHeight; // Start of the line

    // Draw the main vertical line representing the transmission line
    canvas.drawLine(
      Offset(centerX, lineStartY), // Start of the line
      Offset(centerX, size.height), // Bottom of the symbol area
      lineBodyPaint,
    );

    // Draw the arrowhead at the top
    // The base of the arrow should be at the start of the line (lineStartY).
    // The tip of the arrow will be further up.
    final Offset arrowBaseCenter = Offset(centerX, lineStartY);

    final Path arrowPath = Path();
    // Start at the left base point
    arrowPath.moveTo(
      arrowBaseCenter.dx - arrowBaseWidth / 2,
      arrowBaseCenter.dy,
    );
    // Draw to the right base point
    arrowPath.lineTo(
      arrowBaseCenter.dx + arrowBaseWidth / 2,
      arrowBaseCenter.dy,
    );
    // Draw to the tip
    arrowPath.lineTo(
      centerX,
      arrowBaseCenter.dy - arrowHeight,
    ); // Tip is above the base
    arrowPath.close(); // Closes the path to form a triangle
    canvas.drawPath(arrowPath, arrowheadFillPaint);
  }

  @override
  bool shouldRepaint(covariant LineIconPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.strokeWidth != strokeWidth ||
      oldDelegate.equipmentSize != equipmentSize;
}
