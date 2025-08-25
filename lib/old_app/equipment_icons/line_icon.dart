// lib/equipment_icons/line_icon.dart

import 'package:flutter/material.dart';
import 'dart:math';

import 'package:substation_manager/old_app/equipment_icons/transformer_icon.dart';

class LineIconPainter extends EquipmentPainter {
  LineIconPainter({
    required super.color,
    super.strokeWidth = 2.5,
    required super.equipmentSize,
    required Size symbolSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final colors = [Color(0xFF1565C0), Color(0xFF42A5F5)]; // Blue for line
    final strokePaint = createGradientPaint(size, colors, isFill: false);
    final shadowPaint = createShadowPaint();

    final double centerX = size.width / 2;
    const double arrowHeight = 12.0;
    const double arrowBaseWidth = 12.0;
    final double lineStartY = size.height * 0.1 + arrowHeight;

    // Enhanced stroke paint
    strokePaint.strokeCap = StrokeCap.round;

    // Line shadow (subtle)
    canvas.drawLine(
      Offset(centerX + 1, lineStartY + 1),
      Offset(centerX + 1, size.height + 1),
      shadowPaint..strokeWidth = strokeWidth * 0.5, // Lighter
    );

    // Main vertical line with gradient
    final linePaint = Paint()
      ..shader =
          LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: colors,
          ).createShader(
            Rect.fromLTWH(
              centerX - strokeWidth / 2,
              lineStartY,
              strokeWidth,
              size.height - lineStartY,
            ),
          )
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    canvas.drawLine(
      Offset(centerX, lineStartY),
      Offset(centerX, size.height),
      linePaint,
    );

    // Arrowhead with shadow (subtle)
    final Offset arrowBaseCenter = Offset(centerX, lineStartY);
    final arrowPath = Path()
      ..moveTo(arrowBaseCenter.dx - arrowBaseWidth / 2, arrowBaseCenter.dy)
      ..lineTo(arrowBaseCenter.dx + arrowBaseWidth / 2, arrowBaseCenter.dy)
      ..lineTo(centerX, arrowBaseCenter.dy - arrowHeight)
      ..close();

    // Arrow shadow (lighter)
    final arrowShadowPath = Path()
      ..moveTo(
        arrowBaseCenter.dx - arrowBaseWidth / 2 + 1,
        arrowBaseCenter.dy + 1,
      )
      ..lineTo(
        arrowBaseCenter.dx + arrowBaseWidth / 2 + 1,
        arrowBaseCenter.dy + 1,
      )
      ..lineTo(centerX + 1, arrowBaseCenter.dy - arrowHeight + 1)
      ..close();
    canvas.drawPath(
      arrowShadowPath,
      shadowPaint..color = shadowPaint.color.withOpacity(0.1),
    );

    // Arrow without background fill, just stroke
    canvas.drawPath(arrowPath, strokePaint..style = PaintingStyle.stroke);

    // Add transmission line characteristics (parallel lines, no shade)
    final conductorPaint = Paint()
      ..color = colors[1]
          .withOpacity(0.6) // Subtle opacity
      ..strokeWidth = strokeWidth * 0.4
      ..strokeCap = StrokeCap.round;

    // Three parallel conductors
    for (int i = -1; i <= 1; i++) {
      final offset = i * size.width * 0.08;
      canvas.drawLine(
        Offset(centerX + offset, lineStartY + arrowHeight),
        Offset(centerX + offset, size.height * 0.8),
        conductorPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant LineIconPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.strokeWidth != strokeWidth ||
      oldDelegate.equipmentSize != equipmentSize;
}
