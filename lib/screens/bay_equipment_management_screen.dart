import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:substation_manager/models/equipment_model.dart';
import 'package:substation_manager/models/user_model.dart';
import '../utils/snackbar_utils.dart';
import 'equipment_assignment_screen.dart'; // For adding and editing equipment
import 'dart:math'; // For min/max
import '../models/bay_model.dart'; // Import Bay model
import 'package:vector_math/vector_math_64.dart'
    show Matrix4; // Make sure this import is present

// Import all your equipment icon painters
import '../../equipment_icons/transformer_icon.dart';
import '../../equipment_icons/busbar_icon.dart';
import '../../equipment_icons/circuit_breaker_icon.dart';
import '../../equipment_icons/ct_icon.dart';
import '../../equipment_icons/disconnector_icon.dart';
import '../../equipment_icons/ground_icon.dart';
import '../../equipment_icons/isolator_icon.dart';
import '../../equipment_icons/pt_icon.dart';
import '../../equipment_icons/line_icon.dart';
import '../../equipment_icons/feeder_icon.dart';

// --- Data structure for rendering equipment on canvas ---
class EquipmentRenderData {
  final EquipmentInstance equipment;
  final Rect rect;
  final Offset center;
  final Offset topCenter;
  final Offset bottomCenter;

  EquipmentRenderData({
    required this.equipment,
    required this.rect,
    required this.center,
    required this.topCenter,
    required this.bottomCenter,
  });
}

// --- CustomPainter for drawing equipment within a single bay ---
class BayEquipmentDiagramPainter extends CustomPainter {
  final List<EquipmentRenderData> equipmentRenderDataList;
  final String? selectedEquipmentId; // To highlight selected equipment
  final bool debugDrawHitboxes;
  final String bayType; // Pass bay type to painter for specific drawing
  final String? transformerId; // Pass transformer ID if it's a transformer bay

  BayEquipmentDiagramPainter({
    required this.equipmentRenderDataList,
    this.selectedEquipmentId,
    this.debugDrawHitboxes = false,
    required this.bayType, // Required
    this.transformerId, // Optional
  });

  // Helper to get CustomPainter for equipment symbol (similar to SLD screen)
  CustomPainter _getSymbolPainter(String symbolKey, Color color, Size size) {
    switch (symbolKey.toLowerCase()) {
      case 'transformer':
        return TransformerIconPainter(
          color: color,
          equipmentSize: size,
          symbolSize: size,
        );
      case 'circuit breaker':
        return CircuitBreakerIconPainter(
          color: color,
          equipmentSize: size,
          symbolSize: size,
        );
      case 'current transformer':
      case 'ct':
        return CurrentTransformerIconPainter(
          color: color,
          equipmentSize: size,
          symbolSize: size,
        );
      case 'disconnector':
        return DisconnectorIconPainter(
          color: color,
          equipmentSize: size,
          symbolSize: size,
        );
      case 'ground':
        return GroundIconPainter(
          color: color,
          equipmentSize: size,
          symbolSize: size,
        );
      case 'isolator':
        return IsolatorIconPainter(
          color: color,
          equipmentSize: size,
          symbolSize: size,
        );
      case 'voltage transformer':
      case 'pt':
        return PotentialTransformerIconPainter(
          color: color,
          equipmentSize: size,
          symbolSize: size,
        );
      case 'line':
        return LineIconPainter(
          color: color,
          equipmentSize: size,
          symbolSize: size,
        );
      case 'feeder':
        return FeederIconPainter(
          color: color,
          equipmentSize: size,
          symbolSize: size,
        );
      case 'busbar':
        return BusbarIconPainter(
          color: color,
          equipmentSize: size,
          symbolSize: size,
        );
      default:
        return _GenericIconPainter(color: color); // Generic placeholder
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = Colors.black87
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    // Separate lists for equipment above and below transformer
    List<EquipmentRenderData> equipmentAboveTransformer = [];
    EquipmentRenderData? transformerRenderData;
    List<EquipmentRenderData> equipmentBelowTransformer = [];

    // Filter and assign equipment for Transformer bay layout
    if (bayType == 'Transformer' && transformerId != null) {
      for (var renderData in equipmentRenderDataList) {
        if (renderData.equipment.id == transformerId) {
          transformerRenderData = renderData;
        } else if (renderData.equipment.positionIndex! <
            (transformerRenderData?.equipment.positionIndex ?? -1)) {
          equipmentAboveTransformer.add(renderData);
        } else {
          equipmentBelowTransformer.add(renderData);
        }
      }
      // Sort equipment in each section
      equipmentAboveTransformer.sort(
        (a, b) =>
            b.equipment.positionIndex!.compareTo(a.equipment.positionIndex!),
      ); // Reverse order for 'above'
      equipmentBelowTransformer.sort(
        (a, b) =>
            a.equipment.positionIndex!.compareTo(b.equipment.positionIndex!),
      );
    }

    // Draw symbols and labels
    for (var renderData in equipmentRenderDataList) {
      final equipment = renderData.equipment;
      final rect = renderData.rect;
      final bool isSelected = equipment.id == selectedEquipmentId;

      final Color symbolColor = isSelected
          ? Colors.green.shade700
          : Colors.black87;
      final Paint borderPaint = Paint()
        ..color = isSelected ? Colors.green.shade700 : Colors.transparent
        ..strokeWidth = 2.0
        ..style = PaintingStyle.stroke;

      // Draw border if selected
      if (isSelected) {
        canvas.drawRect(
          rect.inflate(4.0),
          borderPaint,
        ); // Draw a slightly larger border
      }

      final painter = _getSymbolPainter(
        equipment.symbolKey,
        symbolColor,
        rect.size,
      );
      canvas.save();
      canvas.translate(rect.topLeft.dx, rect.topLeft.dy);
      painter.paint(canvas, rect.size);
      canvas.restore();

      // Draw label below the symbol
      _drawText(
        canvas,
        equipment.equipmentTypeName,
        rect.bottomCenter,
        offsetY: 4,
      );

      // Draw debug hitbox if enabled
      if (debugDrawHitboxes) {
        final debugPaint = Paint()
          ..color = Colors.red.withOpacity(0.3)
          ..style = PaintingStyle.fill;
        canvas.drawRect(rect, debugPaint);
      }
    }

    // Draw connections based on bay type
    if (bayType == 'Transformer' && transformerRenderData != null) {
      // Connect first equipment above to transformer HV side
      if (equipmentAboveTransformer.isNotEmpty) {
        canvas.drawLine(
          equipmentAboveTransformer
              .first
              .topCenter, // Line from top of first item above
          Offset(
            equipmentAboveTransformer.first.topCenter.dx,
            0,
          ), // To top edge
          linePaint,
        );
        canvas.drawLine(
          equipmentAboveTransformer.first.bottomCenter,
          transformerRenderData.topCenter,
          linePaint,
        );
      } else {
        // Draw small line if no equipment above
        canvas.drawLine(
          Offset(transformerRenderData.topCenter.dx, 0),
          transformerRenderData.topCenter,
          linePaint,
        );
      }

      // Connect transformer LV side to first equipment below
      if (equipmentBelowTransformer.isNotEmpty) {
        canvas.drawLine(
          transformerRenderData.bottomCenter,
          equipmentBelowTransformer.first.topCenter,
          linePaint,
        );
        canvas.drawLine(
          equipmentBelowTransformer
              .last
              .bottomCenter, // Line from bottom of last item below
          Offset(
            equipmentBelowTransformer.last.bottomCenter.dx,
            size.height,
          ), // To bottom edge
          linePaint,
        );
      } else {
        // Draw small line if no equipment below
        canvas.drawLine(
          transformerRenderData.bottomCenter,
          Offset(transformerRenderData.bottomCenter.dx, size.height),
          linePaint,
        );
      }

      // Draw lines between equipment within 'above' section
      for (int i = 0; i < equipmentAboveTransformer.length - 1; i++) {
        canvas.drawLine(
          equipmentAboveTransformer[i].bottomCenter,
          equipmentAboveTransformer[i + 1].topCenter,
          linePaint,
        );
      }
      // Draw lines between equipment within 'below' section
      for (int i = 0; i < equipmentBelowTransformer.length - 1; i++) {
        canvas.drawLine(
          equipmentBelowTransformer[i].bottomCenter,
          equipmentBelowTransformer[i + 1].topCenter,
          linePaint,
        );
      }
    } else {
      // For other bay types (Feeder, Line, etc.)
      // Draw connection lines between consecutive equipment
      // and small lines at the very top and bottom of the overall equipment chain
      if (equipmentRenderDataList.isNotEmpty) {
        // Line extending from the top of the first equipment
        final firstEquipmentTopCenter = equipmentRenderDataList.first.topCenter;
        canvas.drawLine(
          Offset(firstEquipmentTopCenter.dx, 0), // Start from canvas top
          firstEquipmentTopCenter,
          linePaint,
        );

        // Lines between equipment
        for (int i = 0; i < equipmentRenderDataList.length - 1; i++) {
          final source = equipmentRenderDataList[i];
          final target = equipmentRenderDataList[i + 1];
          canvas.drawLine(source.bottomCenter, target.topCenter, linePaint);
        }

        // Line extending from the bottom of the last equipment
        final lastEquipmentBottomCenter =
            equipmentRenderDataList.last.bottomCenter;
        canvas.drawLine(
          lastEquipmentBottomCenter,
          Offset(
            lastEquipmentBottomCenter.dx,
            size.height,
          ), // Extend to canvas bottom
          linePaint,
        );
      }
    }
  }

  void _drawText(
    Canvas canvas,
    String text,
    Offset position, {
    double offsetY = 0,
  }) {
    final textStyle = TextStyle(
      color: Colors.black87,
      fontSize: 10,
      fontWeight: FontWeight.normal,
    );
    final textSpan = TextSpan(text: text, style: textStyle);
    final textPainter = TextPainter(
      text: textSpan,
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    );
    textPainter.layout(maxWidth: 80); // Limit width to prevent overlap
    textPainter.paint(
      canvas,
      Offset(position.dx - textPainter.width / 2, position.dy + offsetY),
    );
  }

  @override
  bool shouldRepaint(covariant BayEquipmentDiagramPainter oldDelegate) {
    // Repaint if the list of equipment or selected equipment or bay type changes
    return oldDelegate.equipmentRenderDataList != equipmentRenderDataList ||
        oldDelegate.selectedEquipmentId != selectedEquipmentId ||
        oldDelegate.bayType != bayType ||
        oldDelegate.transformerId != transformerId;
  }
}

// Generic painter for unknown symbols (copied from MasterEquipmentScreen example)
class _GenericIconPainter extends CustomPainter {
  final Color color;
  _GenericIconPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    final double centerX = size.width / 2;
    final double centerY = size.height / 2;
    final double halfWidth = size.width / 3;
    final double halfHeight = size.height / 3;
    canvas.drawRect(
      Rect.fromCenter(
        center: Offset(centerX, centerY),
        width: halfWidth * 2,
        height: halfHeight * 2,
      ),
      paint,
    );
    canvas.drawLine(
      Offset(centerX - halfWidth, centerY - halfHeight),
      Offset(centerX + halfWidth, centerY + halfHeight),
      paint,
    );
    canvas.drawLine(
      Offset(centerX + halfWidth, centerY - halfHeight),
      Offset(centerX - halfWidth, centerY + halfHeight),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _GenericIconPainter oldDelegate) =>
      oldDelegate.color != color;
}

class BayEquipmentManagementScreen extends StatefulWidget {
  final String bayId;
  final String bayName;
  final String substationId;
  final AppUser currentUser;

  const BayEquipmentManagementScreen({
    super.key,
    required this.bayId,
    required this.bayName,
    required this.substationId,
    required this.currentUser,
  });

  @override
  State<BayEquipmentManagementScreen> createState() =>
      _BayEquipmentManagementScreenState();
}

class _BayEquipmentManagementScreenState
    extends State<BayEquipmentManagementScreen> {
  bool _isLoading = true;
  List<EquipmentInstance> _equipmentInstances = [];
  final TransformationController _transformationController =
      TransformationController();
  Matrix4 _currentInverseMatrix = Matrix4.identity();
  String? _selectedEquipmentId;
  static const double _movementStep = 20.0;
  String? _bayType;
  String? _transformerEquipmentId;

  @override
  void initState() {
    super.initState();
    _fetchBayAndEquipmentDetails();
    _transformationController.value = Matrix4.identity();
    _currentInverseMatrix = _transformationController.value.clone();
    _transformationController.addListener(_updateInverseMatrix);
  }

  void _updateInverseMatrix() {
    final inverse = _transformationController.value.clone();
    if (inverse.invert() != 0) {
      setState(() {
        _currentInverseMatrix = inverse;
      });
    }
  }

  @override
  void dispose() {
    _transformationController.removeListener(_updateInverseMatrix);
    _transformationController.dispose();
    super.dispose();
  }

  Future<void> _fetchBayAndEquipmentDetails() async {
    setState(() {
      _isLoading = true;
      _selectedEquipmentId = null;
      _transformerEquipmentId = null;
    });
    try {
      // Fetch bay details to get its type
      final bayDoc = await FirebaseFirestore.instance
          .collection('bays')
          .doc(widget.bayId)
          .get();
      if (bayDoc.exists) {
        _bayType = (bayDoc.data() as Map<String, dynamic>)['bayType'];
      } else {
        if (mounted) {
          SnackBarUtils.showSnackBar(
            context,
            'Error: Bay not found.',
            isError: true,
          );
          Navigator.of(context).pop();
        }
        return;
      }

      // Fetch equipment instances for this bay
      final snapshot = await FirebaseFirestore.instance
          .collection('equipmentInstances')
          .where('bayId', isEqualTo: widget.bayId)
          .orderBy('positionIndex', descending: false)
          .orderBy('createdAt', descending: false)
          .get();

      _equipmentInstances = snapshot.docs
          .map((doc) => EquipmentInstance.fromFirestore(doc))
          .toList();

      // For Transformer bays, identify the actual Transformer equipment
      if (_bayType == 'Transformer') {
        _transformerEquipmentId = _equipmentInstances
            .firstWhereOrNull(
              (eq) =>
                  eq.equipmentTypeName == 'Transformer' ||
                  eq.symbolKey == 'Transformer',
            )
            ?.id;
      }

      // Assign default positionIndex if null and ensure sequential indexing
      bool needsReindex = false;
      for (int i = 0; i < _equipmentInstances.length; i++) {
        if (_equipmentInstances[i].positionIndex == null ||
            _equipmentInstances[i].positionIndex != i) {
          _equipmentInstances[i] = _equipmentInstances[i].copyWith(
            positionIndex: i,
          );
          needsReindex = true;
        }
      }

      if (needsReindex) {
        await _updateEquipmentPositionsInFirestore(_equipmentInstances);
      }
    } catch (e) {
      print("Error fetching bay and equipment details: $e");
      if (mounted) {
        SnackBarUtils.showSnackBar(
          context,
          'Failed to load details: $e',
          isError: true,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Updates positionIndex for a list of equipment instances in Firestore
  Future<void> _updateEquipmentPositionsInFirestore(
    List<EquipmentInstance> instances,
  ) async {
    final batch = FirebaseFirestore.instance.batch();
    for (int i = 0; i < instances.length; i++) {
      final updatedInstance = instances[i].copyWith(positionIndex: i);
      batch.update(
        FirebaseFirestore.instance
            .collection('equipmentInstances')
            .doc(updatedInstance.id),
        {'positionIndex': updatedInstance.positionIndex},
      );
    }
    try {
      await batch.commit();
      SnackBarUtils.showSnackBar(context, 'Equipment order saved!');
    } catch (e) {
      if (mounted) {
        SnackBarUtils.showSnackBar(
          context,
          'Failed to save order: $e',
          isError: true,
        );
      }
      print("Error updating equipment positions: $e");
    }
  }

  Future<void> _confirmDeleteEquipment(
    BuildContext context,
    String equipmentId,
    String equipmentName,
  ) async {
    final bool confirm =
        await showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text('Confirm Deletion'),
              content: Text(
                'Are you sure you want to delete equipment "$equipmentName"? This action cannot be undone.',
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  child: const Text('Delete'),
                ),
              ],
            );
          },
        ) ??
        false;

    if (confirm) {
      try {
        await FirebaseFirestore.instance
            .collection('equipmentInstances')
            .doc(equipmentId)
            .delete();
        if (context.mounted) {
          SnackBarUtils.showSnackBar(
            context,
            'Equipment "$equipmentName" deleted successfully!',
          );
        }
        _fetchBayAndEquipmentDetails(); // Refresh list after deletion
      } catch (e) {
        print("Error deleting equipment: $e");
        if (context.mounted) {
          SnackBarUtils.showSnackBar(
            context,
            'Failed to delete equipment "$equipmentName": $e',
            isError: true,
          );
        }
      }
    }
  }

  void _showEquipmentActions(
    BuildContext context,
    EquipmentInstance equipment,
    Offset tapPosition,
  ) {
    final List<PopupMenuEntry<String>> menuItems = [
      const PopupMenuItem<String>(
        value: 'edit',
        child: ListTile(leading: Icon(Icons.edit), title: Text('Edit Details')),
      ),
      const PopupMenuItem<String>(
        value: 'move',
        child: ListTile(
          leading: Icon(Icons.open_with),
          title: Text('Select to Move'),
        ),
      ),
      PopupMenuItem<String>(
        value: 'delete',
        child: ListTile(
          leading: Icon(
            Icons.delete,
            color: Theme.of(context).colorScheme.error,
          ),
          title: Text(
            'Delete Equipment',
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ),
      ),
    ];

    showMenu(
      context: context,
      position: RelativeRect.fromLTRB(
        tapPosition.dx,
        tapPosition.dy,
        MediaQuery.of(context).size.width - tapPosition.dx,
        MediaQuery.of(context).size.height - tapPosition.dy,
      ),
      items: menuItems,
    ).then((value) {
      if (value == 'edit') {
        Navigator.of(context)
            .push(
              MaterialPageRoute(
                builder: (context) => EquipmentAssignmentScreen(
                  bayId: widget.bayId,
                  bayName: widget.bayName,
                  substationId: widget.substationId,
                  equipmentToEdit: equipment,
                ),
              ),
            )
            .then((_) => _fetchBayAndEquipmentDetails());
      } else if (value == 'move') {
        setState(() {
          _selectedEquipmentId = equipment.id;
        });
        SnackBarUtils.showSnackBar(
          context,
          'Selected "${equipment.equipmentTypeName}" for movement. Use controls below.',
        );
      } else if (value == 'delete') {
        _confirmDeleteEquipment(
          context,
          equipment.id,
          equipment.equipmentTypeName,
        );
      }
    });
  }

  // --- Movement logic for equipment within the bay ---
  void _moveEquipment(int direction) {
    if (_selectedEquipmentId == null) return;

    final currentIndex = _equipmentInstances.indexWhere(
      (eq) => eq.id == _selectedEquipmentId,
    );
    if (currentIndex == -1) return;

    final newIndex = currentIndex + direction;

    if (newIndex >= 0 && newIndex < _equipmentInstances.length) {
      setState(() {
        final EquipmentInstance movingItem = _equipmentInstances.removeAt(
          currentIndex,
        );
        _equipmentInstances.insert(newIndex, movingItem);

        // Update positionIndex for all affected items locally
        for (int i = 0; i < _equipmentInstances.length; i++) {
          _equipmentInstances[i] = _equipmentInstances[i].copyWith(
            positionIndex: i,
          );
        }
      });
      // Persist the new order to Firestore
      _updateEquipmentPositionsInFirestore(_equipmentInstances);
    } else {
      SnackBarUtils.showSnackBar(
        context,
        'Cannot move further ${direction == -1 ? 'up' : 'down'}.',
        isError: true,
      );
    }
  }

  // NEW: Validation before saving all equipment positions
  Future<void> _performSaveValidationAndSave() async {
    // If it's a Transformer bay, validate transformer equipment presence
    if (_bayType == 'Transformer') {
      final transformerCount = _equipmentInstances
          .where(
            (eq) =>
                eq.equipmentTypeName == 'Transformer' ||
                eq.symbolKey == 'Transformer',
          )
          .length;

      if (transformerCount == 0) {
        SnackBarUtils.showSnackBar(
          context,
          'Transformer bay must contain at least one Transformer equipment.',
          isError: true,
        );
        return;
      } else if (transformerCount > 1) {
        SnackBarUtils.showSnackBar(
          context,
          'Transformer bay can contain only one Transformer equipment.',
          isError: true,
        );
        return;
      }
    }

    // If validation passes, save all positions
    await _updateEquipmentPositionsInFirestore(_equipmentInstances);
    SnackBarUtils.showSnackBar(context, 'All equipment positions saved!');
  }

  @override
  Widget build(BuildContext context) {
    // Determine the equipment render data for the painter
    final List<EquipmentRenderData> equipmentRenderDataList = [];
    const double equipmentSymbolSize = 60;
    const double verticalGap = 40;
    const double horizontalCenterOffset = 100;

    if (!_isLoading && _equipmentInstances.isNotEmpty) {
      double currentY = verticalGap;
      for (var equipment in _equipmentInstances) {
        final rect = Rect.fromCenter(
          center: Offset(
            horizontalCenterOffset,
            currentY + equipmentSymbolSize / 2,
          ),
          width: equipmentSymbolSize,
          height: equipmentSymbolSize,
        );
        equipmentRenderDataList.add(
          EquipmentRenderData(
            equipment: equipment,
            rect: rect,
            center: rect.center,
            topCenter: rect.topCenter,
            bottomCenter: rect.bottomCenter,
          ),
        );
        currentY += equipmentSymbolSize + verticalGap;
      }
    }

    double canvasHeight = equipmentRenderDataList.isNotEmpty
        ? equipmentRenderDataList.last.rect.bottom + verticalGap
        : 200;

    double canvasWidth = 200;

    return PopScope(
      canPop: _selectedEquipmentId == null,
      onPopInvoked: (didPop) {
        if (!didPop && _selectedEquipmentId != null) {
          setState(() {
            _selectedEquipmentId = null;
          });
          SnackBarUtils.showSnackBar(
            context,
            'Movement cancelled. Position not saved.',
          );
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text('Bay: ${widget.bayName} - Equipment'),
          actions: [
            IconButton(
              icon: const Icon(Icons.save),
              tooltip: 'Save Layout',
              onPressed: _performSaveValidationAndSave,
            ),
            if (_selectedEquipmentId != null)
              IconButton(
                icon: const Icon(Icons.check),
                onPressed: () {
                  setState(() {
                    _selectedEquipmentId = null;
                  });
                  SnackBarUtils.showSnackBar(
                    context,
                    'Equipment movement mode exited.',
                  );
                },
              ),
          ],
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  Expanded(
                    child: InteractiveViewer(
                      transformationController: _transformationController,
                      boundaryMargin: const EdgeInsets.all(double.infinity),
                      minScale: 0.1,
                      maxScale: 4.0,
                      constrained: false,
                      onInteractionUpdate: (details) {
                        final inverse = _transformationController.value.clone();
                        if (inverse.invert() != 0) {
                          setState(() {
                            _currentInverseMatrix = inverse;
                          });
                        }
                      },
                      child: GestureDetector(
                        child: CustomPaint(
                          size: Size(canvasWidth, canvasHeight),
                          painter: BayEquipmentDiagramPainter(
                            equipmentRenderDataList: equipmentRenderDataList,
                            selectedEquipmentId: _selectedEquipmentId,
                            debugDrawHitboxes: true,
                            bayType: _bayType ?? 'Unknown',
                            transformerId: _transformerEquipmentId,
                          ),
                        ),
                        onTapUp: (details) {
                          final scenePosition = MatrixUtils.transformPoint(
                            _currentInverseMatrix,
                            details.localPosition,
                          );

                          final tappedEquipment = equipmentRenderDataList
                              .firstWhere(
                                (data) => data.rect.contains(scenePosition),
                                orElse: () => EquipmentRenderData(
                                  equipment: EquipmentInstance(
                                    id: 'dummy',
                                    bayId: '',
                                    templateId: '',
                                    equipmentTypeName: '',
                                    symbolKey: '',
                                    createdBy: '',
                                    createdAt: Timestamp.now(),
                                    customFieldValues: {},
                                    make: '',
                                  ),
                                  rect: Rect.zero,
                                  center: Offset.zero,
                                  topCenter: Offset.zero,
                                  bottomCenter: Offset.zero,
                                ),
                              );

                          if (tappedEquipment.equipment.id != 'dummy') {
                            Navigator.of(context)
                                .push(
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        EquipmentAssignmentScreen(
                                          bayId: widget.bayId,
                                          bayName: widget.bayName,
                                          substationId: widget.substationId,
                                          equipmentToEdit:
                                              tappedEquipment.equipment,
                                        ),
                                  ),
                                )
                                .then((_) => _fetchBayAndEquipmentDetails());
                          } else {
                            setState(() {
                              _selectedEquipmentId = null;
                            });
                          }
                        },
                        onLongPressStart: (details) {
                          final scenePosition = MatrixUtils.transformPoint(
                            _currentInverseMatrix,
                            details.localPosition,
                          );

                          final tappedEquipment = equipmentRenderDataList
                              .firstWhere(
                                (data) => data.rect.contains(scenePosition),
                                orElse: () => EquipmentRenderData(
                                  equipment: EquipmentInstance(
                                    id: 'dummy',
                                    bayId: '',
                                    templateId: '',
                                    equipmentTypeName: '',
                                    symbolKey: '',
                                    createdBy: '',
                                    createdAt: Timestamp.now(),
                                    customFieldValues: {},
                                    make: '',
                                  ),
                                  rect: Rect.zero,
                                  center: Offset.zero,
                                  topCenter: Offset.zero,
                                  bottomCenter: Offset.zero,
                                ),
                              );
                          if (tappedEquipment.equipment.id != 'dummy') {
                            _showEquipmentActions(
                              context,
                              tappedEquipment.equipment,
                              details.globalPosition,
                            );
                          }
                        },
                      ),
                    ),
                  ),
                  if (_selectedEquipmentId != null) _buildMovementControls(),
                ],
              ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () async {
            Navigator.of(context)
                .push(
                  MaterialPageRoute(
                    builder: (context) => EquipmentAssignmentScreen(
                      bayId: widget.bayId,
                      bayName: widget.bayName,
                      substationId: widget.substationId,
                    ),
                  ),
                )
                .then((_) => _fetchBayAndEquipmentDetails());
          },
          label: const Text('Add New Equipment'),
          icon: const Icon(Icons.add),
          backgroundColor: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }

  Widget _buildMovementControls() {
    final selectedEquipmentName = _equipmentInstances
        .firstWhere(
          (eq) => eq.id == _selectedEquipmentId,
          orElse: () => EquipmentInstance(
            id: 'dummy',
            bayId: '',
            templateId: '',
            equipmentTypeName: 'Unknown',
            symbolKey: '',
            createdBy: '',
            createdAt: Timestamp.now(),
            customFieldValues: {},
            make: '',
          ),
        )
        .equipmentTypeName;

    return Container(
      padding: const EdgeInsets.all(8.0),
      color: Colors.blueGrey.shade800,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Move: $selectedEquipmentName',
            style: const TextStyle(color: Colors.white, fontSize: 16),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_upward),
                color: Colors.white,
                onPressed: () => _moveEquipment(-1),
              ),
              const SizedBox(width: 20),
              IconButton(
                icon: const Icon(Icons.arrow_downward),
                color: Colors.white,
                onPressed: () => _moveEquipment(1),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
