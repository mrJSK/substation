// lib/equipment_icons/reactor_icon.dart

import 'package:flutter/material.dart';
import 'dart:math';

import 'package:substation_manager/old_app/equipment_icons/transformer_icon.dart';

class ReactorIconPainter extends EquipmentPainter {
  ReactorIconPainter({
    required super.color,
    super.strokeWidth,
    required super.equipmentSize,
    required Size symbolSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final colors = EquipmentPainter.equipmentColorScheme['Reactor']!;
    final strokePaint = createGradientPaint(size, colors, isFill: false);
    final shadowPaint = createShadowPaint();

    final centerX = size.width / 2;
    final centerY = size.height / 2;
    final coilHeight = size.height * 0.5;
    final coilWidth = size.width * 0.3;

    // Draw inductor coil (series of arcs) with subtle shadows
    final numCoils = 4;
    final coilSpacing = coilHeight / numCoils;

    for (int i = 0; i < numCoils; i++) {
      final y = centerY - coilHeight / 2 + i * coilSpacing;
      final rect = Rect.fromCenter(
        center: Offset(centerX, y + coilSpacing / 2),
        width: coilWidth,
        height: coilSpacing,
      );

      // Draw shadow (subtle)
      final shadowRect = Rect.fromCenter(
        center: Offset(centerX + 1, y + coilSpacing / 2 + 1),
        width: coilWidth,
        height: coilSpacing,
      );
      canvas.drawArc(
        shadowRect,
        0,
        pi,
        false,
        shadowPaint..strokeWidth = strokeWidth * 0.5, // Lighter
      );

      // Draw coil with gradient (stroke only, no fill)
      final coilPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: colors,
        ).createShader(rect)
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;
      canvas.drawArc(rect, 0, pi, false, coilPaint);
    }

    // Connection lines
    canvas.drawLine(
      Offset(centerX, 0),
      Offset(centerX, centerY - coilHeight / 2),
      strokePaint,
    );
    canvas.drawLine(
      Offset(centerX, size.height),
      Offset(centerX, centerY + coilHeight / 2),
      strokePaint,
    );

    // Removed core representation for cleanliness

    // Draw "L" text
    drawStyledText(
      canvas,
      'L',
      Offset(centerX + coilWidth / 2 + 8, centerY - size.width * 0.15),
      colors[0],
      size.width * 0.3,
    );
  }

  @override
  bool shouldRepaint(covariant ReactorIconPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.strokeWidth != strokeWidth ||
      oldDelegate.equipmentSize != equipmentSize;
}
