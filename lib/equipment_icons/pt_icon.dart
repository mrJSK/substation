// lib/equipment_icons/pt_icon.dart

import 'package:flutter/material.dart';
import 'package:substation_manager/equipment_icons/transformer_icon.dart';
import 'dart:math';

class PotentialTransformerIconPainter extends EquipmentPainter {
  PotentialTransformerIconPainter({
    required super.color,
    super.strokeWidth,
    required super.equipmentSize,
    required Size symbolSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final colors =
        EquipmentPainter.equipmentColorScheme['Voltage Transformer']!;
    final strokePaint = createGradientPaint(size, colors, isFill: false);
    final fillPaint = createGradientPaint(size, colors, isFill: true);
    final shadowPaint = createShadowPaint();

    final centerX = size.width / 2;
    final centerY = size.height / 2;
    final coilRadius = min(size.width, size.height) * 0.2;

    // Draw shadows
    canvas.drawCircle(
      Offset(centerX + 1, centerY - coilRadius / 2 + 1),
      coilRadius,
      shadowPaint,
    );
    canvas.drawCircle(
      Offset(centerX + 1, centerY + coilRadius / 2 + 1),
      coilRadius,
      shadowPaint,
    );

    // Draw coil shapes with gradient fill
    canvas.drawCircle(
      Offset(centerX, centerY - coilRadius / 2),
      coilRadius,
      fillPaint..color = colors[1].withOpacity(0.2),
    );
    canvas.drawCircle(
      Offset(centerX, centerY + coilRadius / 2),
      coilRadius,
      fillPaint..color = colors[1].withOpacity(0.2),
    );

    // Draw outlines
    canvas.drawCircle(
      Offset(centerX, centerY - coilRadius / 2),
      coilRadius,
      strokePaint,
    );
    canvas.drawCircle(
      Offset(centerX, centerY + coilRadius / 2),
      coilRadius,
      strokePaint,
    );

    // Primary lines with enhanced styling
    canvas.drawLine(
      Offset(centerX, 0),
      Offset(centerX, centerY - coilRadius),
      strokePaint,
    );
    canvas.drawLine(
      Offset(centerX, size.height),
      Offset(centerX, centerY + coilRadius),
      strokePaint,
    );

    // Add connection dots
    final dotPaint = createGradientPaint(size, colors, isFill: true);
    canvas.drawCircle(
      Offset(centerX, centerY - coilRadius),
      strokeWidth * 0.8,
      dotPaint,
    );
    canvas.drawCircle(
      Offset(centerX, centerY + coilRadius),
      strokeWidth * 0.8,
      dotPaint,
    );

    // Draw "PT" text
    drawStyledText(
      canvas,
      'PT',
      Offset(centerX + coilRadius + 5, centerY - size.width * 0.125),
      colors[0],
      size.width * 0.25,
    );
  }

  @override
  bool shouldRepaint(covariant PotentialTransformerIconPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.strokeWidth != strokeWidth ||
      oldDelegate.equipmentSize != equipmentSize;
}
