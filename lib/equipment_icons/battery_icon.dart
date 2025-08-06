// lib/equipment_icons/battery_icon.dart

import 'package:flutter/material.dart';
import 'package:substation_manager/equipment_icons/transformer_icon.dart';
import 'dart:math';

class BatteryIconPainter extends EquipmentPainter {
  BatteryIconPainter({
    required super.color,
    super.strokeWidth,
    required super.equipmentSize,
    required Size symbolSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final colors =
        EquipmentPainter.equipmentColorScheme['Battery'] ??
        [Color(0xFF4CAF50), Color(0xFF81C784)]; // Green tones for battery
    final strokePaint = createGradientPaint(size, colors, isFill: false);
    final shadowPaint = createShadowPaint();

    final centerX = size.width / 2;
    final centerY = size.height / 2;
    final batteryWidth = size.width * 0.7;
    final batteryHeight = size.height * 0.5;

    // Draw shadow (subtle)
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(centerX + 2, centerY + 2),
          width: batteryWidth,
          height: batteryHeight,
        ),
        const Radius.circular(4),
      ),
      shadowPaint..color = shadowPaint.color.withOpacity(0.1),
    );

    // Draw battery body (stroke only, no fill)
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(centerX, centerY),
          width: batteryWidth,
          height: batteryHeight,
        ),
        const Radius.circular(4),
      ),
      strokePaint,
    );

    // Draw internal cell dividers with enhanced styling
    final numCells = 3;
    final cellSpacing = batteryWidth / numCells;
    for (int i = 1; i < numCells; i++) {
      final x = centerX - batteryWidth / 2 + i * cellSpacing;
      final dividerPaint = Paint()
        ..color = colors[1]
        ..strokeWidth = strokeWidth * 0.8
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(
        Offset(x, centerY - batteryHeight / 2),
        Offset(x, centerY + batteryHeight / 2),
        dividerPaint,
      );
    }

    // Draw positive terminal
    final positiveTerminalWidth = batteryWidth * 0.1;
    final positiveTerminalHeight = batteryHeight * 0.3;
    canvas.drawRect(
      Rect.fromLTWH(
        centerX + batteryWidth / 2,
        centerY - positiveTerminalHeight / 2,
        positiveTerminalWidth,
        positiveTerminalHeight,
      ),
      strokePaint..style = PaintingStyle.stroke,
    );

    // Draw negative terminal
    final negativeTerminalWidth = batteryWidth * 0.1;
    final negativeTerminalHeight = batteryHeight * 0.3;
    canvas.drawRect(
      Rect.fromLTWH(
        centerX - batteryWidth / 2 - negativeTerminalWidth,
        centerY - negativeTerminalHeight / 2,
        negativeTerminalWidth,
        negativeTerminalHeight,
      ),
      strokePaint..style = PaintingStyle.stroke,
    );

    // Connection lines
    canvas.drawLine(
      Offset(centerX - batteryWidth / 2 - negativeTerminalWidth, centerY),
      Offset(0, centerY),
      strokePaint,
    );
    canvas.drawLine(
      Offset(centerX + batteryWidth / 2 + positiveTerminalWidth, centerY),
      Offset(size.width, centerY),
      strokePaint,
    );

    // Draw "+" and "-" signs
    drawStyledText(
      canvas,
      '+',
      Offset(
        centerX + batteryWidth / 2 + positiveTerminalWidth / 2 - 4,
        centerY - 8,
      ),
      colors[0],
      size.width * 0.15,
    );
    drawStyledText(
      canvas,
      '-',
      Offset(
        centerX - batteryWidth / 2 - negativeTerminalWidth / 2 - 4,
        centerY - 8,
      ),
      colors[0],
      size.width * 0.15,
    );
  }

  @override
  bool shouldRepaint(covariant BatteryIconPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.strokeWidth != strokeWidth ||
      oldDelegate.equipmentSize != equipmentSize;
}
