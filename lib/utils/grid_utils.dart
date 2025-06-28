// lib/utils/grid_utils.dart

import 'package:flutter/material.dart';

const double gridSize = 20.0; // Define your grid size here (e.g., 20.0 pixels)

Offset snapToGrid(Offset position) {
  // Calculate snapped X coordinate
  double snappedX = (position.dx / gridSize).round() * gridSize;
  // Calculate snapped Y coordinate
  double snappedY = (position.dy / gridSize).round() * gridSize;

  return Offset(snappedX, snappedY);
}

// Optional: Function to get a size for equipment that's also grid-aligned
Size getGridAlignedSize(double width, double height) {
  double alignedWidth = (width / gridSize).ceil() * gridSize;
  double alignedHeight = (height / gridSize).ceil() * gridSize;
  return Size(alignedWidth, alignedHeight);
}
