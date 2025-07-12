import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:collection/collection.dart';
import 'dart:math';

import '../models/bay_model.dart';
import '../models/user_model.dart';
import '../models/bay_connection_model.dart';
import '../models/equipment_model.dart';
import '../models/substation_sld_layout_model.dart'; // Import the SLD layout model
import '../models/hierarchy_models.dart'; // Assuming Substation is now correctly defined here
import '../utils/snackbar_utils.dart';
import '../screens/bay_equipment_management_screen.dart';
import '../screens/bay_reading_assignment_screen.dart';
import 'energy_sld_screen.dart';

import '../widgets/bay_form_card.dart';
import '../painters/single_line_diagram_painter.dart';

enum BayDetailViewMode { list, add, edit }

enum MovementMode { bay, text }

class SubstationDetailScreen extends StatefulWidget {
  final String substationId;
  final String substationName;
  final AppUser currentUser;

  const SubstationDetailScreen({
    super.key,
    required this.substationId,
    required this.substationName,
    required this.currentUser,
  });

  @override
  State<SubstationDetailScreen> createState() => _SubstationDetailScreenState();
}

class _SubstationDetailScreenState extends State<SubstationDetailScreen> {
  BayDetailViewMode _viewMode = BayDetailViewMode.list;
  Bay? _bayToEdit;

  final TransformationController _transformationController =
      TransformationController();

  // These maps store the live/temporary positions/offsets/lengths during active movement.
  // They are passed to the painter to override the saved values.
  Map<String, Offset> _bayPositions = {};
  Map<String, Offset> _textOffsets = {};
  Map<String, double> _busbarLengths = {};

  String? _selectedBayForMovementId;
  MovementMode _movementMode = MovementMode.bay;

  static const double _movementStep = 10.0;
  static const double _busbarLengthStep = 20.0;

  // Class-level lists and maps to hold data from streams for global access
  List<Bay> _allBays = [];
  Map<String, Bay> _baysMap = {};
  List<BayConnection> _allConnections = [];
  List<EquipmentInstance> _allEquipmentInstances = [];
  Map<String, List<EquipmentInstance>> _equipmentByBayId = {};

  List<BayRenderData> _currentBayRenderDataList = [];

  List<Bay> _availableBusbars =
      []; // CORRECTED: Changed type from Substation to Bay
  bool _isLoadingBusbars = true;
  SubstationSldLayout? _substationSldLayout;

  @override
  void initState() {
    super.initState();
    _fetchBusbarsForBayForm();
    _fetchSubstationSldLayout();
  }

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  BayRenderData _createDummyBayRenderData() {
    return BayRenderData(
      bay: Bay(
        id: 'dummy',
        name: '',
        substationId: '',
        voltageLevel: '',
        bayType: '',
        createdBy: '',
        createdAt: Timestamp.now(),
      ),
      rect: Rect.zero,
      center: Offset.zero,
      topCenter: Offset.zero,
      bottomCenter: Offset.zero,
      leftCenter: Offset.zero,
      rightCenter: Offset.zero,
      textOffset: Offset.zero,
      busbarLength: 0.0,
    );
  }

  Future<void> _fetchSubstationSldLayout() async {
    try {
      final docSnapshot = await FirebaseFirestore.instance
          .collection('substationSldLayouts')
          .doc(widget.substationId) // Assuming doc ID is substationId
          .get();

      if (docSnapshot.exists) {
        _substationSldLayout = SubstationSldLayout.fromFirestore(docSnapshot);
        // Initialize local mutable maps from fetched layout for display
        _bayPositions.clear();
        _textOffsets.clear();
        _busbarLengths.clear();
        _substationSldLayout!.bayLayoutParameters.forEach((bayId, params) {
          _bayPositions[bayId] = Offset(params['x'] ?? 0.0, params['y'] ?? 0.0);
          _textOffsets[bayId] = Offset(
            params['textOffsetDx'] ?? 0.0,
            params['textOffsetDy'] ?? 0.0,
          );
          if (params['busbarLength'] != null) {
            _busbarLengths[bayId] = params['busbarLength']!;
          }
        });
      } else {
        // If no layout exists, create a default one (will be saved on first 'Done & Save')
        _substationSldLayout = SubstationSldLayout(
          id: widget.substationId,
          substationId: widget.substationId,
          createdAt: Timestamp.now(),
          lastModifiedAt: Timestamp.now(),
          createdBy: widget.currentUser.uid,
          lastModifiedBy: widget.currentUser.uid,
          bayLayoutParameters: {}, // Empty, will be populated on first save
        );
      }
    } catch (e) {
      if (mounted) {
        SnackBarUtils.showSnackBar(
          context,
          'Failed to load SLD layout: $e',
          isError: true,
        );
      }
      _substationSldLayout = null; // Ensure it's null if fetch fails
    } finally {
      if (mounted) {
        setState(() {}); // Trigger rebuild after layout is fetched
      }
    }
  }

  Future<void> _fetchBusbarsForBayForm() async {
    setState(() {
      _isLoadingBusbars = true;
    });
    try {
      final busbarSnapshot = await FirebaseFirestore.instance
          .collection('bays')
          .where('substationId', isEqualTo: widget.substationId)
          .where('bayType', isEqualTo: 'Busbar')
          .get();
      _availableBusbars = busbarSnapshot
          .docs // Corrected: Assign directly to List<Bay>
          .map((doc) => Bay.fromFirestore(doc))
          .toList();
    } catch (e) {
      if (mounted) {
        SnackBarUtils.showSnackBar(
          context,
          "Error fetching busbars for form: $e",
          isError: true,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingBusbars = false;
        });
      }
    }
  }

  void _setViewMode(BayDetailViewMode mode, {Bay? bay}) {
    setState(() {
      _viewMode = mode;
      _bayToEdit = bay;
      _selectedBayForMovementId = null;
      // When switching views, ensure temporary movement state is cleared.
      // The SLD painter will then read from _substationSldLayout or default.
      _bayPositions.clear();
      _textOffsets.clear();
      _busbarLengths.clear();
    });
    if (mode != BayDetailViewMode.list) {
      _fetchBusbarsForBayForm();
    }
  }

  void _onBayFormSaveSuccess() {
    _setViewMode(BayDetailViewMode.list);
    // After bay data changes, re-fetch SLD layout to ensure consistency
    _fetchSubstationSldLayout();
  }

  // Callback to receive layout data from the painter
  void _onPainterLayoutCalculated(
    Map<String, Rect> finalBayRects,
    Map<String, Rect> busbarRects,
    Map<String, Map<String, Offset>> busbarConnectionPoints,
    List<BayRenderData> bayRenderDataList,
  ) {
    setState(() {
      // These are the *rendered* rects and connections, used for hit testing.
      // They are updated every paint cycle.
      _currentBayRenderDataList = bayRenderDataList;
      // _renderedBayRects and other maps could be stored here if needed by other widgets in the screen.
      // For now, _currentBayRenderDataList is sufficient for hit-testing via its .rect property.

      // Only initialize _bayPositions, _textOffsets, _busbarLengths from the painter's calculated
      // data if we are NOT actively moving a bay, or if they are currently empty.
      // This ensures the temporary maps reflect the layout provided by the painter.
      if (_selectedBayForMovementId == null && _bayPositions.isEmpty) {
        for (var renderData in bayRenderDataList) {
          _bayPositions[renderData.bay.id] = renderData.center;
          _textOffsets[renderData.bay.id] = renderData.textOffset;
          _busbarLengths[renderData.bay.id] = renderData.busbarLength;
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _viewMode == BayDetailViewMode.list,
      onPopInvoked: (didPop) {
        if (!didPop && _viewMode != BayDetailViewMode.list) {
          _setViewMode(BayDetailViewMode.list);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text('Substation: ${widget.substationName}'),
          actions: [
            if (_viewMode == BayDetailViewMode.list &&
                _selectedBayForMovementId == null)
              IconButton(
                icon: const Icon(Icons.info_outline),
                onPressed: () => SnackBarUtils.showSnackBar(
                  context,
                  'Viewing details for ${widget.substationName}.',
                ),
              ),
            IconButton(
              icon: const Icon(Icons.flash_on),
              tooltip: 'View Energy SLD',
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => EnergySldScreen(
                      substationId: widget.substationId,
                      substationName: widget.substationName,
                      currentUser: widget.currentUser,
                    ),
                  ),
                );
              },
            ),
            if (_viewMode != BayDetailViewMode.list ||
                _selectedBayForMovementId != null)
              IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () {
                  if (_selectedBayForMovementId != null) {
                    setState(() {
                      _selectedBayForMovementId = null;
                      _bayPositions.clear();
                      _textOffsets.clear();
                      _busbarLengths.clear();
                    });
                    SnackBarUtils.showSnackBar(
                      context,
                      'Movement cancelled. Position not saved.',
                    );
                  } else {
                    _setViewMode(BayDetailViewMode.list);
                  }
                },
              ),
          ],
        ),
        body: (_viewMode == BayDetailViewMode.list)
            ? _buildSLDView()
            : BayFormCard(
                bayToEdit: _bayToEdit,
                substationId: widget.substationId,
                currentUser: widget.currentUser,
                onSaveSuccess: _onBayFormSaveSuccess,
                onCancel: () => _setViewMode(BayDetailViewMode.list),
                availableBusbars:
                    _availableBusbars, // Corrected name, now List<Bay>
              ),
        floatingActionButton:
            (_viewMode == BayDetailViewMode.list &&
                _selectedBayForMovementId == null)
            ? FloatingActionButton.extended(
                onPressed: () => _setViewMode(BayDetailViewMode.add),
                label: const Text('Add New Bay'),
                icon: const Icon(Icons.add),
              )
            : null,
        bottomNavigationBar: _selectedBayForMovementId != null
            ? _buildMovementControls()
            : null,
      ),
    );
  }

  Widget _buildMovementControls() {
    final selectedBayRenderData = _currentBayRenderDataList.firstWhereOrNull(
      (data) => data.bay.id == _selectedBayForMovementId,
    );

    if (selectedBayRenderData == null) return const SizedBox.shrink();

    final selectedBay = selectedBayRenderData.bay;

    return Container(
      padding: const EdgeInsets.all(8.0),
      color: Colors.blueGrey.shade800,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Editing: ${selectedBay.name}',
            style: const TextStyle(color: Colors.white, fontSize: 16),
          ),
          const SizedBox(height: 10),
          SegmentedButton<MovementMode>(
            segments: const [
              ButtonSegment(value: MovementMode.bay, label: Text('Move Bay')),
              ButtonSegment(value: MovementMode.text, label: Text('Move Text')),
            ],
            selected: {_movementMode},
            onSelectionChanged: (newSelection) {
              setState(() {
                _movementMode = newSelection.first;
              });
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
          if (selectedBay.bayType == 'Busbar') ...[
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
                  _busbarLengths[selectedBay.id]?.toStringAsFixed(0) ?? 'Auto',
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

  void _moveSelectedItem(double dx, double dy) {
    setState(() {
      if (_movementMode == MovementMode.bay) {
        final currentOffset =
            _bayPositions[_selectedBayForMovementId] ?? Offset.zero;
        _bayPositions[_selectedBayForMovementId!] = Offset(
          currentOffset.dx + dx,
          currentOffset.dy + dy,
        );

        // If the moved item is a busbar, adjust connected transformers, lines, and feeders
        final movedBay = _baysMap[_selectedBayForMovementId];
        if (movedBay != null && movedBay.bayType == 'Busbar') {
          for (var conn in _allConnections) {
            String otherBayId = '';
            if (conn.sourceBayId == movedBay.id) {
              otherBayId = conn.targetBayId;
            } else if (conn.targetBayId == movedBay.id) {
              otherBayId = conn.sourceBayId;
            } else {
              continue;
            }

            final otherBay = _baysMap[otherBayId];
            if (otherBay != null) {
              if (otherBay.bayType == 'Transformer') {
                final String hvBusId = otherBay.hvBusId!;
                final String lvBusId = otherBay.lvBusId!;

                // Get the current effective positions of the connected busbars
                final double hvBusY = _bayPositions[hvBusId]?.dy ?? 0.0;
                final double lvBusY = _bayPositions[lvBusId]?.dy ?? 0.0;

                // Update the transformer's Y position
                _bayPositions[otherBay.id] = Offset(
                  _bayPositions[otherBay.id]?.dx ?? 0.0, // Keep current X
                  (hvBusY + lvBusY) / 2, // New Y is midpoint
                );
              } else if (otherBay.bayType == 'Line' ||
                  otherBay.bayType == 'Feeder') {
                Offset currentOtherBayPos =
                    _bayPositions[otherBay.id] ?? Offset.zero;
                _bayPositions[otherBay.id] = Offset(
                  currentOtherBayPos.dx,
                  // Use the moved busbar's new Y position as reference
                  (_bayPositions[movedBay.id]?.dy ?? 0.0) +
                      (otherBay.bayType == 'Line' ? -70 - 10 : 10),
                );
              }
            }
          }
        }
      } else {
        final currentOffset =
            _textOffsets[_selectedBayForMovementId] ?? Offset.zero;
        _textOffsets[_selectedBayForMovementId!] = Offset(
          currentOffset.dx + dx,
          currentOffset.dy + dy,
        );
      }
    });
  }

  void _adjustBusbarLength(double change) {
    setState(() {
      final currentLength = _busbarLengths[_selectedBayForMovementId!] ?? 100.0;
      _busbarLengths[_selectedBayForMovementId!] = max(
        20.0,
        currentLength + change,
      );
    });
  }

  void _showBaySymbolActions(
    BuildContext context,
    Bay bay,
    Offset tapPosition,
  ) {
    final List<PopupMenuEntry<String>> menuItems = [
      const PopupMenuItem<String>(
        value: 'edit',
        child: ListTile(
          leading: Icon(Icons.edit),
          title: Text('Edit Bay Details'),
        ),
      ),
      const PopupMenuItem<String>(
        value: 'adjust',
        child: ListTile(
          leading: Icon(Icons.open_with),
          title: Text('Adjust Position/Size'),
        ),
      ),
    ];

    if (bay.bayType != 'Busbar') {
      menuItems.add(
        const PopupMenuItem<String>(
          value: 'manage_equipment',
          child: ListTile(
            leading: Icon(Icons.settings),
            title: Text('Manage Equipment'),
          ),
        ),
      );
    }

    menuItems.add(
      const PopupMenuItem<String>(
        value: 'readings',
        child: ListTile(
          leading: Icon(Icons.menu_book),
          title: Text('Manage Reading Assignments'),
        ),
      ),
    );

    menuItems.add(
      PopupMenuItem<String>(
        value: 'delete',
        child: ListTile(
          leading: Icon(
            Icons.delete,
            color: Theme.of(context).colorScheme.error,
          ),
          title: Text(
            'Delete Bay',
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ),
      ),
    );

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
        _setViewMode(BayDetailViewMode.edit, bay: bay);
      } else if (value == 'adjust') {
        setState(() {
          _selectedBayForMovementId = bay.id;
          // Initialize temporary positions/offsets/lengths from the loaded SLD layout
          final bayLayout = _substationSldLayout?.bayLayoutParameters[bay.id];
          _bayPositions[bay.id] = Offset(
            bayLayout?['x'] ?? 0,
            bayLayout?['y'] ?? 0,
          );
          _textOffsets[bay.id] = Offset(
            bayLayout?['textOffsetDx'] ?? 0,
            bayLayout?['textOffsetDy'] ?? 0,
          );
          if (bay.bayType == 'Busbar') {
            _busbarLengths[bay.id] = bayLayout?['busbarLength'] ?? 200.0;
          }
          _movementMode = MovementMode.bay;
        });
        SnackBarUtils.showSnackBar(
          context,
          'Selected "${bay.name}". Use controls below to adjust.',
        );
      } else if (value == 'manage_equipment') {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => BayEquipmentManagementScreen(
              bayId: bay.id,
              bayName: bay.name,
              substationId: widget.substationId,
              currentUser: widget.currentUser,
            ),
          ),
        );
      } else if (value == 'readings') {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => BayReadingAssignmentScreen(
              bayId: bay.id,
              bayName: bay.name,
              currentUser: widget.currentUser,
            ),
          ),
        );
      } else if (value == 'delete') {
        _confirmDeleteBay(context, bay);
      }
    });
  }

  BayRenderData? _getBayRenderData(
    String bayId,
    List<BayRenderData> bayRenderDataList,
  ) {
    try {
      return bayRenderDataList.firstWhere((data) => data.bay.id == bayId);
    } catch (e) {
      return null;
    }
  }

  Future<void> _saveChangesToFirestore() async {
    if (_selectedBayForMovementId == null) return;

    final bayId = _selectedBayForMovementId!;
    try {
      // Prepare the bayLayoutParameters map to save
      final Map<String, Map<String, double>> updatedLayoutParameters = Map.from(
        _substationSldLayout?.bayLayoutParameters ?? {},
      );

      // Update the specific bay's parameters
      updatedLayoutParameters[bayId] = {
        'x': _bayPositions[bayId]!.dx,
        'y': _bayPositions[bayId]!.dy,
        'textOffsetDx': _textOffsets[bayId]!.dx,
        'textOffsetDy': _textOffsets[bayId]!.dy,
        'busbarLength': _busbarLengths[bayId] ?? 0.0,
      };

      // Create a new or update existing SubstationSldLayout
      if (_substationSldLayout == null) {
        _substationSldLayout = SubstationSldLayout(
          id: widget.substationId,
          substationId: widget.substationId,
          createdAt: Timestamp.now(),
          lastModifiedAt: Timestamp.now(),
          createdBy: widget.currentUser.uid,
          lastModifiedBy: widget.currentUser.uid,
          bayLayoutParameters: updatedLayoutParameters,
        );
        await FirebaseFirestore.instance
            .collection('substationSldLayouts')
            .doc(widget.substationId)
            .set(_substationSldLayout!.toFirestore());
      } else {
        _substationSldLayout = _substationSldLayout!.copyWith(
          bayLayoutParameters: updatedLayoutParameters,
          lastModifiedAt: Timestamp.now(),
          lastModifiedBy: widget.currentUser.uid,
        );
        await FirebaseFirestore.instance
            .collection('substationSldLayouts')
            .doc(widget.substationId)
            .update(_substationSldLayout!.toFirestore());
      }

      if (mounted) {
        SnackBarUtils.showSnackBar(context, 'Changes saved successfully!');
      }
    } catch (e) {
      if (mounted) {
        SnackBarUtils.showSnackBar(
          context,
          'Failed to save changes: $e',
          isError: true,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _selectedBayForMovementId = null;
          // Clear temporary positions after saving, so next render pulls from Firestore via _onPainterLayoutCalculated
          _bayPositions.clear();
          _textOffsets.clear();
          _busbarLengths.clear();
        });
      }
    }
  }

  Future<void> _confirmDeleteBay(BuildContext context, Bay bay) async {
    final bool confirm =
        await showDialog(
          context: context,
          builder: (BuildContext context) => AlertDialog(
            title: const Text('Confirm Deletion'),
            content: Text(
              'Are you sure you want to delete bay "${bay.name}"? This will also remove all associated equipment and connections. This action cannot be undone.',
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
          ),
        ) ??
        false;
    if (confirm) {
      try {
        debugPrint('Attempting to delete bay: ${bay.id}');
        await FirebaseFirestore.instance
            .collection('bays')
            .doc(bay.id)
            .delete();
        debugPrint('Bay deleted: ${bay.id}. Now deleting connections...');
        final batch = FirebaseFirestore.instance.batch();
        final connectionsSnapshot = await FirebaseFirestore.instance
            .collection('bay_connections')
            .where('substationId', isEqualTo: widget.substationId)
            .where(
              Filter.or(
                Filter('sourceBayId', isEqualTo: bay.id),
                Filter('targetBayId', isEqualTo: bay.id),
              ),
            )
            .get();
        for (var doc in connectionsSnapshot.docs) {
          batch.delete(doc.reference);
        }
        await batch.commit();
        debugPrint('Connections deleted for bay: ${bay.id}');
        if (mounted) {
          SnackBarUtils.showSnackBar(
            context,
            'Bay "${bay.name}" deleted successfully!',
          );
          // After deleting a bay, re-fetch the SLD layout to ensure any auto-layout
          // adjustments for remaining bays are considered.
          _fetchSubstationSldLayout();
        }
      } catch (e) {
        debugPrint('Error deleting bay: $e');
        if (mounted) {
          SnackBarUtils.showSnackBar(
            context,
            'Failed to delete bay: $e',
            isError: true,
          );
        }
      }
    }
  }

  Widget _buildSLDView() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('bays')
          .where('substationId', isEqualTo: widget.substationId)
          .snapshots(),
      builder: (context, baysSnapshot) {
        if (baysSnapshot.hasError) {
          return Center(child: Text('Error: ${baysSnapshot.error}'));
        }
        if (baysSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!baysSnapshot.hasData || baysSnapshot.data!.docs.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: Text('No bays found. Click "+" to add one.'),
            ),
          );
        }

        // Update class-level _allBays and _baysMap
        _allBays = baysSnapshot.data!.docs
            .map((doc) => Bay.fromFirestore(doc))
            .toList();
        _baysMap = {for (var bay in _allBays) bay.id: bay};

        // If layout not loaded yet, show loading. This handles the initial fetch.
        // Or if bays are loaded but layout is not.
        if (_substationSldLayout == null) {
          return const Center(child: CircularProgressIndicator());
        }

        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('bay_connections')
              .where('substationId', isEqualTo: widget.substationId)
              .snapshots(),
          builder: (context, connectionsSnapshot) {
            if (connectionsSnapshot.hasError) {
              return Center(child: Text('Error: ${connectionsSnapshot.error}'));
            }
            if (connectionsSnapshot.connectionState ==
                ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            // Update class-level _allConnections
            _allConnections =
                connectionsSnapshot.data?.docs
                    .map((doc) => BayConnection.fromFirestore(doc))
                    .toList() ??
                [];

            return StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('equipmentInstances')
                  .where('substationId', isEqualTo: widget.substationId)
                  .snapshots(),
              builder: (context, equipmentSnapshot) {
                if (equipmentSnapshot.hasError) {
                  return Center(
                    child: Text('Error: ${equipmentSnapshot.error}'),
                  );
                }
                if (equipmentSnapshot.connectionState ==
                    ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                // Update class-level _allEquipmentInstances and _equipmentByBayId
                _allEquipmentInstances =
                    equipmentSnapshot.data?.docs
                        .map((doc) => EquipmentInstance.fromFirestore(doc))
                        .toList() ??
                    [];

                _equipmentByBayId.clear();
                for (var eq in _allEquipmentInstances) {
                  _equipmentByBayId.putIfAbsent(eq.bayId, () => []).add(eq);
                }

                return LayoutBuilder(
                  builder: (context, constraints) {
                    // Max size for the painter's canvas, allowing InteractiveViewer to handle scaling
                    final painterCanvasSize = Size(
                      constraints.maxWidth * 2,
                      constraints.maxHeight * 2,
                    );

                    return InteractiveViewer(
                      transformationController: _transformationController,
                      boundaryMargin: const EdgeInsets.all(double.infinity),
                      minScale: 0.1,
                      maxScale: 4.0,
                      constrained: false, // Important for custom painter size
                      child: GestureDetector(
                        // GestureDetector wraps CustomPaint
                        behavior: HitTestBehavior
                            .opaque, // Ensures gestures are captured over transparent areas
                        onTapUp: (details) {
                          // Transform local position to painter's coordinate system
                          final RenderBox renderBox =
                              context.findRenderObject() as RenderBox;
                          final Offset localPosition = renderBox.globalToLocal(
                            details.globalPosition,
                          );
                          final scenePosition = _transformationController
                              .toScene(localPosition);

                          // Use the _currentBayRenderDataList populated by the painter for hit testing
                          final tappedBay = _currentBayRenderDataList
                              .firstWhere(
                                (data) => data.rect.contains(scenePosition),
                                orElse: _createDummyBayRenderData,
                              );

                          if (tappedBay.bay.id != 'dummy') {
                            if (_selectedBayForMovementId == null) {
                              _showBaySymbolActions(
                                context,
                                tappedBay.bay,
                                details.globalPosition,
                              );
                            }
                          }
                        },
                        onLongPressStart: (details) {
                          // Transform local position to painter's coordinate system
                          final RenderBox renderBox =
                              context.findRenderObject() as RenderBox;
                          final Offset localPosition = renderBox.globalToLocal(
                            details.globalPosition,
                          );
                          final scenePosition = _transformationController
                              .toScene(localPosition);

                          // Use the _currentBayRenderDataList populated by the painter for hit testing
                          final tappedBay = _currentBayRenderDataList
                              .firstWhere(
                                (data) => data.rect.contains(scenePosition),
                                orElse: _createDummyBayRenderData,
                              );
                          if (tappedBay.bay.id != 'dummy') {
                            _showBaySymbolActions(
                              context,
                              tappedBay.bay,
                              details.globalPosition,
                            );
                          }
                        },
                        child: CustomPaint(
                          size: painterCanvasSize,
                          painter: SingleLineDiagramPainter(
                            allBays: _allBays, // Pass class-level variable
                            bayConnections:
                                _allConnections, // Pass class-level variable
                            baysMap: _baysMap, // Pass class-level variable
                            createDummyBayRenderData: _createDummyBayRenderData,
                            debugDrawHitboxes: true, // Keep for debugging
                            selectedBayForMovementId: _selectedBayForMovementId,
                            currentBayPositions:
                                _bayPositions, // Pass screen's live editing state
                            currentTextOffsets:
                                _textOffsets, // Pass screen's live editing state
                            currentBusbarLengths:
                                _busbarLengths, // Pass screen's live editing state
                            bayEnergyData:
                                const {}, // No energy data on this screen
                            busEnergySummary:
                                const {}, // No energy data on this screen
                            savedBayLayoutParameters:
                                _substationSldLayout?.bayLayoutParameters ??
                                {}, // Pass the fetched saved layout
                            onLayoutCalculated:
                                _onPainterLayoutCalculated, // Receive layout data from painter
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  double _getVoltageLevelValue(String voltageLevel) {
    final regex = RegExp(r'(\d+(\.\d+)?)');
    final match = regex.firstMatch(voltageLevel);
    if (match != null) {
      return double.tryParse(match.group(1)!) ?? 0.0;
    }
    return 0.0;
  }
}
