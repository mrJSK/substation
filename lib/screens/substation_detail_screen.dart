import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:collection/collection.dart';
import 'dart:math';

import '../models/bay_model.dart';
import '../models/user_model.dart';
import '../models/bay_connection_model.dart';
import '../models/equipment_model.dart';
// NOTE: Make sure you have a single, unified BayRenderData model definition
// and import it here. For example:
// import '../models/bay_render_data.dart';
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

  Map<String, Offset> _bayPositions = {};
  Map<String, Offset> _textOffsets = {};
  Map<String, double> _busbarLengths = {};

  String? _selectedBayForMovementId;
  MovementMode _movementMode = MovementMode.bay;

  static const double _movementStep = 10.0;
  static const double _busbarLengthStep = 20.0;

  List<BayRenderData> _currentBayRenderDataList = [];

  List<Bay> _availableBusbars = [];
  bool _isLoadingBusbars = true;

  @override
  void initState() {
    super.initState();
    _fetchBusbarsInSubstation();
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
      _selectedBayForMovementId = null;
    });
    if (mode != BayDetailViewMode.list) {
      _fetchBusbarsInSubstation();
    }
  }

  void _onBayFormSaveSuccess() {
    _setViewMode(BayDetailViewMode.list);
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
                availableBusbars: _availableBusbars,
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
    final selectedBay = _getBayRenderData(
      _selectedBayForMovementId!,
      _currentBayRenderDataList,
    )?.bay;

    if (selectedBay == null) return const SizedBox.shrink();

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
              setState(() {
                _selectedBayForMovementId = null;
                _bayPositions.clear();
                _textOffsets.clear();
                _busbarLengths.clear();
              });
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
          _bayPositions[bay.id] = Offset(
            bay.xPosition ?? 0,
            bay.yPosition ?? 0,
          );
          _textOffsets[bay.id] = bay.textOffset ?? Offset.zero;
          if (bay.bayType == 'Busbar') {
            _busbarLengths[bay.id] = bay.busbarLength ?? 200.0;
          }
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
      final updateData = <String, dynamic>{};

      if (_bayPositions.containsKey(bayId)) {
        updateData['xPosition'] = _bayPositions[bayId]!.dx;
        updateData['yPosition'] = _bayPositions[bayId]!.dy;
      }
      if (_textOffsets.containsKey(bayId)) {
        updateData['textOffset'] = {
          'dx': _textOffsets[bayId]!.dx,
          'dy': _textOffsets[bayId]!.dy,
        };
      }
      if (_busbarLengths.containsKey(bayId)) {
        updateData['busbarLength'] = _busbarLengths[bayId];
      }

      if (updateData.isNotEmpty) {
        await FirebaseFirestore.instance
            .collection('bays')
            .doc(bayId)
            .update(updateData);
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

        if (_selectedBayForMovementId == null) {
          _bayPositions.clear();
          _textOffsets.clear();
          _busbarLengths.clear();
          for (var bay in allBays) {
            if (bay.xPosition != null && bay.yPosition != null) {
              _bayPositions[bay.id] = Offset(bay.xPosition!, bay.yPosition!);
            }
            if (bay.textOffset != null) {
              _textOffsets[bay.id] = bay.textOffset!;
            }
            if (bay.bayType == 'Busbar' && bay.busbarLength != null) {
              _busbarLengths[bay.id] = bay.busbarLength!;
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
                    continue;
                  }

                  final Bay? currentHvBus = baysMap[hvBusId];
                  final Bay? currentLvBus = baysMap[lvBusId];

                  if (currentHvBus == null || currentLvBus == null) {
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

                  final double busbarWidth =
                      _busbarLengths[busbar.id] ?? effectiveBusWidth;

                  final Rect drawingRect = Rect.fromLTWH(
                    sidePadding,
                    busY,
                    busbarWidth,
                    0,
                  );
                  busbarRects[busbar.id] = drawingRect;

                  final Rect tappableRect = Rect.fromCenter(
                    center: Offset(sidePadding + busbarWidth / 2, busY),
                    width: busbarWidth,
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
                        equipmentInstances: equipmentByBayId[bay.id] ?? [],
                        textOffset: _textOffsets[bay.id] ?? Offset.zero,
                        busbarLength: _busbarLengths[bay.id] ?? 0.0,
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
                        _showBaySymbolActions(
                          context,
                          tappedBay.bay,
                          details.globalPosition,
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
                        busEnergySummary: const {},
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

  double _getVoltageLevelValue(String voltageLevel) {
    final regex = RegExp(r'(\d+(\.\d+)?)');
    final match = regex.firstMatch(voltageLevel);
    if (match != null) {
      return double.tryParse(match.group(1)!) ?? 0.0;
    }
    return 0.0;
  }
}
