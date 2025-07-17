// lib/equipment_icons/feeder_icon.dart (Revised for "arrow base at end of line" and pointing downwards)

import 'package:flutter/material.dart';
import 'dart:math';

// Assuming EquipmentPainter is defined in transformer_icon.dart
import 'package:substation_manager/equipment_icons/transformer_icon.dart';

class FeederIconPainter extends EquipmentPainter {
  FeederIconPainter({
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
    final double lineEndY = size.height * 0.9 - arrowHeight; // End of the line

    // Draw the main vertical line representing the feeder
    canvas.drawLine(
      Offset(centerX, 0), // Top of the symbol area
      Offset(centerX, lineEndY), // End of the line
      lineBodyPaint,
    );

    // Draw the arrowhead at the bottom
    // The base of the arrow should be at the end of the line (lineEndY).
    // The tip of the arrow will be further down.
    final Offset arrowBaseCenter = Offset(centerX, lineEndY);

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
      arrowBaseCenter.dy + arrowHeight,
    ); // Tip is below the base
    arrowPath.close(); // Closes the path to form a triangle
    canvas.drawPath(arrowPath, arrowheadFillPaint);
  }

  @override
  bool shouldRepaint(covariant FeederIconPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.strokeWidth != strokeWidth ||
      oldDelegate.equipmentSize != equipmentSize;
}
