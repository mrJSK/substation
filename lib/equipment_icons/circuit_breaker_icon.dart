// lib/equipment_icons/circuit_breaker_icon.dart

import 'package:flutter/material.dart';
import 'package:substation_manager/equipment_icons/transformer_icon.dart';

class CircuitBreakerIconPainter extends EquipmentPainter {
  CircuitBreakerIconPainter({
    required super.color,
    super.strokeWidth,
    required super.equipmentSize,
    required Size symbolSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final colors = EquipmentPainter.equipmentColorScheme['Circuit Breaker']!;
    final strokePaint = createGradientPaint(size, colors, isFill: false);
    final fillPaint = createGradientPaint(size, colors, isFill: true);
    final shadowPaint = createShadowPaint();

    // Draw shadow
    final shadowRect = Rect.fromLTWH(2, 2, size.width, size.height);
    canvas.drawRect(shadowRect, shadowPaint);

    // Draw the square with gradient fill
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    canvas.drawRect(rect, fillPaint..color = colors[1].withOpacity(0.3));
    canvas.drawRect(rect, strokePaint);

    // Draw diagonal lines with enhanced styling
    final diagonalPaint = Paint()
      ..color = colors[0]
      ..strokeWidth = strokeWidth * 0.8
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(rect.topLeft, rect.bottomRight, diagonalPaint);
    canvas.drawLine(rect.topRight, rect.bottomLeft, diagonalPaint);

    // Add corner accents
    final accentPaint = Paint()
      ..color = colors[1]
      ..strokeWidth = strokeWidth * 0.5
      ..strokeCap = StrokeCap.round;

    // Corner highlights
    canvas.drawLine(Offset(0, size.height * 0.2), Offset(0, 0), accentPaint);
    canvas.drawLine(Offset(0, 0), Offset(size.width * 0.2, 0), accentPaint);
  }

  @override
  bool shouldRepaint(covariant CircuitBreakerIconPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.strokeWidth != strokeWidth ||
      oldDelegate.equipmentSize != equipmentSize;
}
