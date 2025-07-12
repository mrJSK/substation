// lib/widgets/sld_edge_widget.dart
import 'dart:math'; // For min function
import 'dart:ui' as ui; // Import dart:ui with a prefix to avoid conflicts
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/sld_models.dart';
import '../state_management/sld_editor_state.dart';
import '../utils/snackbar_utils.dart'; // For showing messages

class SldEdgeWidget extends StatelessWidget {
  final SldEdge edge;
  final SldNode sourceNode;
  final SldNode targetNode;

  const SldEdgeWidget({
    Key? key,
    required this.edge,
    required this.sourceNode,
    required this.targetNode,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Get the current theme's color scheme
    final colorScheme = Theme.of(context).colorScheme;

    // Use Consumer to react to selection changes and interaction mode
    return Consumer<SldEditorState>(
      builder: (context, sldState, child) {
        final isSelected =
            sldState.sldData?.selectedElementIds.contains(edge.id) ?? false;
        final isDrawingConnection =
            sldState.interactionMode == SldInteractionMode.drawConnection;
        final isSourceOfDrawing =
            isDrawingConnection &&
            sldState.drawingSourceNodeId == sourceNode.id &&
            sldState.drawingSourceConnectionPointId ==
                edge.sourceConnectionPointId;

        // Determine actual line color
        Color currentLineColor = edge.lineColor;
        if (isSelected) {
          currentLineColor = colorScheme.tertiary; // Highlight selected edge
        } else if (isSourceOfDrawing) {
          currentLineColor =
              colorScheme.secondary; // Indicate active drawing path
        } else if (colorScheme.brightness == Brightness.dark &&
            currentLineColor == Colors.black) {
          currentLineColor =
              colorScheme.onSurface; // Adjust default black for dark mode
        }

        // Retrieve the local offsets of the connection points on their respective nodes
        final SldConnectionPoint? sourcePoint =
            sourceNode.connectionPoints[edge.sourceConnectionPointId];
        final SldConnectionPoint? targetPoint =
            targetNode.connectionPoints[edge.targetConnectionPointId];

        // Fallback to node center if connection point is not found (should not happen with good data)
        final Offset startPointGlobal =
            sourceNode.position +
            (sourcePoint?.localOffset ??
                Offset(sourceNode.size.width / 2, sourceNode.size.height / 2));
        final Offset endPointGlobal =
            targetNode.position +
            (targetPoint?.localOffset ??
                Offset(targetNode.size.width / 2, targetNode.size.height / 2));

        return GestureDetector(
          onTap: () {
            // If in drawing mode, don't select edge, but rather complete connection if applicable
            if (isDrawingConnection) {
              // Potentially allow clicking on an existing edge to re-route or branch,
              // but for now, we'll just cancel drawing if an edge is tapped directly.
              SnackBarUtils.showSnackBar(
                context,
                'Tapped on existing connection. Drawing cancelled.',
              );
              sldState.cancelDrawingConnection();
            } else {
              sldState.selectElement(edge.id);
            }
          },
          onLongPress: () {
            // Context menu for edge operations (e.g., delete, edit properties)
            _showEdgeContextMenu(context, sldState, edge);
          },
          // Use a CustomPaint to draw the connection line
          child: CustomPaint(
            // Ensure the CustomPaint covers a large enough area to draw the line
            // without clipping, considering potential canvas transforms.
            // Using MediaQuery size for now, but a more precise bounding box could be calculated.
            size: Size(
              MediaQuery.of(context).size.width,
              MediaQuery.of(context).size.height,
            ),
            painter: _EdgePainter(
              start: startPointGlobal,
              end: endPointGlobal,
              pathPoints: edge.pathPoints,
              lineColor: currentLineColor,
              lineWidth: isSelected
                  ? edge.lineWidth * 1.5
                  : edge.lineWidth, // Thicker if selected
              isDashed: edge.isDashed,
              lineJoin: edge.lineJoin, // Use SldLineJoin
            ),
          ),
        );
      },
    );
  }

  void _showEdgeContextMenu(
    BuildContext context,
    SldEditorState sldState,
    SldEdge edge,
  ) {
    showMenu(
      context: context,
      position: RelativeRect.fromLTRB(
        // Position the menu near the center of the edge for convenience
        (sourceNode.position.dx + targetNode.position.dx) / 2,
        (sourceNode.position.dy + targetNode.position.dy) / 2,
        (sourceNode.position.dx + targetNode.position.dx) / 2 +
            10, // Small width for menu anchor
        (sourceNode.position.dy + targetNode.position.dy) / 2 + 10,
      ),
      items: [
        const PopupMenuItem<String>(
          value: 'edit_properties',
          child: ListTile(
            leading: Icon(Icons.edit),
            title: Text('Edit Properties'),
          ),
        ),
        const PopupMenuItem<String>(
          value: 'delete',
          child: ListTile(
            leading: Icon(Icons.delete),
            title: Text('Delete Connection'),
          ),
        ),
        // Add more options like 'Toggle Status', 'Change Routing' etc.
      ],
      elevation: 8.0,
    ).then((value) {
      if (value != null) {
        switch (value) {
          case 'edit_properties':
            _showEditEdgePropertiesDialog(context, sldState, edge);
            break;
          case 'delete':
            sldState.removeElement(edge.id);
            SnackBarUtils.showSnackBar(context, 'Connection deleted.');
            break;
        }
      }
    });
  }

  void _showEditEdgePropertiesDialog(
    BuildContext context,
    SldEditorState sldState,
    SldEdge edge,
  ) {
    final TextEditingController voltageController = TextEditingController(
      text: edge.properties['voltageLevel'] ?? '',
    );
    final TextEditingController capacityController = TextEditingController(
      text: edge.properties['capacity'] ?? '',
    );
    bool isDashed = edge.isDashed;

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          // Use StatefulBuilder for dialog internal state
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Edit Connection Properties'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: voltageController,
                    decoration: const InputDecoration(
                      labelText: 'Voltage Level (kV)',
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  TextField(
                    controller: capacityController,
                    decoration: const InputDecoration(
                      labelText: 'Capacity (MVA)',
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  Row(
                    children: [
                      const Text('Is Dashed Line?'),
                      Switch(
                        value: isDashed,
                        onChanged: (newValue) {
                          setState(() {
                            // Update dialog's internal state
                            isDashed = newValue;
                          });
                        },
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    // Update properties including the `isDashed` property
                    sldState.updateElementProperties(edge.id, {
                      'voltageLevel': voltageController.text,
                      'capacity': capacityController.text,
                      'isDashed': isDashed,
                    });
                    // You might also need to explicitly update the SldEdge object's `isDashed` field
                    // if it's not entirely derived from the `properties` map,
                    // by calling a specific update method in SldEditorState.
                    // For now, assuming `isDashed` is managed directly as a field on SldEdge.
                    // The `SldEditorState.updateElementProperties` should ideally handle updating
                    // both the generic `properties` map and specific fields like `isDashed`.
                    // A more robust way might be to have a `updateEdgeStyle` method in SldEditorState.

                    Navigator.of(dialogContext).pop();
                    SnackBarUtils.showSnackBar(
                      context,
                      'Connection properties updated.',
                    );
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

/// CustomPainter to draw the actual edge line.
class _EdgePainter extends CustomPainter {
  final Offset start;
  final Offset end;
  final List<Offset> pathPoints; // For complex routing
  final Color lineColor;
  final double lineWidth;
  final bool isDashed;
  final SldLineJoin lineJoin; // Use SldLineJoin

  _EdgePainter({
    required this.start,
    required this.end,
    this.pathPoints = const [],
    required this.lineColor,
    required this.lineWidth,
    required this.isDashed,
    required this.lineJoin, // Use SldLineJoin
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = lineColor
      ..strokeWidth = lineWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap
          .round // Round caps for line ends
      ..strokeJoin = _mapSldLineJoinToStrokeJoin(
        lineJoin,
      ); // Map SldLineJoin to ui.StrokeJoin

    final Path path = Path();
    path.moveTo(start.dx, start.dy);

    if (pathPoints.isNotEmpty) {
      // Draw with intermediate path points for routing
      for (var point in pathPoints) {
        path.lineTo(point.dx, point.dy);
      }
    }
    path.lineTo(end.dx, end.dy);

    if (isDashed) {
      // Implement dashed line drawing (simplified example, needs refinement for complex paths)
      _drawDashedLine(canvas, path, paint);
    } else {
      canvas.drawPath(path, paint);
    }

    // Optionally draw arrows or other indicators
    // _drawArrowHead(canvas, end, pathPoints.isNotEmpty ? pathPoints.last : start, paint);
  }

  // Helper for drawing dashed lines
  void _drawDashedLine(Canvas canvas, ui.Path path, Paint paint) {
    const double dashWidth = 8.0;
    const double dashSpace = 4.0;
    double currentLength = 0;

    final ui.PathMetrics pathMetrics = path
        .computeMetrics(); // Use ui.PathMetrics
    for (final ui.PathMetric metric in pathMetrics) {
      // Use ui.PathMetric
      double distance = 0.0;
      while (distance < metric.length) {
        final double start = distance;
        final double end = min(distance + dashWidth, metric.length);
        canvas.drawPath(metric.extractPath(start, end), paint);
        distance += dashWidth + dashSpace;
      }
    }
  }

  // Helper to map our custom SldLineJoin enum to Flutter's ui.StrokeJoin
  ui.StrokeJoin _mapSldLineJoinToStrokeJoin(SldLineJoin sldLineJoin) {
    switch (sldLineJoin) {
      case SldLineJoin.miter:
        return ui.StrokeJoin.miter;
      case SldLineJoin.round:
        return ui.StrokeJoin.round;
      case SldLineJoin.bevel:
        return ui.StrokeJoin.bevel;
    }
  }

  // Optional: Function to draw arrow head (can be expanded)
  // void _drawArrowHead(Canvas canvas, Offset point, Offset previousPoint, Paint paint) {
  //   const double arrowSize = 8;
  //   final double angle = atan2(point.dy - previousPoint.dy, point.dx - previousPoint.dx);
  //   final path = Path();
  //   path.moveTo(point.dx, point.dy);
  //   path.lineTo(
  //     point.dx - arrowSize * cos(angle + pi / 6),
  //     point.dy - arrowSize * sin(angle + pi / 6),
  //   );
  //   path.lineTo(
  //     point.dx - arrowSize * cos(angle - pi / 6),
  //     point.dy - arrowSize * sin(angle - pi / 6),
  //   );
  //   path.close();
  //   canvas.drawPath(path, paint);
  // }

  @override
  bool shouldRepaint(covariant _EdgePainter oldDelegate) {
    // Repaint if any relevant property changes
    return oldDelegate.start != start ||
        oldDelegate.end != end ||
        oldDelegate.pathPoints !=
            pathPoints || // Checks list identity, consider deep equality for actual points
        oldDelegate.lineColor != lineColor ||
        oldDelegate.lineWidth != lineWidth ||
        oldDelegate.isDashed != isDashed ||
        oldDelegate.lineJoin != lineJoin;
  }
}
