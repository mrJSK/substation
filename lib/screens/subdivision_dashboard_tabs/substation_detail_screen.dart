// lib/screens/substation_detail_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:collection/collection.dart';
import 'dart:math';

import '../../models/bay_model.dart';
import '../../models/user_model.dart';
import '../../models/bay_connection_model.dart';
import '../../models/equipment_model.dart';
import '../../painters/single_line_diagram_painter.dart';
import '../../utils/snackbar_utils.dart';
import '../bay_equipment_management_screen.dart';
import '../bay_reading_assignment_screen.dart';
import 'energy_sld_screen.dart';
import '../../widgets/bay_form_card.dart';
import '../../widgets/sld_view_widget.dart';
import '../../controllers/sld_controller.dart';
import '../../enums/movement_mode.dart';

// New screen for listing equipment
class BayEquipmentListScreen extends StatelessWidget {
  final String bayId;
  final String bayName;
  final AppUser currentUser;

  const BayEquipmentListScreen({
    super.key,
    required this.bayId,
    required this.bayName,
    required this.currentUser,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Equipment in Bay: $bayName')),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('equipment_instances')
            .where('bayId', isEqualTo: bayId)
            .where('status', isEqualTo: 'active')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No equipment found in this bay.'));
          }

          final equipmentDocs = snapshot.data!.docs;
          return ListView.builder(
            itemCount: equipmentDocs.length,
            itemBuilder: (context, index) {
              final equipment = EquipmentInstance.fromFirestore(
                equipmentDocs[index],
              );
              return ListTile(
                title: Text(equipment.equipmentTypeName),
                subtitle: Text('Make: ${equipment.make}'),
                trailing: IconButton(
                  icon: const Icon(Icons.settings),
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => BayEquipmentManagementScreen(
                          bayId: bayId,
                          bayName: bayName,
                          substationId:
                              equipmentDocs[index]['substationId'] ?? '',
                          currentUser: currentUser,
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => BayEquipmentManagementScreen(
                bayId: bayId,
                bayName: bayName,
                substationId: '',
                currentUser: currentUser,
              ),
            ),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}

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
  static const double _movementStep = 5.0;
  static const double _busbarLengthStep = 5.0;
  List<Bay> _availableBusbars = [];
  bool _isLoadingBusbars = true;

  @override
  void initState() {
    super.initState();
    _fetchBusbarsInSubstation();
  }

  Future<void> _fetchBusbarsInSubstation() async {
    if (!mounted) return;
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
          "Error fetching busbars: $e",
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
      final sldController = Provider.of<SldController>(context, listen: false);
      if (mode == BayDetailViewMode.list) {
        sldController.setSelectedBayForMovement(null);
      }
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
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final sldController = Provider.of<SldController>(context);

    if (sldController.substationId != widget.substationId) {
      debugPrint(
        "WARNING: SldController substationId mismatch! Expected ${widget.substationId}, got ${sldController.substationId}",
      );
    }

    return PopScope(
      canPop:
          _viewMode == BayDetailViewMode.list &&
          sldController.selectedBayForMovementId == null,
      onPopInvoked: (didPop) {
        if (!didPop) {
          if (sldController.selectedBayForMovementId != null) {
            sldController.cancelLayoutChanges();
            SnackBarUtils.showSnackBar(
              context,
              'Movement cancelled. Position not saved.',
            );
          } else if (_viewMode != BayDetailViewMode.list) {
            _setViewMode(BayDetailViewMode.list);
          }
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text('Substation: ${widget.substationName}'),
          actions: [
            IconButton(
              icon: const Icon(Icons.schema),
              tooltip: 'View SLD',
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => ChangeNotifierProvider<SldController>(
                      create: (context) => SldController(
                        substationId: widget.substationId,
                        transformationController: TransformationController(),
                      ),
                      child: EnergySldScreen(
                        substationId: widget.substationId,
                        substationName: widget.substationName,
                        currentUser: widget.currentUser,
                      ),
                    ),
                  ),
                );
              },
            ),
            if (_viewMode != BayDetailViewMode.list ||
                sldController.selectedBayForMovementId != null)
              IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () {
                  if (sldController.selectedBayForMovementId != null) {
                    sldController.cancelLayoutChanges();
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
        body: _viewMode == BayDetailViewMode.list
            ? _buildBaysAndEquipmentList()
            : BayFormCard(
                bayToEdit: _bayToEdit,
                substationId: widget.substationId,
                currentUser: widget.currentUser,
                onSaveSuccess: _onBayFormSaveSuccess,
                onCancel: () => _setViewMode(BayDetailViewMode.list),
                availableBusbars: _isLoadingBusbars ? [] : _availableBusbars,
              ),
        floatingActionButton:
            _viewMode == BayDetailViewMode.list &&
                sldController.selectedBayForMovementId == null
            ? Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  FloatingActionButton.extended(
                    onPressed: () => _setViewMode(BayDetailViewMode.add),
                    label: const Text('Add New Bay'),
                    icon: const Icon(Icons.add),
                    heroTag: 'addBay',
                  ),
                  const SizedBox(height: 10),
                  FloatingActionButton.extended(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => BayEquipmentManagementScreen(
                            bayId: '', // Empty bayId for standalone equipment
                            bayName: 'Standalone Equipment',
                            substationId: widget.substationId,
                            currentUser: widget.currentUser,
                          ),
                        ),
                      );
                    },
                    label: const Text('Add Standalone Equipment'),
                    icon: const Icon(Icons.add_box),
                    heroTag: 'addEquipment',
                  ),
                ],
              )
            : null,
        bottomNavigationBar: sldController.selectedBayForMovementId != null
            ? _buildMovementControls(sldController)
            : null,
      ),
    );
  }

  Widget _buildBaysAndEquipmentList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('bays')
          .where('substationId', isEqualTo: widget.substationId)
          .snapshots(),
      builder: (context, baySnapshot) {
        if (baySnapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (baySnapshot.hasError) {
          return Center(child: Text('Error: ${baySnapshot.error}'));
        }

        final bays =
            baySnapshot.data?.docs
                .map((doc) => Bay.fromFirestore(doc))
                .toList() ??
            [];

        // Group bays by voltage level
        final Map<String, List<Bay>> baysByVoltage = {};
        for (var bay in bays) {
          final voltage = bay.voltageLevel;
          if (!baysByVoltage.containsKey(voltage)) {
            baysByVoltage[voltage] = [];
          }
          baysByVoltage[voltage]!.add(bay);
        }

        // Fetch standalone equipment
        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('equipment_instances')
              .where('substationId', isEqualTo: widget.substationId)
              .where('bayId', isEqualTo: '')
              .where('status', isEqualTo: 'active')
              .snapshots(),
          builder: (context, equipmentSnapshot) {
            if (equipmentSnapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (equipmentSnapshot.hasError) {
              return Center(child: Text('Error: ${equipmentSnapshot.error}'));
            }

            final standaloneEquipment =
                equipmentSnapshot.data?.docs
                    .map((doc) => EquipmentInstance.fromFirestore(doc))
                    .toList() ??
                [];

            return ListView(
              children: [
                if (bays.isEmpty && standaloneEquipment.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text('No bays or standalone equipment found.'),
                  ),
                // Bays grouped by voltage level
                ...baysByVoltage.entries.map((entry) {
                  final voltage = entry.key;
                  final bays = entry.value;
                  return ExpansionTile(
                    title: Text('$voltage Bays'),
                    children: bays.map((bay) {
                      return ListTile(
                        title: Text(bay.name),
                        subtitle: Text('Type: ${bay.bayType}'),
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => BayEquipmentListScreen(
                                bayId: bay.id,
                                bayName: bay.name,
                                currentUser: widget.currentUser,
                              ),
                            ),
                          );
                        },
                        trailing: IconButton(
                          icon: const Icon(Icons.edit),
                          onPressed: () =>
                              _setViewMode(BayDetailViewMode.edit, bay: bay),
                        ),
                      );
                    }).toList(),
                  );
                }).toList(),
                // Standalone Equipment Section
                if (standaloneEquipment.isNotEmpty)
                  ExpansionTile(
                    title: const Text('Standalone Equipment'),
                    children: standaloneEquipment.map((equipment) {
                      return ListTile(
                        title: Text(equipment.equipmentTypeName),
                        subtitle: Text('Make: ${equipment.make}'),
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) =>
                                  BayEquipmentManagementScreen(
                                    bayId: '',
                                    bayName: equipment.equipmentTypeName,
                                    substationId: widget.substationId,
                                    currentUser: widget.currentUser,
                                  ),
                            ),
                          );
                        },
                      );
                    }).toList(),
                  ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildMovementControls(SldController sldController) {
    final selectedBay =
        sldController.baysMap[sldController.selectedBayForMovementId!];
    if (selectedBay == null) return const SizedBox.shrink();
    final BayRenderData? selectedBayRenderData = sldController.bayRenderDataList
        .firstWhereOrNull(
          (data) => data.bay.id == sldController.selectedBayForMovementId,
        );

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
              ButtonSegment(value: MovementMode.text, label: Text('Move Name')),
            ],
            selected: {sldController.movementMode},
            onSelectionChanged: (newSelection) {
              sldController.setMovementMode(newSelection.first);
            },
            style: ButtonStyle(
              foregroundColor: MaterialStateProperty.resolveWith<Color>((
                Set<MaterialState> states,
              ) {
                return states.contains(MaterialState.selected)
                    ? Colors.blue.shade100
                    : Colors.blue.shade100;
              }),
              backgroundColor: MaterialStateProperty.resolveWith<Color>((
                Set<MaterialState> states,
              ) {
                return states.contains(MaterialState.selected)
                    ? Theme.of(context).colorScheme.secondary
                    : Colors.blue.shade700;
              }),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back),
                color: Colors.white,
                onPressed: () =>
                    sldController.moveSelectedItem(-_movementStep, 0),
              ),
              Column(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_upward),
                    color: Colors.white,
                    onPressed: () =>
                        sldController.moveSelectedItem(0, -_movementStep),
                  ),
                  IconButton(
                    icon: const Icon(Icons.arrow_downward),
                    color: Colors.white,
                    onPressed: () =>
                        sldController.moveSelectedItem(0, _movementStep),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.arrow_forward),
                color: Colors.white,
                onPressed: () =>
                    sldController.moveSelectedItem(_movementStep, 0),
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
                  onPressed: () =>
                      sldController.adjustBusbarLength(-_busbarLengthStep),
                ),
                Text(
                  selectedBayRenderData?.busbarLength.toStringAsFixed(0) ??
                      'Auto',
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                ),
                IconButton(
                  icon: const Icon(Icons.add),
                  color: Colors.white,
                  onPressed: () =>
                      sldController.adjustBusbarLength(_busbarLengthStep),
                ),
              ],
            ),
          ],
          const SizedBox(height: 10),
          ElevatedButton(
            onPressed: () async {
              final bool success = await sldController
                  .saveSelectedBayLayoutChanges();
              if (mounted) {
                if (success) {
                  SnackBarUtils.showSnackBar(
                    context,
                    'Changes saved successfully!',
                  );
                } else {
                  SnackBarUtils.showSnackBar(
                    context,
                    'Failed to save changes.',
                    isError: true,
                  );
                }
              }
            },
            child: const Text('Done & Save'),
          ),
        ],
      ),
    );
  }

  void _showBayDetailsModalSheet(BuildContext context, Bay bay) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext bc) {
        return Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Bay Details: ${bay.name}',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const Divider(),
              _buildDetailRow('ID:', bay.id),
              _buildDetailRow('Type:', bay.bayType),
              _buildDetailRow('Voltage Level:', bay.voltageLevel),
              if (bay.make != null && bay.make!.isNotEmpty)
                _buildDetailRow('Make:', bay.make!),
              _buildDetailRow('Created By:', bay.createdBy),
              _buildDetailRow(
                'Created At:',
                bay.createdAt.toDate().toLocal().toString().split('.')[0],
              ),
              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  void _showBaySymbolActions(
    BuildContext context,
    Bay bay,
    Offset tapPosition,
    SldController sldController,
  ) {
    final List<PopupMenuEntry<String>> menuItems = [
      const PopupMenuItem<String>(
        value: 'view_details',
        child: ListTile(
          leading: Icon(Icons.info),
          title: Text('View Bay Details'),
        ),
      ),
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
      const PopupMenuItem<String>(
        value: 'manage_equipment',
        child: ListTile(
          leading: Icon(Icons.settings),
          title: Text('Manage Equipment'),
        ),
      ),
      const PopupMenuItem<String>(
        value: 'readings',
        child: ListTile(
          leading: Icon(Icons.menu_book),
          title: Text('Manage Reading Assignments'),
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
            'Delete Bay',
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
      if (value == 'view_details') {
        _showBayDetailsModalSheet(context, bay);
      } else if (value == 'edit') {
        _setViewMode(BayDetailViewMode.edit, bay: bay);
      } else if (value == 'adjust') {
        sldController.setSelectedBayForMovement(bay.id, mode: MovementMode.bay);
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
}
