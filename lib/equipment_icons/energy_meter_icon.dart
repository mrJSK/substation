// lib/equipment_icons/energy_meter_icon.dart

import 'package:flutter/material.dart';
import 'package:substation_manager/equipment_icons/transformer_icon.dart';
import 'dart:math';

class EnergyMeterIconPainter extends EquipmentPainter {
  EnergyMeterIconPainter({
    required super.color,
    super.strokeWidth,
    required super.equipmentSize,
    required Size symbolSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final colors = EquipmentPainter.equipmentColorScheme['Energy Meter']!;
    final strokePaint = createGradientPaint(size, colors, isFill: false);
    final fillPaint = createGradientPaint(size, colors, isFill: true);
    final shadowPaint = createShadowPaint();

    final centerX = size.width / 2;
    final centerY = size.height / 2;
    final radius = min(size.width, size.height) * 0.35;

    // Draw shadow
    canvas.drawCircle(Offset(centerX + 2, centerY + 2), radius, shadowPaint);

    // Draw circular meter body with gradient fill
    canvas.drawCircle(
      Offset(centerX, centerY),
      radius,
      fillPaint..color = colors[1].withOpacity(0.1),
    );
    canvas.drawCircle(Offset(centerX, centerY), radius, strokePaint);

    // Draw scale marks with enhanced styling
    for (int i = 0; i < 8; i++) {
      final angle = i * pi / 4 - pi;
      final innerRadius = radius * 0.75;
      final outerRadius = radius * 0.9;
      final isMainMark = i % 2 == 0;

      final scalePaint = Paint()
        ..color = isMainMark ? colors[0] : colors[1]
        ..strokeWidth = isMainMark ? strokeWidth * 0.8 : strokeWidth * 0.5
        ..strokeCap = StrokeCap.round;

      canvas.drawLine(
        Offset(
          centerX + innerRadius * cos(angle),
          centerY + innerRadius * sin(angle),
        ),
        Offset(
          centerX + outerRadius * cos(angle),
          centerY + outerRadius * sin(angle),
        ),
        scalePaint,
      );
    }

    // Draw meter needle with enhanced styling
    final needleLength = radius * 0.6;
    final needleAngle = -pi / 4;
    final needleEndX = centerX + needleLength * cos(needleAngle);
    final needleEndY = centerY + needleLength * sin(needleAngle);

    // Needle shadow
    canvas.drawLine(
      Offset(centerX + 1, centerY + 1),
      Offset(needleEndX + 1, needleEndY + 1),
      shadowPaint..strokeWidth = strokeWidth * 0.8,
    );

    // Needle with gradient
    final needlePaint = Paint()
      ..shader =
          LinearGradient(
            begin: Alignment.center,
            end: Alignment.bottomRight,
            colors: [colors[0], colors[1]],
          ).createShader(
            Rect.fromCenter(
              center: Offset(centerX, centerY),
              width: needleLength,
              height: strokeWidth,
            ),
          )
      ..strokeWidth = strokeWidth * 0.8
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    canvas.drawLine(
      Offset(centerX, centerY),
      Offset(needleEndX, needleEndY),
      needlePaint,
    );

    // Center hub with gradient
    canvas.drawCircle(Offset(centerX + 0.5, centerY + 0.5), 3, shadowPaint);
    canvas.drawCircle(Offset(centerX, centerY), 3, fillPaint);
    canvas.drawCircle(
      Offset(centerX, centerY),
      3,
      strokePaint..style = PaintingStyle.stroke,
    );

    // Connection lines
    canvas.drawLine(
      Offset(centerX, 0),
      Offset(centerX, centerY - radius),
      strokePaint,
    );
    canvas.drawLine(
      Offset(centerX, size.height),
      Offset(centerX, centerY + radius),
      strokePaint,
    );

    // Add display window
    final displayRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(centerX, centerY + radius * 0.4),
        width: radius * 0.8,
        height: radius * 0.2,
      ),
      const Radius.circular(2),
    );

    canvas.drawRRect(
      displayRect,
      Paint()..color = Colors.black.withOpacity(0.8),
    );

    // Digital display text
    drawStyledText(
      canvas,
      'kWh',
      Offset(centerX - 12, centerY + radius * 0.35),
      Colors.green,
      size.width * 0.15,
    );
  }

  @override
  bool shouldRepaint(covariant EnergyMeterIconPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.strokeWidth != strokeWidth ||
      oldDelegate.equipmentSize != equipmentSize;
}
