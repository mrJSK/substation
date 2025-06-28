// lib/equipment_icons/busbar_icon.dart

import 'package:flutter/material.dart';
import 'package:substation_manager/equipment_icons/transformer_icon.dart'; // Import base EquipmentPainter

class BusbarIconPainter extends EquipmentPainter {
  final String? voltageText; // Optional voltage text for busbar

  BusbarIconPainter({
    required super.color,
    super.strokeWidth,
    required super.equipmentSize, // Use equipmentSize from base
    this.voltageText,
    required Size symbolSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 'size' here is the drawing area (CustomPaint's size)
    final paint = Paint()
      ..color = color
      ..strokeWidth =
          strokeWidth // Use strokeWidth for the line thickness
      ..style = PaintingStyle.stroke;

    // The actual busbar line width should be equipmentSize.width,
    // drawn within the 'size' bounding box.
    // We need to center the busbar line vertically within the CustomPaint widget's height ('size.height')
    final double busbarY =
        size.height /
        2; // Vertically center the line within the CustomPaint area
    canvas.drawLine(
      Offset(0, busbarY),
      Offset(size.width, busbarY),
      paint,
    ); // Draw across the CustomPaint's width

    // Draw voltage text if available
    if (voltageText != null && voltageText!.isNotEmpty) {
      final textSpan = TextSpan(
        text: voltageText,
        style: TextStyle(
          color: color.computeLuminance() > 0.5 ? Colors.black : Colors.white,
          fontSize:
              size.height *
              0.5, // Adjusted font size to fit better within smaller busbar height
          fontWeight: FontWeight.bold,
        ),
      );
      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();

      // Position the text slightly above the busbar line, centered horizontally
      textPainter.paint(
        canvas,
        Offset(
          size.width / 2 - textPainter.width / 2,
          busbarY - textPainter.height - 2,
        ),
      );
    }
  }

  @override
  bool shouldRepaint(covariant BusbarIconPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.strokeWidth != strokeWidth ||
      oldDelegate.equipmentSize != equipmentSize ||
      oldDelegate.voltageText != voltageText;
}
