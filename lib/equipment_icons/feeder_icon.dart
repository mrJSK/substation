// lib/equipment_icons/feeder_icon.dart

import 'package:flutter/material.dart';
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
    final colors = [Color(0xFF2E7D32), Color(0xFF66BB6A)]; // Green for feeder
    final strokePaint = createGradientPaint(size, colors, isFill: false);
    final fillPaint = createGradientPaint(size, colors, isFill: true);
    final shadowPaint = createShadowPaint();

    final double centerX = size.width / 2;
    const double arrowHeight = 12.0;
    const double arrowBaseWidth = 12.0;
    final double lineEndY = size.height * 0.9 - arrowHeight;

    // Enhanced stroke paint
    strokePaint.strokeCap = StrokeCap.round;

    // Line shadow
    canvas.drawLine(
      Offset(centerX + 1, 1),
      Offset(centerX + 1, lineEndY + 1),
      shadowPaint..strokeWidth = strokeWidth,
    );

    // Main vertical line with gradient
    final linePaint = Paint()
      ..shader =
          LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: colors,
          ).createShader(
            Rect.fromLTWH(centerX - strokeWidth / 2, 0, strokeWidth, lineEndY),
          )
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    canvas.drawLine(Offset(centerX, 0), Offset(centerX, lineEndY), linePaint);

    // Arrowhead with shadow
    final Offset arrowBaseCenter = Offset(centerX, lineEndY);
    final arrowPath = Path()
      ..moveTo(arrowBaseCenter.dx - arrowBaseWidth / 2, arrowBaseCenter.dy)
      ..lineTo(arrowBaseCenter.dx + arrowBaseWidth / 2, arrowBaseCenter.dy)
      ..lineTo(centerX, arrowBaseCenter.dy + arrowHeight)
      ..close();

    // Arrow shadow
    final arrowShadowPath = Path()
      ..moveTo(
        arrowBaseCenter.dx - arrowBaseWidth / 2 + 1,
        arrowBaseCenter.dy + 1,
      )
      ..lineTo(
        arrowBaseCenter.dx + arrowBaseWidth / 2 + 1,
        arrowBaseCenter.dy + 1,
      )
      ..lineTo(centerX + 1, arrowBaseCenter.dy + arrowHeight + 1)
      ..close();

    canvas.drawPath(arrowShadowPath, shadowPaint);
    canvas.drawPath(arrowPath, fillPaint);
    canvas.drawPath(arrowPath, strokePaint..style = PaintingStyle.stroke);

    // Add feeder identification marks
    final markPaint = Paint()
      ..color = colors[1]
      ..strokeWidth = strokeWidth * 0.6
      ..strokeCap = StrokeCap.round;

    // Three small perpendicular lines
    for (int i = 1; i <= 3; i++) {
      final y = size.height * 0.15 * i;
      canvas.drawLine(
        Offset(centerX - size.width * 0.1, y),
        Offset(centerX + size.width * 0.1, y),
        markPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant FeederIconPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.strokeWidth != strokeWidth ||
      oldDelegate.equipmentSize != equipmentSize;
}
