// lib/widgets/sld_node_widget.dart
import 'dart:math'; // Import for min function if needed
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/sld_models.dart';
import '../state_management/sld_editor_state.dart';
import '../utils/snackbar_utils.dart'; // Import SnackBarUtils

// Import all your equipment icon painters here.
// Make sure these painters (and their base class EquipmentPainter) accept a ColorScheme.
import '../equipment_icons/transformer_icon.dart';
import '../equipment_icons/busbar_icon.dart';
import '../equipment_icons/circuit_breaker_icon.dart';
import '../equipment_icons/ct_icon.dart';
import '../equipment_icons/disconnector_icon.dart';
import '../equipment_icons/ground_icon.dart';
import '../equipment_icons/isolator_icon.dart';
import '../equipment_icons/line_icon.dart';
import '../equipment_icons/pt_icon.dart';
import '../equipment_icons/feeder_icon.dart';
// Add other custom icon painters as needed

class SldNodeWidget extends StatelessWidget {
  final SldNode node;

  const SldNodeWidget({Key? key, required this.node}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final sldState = Provider.of<SldEditorState>(context, listen: false);
    final colorScheme = Theme.of(context).colorScheme;

    // Determine the painter for the node's main shape or custom icon
    CustomPainter? nodePainter;
    final Size equipmentDrawingSize = node.size; // Use node's size for drawing

    if (node.nodeShape == SldNodeShape.custom &&
        node.properties['equipmentType'] != null) {
      // Use equipmentType property to select the correct painter
      // Pass colorScheme, equipmentSize, and symbolSize to all painters
      switch (node.properties['equipmentType']) {
        case 'Transformer':
          nodePainter = TransformerIconPainter(
            color: colorScheme.onSurface, // Or a specific icon color
            equipmentSize: equipmentDrawingSize,
            symbolSize: equipmentDrawingSize, // Pass node's size as symbol size
          );
          break;
        case 'Busbar':
          nodePainter = BusbarIconPainter(
            color: colorScheme.onSurface,
            equipmentSize: equipmentDrawingSize,
            symbolSize: equipmentDrawingSize,
            voltageText:
                node.properties['voltage'] ?? '', // Example: pass voltage text
          );
          break;
        case 'Circuit Breaker':
          nodePainter = CircuitBreakerIconPainter(
            color: colorScheme.onSurface,
            equipmentSize: equipmentDrawingSize,
            symbolSize: equipmentDrawingSize,
          );
          break;
        case 'Current Transformer':
          nodePainter = CurrentTransformerIconPainter(
            color: colorScheme.onSurface,
            equipmentSize: equipmentDrawingSize,
            symbolSize: equipmentDrawingSize,
          );
          break;
        case 'Disconnector':
          nodePainter = DisconnectorIconPainter(
            color: colorScheme.onSurface,
            equipmentSize: equipmentDrawingSize,
            symbolSize: equipmentDrawingSize,
          );
          break;
        case 'Earth Switch': // Assuming 'Ground' is 'Earth Switch'
          nodePainter = GroundIconPainter(
            color: colorScheme.onSurface,
            equipmentSize: equipmentDrawingSize,
            symbolSize: equipmentDrawingSize,
          );
          break;
        case 'Isolator':
          nodePainter = IsolatorIconPainter(
            color: colorScheme.onSurface,
            equipmentSize: equipmentDrawingSize,
            symbolSize: equipmentDrawingSize,
          );
          break;
        case 'Line':
          nodePainter = LineIconPainter(
            color: colorScheme.onSurface,
            equipmentSize: equipmentDrawingSize,
            symbolSize: equipmentDrawingSize,
          );
          break;
        case 'Potential Transformer':
          nodePainter = PotentialTransformerIconPainter(
            color: colorScheme.onSurface,
            equipmentSize: equipmentDrawingSize,
            symbolSize: equipmentDrawingSize,
          );
          break;
        case 'Feeder':
          nodePainter = FeederIconPainter(
            color: colorScheme.onSurface,
            equipmentSize: equipmentDrawingSize,
            symbolSize: equipmentDrawingSize,
          );
          break;
        default:
          nodePainter = null; // Fallback to generic painter if type not found
      }
    } else if (node.nodeShape == SldNodeShape.busbar) {
      nodePainter = BusbarIconPainter(
        color: colorScheme.onSurface,
        equipmentSize: equipmentDrawingSize,
        symbolSize: equipmentDrawingSize,
        voltageText: node.properties['voltage'] ?? '',
      );
    }

    // Generic painter for rectangle/circle or if custom painter not found
    if (nodePainter == null) {
      nodePainter = _GenericShapePainter(
        node: node,
        isSelected: false, // Selection handled by border, not painter fill
        colorScheme: colorScheme,
      );
    }

    // Use Consumer to react to selection changes only
    return Consumer<SldEditorState>(
      builder: (context, sldState, child) {
        // We only care about selection status here to rebuild the border
        final isSelected =
            sldState.sldData?.selectedElementIds.contains(node.id) ?? false;
        final isDrawingConnection =
            sldState.interactionMode == SldInteractionMode.drawConnection;
        final isSourceNode = sldState.drawingSourceNodeId == node.id;

        return GestureDetector(
          // Drag gesture for moving the node
          onPanUpdate: (details) {
            if (sldState.interactionMode == SldInteractionMode.select) {
              // Adjust position based on zoom level
              final currentZoom = sldState.sldData?.currentZoom ?? 1.0;
              sldState.moveNode(
                node.id,
                node.position + details.delta / currentZoom,
              );
            }
          },
          // Tap gesture for selection
          onTap: () {
            if (isDrawingConnection) {
              // If in connection drawing mode, attempt to complete connection
              if (sldState.drawingSourceNodeId != node.id) {
                // Cannot connect a node to itself
                _showConnectionPointPicker(context, sldState, node);
              } else {
                SnackBarUtils.showSnackBar(
                  context,
                  'Cannot connect a node to itself.',
                  isError: true,
                );
                sldState.cancelDrawingConnection(); // Cancel drawing
              }
            } else {
              sldState.selectElement(node.id);
            }
          },
          // Long press for context menu (e.g., delete, edit properties, start connection)
          onLongPress: () {
            _showNodeContextMenu(context, sldState, node);
          },
          child: Container(
            width: node.size.width,
            height: node.size.height,
            decoration: BoxDecoration(
              border: isSelected
                  ? Border.all(
                      color: colorScheme.tertiary,
                      width: 2,
                    ) // Highlight selected node
                  : (isDrawingConnection &&
                        !isSourceNode) // Highlight potential target in connection mode
                  ? Border.all(
                      color: colorScheme.secondary.withOpacity(0.5),
                      width: 1,
                    )
                  : null,
            ),
            child: Stack(
              children: [
                // Main node shape/icon
                CustomPaint(size: node.size, painter: nodePainter),
                // Node Name / Label
                Positioned(
                  top: 5,
                  left: 0,
                  right: 0,
                  child: Text(
                    node.properties['name'] ?? 'Untitled',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: isSelected
                          ? colorScheme.tertiary
                          : colorScheme.onSurface,
                      fontSize: 12,
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                // Display Energy Data (example)
                if (node.properties.containsKey('energyReading'))
                  Positioned(
                    bottom: 5,
                    left: 0,
                    right: 0,
                    child: Text(
                      '${(node.properties['energyReading'] as num).toStringAsFixed(2)} kWh',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: colorScheme.secondary,
                        fontSize: 10,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                // Visual indicators for connection points (optional, for debugging/clarity)
                // if (isSelected || (isDrawingConnection && isSourceNode))
                //   ...node.connectionPoints.values.map((cp) {
                //     return Positioned(
                //       left: cp.localOffset.dx - 3,
                //       top: cp.localOffset.dy - 3,
                //       child: Container(
                //         width: 6,
                //         height: 6,
                //         decoration: BoxDecoration(
                //           color: isSourceNode ? Colors.red : Colors.green,
                //           shape: BoxShape.circle,
                //           border: Border.all(color: Colors.white, width: 1),
                //         ),
                //       ),
                //     );
                //   }).toList(),
              ],
            ),
          ),
        );
      },
    );
  }

  // --- Context Menu for Node Operations ---
  void _showNodeContextMenu(
    BuildContext context,
    SldEditorState sldState,
    SldNode node,
  ) {
    showMenu(
      context: context,
      position: RelativeRect.fromLTRB(
        node.position.dx,
        node.position.dy,
        node.position.dx + node.size.width,
        node.position.dy + node.size.height,
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
          value: 'start_connection',
          child: ListTile(
            leading: Icon(Icons.link),
            title: Text('Start Connection'),
          ),
        ),
        const PopupMenuItem<String>(
          value: 'delete',
          child: ListTile(
            leading: Icon(Icons.delete),
            title: Text('Delete Node'),
          ),
        ),
      ],
      elevation: 8.0,
    ).then((value) {
      if (value != null) {
        switch (value) {
          case 'edit_properties':
            // Implement a dialog to edit node properties (e.g., name, voltage)
            _showEditPropertiesDialog(context, sldState, node);
            break;
          case 'start_connection':
            // Prompt user to select a connection point
            _showConnectionPointPicker(context, sldState, node, isSource: true);
            break;
          case 'delete':
            sldState.removeElement(node.id);
            SnackBarUtils.showSnackBar(context, 'Node deleted.');
            break;
        }
      }
    });
  }

  // --- Dialog for picking connection points (used for both source and target) ---
  void _showConnectionPointPicker(
    BuildContext context,
    SldEditorState sldState,
    SldNode node, {
    bool isSource = false,
  }) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        if (node.connectionPoints.isEmpty) {
          return AlertDialog(
            title: const Text('No Connection Points'),
            content: Text(
              'This node (${node.properties['name'] ?? 'Untitled'}) has no defined connection points.',
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(dialogContext).pop();
                  if (isSource)
                    sldState
                        .cancelDrawingConnection(); // Cancel if starting connection
                },
                child: const Text('OK'),
              ),
            ],
          );
        }

        return AlertDialog(
          title: Text(
            '${isSource ? 'Select Source' : 'Select Target'} Connection Point for ${node.properties['name'] ?? 'Untitled'}',
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: node.connectionPoints.values.map((cp) {
                return ListTile(
                  title: Text(cp.id), // Display connection point ID/name
                  subtitle: Text(
                    '(${cp.localOffset.dx.toStringAsFixed(1)}, ${cp.localOffset.dy.toStringAsFixed(1)}) - ${cp.direction.name}',
                  ),
                  onTap: () {
                    Navigator.of(dialogContext).pop();
                    if (isSource) {
                      sldState.startDrawingConnection(node.id, cp.id);
                    } else {
                      // Complete connection if this is the target node
                      sldState.completeDrawingConnection(node.id, cp.id);
                    }
                  },
                );
              }).toList(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                if (isSource)
                  sldState
                      .cancelDrawingConnection(); // Cancel if user backs out of source selection
              },
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  // --- Dialog for editing node properties (simple example) ---
  void _showEditPropertiesDialog(
    BuildContext context,
    SldEditorState sldState,
    SldNode node,
  ) {
    final TextEditingController nameController = TextEditingController(
      text: node.properties['name'] ?? '',
    );
    final TextEditingController voltageController = TextEditingController(
      text: node.properties['voltage'] ?? '',
    );

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Edit Node Properties'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              TextField(
                controller: voltageController,
                decoration: const InputDecoration(labelText: 'Voltage (kV)'),
                keyboardType: TextInputType.number,
              ),
              // Add more fields for other properties as needed
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                sldState.updateElementProperties(node.id, {
                  'name': nameController.text,
                  'voltage': voltageController.text,
                });
                Navigator.of(dialogContext).pop();
                SnackBarUtils.showSnackBar(context, 'Node properties updated.');
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }
}

// --- Generic Painter for basic shapes (Rectangle, Circle) ---
// This painter will be used if node.nodeShape is not SldNodeShape.custom or busbar
class _GenericShapePainter extends CustomPainter {
  final SldNode node;
  final bool isSelected;
  final ColorScheme colorScheme;

  _GenericShapePainter({
    required this.node,
    required this.isSelected,
    required this.colorScheme,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final isDarkMode = colorScheme.brightness == Brightness.dark;

    final paint = Paint()
      ..style = PaintingStyle.fill
      ..color =
          node.fillColor ??
          (isDarkMode
              ? colorScheme.surfaceVariant
              : Colors.grey.shade200); // Default fill based on theme

    final strokePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = node.strokeWidth
      ..color =
          node.strokeColor ??
          (isDarkMode
              ? colorScheme.onSurface
              : Colors.black87); // Default stroke based on theme

    // Draw shape
    switch (node.nodeShape) {
      case SldNodeShape.rectangle:
        final rect = Rect.fromLTWH(0, 0, size.width, size.height);
        canvas.drawRect(rect, paint);
        canvas.drawRect(rect, strokePaint);
        break;
      case SldNodeShape.circle:
        final center = Offset(size.width / 2, size.height / 2);
        final radius = min(size.width, size.height) / 2;
        canvas.drawCircle(center, radius, paint);
        canvas.drawCircle(center, radius, strokePaint);
        break;
      case SldNodeShape.busbar:
        // Busbar is handled by BusbarIconPainter, this case should ideally not be reached
        // or can draw a generic thick line.
        final busbarPaint = Paint()
          ..color = strokePaint.color
          ..strokeWidth =
              8.0 // Thicker line for busbar
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.butt;
        canvas.drawLine(
          Offset(0, size.height / 2),
          Offset(size.width, size.height / 2),
          busbarPaint,
        );
        break;
      case SldNodeShape.custom:
        // This should be handled by a specific equipment painter, not here.
        // Draw a placeholder if no custom painter is provided or matched.
        final placeholderPaint = Paint()
          ..color = Colors.red.withOpacity(0.5)
          ..style = PaintingStyle.fill;
        canvas.drawRect(
          Rect.fromLTWH(0, 0, size.width, size.height),
          placeholderPaint,
        );
        TextPainter(
            text: const TextSpan(
              text: '?',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            textDirection: TextDirection.ltr,
            textAlign: TextAlign.center,
          )
          ..layout(minWidth: size.width)
          ..paint(canvas, Offset(0, size.height / 2 - 12));
        break;
    }
  }

  @override
  bool shouldRepaint(covariant _GenericShapePainter oldDelegate) {
    // Only repaint if node properties (that affect drawing) or selection changes
    return oldDelegate.node != node ||
        oldDelegate.isSelected != isSelected ||
        oldDelegate.colorScheme != colorScheme;
  }
}
