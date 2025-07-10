// lib/screens/substation_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:collection/collection.dart'; // Import for firstWhereOrNull
import 'dart:math'; // Ensure this is imported for 'max'

import '../models/bay_model.dart';
import '../models/user_model.dart';
import '../models/bay_connection_model.dart';
import '../models/equipment_model.dart'; // For EquipmentInstance model
import '../utils/snackbar_utils.dart';
import '../screens/bay_equipment_management_screen.dart'; // To manage equipment list
import '../screens/bay_reading_assignment_screen.dart';
import 'energy_sld_screen.dart'; // Import EnergySldScreen for BayEnergyData and SldRenderData

// Import the new split files
import '../widgets/bay_form_card.dart'; // NEW: Import the BayFormCard widget
import '../painters/single_line_diagram_painter.dart'; // NEW: Import the SingleLineDiagramPainter

enum BayDetailViewMode { list, add, edit }

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

  // New state variables for movement
  Map<String, Offset> _bayPositions = {}; // Stores x,y for each bay ID
  String?
  _selectedBayForMovementId; // ID of the bay currently selected for movement
  static const double _movementStep =
      10.0; // How many pixels to move per button press

  // This variable needs to be accessible in _buildMovementControls, so it must be a class member
  List<BayRenderData> _currentBayRenderDataList = [];

  // Variables for form data that might be needed by BayFormCard
  List<Bay> _availableBusbars = [];
  bool _isLoadingBusbars = true; // New loading state for busbars

  @override
  void initState() {
    super.initState();
    _fetchBusbarsInSubstation(); // Fetch busbars initially
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
    );
  }

  Future<void> _fetchBusbarsInSubstation() async {
    setState(() {
      _isLoadingBusbars = true;
    });
    try {
      final busbarSnapshot = await FirebaseFirestore.instance
          .collection('bays')
          .where('substationId', isEqualTo: widget.substationId)
          .where('bayType', isEqualTo: 'Busbar')
          .get();
      _availableBusbars = busbarSnapshot.docs
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
      _selectedBayForMovementId = null; // Exit movement mode
    });
    if (mode != BayDetailViewMode.list) {
      // If going to add/edit, ensure busbars are fresh for the form
      _fetchBusbarsInSubstation();
    }
  }

  void _onBayFormSaveSuccess() {
    _setViewMode(BayDetailViewMode.list);
    // You might want to refresh main SLD data here if it's not reactive
    // via streams already. StreamBuilder handles it automatically usually.
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
                      _bayPositions
                          .clear(); // Clear local positions to re-read from Firestore
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
                availableBusbars: _availableBusbars, // Pass busbars here
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
    return Container(
      padding: const EdgeInsets.all(8.0),
      color: Colors.blueGrey.shade800,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Moving: ${_getBayRenderData(_selectedBayForMovementId!, _currentBayRenderDataList)?.bay.name ?? "Bay"}',
            style: const TextStyle(color: Colors.white, fontSize: 16),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back),
                color: Colors.white,
                onPressed: () {
                  setState(() {
                    final currentOffset =
                        _bayPositions[_selectedBayForMovementId];
                    if (currentOffset != null) {
                      _bayPositions[_selectedBayForMovementId!] = Offset(
                        currentOffset.dx - _movementStep,
                        currentOffset.dy,
                      );
                    }
                  });
                },
              ),
              Column(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_upward),
                    color: Colors.white,
                    onPressed: () {
                      setState(() {
                        final currentOffset =
                            _bayPositions[_selectedBayForMovementId];
                        if (currentOffset != null) {
                          _bayPositions[_selectedBayForMovementId!] = Offset(
                            currentOffset.dx,
                            currentOffset.dy - _movementStep,
                          );
                        }
                      });
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.arrow_downward),
                    color: Colors.white,
                    onPressed: () {
                      setState(() {
                        final currentOffset =
                            _bayPositions[_selectedBayForMovementId];
                        if (currentOffset != null) {
                          _bayPositions[_selectedBayForMovementId!] = Offset(
                            currentOffset.dx,
                            currentOffset.dy + _movementStep,
                          );
                        }
                      });
                    },
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.arrow_forward),
                color: Colors.white,
                onPressed: () {
                  setState(() {
                    final currentOffset =
                        _bayPositions[_selectedBayForMovementId];
                    if (currentOffset != null) {
                      _bayPositions[_selectedBayForMovementId!] = Offset(
                        currentOffset.dx + _movementStep,
                        currentOffset.dy,
                      );
                    }
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 10),
          ElevatedButton(
            onPressed: () async {
              if (_selectedBayForMovementId != null &&
                  _bayPositions.containsKey(_selectedBayForMovementId!)) {
                await _updateBayPositionInFirestore(
                  _selectedBayForMovementId!,
                  _bayPositions[_selectedBayForMovementId!]!,
                );
              }
              setState(() {
                _selectedBayForMovementId = null;
                _bayPositions
                    .clear(); // Clear local cache to re-read from Firestore on next load
              });
            },
            child: const Text('Done Moving & Save'),
          ),
        ],
      ),
    );
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
    ];

    if (bay.bayType != 'Busbar') {
      menuItems.add(
        const PopupMenuItem<String>(
          value: 'move',
          child: ListTile(
            leading: Icon(Icons.open_with),
            title: Text('Move Bay'),
          ),
        ),
      );
    }

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
      } else if (value == 'move') {
        setState(() {
          _selectedBayForMovementId = bay.id;
        });
        SnackBarUtils.showSnackBar(
          context,
          'Selected "${bay.name}" for movement. Use controls below.',
        );
      } else if (value == 'manage_equipment') {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => BayEquipmentManagementScreen(
              bayId: bay.id,
              bayName: bay.name,
              substationId: widget.substationId, // Pass substationId
              currentUser: widget.currentUser, // Pass currentUser
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

  Future<void> _updateBayPositionInFirestore(
    String bayId,
    Offset newPosition,
  ) async {
    try {
      await FirebaseFirestore.instance.collection('bays').doc(bayId).update({
        'xPosition': newPosition.dx,
        'yPosition': newPosition.dy,
      });
      SnackBarUtils.showSnackBar(context, 'Bay position saved!');
    } catch (e) {
      if (mounted) {
        SnackBarUtils.showSnackBar(
          context,
          'Failed to save bay position: $e',
          isError: true,
        );
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
        await FirebaseFirestore.instance
            .collection('bays')
            .doc(bay.id)
            .delete();
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
        if (mounted) {
          SnackBarUtils.showSnackBar(
            context,
            'Bay "${bay.name}" deleted successfully!',
          );
        }
      } catch (e) {
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

        final allBays = baysSnapshot.data!.docs
            .map((doc) => Bay.fromFirestore(doc))
            .toList();
        final baysMap = {for (var bay in allBays) bay.id: bay};

        // Initialize _bayPositions from Firestore data on initial load
        if (_selectedBayForMovementId == null && _bayPositions.isEmpty) {
          for (var bay in allBays) {
            if (bay.xPosition != null && bay.yPosition != null) {
              _bayPositions[bay.id] = Offset(bay.xPosition!, bay.yPosition!);
            }
          }
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

            final allConnections =
                connectionsSnapshot.data?.docs
                    .map((doc) => BayConnection.fromFirestore(doc))
                    .toList() ??
                [];

            // Fetch all equipment instances for this substation
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

                final allEquipmentInstances =
                    equipmentSnapshot.data?.docs
                        .map((doc) => EquipmentInstance.fromFirestore(doc))
                        .toList() ??
                    [];

                final Map<String, List<EquipmentInstance>> equipmentByBayId =
                    {};
                for (var eq in allEquipmentInstances) {
                  equipmentByBayId.putIfAbsent(eq.bayId, () => []).add(eq);
                }

                final bayRenderDataList = <BayRenderData>[];
                final busbarRects = <String, Rect>{};
                final busbarConnectionPoints = <String, Map<String, Offset>>{};

                const double symbolWidth = 60;
                const double symbolHeight = 60;
                const double horizontalSpacing = 100;
                const double verticalBusbarSpacing = 200;
                const double topPadding = 80;
                const double sidePadding = 100;
                const double busbarHitboxHeight = 20.0;
                const double lineFeederHeight = 40.0;

                final busbars = allBays
                    .where((b) => b.bayType == 'Busbar')
                    .toList();
                busbars.sort((a, b) {
                  double getV(String v) =>
                      double.tryParse(v.replaceAll(RegExp(r'[^0-9.]'), '')) ??
                      0;
                  return getV(b.voltageLevel).compareTo(getV(a.voltageLevel));
                });

                Map<String, double> busYPositions = {};
                for (int i = 0; i < busbars.length; i++) {
                  busYPositions[busbars[i].id] =
                      topPadding + i * verticalBusbarSpacing;
                }

                Map<String, List<Bay>> busbarToConnectedBaysAbove = {};
                Map<String, List<Bay>> busbarToConnectedBaysBelow = {};
                Map<String, Map<String, List<Bay>>> transformersByBusPair = {};

                for (var bay in allBays) {
                  if (bay.bayType == 'Transformer') {
                    if (bay.hvBusId != null && bay.lvBusId != null) {
                      final hvBus = baysMap[bay.hvBusId];
                      final lvBus = baysMap[bay.lvBusId];
                      if (hvBus != null && lvBus != null) {
                        final double hvVoltage =
                            double.tryParse(
                              hvBus.voltageLevel.replaceAll(
                                RegExp(r'[^0-9.]'),
                                '',
                              ),
                            ) ??
                            0;
                        final double lvVoltage =
                            double.tryParse(
                              lvBus.voltageLevel.replaceAll(
                                RegExp(r'[^0-9.]'),
                                '',
                              ),
                            ) ??
                            0;

                        String key = "";
                        if (hvVoltage > lvVoltage) {
                          key = "${hvBus.id}-${lvBus.id}";
                        } else {
                          key = "${lvBus.id}-${hvBus.id}";
                        }
                        transformersByBusPair
                            .putIfAbsent(key, () => {})
                            .putIfAbsent(hvBus.id, () => [])
                            .add(bay);
                      } else {
                        debugPrint(
                          'Transformer ${bay.name} (${bay.id}) linked to non-busbar or missing bus: HV=${bay.hvBusId}, LV=${bay.lvBusId}',
                        );
                      }
                    }
                  } else if (bay.bayType != 'Busbar') {
                    final connectionToBus = allConnections.firstWhereOrNull((
                      c,
                    ) {
                      final bool sourceIsBay = c.sourceBayId == bay.id;
                      final bool targetIsBay = c.targetBayId == bay.id;
                      final bool sourceIsBus =
                          baysMap[c.sourceBayId]?.bayType == 'Busbar';
                      final bool targetIsBus =
                          baysMap[c.targetBayId]?.bayType == 'Busbar';
                      return (sourceIsBay && targetIsBus) ||
                          (targetIsBay && sourceIsBus);
                    });

                    if (connectionToBus != null) {
                      String connectedBusId =
                          baysMap[connectionToBus.sourceBayId]?.bayType ==
                              'Busbar'
                          ? connectionToBus.sourceBayId
                          : connectionToBus.targetBayId;

                      if (bay.bayType == 'Line') {
                        busbarToConnectedBaysAbove
                            .putIfAbsent(connectedBusId, () => [])
                            .add(bay);
                      } else {
                        busbarToConnectedBaysBelow
                            .putIfAbsent(connectedBusId, () => [])
                            .add(bay);
                      }
                    }
                  }
                }

                busbarToConnectedBaysAbove.forEach(
                  (key, value) =>
                      value.sort((a, b) => a.name.compareTo(b.name)),
                );
                busbarToConnectedBaysBelow.forEach(
                  (key, value) =>
                      value.sort((a, b) => a.name.compareTo(b.name)),
                );
                transformersByBusPair.forEach((pairKey, transformersMap) {
                  transformersMap.forEach((busId, transformers) {
                    transformers.sort((a, b) => a.name.compareTo(b.name));
                  });
                });

                Map<String, Rect> finalBayRects = {};
                double maxOverallXForCanvas = sidePadding;
                double nextTransformerX = sidePadding;
                final List<Bay> placedTransformers = [];

                for (var busPairEntry in transformersByBusPair.entries) {
                  final String pairKey = busPairEntry.key;
                  final Map<String, List<Bay>> transformersForPair =
                      busPairEntry.value;

                  List<String> busIdsInPair = pairKey.split('-');
                  String hvBusId = busIdsInPair[0];
                  String lvBusId = busIdsInPair[1];

                  if (!busYPositions.containsKey(hvBusId) ||
                      !busYPositions.containsKey(lvBusId)) {
                    debugPrint(
                      'Skipping transformer group for pair $pairKey: One or both bus IDs not found in busYPositions.',
                    );
                    continue;
                  }

                  final Bay? currentHvBus = baysMap[hvBusId];
                  final Bay? currentLvBus = baysMap[lvBusId];

                  if (currentHvBus == null || currentLvBus == null) {
                    debugPrint(
                      'Skipping transformer group for pair $pairKey: One or both bus objects not found in baysMap.',
                    );
                    continue;
                  }

                  final double hvVoltageValue = _getVoltageLevelValue(
                    currentHvBus.voltageLevel,
                  );
                  final double lvVoltageValue = _getVoltageLevelValue(
                    currentLvBus.voltageLevel,
                  );

                  if (hvVoltageValue < lvVoltageValue) {
                    String temp = hvBusId;
                    hvBusId = lvBusId;
                    lvBusId = temp;
                  }

                  final double hvBusY = busYPositions[hvBusId]!;
                  final double lvBusY = busYPositions[lvBusId]!;

                  final List<Bay> transformers =
                      transformersForPair[hvBusId] ??
                      transformersForPair[lvBusId] ??
                      [];
                  for (var tf in transformers) {
                    if (!placedTransformers.contains(tf)) {
                      Offset calculatedOffset = Offset(
                        nextTransformerX + symbolWidth / 2,
                        (hvBusY + lvBusY) / 2,
                      );

                      Offset finalOffset =
                          _bayPositions[tf.id] ??
                          (tf.xPosition != null && tf.yPosition != null
                              ? Offset(tf.xPosition!, tf.yPosition!)
                              : calculatedOffset);

                      if (!_bayPositions.containsKey(tf.id) &&
                          (tf.xPosition == null || tf.yPosition == null)) {
                        _bayPositions[tf.id] = finalOffset;
                      }

                      final tfRect = Rect.fromCenter(
                        center: finalOffset,
                        width: symbolWidth,
                        height: symbolHeight,
                      );
                      finalBayRects[tf.id] = tfRect;
                      nextTransformerX += horizontalSpacing;
                      placedTransformers.add(tf);
                      maxOverallXForCanvas = max(
                        maxOverallXForCanvas,
                        tfRect.right,
                      );
                    }
                  }
                }

                double currentLaneXForOtherBays = nextTransformerX;

                for (var busbar in busbars) {
                  final double busY = busYPositions[busbar.id]!;

                  final List<Bay> baysAbove = List.from(
                    busbarToConnectedBaysAbove[busbar.id] ?? [],
                  );
                  double currentX = currentLaneXForOtherBays;
                  for (var bay in baysAbove) {
                    Offset calculatedOffset = Offset(
                      currentX,
                      busY - lineFeederHeight - 10,
                    );
                    Offset finalOffset =
                        _bayPositions[bay.id] ??
                        (bay.xPosition != null && bay.yPosition != null
                            ? Offset(bay.xPosition!, bay.yPosition!)
                            : calculatedOffset);

                    if (!_bayPositions.containsKey(bay.id) &&
                        (bay.xPosition == null || bay.yPosition == null)) {
                      _bayPositions[bay.id] = finalOffset;
                    }

                    final bayRect = Rect.fromLTWH(
                      finalOffset.dx,
                      finalOffset.dy,
                      symbolWidth,
                      lineFeederHeight,
                    );
                    finalBayRects[bay.id] = bayRect;
                    currentX += horizontalSpacing;
                  }
                  maxOverallXForCanvas = max(maxOverallXForCanvas, currentX);

                  final List<Bay> baysBelow = List.from(
                    busbarToConnectedBaysBelow[busbar.id] ?? [],
                  );
                  currentX = currentLaneXForOtherBays;
                  for (var bay in baysBelow) {
                    Offset calculatedOffset = Offset(currentX, busY + 10);
                    Offset finalOffset =
                        _bayPositions[bay.id] ??
                        (bay.xPosition != null && bay.yPosition != null
                            ? Offset(bay.xPosition!, bay.yPosition!)
                            : calculatedOffset);

                    if (!_bayPositions.containsKey(bay.id) &&
                        (bay.xPosition == null || bay.yPosition == null)) {
                      _bayPositions[bay.id] = finalOffset;
                    }

                    final bayRect = Rect.fromLTWH(
                      finalOffset.dx,
                      finalOffset.dy,
                      symbolWidth,
                      lineFeederHeight,
                    );
                    finalBayRects[bay.id] = bayRect;
                    currentX += horizontalSpacing;
                  }
                  maxOverallXForCanvas = max(maxOverallXForCanvas, currentX);
                }

                for (var busbar in busbars) {
                  final double busY = busYPositions[busbar.id]!;
                  double maxConnectedBayX = sidePadding;

                  allBays.where((b) => b.bayType != 'Busbar').forEach((bay) {
                    if (bay.bayType == 'Transformer') {
                      if ((bay.hvBusId == busbar.id ||
                              bay.lvBusId == busbar.id) &&
                          finalBayRects.containsKey(bay.id)) {
                        maxConnectedBayX = max(
                          maxConnectedBayX,
                          finalBayRects[bay.id]!.right,
                        );
                      }
                    } else {
                      final connectionToBus = allConnections.firstWhereOrNull((
                        c,
                      ) {
                        return (c.sourceBayId == bay.id &&
                                c.targetBayId == busbar.id) ||
                            (c.targetBayId == bay.id &&
                                c.sourceBayId == busbar.id);
                      });
                      if (connectionToBus != null &&
                          finalBayRects.containsKey(bay.id)) {
                        maxConnectedBayX = max(
                          maxConnectedBayX,
                          finalBayRects[bay.id]!.right,
                        );
                      }
                    }
                  });

                  final double effectiveBusWidth = max(
                    maxConnectedBayX - sidePadding + horizontalSpacing,
                    symbolWidth * 2,
                  ).toDouble();

                  final Rect drawingRect = Rect.fromLTWH(
                    sidePadding,
                    busY,
                    effectiveBusWidth,
                    0,
                  );
                  busbarRects[busbar.id] = drawingRect;

                  final Rect tappableRect = Rect.fromCenter(
                    center: Offset(sidePadding + effectiveBusWidth / 2, busY),
                    width: effectiveBusWidth,
                    height: busbarHitboxHeight,
                  );
                  finalBayRects[busbar.id] = tappableRect;
                }

                final List<String> allowedVisualBayTypes = [
                  'Busbar',
                  'Transformer',
                  'Line',
                  'Feeder',
                ];

                for (var bay in allBays) {
                  if (!allowedVisualBayTypes.contains(bay.bayType)) {
                    continue;
                  }
                  final Rect? rect = finalBayRects[bay.id];
                  if (rect != null) {
                    bayRenderDataList.add(
                      BayRenderData(
                        bay: bay,
                        rect: rect,
                        center: rect.center,
                        topCenter: rect.topCenter,
                        bottomCenter: rect.bottomCenter,
                        leftCenter: rect.centerLeft,
                        rightCenter: rect.centerRight,
                        equipmentInstances:
                            equipmentByBayId[bay.id] ?? [], // Pass equipment
                      ),
                    );
                  }
                }

                _currentBayRenderDataList = bayRenderDataList;

                for (var connection in allConnections) {
                  final sourceBay = baysMap[connection.sourceBayId];
                  final targetBay = baysMap[connection.targetBayId];
                  if (sourceBay == null || targetBay == null) continue;

                  if (!allowedVisualBayTypes.contains(sourceBay.bayType) ||
                      !allowedVisualBayTypes.contains(targetBay.bayType)) {
                    continue;
                  }

                  if (sourceBay.bayType == 'Busbar' &&
                      targetBay.bayType == 'Transformer') {
                    final Rect? targetRect = finalBayRects[targetBay.id];
                    final double? busY = busYPositions[sourceBay.id];
                    if (targetRect != null && busY != null) {
                      busbarConnectionPoints.putIfAbsent(
                        sourceBay.id,
                        () => {},
                      )[targetBay.id] = Offset(
                        targetRect.center.dx,
                        busY,
                      );
                    }
                  } else if (targetBay.bayType == 'Busbar' &&
                      sourceBay.bayType == 'Transformer') {
                    final Rect? sourceRect = finalBayRects[sourceBay.id];
                    final double? busY = busYPositions[targetBay.id];
                    if (sourceRect != null && busY != null) {
                      busbarConnectionPoints.putIfAbsent(
                        targetBay.id,
                        () => {},
                      )[sourceBay.id] = Offset(
                        sourceRect.center.dx,
                        busY,
                      );
                    }
                  } else if (sourceBay.bayType == 'Busbar' &&
                      targetBay.bayType != 'Busbar') {
                    final Rect? targetRect = finalBayRects[targetBay.id];
                    final double? busY = busYPositions[sourceBay.id];
                    if (targetRect != null && busY != null) {
                      busbarConnectionPoints.putIfAbsent(
                        sourceBay.id,
                        () => {},
                      )[targetBay.id] = Offset(
                        targetRect.center.dx,
                        busY,
                      );
                    }
                  } else if (targetBay.bayType == 'Busbar' &&
                      sourceBay.bayType != 'Busbar') {
                    final sourceRect = finalBayRects[sourceBay.id];
                    final double? busY = busYPositions[targetBay.id];
                    if (sourceRect != null && busY != null) {
                      busbarConnectionPoints.putIfAbsent(
                        targetBay.id,
                        () => {},
                      )[sourceBay.id] = Offset(
                        sourceRect.center.dx,
                        busY,
                      );
                    }
                  }
                }

                double canvasWidth = maxOverallXForCanvas + sidePadding + 50;
                double canvasHeight = busYPositions.values.isNotEmpty
                    ? busYPositions.values.last +
                          verticalBusbarSpacing / 2 +
                          100
                    : topPadding + verticalBusbarSpacing;

                canvasWidth = max(
                  MediaQuery.of(context).size.width,
                  canvasWidth,
                );
                canvasHeight = max(
                  MediaQuery.of(context).size.height,
                  canvasHeight,
                );

                return InteractiveViewer(
                  transformationController: _transformationController,
                  boundaryMargin: const EdgeInsets.all(double.infinity),
                  minScale: 0.1,
                  maxScale: 4.0,
                  constrained: false,
                  child: GestureDetector(
                    onTapUp: (details) {
                      final RenderBox renderBox =
                          context.findRenderObject() as RenderBox;
                      final Offset localPosition = renderBox.globalToLocal(
                        details.globalPosition,
                      );
                      final scenePosition = _transformationController.toScene(
                        localPosition,
                      );

                      final tappedBay = _currentBayRenderDataList.firstWhere(
                        (data) => data.rect.contains(scenePosition),
                        orElse: _createDummyBayRenderData,
                      );

                      if (tappedBay.bay.id != 'dummy') {
                        debugPrint(
                          'Tapped Bay: ${tappedBay.bay.name} at ${scenePosition}',
                        );
                        if (_selectedBayForMovementId == null) {
                          _setViewMode(
                            BayDetailViewMode.edit,
                            bay: tappedBay.bay,
                          );
                        }
                      } else {
                        debugPrint('Tapped: No Bay found at ${scenePosition}');
                        if (_selectedBayForMovementId != null) {
                          setState(() {
                            _selectedBayForMovementId = null;
                            _bayPositions.clear();
                          });
                          SnackBarUtils.showSnackBar(
                            context,
                            'Movement cancelled. Position not saved.',
                          );
                        }
                      }
                    },
                    onLongPressStart: (details) {
                      final RenderBox renderBox =
                          context.findRenderObject() as RenderBox;
                      final Offset localPosition = renderBox.globalToLocal(
                        details.globalPosition,
                      );
                      final scenePosition = _transformationController.toScene(
                        localPosition,
                      );

                      final tappedBay = _currentBayRenderDataList.firstWhere(
                        (data) => data.rect.contains(scenePosition),
                        orElse: _createDummyBayRenderData,
                      );
                      if (tappedBay.bay.id != 'dummy') {
                        debugPrint(
                          'Long Pressed Bay: ${tappedBay.bay.name} at ${scenePosition}',
                        );
                        _showBaySymbolActions(
                          context,
                          tappedBay.bay,
                          details.globalPosition,
                        );
                      } else {
                        debugPrint(
                          'Long pressed: No Bay found at ${scenePosition}',
                        );
                      }
                    },
                    child: CustomPaint(
                      size: Size(canvasWidth, canvasHeight),
                      painter: SingleLineDiagramPainter(
                        bayRenderDataList: _currentBayRenderDataList,
                        bayConnections: allConnections,
                        baysMap: baysMap,
                        createDummyBayRenderData: _createDummyBayRenderData,
                        busbarRects: busbarRects,
                        busbarConnectionPoints: busbarConnectionPoints,
                        debugDrawHitboxes: true,
                        selectedBayForMovementId: _selectedBayForMovementId,
                        bayEnergyData: const {},
                        busEnergySummary: {},
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
  }

  // Helper function to extract numerical voltage value for sorting
  double _getVoltageLevelValue(String voltageLevel) {
    final regex = RegExp(r'(\d+(\.\d+)?)');
    final match = regex.firstMatch(voltageLevel);
    if (match != null) {
      return double.tryParse(match.group(1)!) ?? 0.0;
    }
    return 0.0;
  }
}
