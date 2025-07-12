// lib/screens/energy_sld_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math'; // For min/max
import 'package:collection/collection.dart'; // For firstWhereOrNull
import 'package:flutter_speed_dial/flutter_speed_dial.dart';
import 'package:provider/provider.dart'; // For ChangeNotifierProvider and Consumer

// PDF & Capture related imports
import 'package:intl/intl.dart'; // For DateFormat
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io'; // For File operations
import 'dart:typed_data'; // For Uint8List
import 'dart:ui' as ui; // For ImageByteFormat for screenshot
import 'package:widgets_to_image/widgets_to_image.dart';
import 'package:flutter/rendering.dart'; // For RenderRepaintBoundary

// Core Models
import '../models/bay_model.dart';
import '../models/equipment_model.dart'; // Needed for _allEquipmentInstances
import '../models/user_model.dart';
import '../models/reading_models.dart';
import '../models/logsheet_models.dart';
import '../models/bay_connection_model.dart'; // Now has connectionType
import '../models/busbar_energy_map.dart';
import '../models/assessment_model.dart';
import '../models/saved_sld_model.dart';

// Utility
import '../utils/snackbar_utils.dart';

// NEW SLD BUILDER COMPONENTS
import '../models/sld_models.dart';
import '../state_management/sld_editor_state.dart';
import '../widgets/sld_node_widget.dart';
import '../widgets/sld_edge_widget.dart';
import '../widgets/sld_text_label_widget.dart'; // Import the text label widget
import '../services/energy_account_services.dart'; // Import the service

// Painter for PDF (static rendering)
import '../painters/single_line_diagram_painter.dart';
import '../widgets/energy_assessment_dialog.dart';

// Moved BayEnergyData, AggregatedFeederEnergyData, SldRenderData to energy_account_services.dart.
// These are included here as a reminder that they are still used, but now defined in the service file.
// The classes themselves are defined at the top of energy_account_services.dart.

final GlobalKey<ScaffoldMessengerState> energySldScaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

enum MovementMode { bay, text } // For UI controls related to movement

class EnergySldScreen extends StatefulWidget {
  final String substationId;
  final String substationName;
  final AppUser currentUser;
  final SavedSld? savedSld; // Optional parameter for saved SLD

  const EnergySldScreen({
    super.key,
    required this.substationId,
    required this.substationName,
    required this.currentUser,
    this.savedSld,
  });

  @override
  State<EnergySldScreen> createState() => _EnergySldScreenState();
}

class _EnergySldScreenState extends State<EnergySldScreen> {
  // NEW: SldEditorState instance - now declared without `late` as it's initialized in didChangeDependencies
  SldEditorState? _sldEditorState; // Made nullable
  // NEW: EnergyAccountService instance
  late EnergyAccountService _energyAccountService;

  bool _isLoading = true;
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 1));
  DateTime _endDate = DateTime.now();
  bool _showTables = true; // State for table visibility

  final TransformationController _transformationController =
      TransformationController();

  int _currentPageIndex = 0;
  int _feederTablePageIndex = 0;

  // Flag to indicate if we are viewing a saved SLD
  bool _isViewingSavedSld = false;
  // Data loaded from a saved SLD
  Map<String, dynamic>? _loadedSldParameters;
  List<Map<String, dynamic>> _loadedAssessmentsSummary = [];

  // WidgetsToImageController for capturing the SLD widget
  final WidgetsToImageController _widgetsToImageController =
      WidgetsToImageController();

  // State to control rendering size for PDF capture
  bool _isCapturingPdf = false;
  Matrix4? _originalTransformation;

  // Static step values for fine-grained movement via buttons
  static const double _movementStep = 10.0;
  static const double _busbarLengthStep = 20.0;

  @override
  void initState() {
    super.initState();
    _energyAccountService = EnergyAccountService(context: context);
    // Set context for SnackBarUtils for EnergyAccountService as well
    _energyAccountService.setContext(context);

    _isViewingSavedSld = widget.savedSld != null;
    if (_isViewingSavedSld) {
      _startDate = widget.savedSld!.startDate.toDate();
      _endDate = widget.savedSld!.endDate.toDate();
      _loadedSldParameters = widget.savedSld!.sldParameters;
      _loadedAssessmentsSummary = widget.savedSld!.assessmentsSummary;
    }
    // _loadData will be called in didChangeDependencies
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_sldEditorState == null) {
      _sldEditorState = Provider.of<SldEditorState>(context);
      _sldEditorState!.setContext(context);
      _sldEditorState!.addListener(_onSldStateChanged);

      // Now that _sldEditorState is available, call _loadData
      if (_isViewingSavedSld) {
        _loadData(fromSaved: true);
      } else {
        if (widget.substationId.isNotEmpty) {
          _loadData();
        } else {
          _isLoading = false;
        }
      }
    }
  }

  @override
  void dispose() {
    _sldEditorState?.removeListener(_onSldStateChanged);
    _sldEditorState
        ?.dispose(); // Dispose the provider when the widget is disposed
    _transformationController.dispose();
    super.dispose();
  }

  // Listener for SldEditorState changes to trigger UI rebuild
  void _onSldStateChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  double _getVoltageLevelValue(String voltageLevel) {
    final regex = RegExp(r'(\d+(\.\d+)?)');
    final match = regex.firstMatch(voltageLevel);
    if (match != null) {
      return double.tryParse(match.group(1)!) ?? 0.0;
    }
    return 0.0;
  }

  // NEW: Centralized data loading method
  Future<void> _loadData({bool fromSaved = false}) async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _currentPageIndex = 0;
      _feederTablePageIndex = 0;
    });

    try {
      // Load energy data using the service
      await _energyAccountService.loadEnergyData(
        substationId: widget.substationId,
        startDate: _startDate,
        endDate: _endDate,
        savedSld: fromSaved ? widget.savedSld : null,
      );

      // If loading from saved, explicitly set SLD data in state manager
      if (fromSaved && _loadedSldParameters != null) {
        final sldDataMap = Map<String, dynamic>.from(_loadedSldParameters!);
        if (sldDataMap.containsKey('elements')) {
          final Map<String, SldElement> elements = {};
          (sldDataMap['elements'] as Map<String, dynamic>).forEach((id, data) {
            elements[id] = SldElement.fromJson(data);
          });
          sldDataMap['elements'] = elements;
        }
        final savedSldData = SldData.fromJson(sldDataMap);
        _sldEditorState!.setSldData(
          savedSldData,
          addToHistory: false,
          markDirty: false,
        );
        _transformationController.value = Matrix4.identity()
          ..translate(
            savedSldData.currentPanOffset.dx,
            savedSldData.currentPanOffset.dy,
          )
          ..scale(savedSldData.currentZoom);
      } else {
        // If loading live data, build SldData from live data and set it
        final liveSldData = _buildSldDataFromLive();
        _sldEditorState!.setSldData(
          liveSldData,
          addToHistory: true,
          markDirty: true,
        ); // Mark dirty if new
      }
    } catch (e) {
      print("Error loading data in EnergySldScreen: $e");
      SnackBarUtils.showSnackBar(
        context,
        'Failed to load data: $e',
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Helper method to construct SldData from live Bay/Connection data
  SldData _buildSldDataFromLive() {
    final Map<String, SldElement> elements = {};
    int currentZIndex = 0; // Simple z-index assignment for initial layout

    // Access data from the service
    final allBaysInSubstation = _energyAccountService.allBaysInSubstation;
    final allConnections = _energyAccountService.allConnections;
    final bayEnergyData = _energyAccountService.bayEnergyData;

    // Add Bays as SldNodes
    for (var bay in allBaysInSubstation) {
      // If no position exists, assign a default or incremental position
      final Offset initialPosition = Offset(
        bay.xPosition ?? (100.0 + (elements.length % 5) * 150), // Simple spread
        bay.yPosition ?? (100.0 + (elements.length ~/ 5) * 150),
      );

      final sldNode = bay.toSldNode(
        position: initialPosition,
        // Pass original Bay's properties and calculated energy for the SLD Node to render
        additionalProperties: {
          // Store raw offsets for movement control via buttons
          'textOffsetDx': bay.textOffset?.dx,
          'textOffsetDy': bay.textOffset?.dy,
          'energyTextOffsetDx': bay.energyTextOffset?.dx,
          'energyTextOffsetDy': bay.energyTextOffset?.dy,
          'busbarLength':
              bay.busbarLength, // Pass busbarLength for busbar nodes
          // Pass live energy data for rendering
          'energyReading': bayEnergyData[bay.id]?.impConsumed,
          // Formatted names/voltages for rendering on the node widget directly
          'bayNameFormatted': bay.name, // Use original bay name
          'bayTypeString': bay.bayType
              .toString()
              .split('.')
              .last, // String representation
          'bayVoltage': bay.voltageLevel,
          'hvVoltage': bay.hvVoltage,
          'lvVoltage': bay.lvVoltage,
        },
      );
      sldNode.zIndex = currentZIndex++; // Assign zIndex
      elements[sldNode.id] = sldNode;
    }

    // Add BayConnections as SldEdges
    for (var conn in allConnections) {
      final sourceNode = elements[conn.sourceBayId] as SldNode?;
      final targetNode = elements[conn.targetBayId] as SldNode?;

      if (sourceNode != null && targetNode != null) {
        // Determine suitable connection points from SldNode's defined connectionPoints
        String sourcePointId = 'bottom'; // Default
        String targetPointId = 'top'; // Default

        // More intelligent default connection point logic based on bay types
        // FIX: Access bayType from SldNode's properties map
        if (sourceNode.properties['bayTypeString'] ==
            BayType.Busbar.toString().split('.').last) {
          sourcePointId = sourceNode.connectionPoints.containsKey('right')
              ? 'right'
              : sourceNode.connectionPoints.keys.firstOrNull ?? 'top';
          targetPointId = targetNode.connectionPoints.containsKey('top')
              ? 'top'
              : targetNode.connectionPoints.keys.firstOrNull ?? 'top';
        } else if (targetNode.properties['bayTypeString'] ==
            BayType.Busbar.toString().split('.').last) {
          sourcePointId = sourceNode.connectionPoints.containsKey('bottom')
              ? 'bottom'
              : sourceNode.connectionPoints.keys.firstOrNull ?? 'top';
          targetPointId = targetNode.connectionPoints.containsKey('left')
              ? 'left'
              : targetNode.connectionPoints.keys.firstOrNull ?? 'top';
        } else if (sourceNode.properties['bayTypeString'] ==
            BayType.Transformer.toString().split('.').last) {
          if (conn.connectionType == 'HV_BUS_CONNECTION' &&
              sourceNode.connectionPoints.containsKey('hv_top')) {
            sourcePointId = 'hv_top';
          } else if (conn.connectionType == 'LV_BUS_CONNECTION' &&
              sourceNode.connectionPoints.containsKey('lv_bottom')) {
            sourcePointId = 'lv_bottom';
          }
        }
        // Fallback if specific point not found
        if (!sourceNode.connectionPoints.containsKey(sourcePointId)) {
          sourcePointId =
              sourceNode.connectionPoints.keys.firstOrNull ??
              (sourceNode.size.height > sourceNode.size.width
                  ? 'bottom'
                  : 'right');
        }
        if (!targetNode.connectionPoints.containsKey(targetPointId)) {
          targetPointId =
              targetNode.connectionPoints.keys.firstOrNull ??
              (targetNode.size.height > targetNode.size.width ? 'top' : 'left');
        }

        final sldEdge = SldEdge(
          id: conn.id,
          sourceNodeId: conn.sourceBayId,
          sourceConnectionPointId: sourcePointId,
          targetNodeId: conn.targetBayId,
          targetConnectionPointId: targetPointId,
          lineColor: Colors.blue,
          lineWidth: 2.0,
          lineJoin: SldLineJoin.round,
          properties: {
            'connectionType': conn.connectionType,
          }, // Access connectionType from BayConnection
        );
        sldEdge.zIndex = currentZIndex++;
        elements[sldEdge.id] = sldEdge;
      }
    }

    final sortedElements = elements.values.toList()
      ..sort((a, b) => a.zIndex.compareTo(b.zIndex));
    final Map<String, SldElement> finalElementsMap = {
      for (var e in sortedElements) e.id: e,
    };

    return SldData(
      substationId: widget.substationId,
      elements: finalElementsMap,
      currentZoom: 1.0,
      currentPanOffset: Offset.zero,
      selectedElementIds: {},
      interactionMode: SldInteractionMode.select,
      lastZIndex: currentZIndex,
    );
  }

  Future<void> _selectDate(BuildContext context) async {
    if (_isViewingSavedSld) return;

    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
    );

    if (picked != null &&
        (picked.start != _startDate || picked.end != _endDate)) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
      await _loadData();
    }
  }

  Future<void> _saveBusbarEnergyMap(BusbarEnergyMap map) async {
    if (_isViewingSavedSld) return;

    try {
      if (map.id == null) {
        await FirebaseFirestore.instance
            .collection('busbarEnergyMaps')
            .add(map.toFirestore());
      } else {
        await FirebaseFirestore.instance
            .collection('busbarEnergyMaps')
            .doc(map.id)
            .update(map.toFirestore());
      }
      await _loadData();
    } catch (e) {
      print('Error saving BusbarEnergyMap: $e');
      if (mounted) {
        SnackBarUtils.showSnackBar(
          context,
          'Failed to save energy map: $e',
          isError: true,
        );
      }
    }
  }

  Future<void> _deleteBusbarEnergyMap(String mapId) async {
    if (_isViewingSavedSld) return;

    try {
      await FirebaseFirestore.instance
          .collection('busbarEnergyMaps')
          .doc(mapId)
          .delete();
      await _loadData();
    } catch (e) {
      print('Error deleting BusbarEnergyMap: $e');
      if (mounted) {
        SnackBarUtils.showSnackBar(
          context,
          'Failed to delete energy map: $e',
          isError: true,
        );
      }
    }
  }

  void _showBusbarSelectionDialog() {
    if (_isViewingSavedSld) return;

    final List<Bay> busbars = _energyAccountService.allBaysInSubstation
        .where((bay) => bay.bayType == BayType.Busbar)
        .toList();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Select Busbar'),
          content: busbars.isEmpty
              ? const Text('No busbars found in this substation.')
              : SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: busbars.map((busbar) {
                      return ListTile(
                        title: Text('${busbar.voltageLevel} ${busbar.name}'),
                        onTap: () {
                          Navigator.pop(context);
                          _showBusbarEnergyAssignmentDialog(busbar);
                        },
                      );
                    }).toList(),
                  ),
                ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  void _showBusbarEnergyAssignmentDialog(Bay busbar) {
    if (_isViewingSavedSld) return;

    final List<Bay> connectedBays = _energyAccountService.allConnections
        .where(
          (conn) =>
              conn.sourceBayId == busbar.id || conn.targetBayId == busbar.id,
        )
        .map((conn) {
          final String otherBayId = conn.sourceBayId == busbar.id
              ? conn.targetBayId
              : conn.sourceBayId;
          return _energyAccountService.baysMap[otherBayId];
        })
        .whereType<Bay>()
        .where((bay) => bay.bayType != BayType.Busbar)
        .toList();

    final Map<String, BusbarEnergyMap> currentBusbarMaps = {};
    _energyAccountService.busbarEnergyMaps.forEach((key, value) {
      if (value.busbarId == busbar.id) {
        currentBusbarMaps[value.connectedBayId] = value;
      }
    });

    showDialog(
      context: context,
      builder: (context) => _BusbarEnergyAssignmentDialog(
        busbar: busbar,
        connectedBays: connectedBays,
        currentUser: widget.currentUser,
        currentMaps: currentBusbarMaps,
        onSaveMap: _saveBusbarEnergyMap,
        onDeleteMap: _deleteBusbarEnergyMap,
      ),
    );
  }

  /// Method to show the energy assessment dialog for a specific bay
  void _showEnergyAssessmentDialog(Bay bay, BayEnergyData? energyData) {
    if (_isViewingSavedSld) return;

    showDialog(
      context: context,
      builder: (context) => EnergyAssessmentDialog(
        bay: bay,
        currentUser: widget.currentUser,
        currentEnergyData: energyData,
        onSaveAssessment: _loadData,
        latestExistingAssessment:
            _energyAccountService.latestAssessmentsPerBay[bay.id],
      ),
    );
  }

  /// Method to show a dialog for selecting a bay for assessment
  void _showBaySelectionForAssessment() {
    if (_isViewingSavedSld) return;

    final List<Bay> assessableBays = _energyAccountService.allBaysInSubstation
        .where(
          (bay) => [
            BayType.Feeder,
            BayType.Line,
            BayType.Transformer,
          ].contains(bay.bayType),
        )
        .toList();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Select Bay for Assessment'),
          content: assessableBays.isEmpty
              ? const Text('No assessable bays found in this substation.')
              : SizedBox(
                  width: MediaQuery.of(context).size.width * 0.7,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: assessableBays.map((bay) {
                        return ListTile(
                          title: Text(
                            '${bay.name} (${bay.bayType.toString().split('.').last})',
                          ),
                          onTap: () {
                            Navigator.pop(context);
                            _showEnergyAssessmentDialog(
                              bay,
                              _energyAccountService.bayEnergyData[bay.id],
                            );
                          },
                        );
                      }).toList(),
                    ),
                  ),
                ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  // --- Start of methods for movement functionality ---

  /// Function to save position/textOffset/busbarLength changes to Firestore
  Future<void> _saveChangesToFirestore() async {
    if (_isViewingSavedSld) {
      SnackBarUtils.showSnackBar(
        context,
        'Cannot save position changes to a historical SLD.',
        isError: true,
      );
      return;
    }
    await _sldEditorState!.saveSld();
    if (mounted) {
      setState(() {});
    }
  }

  /// Method to show context menu for SLD element actions (position, text, delete)
  void _showElementActionsMenu(
    BuildContext context,
    String elementId,
    Offset tapPosition,
  ) {
    if (_isViewingSavedSld) {
      SnackBarUtils.showSnackBar(
        context,
        'Cannot modify SLD elements in a saved historical SLD.',
      );
      return;
    }

    _sldEditorState!.selectElement(elementId);

    final List<PopupMenuEntry<String>> menuItems = [
      const PopupMenuItem<String>(
        value: 'adjust',
        child: ListTile(
          leading: Icon(Icons.open_with),
          title: Text('Adjust Position/Size'),
        ),
      ),
      const PopupMenuItem<String>(
        value: 'move_label',
        child: ListTile(
          leading: Icon(Icons.text_fields),
          title: Text('Adjust Label Position'),
        ),
      ),
      const PopupMenuItem<String>(
        value: 'delete',
        child: ListTile(leading: Icon(Icons.delete), title: Text('Delete')),
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
      if (value == 'adjust') {
        _sldEditorState!.setInteractionMode(SldInteractionMode.pan);
        SnackBarUtils.showSnackBar(
          context,
          'Selected element. Drag to position.', // Simplified for consistency with SldEditorState.moveNode
        );
      } else if (value == 'move_label') {
        _sldEditorState!.setInteractionMode(SldInteractionMode.addText);
        SnackBarUtils.showSnackBar(
          context,
          'Selected element label. Drag to position.', // Simplified
        );
      } else if (value == 'delete') {
        _sldEditorState!.removeElement(elementId);
        SnackBarUtils.showSnackBar(context, 'Element deleted.');
      }
    });
  }

  /// Method to handle moving the selected item (node or text label) via buttons
  void _moveSelectedItem(double dx, double dy) {
    final sldState = _sldEditorState!;
    final selectedId = sldState.sldData?.selectedElementIds.firstOrNull;
    if (selectedId == null) return;

    final currentElement = sldState.sldData?.elements[selectedId];
    if (currentElement == null) return;

    final currentZoom = sldState.sldData?.currentZoom ?? 1.0;

    if (sldState.interactionMode == SldInteractionMode.pan) {
      if (currentElement is SldNode) {
        // Direct update of node position within SldEditorState.moveNode
        sldState.moveNode(
          selectedId,
          currentElement.position + Offset(dx / currentZoom, dy / currentZoom),
        );
      } else if (currentElement is SldTextLabel) {
        // Direct update of text label position via updateElementProperties
        sldState.updateElementProperties(selectedId, {
          'positionX': currentElement.position.dx + dx / currentZoom,
          'positionY': currentElement.position.dy + dy / currentZoom,
        });
      }
    } else if (sldState.interactionMode == SldInteractionMode.addText) {
      if (currentElement is SldNode) {
        // Update text offset in node properties
        sldState.updateElementProperties(selectedId, {
          'textOffsetDx':
              ((currentElement.properties['textOffsetDx'] as num?)
                      ?.toDouble() ??
                  0.0) +
              dx / currentZoom,
          'textOffsetDy':
              ((currentElement.properties['textOffsetDy'] as num?)
                      ?.toDouble() ??
                  0.0) +
              dy / currentZoom,
        });
      } else if (currentElement is SldTextLabel) {
        // Update text label position (same as pan for text label)
        sldState.updateElementProperties(selectedId, {
          'positionX': currentElement.position.dx + dx / currentZoom,
          'positionY': currentElement.position.dy + dy / currentZoom,
        });
      }
    }
  }

  /// Method to adjust busbar length of a selected busbar node
  void _adjustBusbarLength(double change) {
    final sldState = _sldEditorState!;
    final selectedId = sldState.sldData?.selectedElementIds.firstOrNull;
    if (selectedId == null) return;

    final currentElement = sldState.sldData?.elements[selectedId];
    if (currentElement is SldNode &&
        currentElement.properties['bayTypeString'] ==
            BayType.Busbar.toString().split('.').last) {
      final double currentLength =
          (currentElement.properties['busbarLength'] as num?)?.toDouble() ??
          150.0;
      sldState.updateElementProperties(selectedId, {
        'busbarLength': max(20.0, currentLength + change),
      });
    }
  }

  /// Widget for movement controls
  Widget _buildMovementControls() {
    final sldState = _sldEditorState!; // Use the instance
    final selectedId = sldState.sldData?.selectedElementIds.firstOrNull;
    if (selectedId == null) return const SizedBox.shrink();

    final selectedElement = sldState.sldData?.elements[selectedId];
    if (selectedElement == null ||
        (selectedElement is! SldNode && selectedElement is! SldTextLabel))
      return const SizedBox.shrink();

    final String displayName = (selectedElement is SldNode)
        ? selectedElement.properties['bayNameFormatted'] ?? 'Unknown Bay'
        : (selectedElement as SldTextLabel).text;
    final bool isBusbar =
        (selectedElement is SldNode) &&
        (selectedElement.properties['bayTypeString'] ==
            BayType.Busbar.toString().split('.').last);

    final MovementMode currentMovementMode;
    if (sldState.interactionMode == SldInteractionMode.pan) {
      currentMovementMode = MovementMode.bay;
    } else if (sldState.interactionMode == SldInteractionMode.addText) {
      currentMovementMode = MovementMode.text;
    } else {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(8.0),
      color: Colors.blueGrey.shade800,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Editing: $displayName',
            style: const TextStyle(color: Colors.white, fontSize: 16),
          ),
          const SizedBox(height: 10),
          SegmentedButton<MovementMode>(
            segments: const [
              ButtonSegment(
                value: MovementMode.bay,
                label: Text('Move Element'),
              ),
              ButtonSegment(
                value: MovementMode.text,
                label: Text('Move Label'),
              ),
            ],
            selected: {currentMovementMode},
            onSelectionChanged: (newSelection) {
              final newMode = newSelection.first;
              if (newMode == MovementMode.bay) {
                sldState.setInteractionMode(SldInteractionMode.pan);
              } else {
                sldState.setInteractionMode(SldInteractionMode.addText);
              }
            },
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back),
                color: Colors.white,
                onPressed: () => _moveSelectedItem(-_movementStep, 0),
              ),
              Column(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_upward),
                    color: Colors.white,
                    onPressed: () => _moveSelectedItem(0, -_movementStep),
                  ),
                  IconButton(
                    icon: const Icon(Icons.arrow_downward),
                    color: Colors.white,
                    onPressed: () => _moveSelectedItem(0, _movementStep),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.arrow_forward),
                color: Colors.white,
                onPressed: () => _moveSelectedItem(_movementStep, 0),
              ),
            ],
          ),
          if (isBusbar) ...[
            const SizedBox(height: 10),
            const Text('Busbar Length', style: TextStyle(color: Colors.white)),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.remove),
                  color: Colors.white,
                  onPressed: () => _adjustBusbarLength(-_busbarLengthStep),
                ),
                Text(
                  (selectedElement.properties['busbarLength'] as num?)
                          ?.toStringAsFixed(0) ??
                      'Auto',
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                ),
                IconButton(
                  icon: const Icon(Icons.add),
                  color: Colors.white,
                  onPressed: () => _adjustBusbarLength(_busbarLengthStep),
                ),
              ],
            ),
          ],
          const SizedBox(height: 10),
          ElevatedButton(
            onPressed: () async {
              await _saveChangesToFirestore();
            },
            child: const Text('Done & Save'),
          ),
        ],
      ),
    );
  }

  /// Method to save the current SLD state (uses SldEditorState)
  Future<void> _saveSld() async {
    if (_isViewingSavedSld) {
      SnackBarUtils.showSnackBar(
        context,
        'Cannot re-save a loaded historical SLD. Please go to a live SLD to save.',
        isError: true,
      );
      return;
    }

    if (!(_sldEditorState!.isDirty) &&
        (_sldEditorState!.sldData?.selectedElementIds.isEmpty ?? true)) {
      SnackBarUtils.showSnackBar(
        context,
        'No changes to save.',
        isError: false,
      );
      return;
    }

    if (!(_sldEditorState!.sldData?.selectedElementIds.isEmpty ?? true)) {
      SnackBarUtils.showSnackBar(
        context,
        'Please save or cancel current adjustments before saving SLD.',
        isError: true,
      );
      return;
    }

    TextEditingController sldNameController = TextEditingController();
    final String? sldName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Save SLD As...'),
        content: TextField(
          controller: sldNameController,
          decoration: const InputDecoration(hintText: "Enter SLD name"),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (sldNameController.text.trim().isEmpty) {
                SnackBarUtils.showSnackBar(
                  context,
                  'SLD name cannot be empty!',
                  isError: true,
                );
              } else {
                Navigator.pop(context, sldNameController.text.trim());
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (sldName == null || sldName.isEmpty) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final SldData currentSldData = _sldEditorState!.sldData!;

      currentSldData.currentZoom = _transformationController.value
          .getMaxScaleOnAxis();
      currentSldData.currentPanOffset = Offset(
        _transformationController.value.getTranslation().x,
        _transformationController.value.getTranslation().y,
      );

      final Map<String, dynamic> savedSldParameters = currentSldData.toJson();
      savedSldParameters.addAll({
        'bayEnergyData': {
          for (var entry in _energyAccountService.bayEnergyData.entries)
            entry.key: entry.value.toMap(),
        },
        'busEnergySummary': _energyAccountService.busEnergySummary,
        'abstractEnergyData': _energyAccountService.abstractEnergyData,
        'aggregatedFeederEnergyData': _energyAccountService
            .aggregatedFeederEnergyData
            .map((e) => e.toMap())
            .toList(),
        'bayNamesLookup': {
          for (var bay in _energyAccountService.allBaysInSubstation)
            bay.id: bay.name,
        },
      });

      final List<Map<String, dynamic>> currentAssessmentsSummary =
          _energyAccountService.allAssessmentsForDisplay
              .map(
                (assessment) => {
                  ...assessment.toFirestore(),
                  'bayName':
                      _energyAccountService.baysMap[assessment.bayId]?.name ??
                      'N/A',
                },
              )
              .toList();

      final newSavedSld = SavedSld(
        name: sldName,
        substationId: widget.substationId,
        substationName: widget.substationName,
        startDate: Timestamp.fromDate(_startDate),
        endDate: Timestamp.fromDate(_endDate),
        createdBy: widget.currentUser.uid,
        createdAt: Timestamp.now(),
        sldParameters: savedSldParameters,
        assessmentsSummary: currentAssessmentsSummary,
      );

      await FirebaseFirestore.instance
          .collection('savedSlds')
          .add(newSavedSld.toFirestore());

      if (mounted) {
        SnackBarUtils.showSnackBar(
          context,
          'SLD "${sldName}" saved successfully!',
        );
      }
    } catch (e) {
      print('Error saving SLD: $e');
      if (mounted) {
        SnackBarUtils.showSnackBar(
          context,
          'Failed to save SLD: $e',
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

  /// Function to generate PDF content from the current SLD state
  Future<Uint8List> _generatePdfFromCurrentSld() async {
    final pdf = pw.Document();
    final ColorScheme colorScheme = Theme.of(context).colorScheme;

    final SldData? currentSldData = _sldEditorState!.sldData;
    if (currentSldData == null || currentSldData.elements.isEmpty) {
      SnackBarUtils.showSnackBar(
        context,
        'No SLD data to generate PDF.',
        isError: true,
      );
      return Uint8List(0);
    }

    double minXForContent = double.infinity;
    double minYForContent = double.infinity;
    double maxXForContent = double.negativeInfinity;
    double maxYForContent = double.negativeInfinity;

    for (var element in currentSldData.elements.values) {
      // Calculate content bounds considering all element types
      double elementMinX = element.position.dx;
      double elementMinY = element.position.dy;
      double elementMaxX = element.position.dx + element.size.width;
      double elementMaxY = element.position.dy + element.size.height;

      if (element is SldNode) {
        // Consider potential text offsets and energy text offsets for nodes
        if (element.properties.containsKey('textOffsetDx')) {
          elementMinX = min(
            elementMinX,
            element.position.dx +
                (element.properties['textOffsetDx'] as num).toDouble(),
          );
          elementMaxX = max(
            elementMaxX,
            element.position.dx +
                (element.properties['textOffsetDx'] as num).toDouble() +
                100, // Approximate text width
          );
        }
        if (element.properties.containsKey('textOffsetDy')) {
          elementMinY = min(
            elementMinY,
            element.position.dy +
                (element.properties['textOffsetDy'] as num).toDouble(),
          );
          elementMaxY = max(
            elementMaxY,
            element.position.dy +
                (element.properties['textOffsetDy'] as num).toDouble() +
                50, // Approximate text height
          );
        }
        if (element.properties.containsKey('energyTextOffsetDx')) {
          elementMinX = min(
            elementMinX,
            element.position.dx +
                (element.properties['energyTextOffsetDx'] as num).toDouble(),
          );
          elementMaxX = max(
            elementMaxX,
            element.position.dx +
                (element.properties['energyTextOffsetDx'] as num).toDouble() +
                120, // Approximate energy text width
          );
        }
        if (element.properties.containsKey('energyTextOffsetDy')) {
          elementMinY = min(
            elementMinY,
            element.position.dy +
                (element.properties['energyTextOffsetDy'] as num).toDouble(),
          );
          elementMaxY = max(
            elementMaxY,
            element.position.dy +
                (element.properties['energyTextOffsetDy'] as num).toDouble() +
                100, // Approximate energy text height
          );
        }
      } else if (element is SldEdge) {
        final startNode = currentSldData.nodes[element.sourceNodeId];
        final targetNode = currentSldData.nodes[element.targetNodeId];
        if (startNode != null && targetNode != null) {
          final startPoint =
              startNode.position +
              (startNode
                      .connectionPoints[element.sourceConnectionPointId]
                      ?.localOffset ??
                  Offset.zero);
          final endPoint =
              targetNode.position +
              (targetNode
                      .connectionPoints[element.targetConnectionPointId]
                      ?.localOffset ??
                  Offset.zero);
          elementMinX = min(elementMinX, min(startPoint.dx, endPoint.dx));
          elementMinY = min(elementMinY, min(startPoint.dy, endPoint.dy));
          elementMaxX = max(elementMaxX, max(startPoint.dx, endPoint.dx));
          elementMaxY = max(elementMaxY, max(startPoint.dy, endPoint.dy));
          for (var p in element.pathPoints) {
            elementMinX = min(elementMinX, p.dx);
            elementMinY = min(elementMinY, p.dy);
            elementMaxX = max(elementMaxX, p.dx);
            elementMaxY = max(elementMaxY, p.dy);
          }
        }
      }
      // Update overall min/max bounds
      minXForContent = min(minXForContent, elementMinX);
      minYForContent = min(minYForContent, elementMinY);
      maxXForContent = max(maxXForContent, elementMaxX);
      maxYForContent = max(maxYForContent, elementMaxY);
    }

    const double capturePadding = 50.0;
    final double diagramContentWidth =
        (maxXForContent - minXForContent).abs() + 2 * capturePadding;
    final double diagramContentHeight =
        (maxYForContent - minYForContent).abs() + 2 * capturePadding;
    final Offset originOffsetForPainter = Offset(
      -minXForContent + capturePadding,
      -minYForContent + capturePadding,
    );

    // Set a fixed render box for the custom painter to draw into for PDF.
    // This is the size of the 'contentBounds' for the SingleLineDiagramPainter.
    // Ensure these dimensions are suitable for A4 aspect ratio or adjusted.
    final Size pdfRenderBoxSize = Size(
      diagramContentWidth,
      diagramContentHeight,
    );

    _originalTransformation = Matrix4.copy(_transformationController.value);
    _transformationController.value = Matrix4.identity()
      ..translate(originOffsetForPainter.dx, originOffsetForPainter.dy);

    setState(() {
      _isCapturingPdf = true;
    });
    await WidgetsBinding.instance.endOfFrame;

    // Capture the widget as an image using the custom painter's actual bounds
    // The WidgetsToImage widget will wrap the CustomPaint.
    // This ensures that the image generated is exactly what the painter draws
    // within the calculated content bounds.
    final Uint8List? sldImageBytes = await _widgetsToImageController.capturePng(
      pixelRatio: 5.0, // High quality capture for PDF
      // Bounds will be handled by the CustomPaint's size during capture
    );

    setState(() {
      _isCapturingPdf = false;
    });
    _transformationController.value =
        _originalTransformation!; // Restore original transformation

    pw.MemoryImage? sldPdfImage;
    if (sldImageBytes != null) {
      sldPdfImage = pw.MemoryImage(sldImageBytes);
    }

    final Map<String, dynamic> currentAbstractEnergyData =
        _energyAccountService.abstractEnergyData;
    final Map<String, Map<String, double>> currentBusEnergySummaryData =
        _energyAccountService.busEnergySummary;
    final List<AggregatedFeederEnergyData> currentAggregatedFeederData =
        _energyAccountService.aggregatedFeederEnergyData;
    final List<Map<String, dynamic>> assessmentsForPdf = _isViewingSavedSld
        ? _loadedAssessmentsSummary
        : _energyAccountService.allAssessmentsForDisplay
              .map(
                (e) => {
                  ...e.toFirestore(),
                  'bayName':
                      _energyAccountService.baysMap[e.bayId]?.name ?? 'N/A',
                },
              )
              .toList();

    final Map<String, String> currentBayNamesLookup;
    if (_isViewingSavedSld &&
        _loadedSldParameters != null &&
        _loadedSldParameters!.containsKey('bayNamesLookup')) {
      currentBayNamesLookup = Map<String, String>.from(
        _loadedSldParameters!['bayNamesLookup'],
      );
    } else {
      currentBayNamesLookup = {
        for (var bay in _energyAccountService.allBaysInSubstation)
          bay.id: bay.name,
      };
    }

    final List<String> uniqueBusVoltages =
        _energyAccountService.allBaysInSubstation
            .where((bay) => bay.bayType == BayType.Busbar)
            .map((bay) => bay.voltageLevel)
            .toSet()
            .toList()
          ..sort(
            (a, b) =>
                _getVoltageLevelValue(b).compareTo(_getVoltageLevelValue(a)),
          );

    final List<String> uniqueDistributionSubdivisionNames =
        currentAggregatedFeederData
            .map((data) => data.distributionSubdivisionName)
            .toSet()
            .toList()
          ..sort();

    List<String> abstractTableHeaders = [''];
    for (String voltage in uniqueBusVoltages) {
      abstractTableHeaders.add('$voltage BUS');
    }
    abstractTableHeaders.add('ABSTRACT OF S/S');
    for (String subDivisionName in uniqueDistributionSubdivisionNames) {
      abstractTableHeaders.add(subDivisionName);
    }
    abstractTableHeaders.add('TOTAL');

    List<List<String>> abstractTableData = [];

    final List<String> rowLabels = [
      'Imp. (MWH)',
      'Exp. (MWH)',
      'Diff. (MWH)',
      'Loss (%)',
    ];

    for (int i = 0; i < rowLabels.length; i++) {
      List<String> row = [rowLabels[i]];
      double rowTotalSummable = 0.0;
      double tempRowImportForLossCalc = 0.0;
      double tempRowDifferenceForLossCalc = 0.0;

      for (String voltage in uniqueBusVoltages) {
        final busbarsOfThisVoltage = _energyAccountService.allBaysInSubstation
            .where(
              (bay) =>
                  bay.bayType == BayType.Busbar && bay.voltageLevel == voltage,
            );
        double totalForThisBusVoltageImp = 0.0;
        double totalForThisBusVoltageExp = 0.0;
        double totalForThisBusVoltageDiff = 0.0;

        for (var busbar in busbarsOfThisVoltage) {
          final busSummary = currentBusEnergySummaryData[busbar.id];
          if (busSummary != null) {
            totalForThisBusVoltageImp += busSummary['totalImp'] ?? 0.0;
            totalForThisBusVoltageExp += busSummary['totalExp'] ?? 0.0;
            totalForThisBusVoltageDiff += busSummary['difference'] ?? 0.0;
          }
        }

        if (rowLabels[i].contains('Imp.')) {
          row.add(totalForThisBusVoltageImp.toStringAsFixed(2));
          rowTotalSummable += totalForThisBusVoltageImp;
          tempRowImportForLossCalc += totalForThisBusVoltageImp;
        } else if (rowLabels[i].contains('Exp.')) {
          row.add(totalForThisBusVoltageExp.toStringAsFixed(2));
          rowTotalSummable += totalForThisBusVoltageExp;
        } else if (rowLabels[i].contains('Diff.')) {
          row.add(totalForThisBusVoltageDiff.toStringAsFixed(2));
          rowTotalSummable += totalForThisBusVoltageDiff;
          tempRowDifferenceForLossCalc += totalForThisBusVoltageDiff;
        } else if (rowLabels[i].contains('Loss')) {
          String lossValue = 'N/A';
          if (totalForThisBusVoltageImp > 0) {
            lossValue =
                ((totalForThisBusVoltageDiff / totalForThisBusVoltageImp) * 100)
                    .toStringAsFixed(2);
          }
          row.add(lossValue);
        }
      }

      if (rowLabels[i].contains('Imp.')) {
        row.add(
          (currentAbstractEnergyData['totalImp'] ?? 0.0).toStringAsFixed(2),
        );
        rowTotalSummable += (currentAbstractEnergyData['totalImp'] ?? 0.0);
        tempRowImportForLossCalc +=
            (currentAbstractEnergyData['totalImp'] ?? 0.0);
      } else if (rowLabels[i].contains('Exp.')) {
        row.add(
          (currentAbstractEnergyData['totalExp'] ?? 0.0).toStringAsFixed(2),
        );
        rowTotalSummable += (currentAbstractEnergyData['totalExp'] ?? 0.0);
      } else if (rowLabels[i].contains('Diff.')) {
        row.add(
          (currentAbstractEnergyData['difference'] ?? 0.0).toStringAsFixed(2),
        );
        rowTotalSummable += (currentAbstractEnergyData['difference'] ?? 0.0);
        tempRowDifferenceForLossCalc +=
            (currentAbstractEnergyData['difference'] ?? 0.0);
      } else if (rowLabels[i].contains('Loss')) {
        row.add(
          (currentAbstractEnergyData['lossPercentage'] ?? 0.0).toStringAsFixed(
            2,
          ),
        );
      }

      for (String subDivisionName in uniqueDistributionSubdivisionNames) {
        double currentFeederImp = 0.0;
        double currentFeederExp = 0.0;
        double currentFeederDiff = 0.0;

        for (var feederData
            in _energyAccountService.aggregatedFeederEnergyData.where(
              (data) => data.distributionSubdivisionName == subDivisionName,
            )) {
          currentFeederImp += feederData.importedEnergy;
          currentFeederExp += feederData.exportedEnergy;
          currentFeederDiff +=
              (feederData.importedEnergy - feederData.exportedEnergy);
        }

        if (rowLabels[i].contains('Imp.')) {
          row.add(currentFeederImp.toStringAsFixed(2));
          rowTotalSummable += currentFeederImp;
          tempRowImportForLossCalc += currentFeederImp;
        } else if (rowLabels[i].contains('Exp.')) {
          row.add(currentFeederExp.toStringAsFixed(2));
          rowTotalSummable += currentFeederExp;
        } else if (rowLabels[i].contains('Diff.')) {
          row.add(currentFeederDiff.toStringAsFixed(2));
          rowTotalSummable += currentFeederDiff;
          tempRowDifferenceForLossCalc += currentFeederDiff;
        } else if (rowLabels[i].contains('Loss')) {
          String lossValue = 'N/A';
          if (currentFeederImp > 0) {
            lossValue = ((currentFeederDiff / currentFeederImp) * 100)
                .toStringAsFixed(2);
          }
          row.add(lossValue);
        }
      }

      if (rowLabels[i].contains('Loss')) {
        String overallTotalLossPercentage = 'N/A';
        if (tempRowImportForLossCalc > 0) {
          overallTotalLossPercentage =
              ((tempRowDifferenceForLossCalc / tempRowImportForLossCalc) * 100)
                  .toStringAsFixed(2);
        }
        row.add(overallTotalLossPercentage);
      } else {
        row.add(rowTotalSummable.toStringAsFixed(2));
      }

      abstractTableData.add(row);
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.copyWith(
          marginBottom: 1.5 * PdfPageFormat.cm,
          marginTop: 1.5 * PdfPageFormat.cm,
          marginLeft: 1.5 * PdfPageFormat.cm,
          marginRight: 1.5 * PdfPageFormat.cm,
        ),
        header: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'Substation Energy Account Report',
                style: pw.TextStyle(
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.Text(widget.substationName, style: pw.TextStyle(fontSize: 14)),
              pw.Text(
                'Period: ${DateFormat('dd-MMM-yyyy').format(_startDate)} to ${DateFormat('dd-MMM-yyyy').format(_endDate)}',
                style: pw.TextStyle(fontSize: 12),
              ),
              pw.Divider(),
            ],
          );
        },
        build: (pw.Context context) {
          return [
            if (sldPdfImage != null)
              pw.Center(
                child: pw.Column(
                  children: [
                    pw.Text(
                      'Single Line Diagram',
                      style: pw.TextStyle(
                        fontSize: 14,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 10),
                    pw.Image(
                      sldPdfImage,
                      fit: pw.BoxFit.contain,
                      width: PdfPageFormat.a4.width - (3 * PdfPageFormat.cm),
                    ),
                    pw.SizedBox(height: 30),
                  ],
                ),
              )
            else
              pw.Text(
                'SLD Diagram could not be captured.',
                style: pw.TextStyle(color: PdfColors.red),
              ),
            pw.Header(
              level: 0,
              text: 'Consolidated Energy Abstract',
              decoration: pw.BoxDecoration(
                border: pw.Border(bottom: pw.BorderSide()),
              ),
            ),
            pw.Table.fromTextArray(
              context: context,
              headers: abstractTableHeaders,
              data: abstractTableData,
              border: pw.TableBorder.all(width: 0.5),
              headerStyle: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                fontSize: 8,
              ),
              cellAlignment: pw.Alignment.center,
              cellPadding: const pw.EdgeInsets.all(3),
              columnWidths: {
                0: const pw.FlexColumnWidth(1.2),
                for (int i = 0; i < uniqueBusVoltages.length; i++)
                  (i + 1).toInt(): const pw.FlexColumnWidth(1.0),
                (uniqueBusVoltages.length + 1).toInt():
                    const pw.FlexColumnWidth(1.2),
                for (
                  int i = 0;
                  i < uniqueDistributionSubdivisionNames.length;
                  i++
                )
                  (uniqueBusVoltages.length + 2 + i).toInt():
                      const pw.FlexColumnWidth(1.0),
                (uniqueBusVoltages.length +
                        2 +
                        uniqueDistributionSubdivisionNames.length)
                    .toInt(): const pw.FlexColumnWidth(
                  1.2,
                ),
              },
            ),
            pw.SizedBox(height: 20),
            pw.Header(
              level: 0,
              text: 'Feeder Energy Supplied by Distribution Hierarchy',
              decoration: pw.BoxDecoration(
                border: pw.Border(bottom: pw.BorderSide()),
              ),
            ),
            if (currentAggregatedFeederData.isNotEmpty)
              pw.Table.fromTextArray(
                context: context,
                headers: <String>[
                  'D-Zone',
                  'D-Circle',
                  'D-Division',
                  'D-Subdivision',
                  'Import (MWH)',
                  'Export (MWH)',
                ],
                data: currentAggregatedFeederData.map((data) {
                  return <String>[
                    data.zoneName,
                    data.circleName,
                    data.divisionName,
                    data.distributionSubdivisionName,
                    data.importedEnergy.toStringAsFixed(2),
                    data.exportedEnergy.toStringAsFixed(2),
                  ];
                }).toList(),
                border: pw.TableBorder.all(width: 0.5),
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                cellAlignment: pw.Alignment.centerLeft,
                cellPadding: const pw.EdgeInsets.all(4),
              )
            else
              pw.Text('No aggregated feeder energy data available.'),
            pw.SizedBox(height: 20),
            pw.Header(
              level: 0,
              text: 'Assessments for this Period',
              decoration: pw.BoxDecoration(
                border: pw.Border(bottom: pw.BorderSide()),
              ),
            ),
            if (assessmentsForPdf.isNotEmpty)
              pw.Table.fromTextArray(
                context: context,
                headers: <String>[
                  'Bay Name',
                  'Import Adj.',
                  'Export Adj.',
                  'Reason',
                  'Timestamp',
                ],
                data: assessmentsForPdf.map((assessmentMap) {
                  final Assessment assessment = Assessment.fromMap(
                    assessmentMap,
                  );
                  return <String>[
                    assessmentMap['bayName'] ?? 'N/A',
                    assessment.importAdjustment?.toStringAsFixed(2) ?? 'N/A',
                    assessment.exportAdjustment?.toStringAsFixed(2) ?? 'N/A',
                    assessment.reason,
                    DateFormat(
                      'dd-MMM-yyyy HH:mm',
                    ).format(assessment.assessmentTimestamp.toDate()),
                  ];
                }).toList(),
                border: pw.TableBorder.all(width: 0.5),
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                cellAlignment: pw.Alignment.centerLeft,
                cellPadding: const pw.EdgeInsets.all(4),
                columnWidths: {
                  0: const pw.FlexColumnWidth(2),
                  1: const pw.FlexColumnWidth(1.2),
                  2: const pw.FlexColumnWidth(1.2),
                  3: const pw.FlexColumnWidth(3),
                  4: const pw.FlexColumnWidth(2),
                },
              )
            else
              pw.Text('No assessments were made for this period.'),
          ];
        },
      ),
    );

    return await pdf.save();
  }

  pw.Widget _buildPdfEnergyRow(String label, dynamic value, String unit) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2.0),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text('$label:', style: const pw.TextStyle(fontSize: 10)),
          pw.Text(
            value != null ? '${value.toStringAsFixed(2)} $unit' : 'N/A',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
          ),
        ],
      ),
    );
  }

  Widget _buildPageIndicator(int pageCount, int currentPage) {
    List<Widget> indicators = [];
    final actualPageCount = pageCount > 0 ? pageCount : 1;
    for (int i = 0; i < actualPageCount; i++) {
      indicators.add(
        Container(
          width: 8.0,
          height: 8.0,
          margin: const EdgeInsets.symmetric(horizontal: 4.0),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: currentPage == i ? Colors.blue : Colors.grey,
          ),
        ),
      );
    }
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: indicators,
    );
  }

  Future<void> _shareCurrentSldAsPdf() async {
    try {
      SnackBarUtils.showSnackBar(context, 'Generating PDF...');
      final Uint8List pdfBytes = await _generatePdfFromCurrentSld();

      final output = await getTemporaryDirectory();
      final String filename =
          '${widget.substationName.replaceAll(RegExp(r'[^\w\s.-]'), '_')}_energy_report_${DateFormat('yyyyMMdd').format(_endDate)}.pdf';
      final file = File('${output.path}/$filename');
      await file.writeAsBytes(pdfBytes);

      await Share.shareXFiles([
        XFile(file.path),
      ], subject: 'Energy SLD Report: ${widget.substationName}');

      if (mounted) {
        SnackBarUtils.showSnackBar(
          context,
          'PDF generated and shared successfully!',
        );
      }
    } catch (e) {
      print("Error generating/sharing PDF: $e");
      if (mounted) {
        SnackBarUtils.showSnackBar(
          context,
          'Failed to generate/share PDF: $e',
          isError: true,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    String dateRangeText;
    if (_startDate.isAtSameMomentAs(_endDate)) {
      dateRangeText = DateFormat('dd-MMM-yyyy').format(_startDate);
    } else {
      dateRangeText =
          '${DateFormat('dd-MMM-yyyy').format(_startDate)} to ${DateFormat('dd-MMM-yyyy').format(_endDate)}';
    }

    if (widget.substationId.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Text(
            'Please select a substation to view energy SLD.',
            textAlign: TextAlign.center,
            style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey),
          ),
        ),
      );
    }

    // Access sldState using Provider.of here, ensuring it's not null.
    // The `_sldEditorState` is initialized in `didChangeDependencies`,
    // so it should be available by the time `build` runs if `mounted` is true.
    final SldEditorState sldState = _sldEditorState!;
    final SldData? currentSldData = sldState.sldData;

    double minXForContent = double.infinity;
    double minYForContent = double.infinity;
    double maxXForContent = double.negativeInfinity;
    double maxYForContent = double.negativeInfinity;

    if (currentSldData != null) {
      for (var element in currentSldData.elements.values) {
        // Calculate content bounds considering all element types
        double elementMinX = element.position.dx;
        double elementMinY = element.position.dy;
        double elementMaxX = element.position.dx + element.size.width;
        double elementMaxY = element.position.dy + element.size.height;

        if (element is SldNode) {
          // Consider potential text offsets and energy text offsets for nodes
          if (element.properties.containsKey('textOffsetDx')) {
            elementMinX = min(
              elementMinX,
              element.position.dx +
                  (element.properties['textOffsetDx'] as num).toDouble(),
            );
            elementMaxX = max(
              elementMaxX,
              element.position.dx +
                  (element.properties['textOffsetDx'] as num).toDouble() +
                  100, // Approximate text width
            );
          }
          if (element.properties.containsKey('textOffsetDy')) {
            elementMinY = min(
              elementMinY,
              element.position.dy +
                  (element.properties['textOffsetDy'] as num).toDouble(),
            );
            elementMaxY = max(
              elementMaxY,
              element.position.dy +
                  (element.properties['textOffsetDy'] as num).toDouble() +
                  50, // Approximate text height
            );
          }
          if (element.properties.containsKey('energyTextOffsetDx')) {
            elementMinX = min(
              elementMinX,
              element.position.dx +
                  (element.properties['energyTextOffsetDx'] as num).toDouble(),
            );
            elementMaxX = max(
              elementMaxX,
              element.position.dx +
                  (element.properties['energyTextOffsetDx'] as num).toDouble() +
                  120, // Approximate energy text width
            );
          }
          if (element.properties.containsKey('energyTextOffsetDy')) {
            elementMinY = min(
              elementMinY,
              element.position.dy +
                  (element.properties['energyTextOffsetDy'] as num).toDouble(),
            );
            elementMaxY = max(
              elementMaxY,
              element.position.dy +
                  (element.properties['energyTextOffsetDy'] as num).toDouble() +
                  100, // Approximate energy text height
            );
          }
        } else if (element is SldEdge) {
          final startNode = currentSldData.nodes[element.sourceNodeId];
          final targetNode = currentSldData.nodes[element.targetNodeId];
          if (startNode != null && targetNode != null) {
            final startPoint =
                startNode.position +
                (startNode
                        .connectionPoints[element.sourceConnectionPointId]
                        ?.localOffset ??
                    Offset.zero);
            final endPoint =
                targetNode.position +
                (targetNode
                        .connectionPoints[element.targetConnectionPointId]
                        ?.localOffset ??
                    Offset.zero);
            elementMinX = min(elementMinX, min(startPoint.dx, endPoint.dx));
            elementMinY = min(elementMinY, min(startPoint.dy, endPoint.dy));
            elementMaxX = max(elementMaxX, max(startPoint.dx, endPoint.dx));
            elementMaxY = max(elementMaxY, max(startPoint.dy, endPoint.dy));
            for (var p in element.pathPoints) {
              elementMinX = min(elementMinX, p.dx);
              elementMinY = min(elementMinY, p.dy);
              elementMaxX = max(elementMaxX, p.dx);
              elementMaxY = max(elementMaxY, p.dy);
            }
          }
        } else if (element is SldTextLabel) {
          elementMinX = min(elementMinX, element.position.dx);
          elementMinY = min(elementMinY, element.position.dy);
          elementMaxX = max(
            elementMaxX,
            element.position.dx + element.size.width,
          );
          elementMaxY = max(
            elementMaxY,
            element.position.dy + element.size.height,
          );
        }
        // Update overall min/max bounds
        minXForContent = min(minXForContent, elementMinX);
        minYForContent = min(minYForContent, elementMinY);
        maxXForContent = max(maxXForContent, elementMaxX);
        maxYForContent = max(maxYForContent, elementMaxY);
      }
    }

    if (!minXForContent.isFinite ||
        !minYForContent.isFinite ||
        !maxXForContent.isFinite ||
        !maxYForContent.isFinite ||
        (maxXForContent - minXForContent) <= 0 ||
        (maxYForContent - minYForContent) <= 0) {
      minXForContent = 0;
      minYForContent = 0;
      maxXForContent = 400;
      maxYForContent = 300;
    }

    const double contentPaddingForCanvas = 50.0;
    final double effectiveContentWidth =
        (maxXForContent - minXForContent) + 2 * contentPaddingForCanvas;
    final double effectiveContentHeight =
        (maxYForContent - minYForContent) + 2 * contentPaddingForCanvas;

    final Offset originOffsetForPainter = Offset(
      -minXForContent + contentPaddingForCanvas,
      -minYForContent + contentPaddingForCanvas,
    );

    final double canvasWidthForPainter = max(
      MediaQuery.of(context).size.width,
      effectiveContentWidth,
    );
    final double canvasHeightForPainter = max(
      MediaQuery.of(context).size.height,
      effectiveContentHeight,
    );

    const double consolidatedTableHeight = 250;

    final List<String> uniqueBusVoltages =
        _energyAccountService.allBaysInSubstation
            .where((bay) => bay.bayType == BayType.Busbar)
            .map((bay) => bay.voltageLevel)
            .toSet()
            .toList()
          ..sort(
            (a, b) =>
                _getVoltageLevelValue(b).compareTo(_getVoltageLevelValue(a)),
          );

    final List<String> uniqueDistributionSubdivisionNames =
        _energyAccountService.aggregatedFeederEnergyData
            .map((data) => data.distributionSubdivisionName)
            .toSet()
            .toList()
          ..sort();

    List<String> abstractTableHeaders = [''];
    for (String voltage in uniqueBusVoltages) {
      abstractTableHeaders.add('$voltage BUS');
    }
    abstractTableHeaders.add('ABSTRACT OF S/S');
    for (String subDivisionName in uniqueDistributionSubdivisionNames) {
      abstractTableHeaders.add(subDivisionName);
    }
    abstractTableHeaders.add('TOTAL');

    List<DataRow> consolidatedEnergyTableRows = [];
    final List<String> rowLabels = [
      'Import (MWH)',
      'Export (MWH)',
      'Diff. (MWH)',
      'Loss (%)',
    ];

    for (int i = 0; i < rowLabels.length; i++) {
      List<DataCell> rowCells = [DataCell(Text(rowLabels[i]))];
      double rowTotalSummable = 0.0;
      double tempRowImportForLossCalc = 0.0;
      double tempRowDifferenceForLossCalc = 0.0;

      for (String voltage in uniqueBusVoltages) {
        final busbarsOfThisVoltage = _energyAccountService.allBaysInSubstation
            .where(
              (bay) =>
                  bay.bayType == BayType.Busbar && bay.voltageLevel == voltage,
            );
        double totalForThisBusVoltageImp = 0.0;
        double totalForThisBusVoltageExp = 0.0;
        double totalForThisBusVoltageDiff = 0.0;

        for (var busbar in busbarsOfThisVoltage) {
          final busSummary = _energyAccountService.busEnergySummary[busbar.id];
          if (busSummary != null) {
            totalForThisBusVoltageImp += busSummary['totalImp'] ?? 0.0;
            totalForThisBusVoltageExp += busSummary['totalExp'] ?? 0.0;
            totalForThisBusVoltageDiff += busSummary['difference'] ?? 0.0;
          }
        }

        if (rowLabels[i].contains('Imp.')) {
          rowCells.add(
            DataCell(Text(totalForThisBusVoltageImp.toStringAsFixed(2))),
          );
          rowTotalSummable += totalForThisBusVoltageImp;
          tempRowImportForLossCalc += totalForThisBusVoltageImp;
        } else if (rowLabels[i].contains('Exp.')) {
          rowCells.add(
            DataCell(Text(totalForThisBusVoltageExp.toStringAsFixed(2))),
          );
          rowTotalSummable += totalForThisBusVoltageExp;
        } else if (rowLabels[i].contains('Diff.')) {
          rowCells.add(
            DataCell(Text(totalForThisBusVoltageDiff.toStringAsFixed(2))),
          );
          rowTotalSummable += totalForThisBusVoltageDiff;
          tempRowDifferenceForLossCalc += totalForThisBusVoltageDiff;
        } else if (rowLabels[i].contains('Loss')) {
          String lossValue = 'N/A';
          if (totalForThisBusVoltageImp > 0) {
            lossValue =
                ((totalForThisBusVoltageDiff / totalForThisBusVoltageImp) * 100)
                    .toStringAsFixed(2);
          }
          rowCells.add(DataCell(Text(lossValue)));
        }
      }

      if (rowLabels[i].contains('Imp.')) {
        rowCells.add(
          DataCell(
            Text(
              (_energyAccountService.abstractEnergyData['totalImp'] ?? 0.0)
                  .toStringAsFixed(2),
            ),
          ),
        );
        rowTotalSummable +=
            (_energyAccountService.abstractEnergyData['totalImp'] ?? 0.0);
        tempRowImportForLossCalc +=
            (_energyAccountService.abstractEnergyData['totalImp'] ?? 0.0);
      } else if (rowLabels[i].contains('Exp.')) {
        rowCells.add(
          DataCell(
            Text(
              (_energyAccountService.abstractEnergyData['totalExp'] ?? 0.0)
                  .toStringAsFixed(2),
            ),
          ),
        );
        rowTotalSummable +=
            (_energyAccountService.abstractEnergyData['totalExp'] ?? 0.0);
      } else if (rowLabels[i].contains('Diff.')) {
        rowCells.add(
          DataCell(
            Text(
              (_energyAccountService.abstractEnergyData['difference'] ?? 0.0)
                  .toStringAsFixed(2),
            ),
          ),
        );
        rowTotalSummable +=
            (_energyAccountService.abstractEnergyData['difference'] ?? 0.0);
        tempRowDifferenceForLossCalc +=
            (_energyAccountService.abstractEnergyData['difference'] ?? 0.0);
      } else if (rowLabels[i].contains('Loss')) {
        rowCells.add(
          DataCell(
            Text(
              (_energyAccountService.abstractEnergyData['lossPercentage'] ??
                      0.0)
                  .toStringAsFixed(2),
            ),
          ),
        );
      }

      for (String subDivisionName in uniqueDistributionSubdivisionNames) {
        double currentFeederImp = 0.0;
        double currentFeederExp = 0.0;
        double currentFeederDiff = 0.0;

        for (var feederData
            in _energyAccountService.aggregatedFeederEnergyData.where(
              (data) => data.distributionSubdivisionName == subDivisionName,
            )) {
          currentFeederImp += feederData.importedEnergy;
          currentFeederExp += feederData.exportedEnergy;
          currentFeederDiff +=
              (feederData.importedEnergy - feederData.exportedEnergy);
        }

        if (rowLabels[i].contains('Imp.')) {
          rowCells.add(DataCell(Text(currentFeederImp.toStringAsFixed(2))));
          rowTotalSummable += currentFeederImp;
          tempRowImportForLossCalc += currentFeederImp;
        } else if (rowLabels[i].contains('Exp.')) {
          rowCells.add(DataCell(Text(currentFeederExp.toStringAsFixed(2))));
          rowTotalSummable += currentFeederExp;
        } else if (rowLabels[i].contains('Diff.')) {
          rowCells.add(DataCell(Text(currentFeederDiff.toStringAsFixed(2))));
          rowTotalSummable += currentFeederDiff;
          tempRowDifferenceForLossCalc += currentFeederDiff;
        } else if (rowLabels[i].contains('Loss')) {
          String lossValue = 'N/A';
          if (currentFeederImp > 0) {
            lossValue = ((currentFeederDiff / currentFeederImp) * 100)
                .toStringAsFixed(2);
          }
          rowCells.add(DataCell(Text(lossValue)));
        }
      }

      if (rowLabels[i].contains('Loss')) {
        String overallTotalLossPercentage = 'N/A';
        if (tempRowImportForLossCalc > 0) {
          overallTotalLossPercentage =
              ((tempRowDifferenceForLossCalc / tempRowImportForLossCalc) * 100)
                  .toStringAsFixed(2);
        }
        rowCells.add(DataCell(Text(overallTotalLossPercentage)));
      } else {
        rowCells.add(DataCell(Text(rowTotalSummable.toStringAsFixed(2))));
      }

      consolidatedEnergyTableRows.add(DataRow(cells: rowCells));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Energy Account: ${widget.substationName} ($dateRangeText)',
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today),
            onPressed: _isViewingSavedSld ? null : () => _selectDate(context),
            tooltip: _isViewingSavedSld
                ? 'Date range cannot be changed for saved SLD'
                : 'Change Date Range',
          ),
          if (!_isViewingSavedSld &&
              (sldState.sldData?.selectedElementIds.isEmpty ?? true))
            IconButton(
              icon: const Icon(Icons.move_up),
              tooltip: 'Adjust SLD Layout',
              onPressed: () {
                SnackBarUtils.showSnackBar(
                  context,
                  'Tap and hold an element to adjust its position/size.',
                );
                sldState.setInteractionMode(SldInteractionMode.select);
              },
            ),
          if (!(sldState.sldData?.selectedElementIds.isEmpty ?? true))
            IconButton(
              icon: const Icon(Icons.cancel),
              tooltip: 'Cancel Adjustments',
              onPressed: () {
                sldState.clearSelection();
                sldState.setInteractionMode(SldInteractionMode.select);
                SnackBarUtils.showSnackBar(
                  context,
                  'Adjustments cancelled. Position not saved.',
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
                  child: Stack(
                    children: [
                      WidgetsToImage(
                        controller: _widgetsToImageController,
                        child: _isCapturingPdf
                            ?
                              // For PDF capture, render the custom painter in a fixed-size SizedBox
                              // to ensure consistent output dimensions.
                              SizedBox(
                                // Use the calculated content size for the painter's drawing area
                                // This assumes the painter itself can scale its content to fit.
                                width: effectiveContentWidth,
                                height: effectiveContentHeight,
                                child: CustomPaint(
                                  size: Size(
                                    effectiveContentWidth,
                                    effectiveContentHeight,
                                  ),
                                  painter: SingleLineDiagramPainter(
                                    sldData: currentSldData!,
                                    baysMap: _energyAccountService.baysMap,
                                    bayEnergyData:
                                        _energyAccountService.bayEnergyData,
                                    busEnergySummary:
                                        _energyAccountService.busEnergySummary,
                                    colorScheme: Theme.of(context).colorScheme,
                                    contentBounds: Size(
                                      maxXForContent - minXForContent,
                                      maxYForContent - minYForContent,
                                    ), // Pass Size
                                    originOffsetForPdf: originOffsetForPainter,
                                  ),
                                ),
                              )
                            :
                              // For interactive display, use InteractiveViewer
                              InteractiveViewer(
                                transformationController:
                                    _transformationController,
                                boundaryMargin: const EdgeInsets.all(
                                  double.infinity,
                                ),
                                minScale: 0.1,
                                maxScale: 4.0,
                                constrained: false,
                                onInteractionEnd: (details) {
                                  if (sldState.sldData != null) {
                                    sldState.updateCanvasTransform(
                                      _transformationController.value
                                          .getMaxScaleOnAxis(),
                                      Offset(
                                        _transformationController.value
                                            .getTranslation()
                                            .x,
                                        _transformationController.value
                                            .getTranslation()
                                            .y,
                                      ),
                                    );
                                  }
                                },
                                child: Container(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.background,
                                  child: Stack(
                                    children: [
                                      CustomPaint(
                                        size: Size(
                                          canvasWidthForPainter,
                                          canvasHeightForPainter,
                                        ),
                                        painter: _GridPainter(
                                          colorScheme: Theme.of(
                                            context,
                                          ).colorScheme,
                                          gridSize: 50.0,
                                          panOffset:
                                              currentSldData
                                                  ?.currentPanOffset ??
                                              Offset.zero,
                                          zoom:
                                              currentSldData?.currentZoom ??
                                              1.0,
                                        ),
                                      ),
                                      ...(currentSldData?.elements.values
                                              .whereType<SldNode>()
                                              .map((node) {
                                                return Positioned(
                                                  left: node.position.dx,
                                                  top: node.position.dy,
                                                  child: SldNodeWidget(
                                                    node: node,
                                                  ),
                                                );
                                              })
                                              .toList() ??
                                          []),
                                      ...(currentSldData?.elements.values
                                              .whereType<SldEdge>()
                                              .map((edge) {
                                                final SldNode? sourceNode =
                                                    currentSldData.nodes[edge
                                                        .sourceNodeId];
                                                final SldNode? targetNode =
                                                    currentSldData.nodes[edge
                                                        .targetNodeId];
                                                if (sourceNode != null &&
                                                    targetNode != null) {
                                                  return SldEdgeWidget(
                                                    edge: edge,
                                                    sourceNode: sourceNode,
                                                    targetNode: targetNode,
                                                  );
                                                }
                                                return const SizedBox.shrink();
                                              })
                                              .toList() ??
                                          []),
                                      ...(currentSldData?.elements.values
                                              .whereType<SldTextLabel>()
                                              .map((label) {
                                                return Positioned(
                                                  left: label.position.dx,
                                                  top: label.position.dy,
                                                  child: SldTextLabelWidget(
                                                    textLabel: label,
                                                  ),
                                                );
                                              })
                                              .toList() ??
                                          []),
                                    ],
                                  ),
                                ),
                              ),
                      ),
                    ],
                  ),
                ),
                if (!(sldState.sldData?.selectedElementIds.isEmpty ?? true))
                  _buildMovementControls(),
                Visibility(
                  visible: _showTables,
                  child: Column(
                    children: [
                      Container(
                        height: consolidatedTableHeight,
                        padding: const EdgeInsets.all(8.0),
                        child: Column(
                          children: [
                            Text(
                              'Consolidated Energy Abstract',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const Divider(),
                            Expanded(
                              child: SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: DataTable(
                                  columns: abstractTableHeaders
                                      .map(
                                        (header) => DataColumn(
                                          label: Text(
                                            header,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      )
                                      .toList(),
                                  rows: consolidatedEnergyTableRows,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        height: min(
                          (_energyAccountService
                                      .aggregatedFeederEnergyData
                                      .length *
                                  50.0) +
                              100,
                          MediaQuery.of(context).size.height * 0.4,
                        ),
                        padding: const EdgeInsets.all(8.0),
                        child: Column(
                          children: [
                            Text(
                              'Feeder Energy Supplied by Distribution Hierarchy',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const Divider(),
                            Expanded(
                              child: PageView.builder(
                                itemCount:
                                    (_energyAccountService
                                                .aggregatedFeederEnergyData
                                                .length /
                                            5)
                                        .ceil()
                                        .toInt() +
                                    (_energyAccountService
                                            .aggregatedFeederEnergyData
                                            .isEmpty
                                        ? 1
                                        : 0),
                                onPageChanged: (index) {
                                  setState(() {
                                    _feederTablePageIndex = index;
                                  });
                                },
                                itemBuilder: (context, pageIndex) {
                                  if (_energyAccountService
                                      .aggregatedFeederEnergyData
                                      .isEmpty) {
                                    return const Center(
                                      child: Text(
                                        'No aggregated feeder energy data available for this date range.',
                                      ),
                                    );
                                  }
                                  final int startIndex = pageIndex * 5;
                                  final int endIndex = (startIndex + 5).clamp(
                                    0,
                                    _energyAccountService
                                        .aggregatedFeederEnergyData
                                        .length,
                                  );
                                  final List<AggregatedFeederEnergyData>
                                  currentPageData = _energyAccountService
                                      .aggregatedFeederEnergyData
                                      .sublist(startIndex, endIndex);
                                  return SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: DataTable(
                                      columns: const [
                                        DataColumn(label: Text('D-Zone')),
                                        DataColumn(label: Text('D-Circle')),
                                        DataColumn(label: Text('D-Division')),
                                        DataColumn(
                                          label: Text('D-Subdivision'),
                                        ),
                                        DataColumn(label: Text('Import (MWH)')),
                                        DataColumn(label: Text('Export (MWH)')),
                                      ],
                                      rows: currentPageData.mapIndexed((
                                        index,
                                        data,
                                      ) {
                                        final AggregatedFeederEnergyData?
                                        prevDataOverall =
                                            (startIndex + index > 0)
                                            ? _energyAccountService
                                                  .aggregatedFeederEnergyData[startIndex +
                                                  index -
                                                  1]
                                            : null;
                                        final bool mergeZone =
                                            (prevDataOverall != null) &&
                                            data.zoneName ==
                                                prevDataOverall.zoneName;
                                        final bool mergeCircle =
                                            mergeZone &&
                                            data.circleName ==
                                                prevDataOverall.circleName;
                                        final bool mergeDivision =
                                            mergeCircle &&
                                            data.divisionName ==
                                                prevDataOverall.divisionName;
                                        final bool mergeSubdivision =
                                            mergeDivision &&
                                            data.distributionSubdivisionName ==
                                                prevDataOverall
                                                    .distributionSubdivisionName;
                                        return DataRow(
                                          cells: [
                                            DataCell(
                                              Text(
                                                mergeZone ? '' : data.zoneName,
                                              ),
                                            ),
                                            DataCell(
                                              Text(
                                                mergeCircle
                                                    ? ''
                                                    : data.circleName,
                                              ),
                                            ),
                                            DataCell(
                                              Text(
                                                mergeDivision
                                                    ? ''
                                                    : data.divisionName,
                                              ),
                                            ),
                                            DataCell(
                                              Text(
                                                mergeSubdivision
                                                    ? ''
                                                    : data.distributionSubdivisionName,
                                              ),
                                            ),
                                            DataCell(
                                              Text(
                                                data.importedEnergy
                                                    .toStringAsFixed(2),
                                              ),
                                            ),
                                            DataCell(
                                              Text(
                                                data.exportedEnergy
                                                    .toStringAsFixed(2),
                                              ),
                                            ),
                                          ],
                                        );
                                      }).toList(),
                                    ),
                                  );
                                },
                              ),
                            ),
                            if (_energyAccountService
                                .aggregatedFeederEnergyData
                                .isNotEmpty)
                              _buildPageIndicator(
                                (_energyAccountService
                                            .aggregatedFeederEnergyData
                                            .length /
                                        5)
                                    .ceil()
                                    .toInt(),
                                _feederTablePageIndex,
                              ),
                          ],
                        ),
                      ),
                      if ((_isViewingSavedSld &&
                              _loadedAssessmentsSummary.isNotEmpty) ||
                          (!_isViewingSavedSld &&
                              _energyAccountService
                                  .allAssessmentsForDisplay
                                  .isNotEmpty))
                        Container(
                          height: min(
                            ((_isViewingSavedSld
                                        ? _loadedAssessmentsSummary.length
                                        : _energyAccountService
                                              .allAssessmentsForDisplay
                                              .length) *
                                    60.0) +
                                100,
                            MediaQuery.of(context).size.height * 0.4,
                          ),
                          padding: const EdgeInsets.all(8.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Assessments for this Period:',
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              const Divider(),
                              Expanded(
                                child: SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: DataTable(
                                    columns: const [
                                      DataColumn(label: Text('Bay Name')),
                                      DataColumn(label: Text('Import Adj.')),
                                      DataColumn(label: Text('Export Adj.')),
                                      DataColumn(label: Text('Reason')),
                                      DataColumn(label: Text('Timestamp')),
                                    ],
                                    rows:
                                        (_isViewingSavedSld
                                                ? _loadedAssessmentsSummary
                                                : _energyAccountService
                                                      .allAssessmentsForDisplay
                                                      .map(
                                                        (e) => e.toFirestore(),
                                                      )
                                                      .toList())
                                            .map((assessmentMap) {
                                              final Assessment assessment =
                                                  Assessment.fromMap(
                                                    assessmentMap,
                                                  );
                                              final String assessedBayName =
                                                  assessmentMap['bayName'] ??
                                                  'N/A';
                                              return DataRow(
                                                cells: [
                                                  DataCell(
                                                    Text(assessedBayName),
                                                  ),
                                                  DataCell(
                                                    Text(
                                                      assessment.importAdjustment !=
                                                              null
                                                          ? assessment
                                                                .importAdjustment!
                                                                .toStringAsFixed(
                                                                  2,
                                                                )
                                                          : 'N/A',
                                                    ),
                                                  ),
                                                  DataCell(
                                                    Text(
                                                      assessment.exportAdjustment !=
                                                              null
                                                          ? assessment
                                                                .exportAdjustment!
                                                                .toStringAsFixed(
                                                                  2,
                                                                )
                                                          : 'N/A',
                                                    ),
                                                  ),
                                                  DataCell(
                                                    Text(assessment.reason),
                                                  ),
                                                  DataCell(
                                                    Text(
                                                      DateFormat(
                                                        'dd-MMM-yyyy HH:mm',
                                                      ).format(
                                                        assessment
                                                            .assessmentTimestamp
                                                            .toDate(),
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              );
                                            })
                                            .toList(),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        Container(
                          height: 100,
                          alignment: Alignment.center,
                          child: Text(
                            'No assessments were made for this period.',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(fontStyle: FontStyle.italic),
                            textAlign: TextAlign.center,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
      floatingActionButton: SpeedDial(
        icon: Icons.menu,
        activeIcon: Icons.close,
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        overlayColor: Colors.black,
        overlayOpacity: 0.5,
        spacing: 12,
        spaceBetweenChildren: 12,
        children: [
          SpeedDialChild(
            child: const Icon(Icons.save),
            backgroundColor:
                _isViewingSavedSld ||
                    !(_sldEditorState!.isDirty) ||
                    !(sldState.sldData?.selectedElementIds.isEmpty ?? true)
                ? Colors.grey
                : Colors.green,
            label: 'Save SLD',
            onTap:
                _isViewingSavedSld ||
                    !(_sldEditorState!.isDirty) ||
                    !(sldState.sldData?.selectedElementIds.isEmpty ?? true)
                ? null
                : _saveSld,
          ),
          SpeedDialChild(
            child: const Icon(Icons.print),
            backgroundColor: Colors.blue,
            label: 'Print/Share SLD',
            onTap: _shareCurrentSldAsPdf,
          ),
          SpeedDialChild(
            child: Icon(_showTables ? Icons.visibility_off : Icons.visibility),
            backgroundColor: Colors.orange,
            label: _showTables ? 'Hide Tables' : 'Show Tables',
            onTap: () {
              setState(() {
                _showTables = !_showTables;
              });
            },
          ),
          SpeedDialChild(
            child: const Icon(Icons.settings_input_antenna),
            backgroundColor: Colors.purple,
            label: 'Configure Busbar Energy',
            onTap:
                _isViewingSavedSld ||
                    !(sldState.sldData?.selectedElementIds.isEmpty ?? true)
                ? null
                : () => _showBusbarSelectionDialog(),
          ),
          SpeedDialChild(
            child: const Icon(Icons.assessment),
            backgroundColor: Colors.red,
            label: 'Add Energy Assessment',
            onTap:
                _isViewingSavedSld ||
                    !(sldState.sldData?.selectedElementIds.isEmpty ?? true)
                ? null
                : () => _showBaySelectionForAssessment(),
          ),
          SpeedDialChild(
            child: const Icon(Icons.add_circle),
            backgroundColor: Colors.blueGrey,
            label: 'Add New Bay',
            onTap: () {
              // Ensure _sldEditorState is not null before using it
              _sldEditorState?.addElement(
                Bay(
                  id: 'new_bay_${DateTime.now().microsecondsSinceEpoch}',
                  name: 'New Bay',
                  substationId: widget.substationId,
                  voltageLevel: '11kV',
                  bayType: BayType.Feeder,
                  createdBy: widget.currentUser.uid,
                  createdAt: Timestamp.now(),
                ).toSldNode(position: Offset(200, 200)),
              );
              SnackBarUtils.showSnackBar(
                context,
                'New bay added. Drag to position.',
              );
            },
          ),
          SpeedDialChild(
            child: const Icon(Icons.text_fields),
            backgroundColor: Colors.brown,
            label: 'Add Text Label',
            onTap: () {
              // Ensure _sldEditorState is not null before using it
              _sldEditorState?.addElement(
                SldTextLabel(
                  position: Offset(300, 300),
                  size: Size(100, 30),
                  text: 'New Label',
                  textStyle: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: 14,
                  ),
                ),
              );
              SnackBarUtils.showSnackBar(
                context,
                'New text label added. Drag to position.',
              );
            },
          ),
          SpeedDialChild(
            child: const Icon(Icons.link),
            backgroundColor: Colors.deepPurple,
            label: 'Draw Connection',
            onTap: () {
              // Ensure _sldEditorState is not null before using it
              _sldEditorState?.setInteractionMode(
                SldInteractionMode.drawConnection,
              );
              SnackBarUtils.showSnackBar(
                context,
                'Tap source node to start connection.',
              );
            },
          ),
          SpeedDialChild(
            child: const Icon(Icons.select_all),
            backgroundColor: Colors.teal,
            label: 'Select Mode',
            onTap: () {
              // Ensure _sldEditorState is not null before using it
              _sldEditorState?.setInteractionMode(SldInteractionMode.select);
              _sldEditorState?.clearSelection();
              SnackBarUtils.showSnackBar(context, 'Switched to select mode.');
            },
          ),
          SpeedDialChild(
            child: const Icon(Icons.undo),
            backgroundColor: sldState.canUndo
                ? Colors.grey.shade600
                : Colors.grey.shade300,
            label: 'Undo',
            onTap: sldState.canUndo ? sldState.undo : null,
          ),
          SpeedDialChild(
            child: const Icon(Icons.redo),
            backgroundColor: sldState.canRedo
                ? Colors.grey.shade600
                : Colors.grey.shade300,
            label: 'Redo',
            onTap: sldState.canRedo ? sldState.redo : null,
          ),
        ],
      ),
    );
  }
}

// Optional: A simple painter for the background grid if you want it
class _GridPainter extends CustomPainter {
  final ColorScheme colorScheme;
  final double gridSize;
  final Offset panOffset;
  final double zoom;

  _GridPainter({
    required this.colorScheme,
    this.gridSize = 50.0,
    this.panOffset = Offset.zero,
    this.zoom = 1.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = colorScheme.onSurface.withOpacity(0.1)
      ..strokeWidth = 0.5;

    final double effectiveGridSize = gridSize * zoom;
    final Offset effectivePanOffset = panOffset;

    for (
      double i = effectivePanOffset.dy % effectiveGridSize;
      i < size.height;
      i += effectiveGridSize
    ) {
      canvas.drawLine(Offset(0, i), Offset(size.width, i), paint);
    }
    for (
      double i = effectivePanOffset.dx % effectiveGridSize;
      i < size.width;
      i += effectiveGridSize
    ) {
      canvas.drawLine(Offset(i, 0), Offset(i, size.height), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _GridPainter oldDelegate) {
    return oldDelegate.colorScheme != colorScheme ||
        oldDelegate.gridSize != gridSize ||
        oldDelegate.panOffset != panOffset ||
        oldDelegate.zoom != zoom;
  }
}

// Dialog for configuring busbar energy contributions (remains unchanged)
class _BusbarEnergyAssignmentDialog extends StatefulWidget {
  final Bay busbar;
  final List<Bay> connectedBays;
  final AppUser currentUser;
  final Map<String, BusbarEnergyMap> currentMaps;
  final Function(BusbarEnergyMap) onSaveMap;
  final Function(String) onDeleteMap;

  const _BusbarEnergyAssignmentDialog({
    required this.busbar,
    required this.connectedBays,
    required this.currentUser,
    required this.currentMaps,
    required this.onSaveMap,
    required this.onDeleteMap,
  });

  @override
  __BusbarEnergyAssignmentDialogState createState() =>
      __BusbarEnergyAssignmentDialogState();
}

class __BusbarEnergyAssignmentDialogState
    extends State<_BusbarEnergyAssignmentDialog> {
  final Map<String, Map<String, dynamic>> _bayContributionSelections = {};
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    for (var bay in widget.connectedBays) {
      final existingMap = widget.currentMaps[bay.id];
      _bayContributionSelections[bay.id] = {
        'import':
            existingMap?.importContribution ?? EnergyContributionType.none,
        'export':
            existingMap?.exportContribution ?? EnergyContributionType.none,
        'originalMapId': existingMap?.id,
      };
    }
  }

  Future<void> _saveAllContributions() async {
    setState(() => _isSaving = true);
    try {
      for (var bayId in _bayContributionSelections.keys) {
        final selection = _bayContributionSelections[bayId]!;
        final originalMapId = selection['originalMapId'] as String?;
        final importContrib = selection['import'] as EnergyContributionType;
        final exportContrib = selection['export'] as EnergyContributionType;

        if (importContrib == EnergyContributionType.none &&
            exportContrib == EnergyContributionType.none) {
          if (originalMapId != null) {
            widget.onDeleteMap(originalMapId);
          }
        } else {
          final newMap = BusbarEnergyMap(
            id: originalMapId,
            substationId: widget.busbar.substationId,
            busbarId: widget.busbar.id,
            connectedBayId: bayId,
            importContribution: importContrib,
            exportContribution: exportContrib,
            createdBy: originalMapId != null
                ? widget.currentUser.uid
                : widget.currentUser.uid,
            createdAt: originalMapId != null
                ? Timestamp.now()
                : Timestamp.now(),
            lastModifiedAt: Timestamp.now(),
          );
          widget.onSaveMap(newMap);
        }
      }
      if (mounted) {
        SnackBarUtils.showSnackBar(context, 'Busbar energy assignments saved!');
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        SnackBarUtils.showSnackBar(
          context,
          'Failed to save assignments: $e',
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Assign Energy Flow for ${widget.busbar.name}'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Configure how energy from connected bays contributes to this busbar\'s import/export.',
            ),
            const SizedBox(height: 16),
            if (widget.connectedBays.isEmpty)
              const Text('No bays connected to this busbar.'),
            ...widget.connectedBays.map((bay) {
              final currentSelection = _bayContributionSelections[bay.id]!;
              return Card(
                margin: const EdgeInsets.symmetric(vertical: 8),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${bay.name} (${bay.bayType.toString().split('.').last})',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<EnergyContributionType>(
                        decoration: const InputDecoration(
                          labelText: 'Bay Import contributes to Busbar:',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        value: currentSelection['import'],
                        items: EnergyContributionType.values.map((type) {
                          return DropdownMenuItem(
                            value: type,
                            child: Text(
                              type
                                  .toString()
                                  .split('.')
                                  .last
                                  .replaceAll('bus', 'Bus '),
                            ),
                          );
                        }).toList(),
                        onChanged: (newValue) {
                          setState(() {
                            currentSelection['import'] = newValue;
                          });
                        },
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<EnergyContributionType>(
                        decoration: const InputDecoration(
                          labelText: 'Bay Export contributes to Busbar:',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        value: currentSelection['export'],
                        items: EnergyContributionType.values.map((type) {
                          return DropdownMenuItem(
                            value: type,
                            child: Text(
                              type
                                  .toString()
                                  .split('.')
                                  .last
                                  .replaceAll('bus', 'Bus '),
                            ),
                          );
                        }).toList(),
                        onChanged: (newValue) {
                          setState(() {
                            currentSelection['export'] = newValue;
                          });
                        },
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isSaving ? null : _saveAllContributions,
          child: _isSaving
              ? const CircularProgressIndicator(strokeWidth: 2)
              : const Text('Save Assignments'),
        ),
      ],
    );
  }
}
