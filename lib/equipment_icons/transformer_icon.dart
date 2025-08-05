// lib/equipment_icons/transformer_icon.dart

import 'package:flutter/material.dart';
import 'dart:math';

// Abstract base class for all equipment painters
abstract class EquipmentPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final Size equipmentSize;

  EquipmentPainter({
    required this.color,
    this.strokeWidth = 2.5,
    required this.equipmentSize,
  });

  // Professional color scheme
  static const Map<String, List<Color>> equipmentColorScheme = {
    'Transformer': [Color(0xFF1976D2), Color(0xFF42A5F5)], // Blue gradient
    'Circuit Breaker': [Color(0xFFD32F2F), Color(0xFFEF5350)], // Red gradient
    'Disconnector': [Color(0xFFFF8F00), Color(0xFFFFB74D)], // Orange gradient
    'Current Transformer': [
      Color(0xFF7B1FA2),
      Color(0xFFBA68C8),
    ], // Purple gradient
    'Voltage Transformer': [
      Color(0xFF388E3C),
      Color(0xFF66BB6A),
    ], // Green gradient
    'Relay': [Color(0xFF5D4037), Color(0xFF8D6E63)], // Brown gradient
    'Capacitor Bank': [Color(0xFF0097A7), Color(0xFF4DD0E1)], // Cyan gradient
    'Reactor': [Color(0xFFE64A19), Color(0xFFFF8A65)], // Deep orange gradient
    'Surge Arrester': [Color(0xFF9C27B0), Color(0xFFCE93D8)], // Pink gradient
    'Energy Meter': [
      Color(0xFF689F38),
      Color(0xFF9CCC65),
    ], // Light green gradient
    'Ground': [Color(0xFF795548), Color(0xFFA1887F)], // Brown-grey gradient
    'Busbar': [Color(0xFF37474F), Color(0xFF78909C)], // Blue-grey gradient
    'Isolator': [Color(0xFFF57C00), Color(0xFFFFCC02)], // Amber gradient
    'Other': [Color(0xFF616161), Color(0xFF9E9E9E)], // Grey gradient
  };

  // Helper method to create gradient paint
  Paint createGradientPaint(
    Size size,
    List<Color> colors, {
    bool isFill = true,
  }) {
    return Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: colors,
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = isFill ? PaintingStyle.fill : PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
  }

  // Helper method to create shadow paint
  Paint createShadowPaint() {
    return Paint()
      ..color = Colors.black.withOpacity(0.2)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
  }

  // Helper method to create text with consistent styling
  void drawStyledText(
    Canvas canvas,
    String text,
    Offset position,
    Color color,
    double fontSize,
  ) {
    final textSpan = TextSpan(
      text: text,
      style: TextStyle(
        color: color,
        fontSize: fontSize,
        fontWeight: FontWeight.bold,
        shadows: [
          Shadow(
            offset: const Offset(1, 1),
            blurRadius: 2,
            color: Colors.black.withOpacity(0.3),
          ),
        ],
      ),
    );
    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(canvas, position);
  }
}

class TransformerIconPainter extends EquipmentPainter {
  TransformerIconPainter({
    required super.color,
    super.strokeWidth,
    required super.equipmentSize,
    required Size symbolSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final colors = EquipmentPainter.equipmentColorScheme['Transformer']!;
    final gradientPaint = createGradientPaint(size, colors, isFill: false);
    final shadowPaint = createShadowPaint();

    final double centerX = size.width / 2;
    final double centerY = size.height / 2;
    final double radius = min(size.width, size.height) / 3.5;

    // Draw shadows first
    canvas.drawCircle(
      Offset(centerX - radius / 2 + 2, centerY + 2),
      radius,
      shadowPaint,
    );
    canvas.drawCircle(
      Offset(centerX + radius / 2 + 2, centerY + 2),
      radius,
      shadowPaint,
    );
    canvas.drawCircle(
      Offset(centerX + 2, centerY - radius * sqrt(3) / 2 + 2),
      radius,
      shadowPaint,
    );

    // Draw circles with gradient
    canvas.drawCircle(
      Offset(centerX - radius / 2, centerY),
      radius,
      gradientPaint,
    );
    canvas.drawCircle(
      Offset(centerX + radius / 2, centerY),
      radius,
      gradientPaint,
    );
    canvas.drawCircle(
      Offset(centerX, centerY - radius * sqrt(3) / 2),
      radius,
      gradientPaint,
    );

    // Connection line with gradient
    canvas.drawLine(
      Offset(centerX, centerY + radius),
      Offset(centerX, size.height),
      gradientPaint,
    );

    // Add "T" label
    drawStyledText(
      canvas,
      'T',
      Offset(centerX - 6, centerY - 8),
      colors[0],
      size.width * 0.3,
    );
  }

  @override
  bool shouldRepaint(covariant TransformerIconPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.strokeWidth != strokeWidth ||
      oldDelegate.equipmentSize != equipmentSize;
}
