// lib/equipment_icons/busbar_icon.dart

import 'package:flutter/material.dart';
import 'package:substation_manager/equipment_icons/transformer_icon.dart';

class BusbarIconPainter extends EquipmentPainter {
  final String? voltageText;

  BusbarIconPainter({
    required super.color,
    super.strokeWidth,
    required super.equipmentSize,
    this.voltageText,
    required Size symbolSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final colors = EquipmentPainter.equipmentColorScheme['Busbar']!;
    final gradientPaint = createGradientPaint(size, colors, isFill: false);

    final double busbarY = size.height / 2;

    // Draw shadow
    final shadowPaint = Paint()
      ..color = Colors.black.withOpacity(0.2)
      ..strokeWidth = strokeWidth + 2
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(
      Offset(0, busbarY + 1),
      Offset(size.width, busbarY + 1),
      shadowPaint,
    );

    // Draw main busbar line with gradient effect
    final mainPaint = Paint()
      ..shader =
          LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [colors[0], colors[1], colors[0]],
          ).createShader(
            Rect.fromLTWH(
              0,
              busbarY - strokeWidth / 2,
              size.width,
              strokeWidth,
            ),
          )
      ..strokeWidth = strokeWidth * 1.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    canvas.drawLine(Offset(0, busbarY), Offset(size.width, busbarY), mainPaint);

    // Add connection points (small circles at ends)
    final connectionPaint = createGradientPaint(size, colors, isFill: true);
    canvas.drawCircle(Offset(0, busbarY), strokeWidth, connectionPaint);
    canvas.drawCircle(
      Offset(size.width, busbarY),
      strokeWidth,
      connectionPaint,
    );

    // Draw voltage text if available
    if (voltageText != null && voltageText!.isNotEmpty) {
      drawStyledText(
        canvas,
        voltageText!,
        Offset(
          size.width / 2 - (voltageText!.length * size.height * 0.15),
          busbarY - size.height * 0.3,
        ),
        colors[0],
        size.height * 0.3,
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
