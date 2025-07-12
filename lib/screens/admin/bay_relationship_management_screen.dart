// lib/screens/admin/bay_relationship_management_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dropdown_search/dropdown_search.dart';

import '../../models/hierarchy_models.dart';
import '../../models/bay_model.dart'; // Ensure this is the updated Bay model
import '../../models/user_model.dart';
import '../../utils/snackbar_utils.dart';

// Renamed _RelationshipDialog for clarity of its new purpose
class _BayConnectionDialog extends StatefulWidget {
  final AppUser currentUser;
  final String substationId;
  final List<Bay> bays; // All bays in the substation
  final List<Bay> busbars; // Only busbar bays
  final Bay? bayToEdit; // The specific bay being edited (can be null for new?)
  final VoidCallback onSave;

  const _BayConnectionDialog({
    required this.currentUser,
    required this.substationId,
    required this.bays,
    required this.busbars,
    this.bayToEdit,
    required this.onSave,
  });

  @override
  __BayConnectionDialogState createState() => __BayConnectionDialogState();
}

class __BayConnectionDialogState extends State<_BayConnectionDialog> {
  final _formKey = GlobalKey<FormState>();
  bool _isSaving = false;

  // State for connections based on bay type
  String?
  _selectedSingleBusId; // For non-transformer, non-busbar, non-battery bays
  String? _selectedHvBusId; // For transformer HV
  String? _selectedLvBusId; // For transformer LV

  @override
  void initState() {
    super.initState();
    if (widget.bayToEdit != null) {
      final bay = widget.bayToEdit!;
      // FIX: Use BayType enum directly for comparison
      if (bay.bayType == BayType.Transformer) {
        _selectedHvBusId = bay.hvBusId;
        _selectedLvBusId = bay.lvBusId;
      } else {
        _fetchSingleBusConnection(bay.id);
      }
    }
  }

  // Helper to fetch single bus connection for a bay
  Future<void> _fetchSingleBusConnection(String bayId) async {
    try {
      final connectionsSnapshot = await FirebaseFirestore.instance
          .collection('bay_connections')
          .where(
            Filter.or(
              Filter('sourceBayId', isEqualTo: bayId),
              Filter('targetBayId', isEqualTo: bayId),
            ),
          )
          .get();

      if (connectionsSnapshot.docs.isNotEmpty) {
        final connectionDoc = connectionsSnapshot.docs.first;
        String? connectedBusId;

        // Determine which ID in the connection refers to a busbar
        if (widget.busbars.any((b) => b.id == connectionDoc['sourceBayId'])) {
          connectedBusId = connectionDoc['sourceBayId'] as String;
        } else if (widget.busbars.any(
          (b) => b.id == connectionDoc['targetBayId'],
        )) {
          connectedBusId = connectionDoc['targetBayId'] as String;
        }

        if (connectedBusId != null && mounted) {
          setState(() {
            _selectedSingleBusId = connectedBusId;
          });
        }
      } else if (mounted) {
        setState(() {
          _selectedSingleBusId = null; // No existing connection found
        });
      }
    } catch (e) {
      print("Error fetching single bus connection: $e");
    }
  }

  Future<void> _saveConnections() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    try {
      final bay = widget.bayToEdit!;
      final batch = FirebaseFirestore.instance.batch();

      // Clear existing connections for this bay first, to replace them
      final existingConnections = await FirebaseFirestore.instance
          .collection('bay_connections')
          .where(
            Filter.or(
              Filter('sourceBayId', isEqualTo: bay.id),
              Filter('targetBayId', isEqualTo: bay.id),
            ),
          )
          .get();

      for (var doc in existingConnections.docs) {
        batch.delete(doc.reference);
      }

      Map<String, dynamic> bayUpdateData = {};

      // FIX: Use BayType enum directly for comparison
      if (bay.bayType == BayType.Transformer) {
        // Update hvBusId and lvBusId on the Bay document itself
        bayUpdateData['hvBusId'] = _selectedHvBusId;
        bayUpdateData['lvBusId'] = _selectedLvBusId;

        // Add new BayConnection documents for Transformer
        if (_selectedHvBusId != null) {
          batch.set(
            FirebaseFirestore.instance.collection('bay_connections').doc(),
            {
              'substationId': widget.substationId,
              'sourceBayId': bay.id, // Transformer is source for HV
              'targetBayId': _selectedHvBusId!,
              'connectionType': 'HV_BUS_CONNECTION',
              'createdBy': widget.currentUser.uid,
              'createdAt': Timestamp.now(),
            },
          );
        }
        if (_selectedLvBusId != null) {
          batch.set(
            FirebaseFirestore.instance.collection('bay_connections').doc(),
            {
              'substationId': widget.substationId,
              'sourceBayId': bay.id, // Transformer is source for LV
              'targetBayId': _selectedLvBusId!,
              'connectionType': 'LV_BUS_CONNECTION',
              'createdBy': widget.currentUser.uid,
              'createdAt': Timestamp.now(),
            },
          );
        }
        // FIX: Use BayType enum directly for comparison for other types
      } else if (bay.bayType != BayType.Busbar &&
          bay.bayType != BayType.Battery) {
        // For other types that connect to a single busbar
        if (_selectedSingleBusId != null) {
          batch.set(
            FirebaseFirestore.instance.collection('bay_connections').doc(),
            {
              'substationId': widget.substationId,
              'sourceBayId': bay.id, // Bay is source
              'targetBayId': _selectedSingleBusId!, // Busbar is target
              'connectionType': 'SINGLE_BUS_CONNECTION',
              'createdBy': widget.currentUser.uid,
              'createdAt': Timestamp.now(),
            },
          );
        }
      }

      // Update the Bay document itself (only for transformer bus IDs)
      if (bayUpdateData.isNotEmpty) {
        batch.update(
          FirebaseFirestore.instance.collection('bays').doc(bay.id),
          bayUpdateData,
        );
      }

      await batch.commit();

      if (mounted) {
        SnackBarUtils.showSnackBar(
          context,
          'Connections for ${bay.name} saved successfully!',
        );
        widget.onSave(); // Callback to parent to refresh data
      }
    } catch (e) {
      if (mounted) {
        SnackBarUtils.showSnackBar(
          context,
          'Error saving connections: $e',
          isError: true,
        );
      }
      print('Error saving connections: $e'); // Debug print
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bay = widget.bayToEdit!;
    // FIX: Use BayType enum directly for comparison
    final bool isTransformer = bay.bayType == BayType.Transformer;
    final bool isBusbarOrBattery =
        bay.bayType == BayType.Busbar || bay.bayType == BayType.Battery;

    // Filter busbars by voltage level for transformers
    List<Bay> hvCompatibleBusbars = [];
    // Access hvVoltage from bay model directly, which is String?
    if (isTransformer && bay.hvVoltage != null) {
      hvCompatibleBusbars = widget.busbars
          .where((b) => b.voltageLevel == bay.hvVoltage)
          .toList();
    }

    List<Bay> lvCompatibleBusbars = [];
    // Access lvVoltage from bay model directly, which is String?
    if (isTransformer && bay.lvVoltage != null) {
      lvCompatibleBusbars = widget.busbars
          .where((b) => b.voltageLevel == bay.lvVoltage)
          .toList();
    }

    // Busbars available for single connection (for non-transformer, non-busbar, non-battery)
    List<Bay> singleConnectBusbars = widget.busbars;
    // Filter single connect busbars based on the bay's main voltageLevel
    if (!isTransformer && !isBusbarOrBattery && bay.voltageLevel != null) {
      singleConnectBusbars = widget.busbars
          .where((b) => b.voltageLevel == bay.voltageLevel)
          .toList();
    }

    return AlertDialog(
      title: Text('Manage Connections for ${bay.name}'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isTransformer) ...[
                Text(
                  // Display hvVoltage from bay model
                  'HV Voltage: ${bay.hvVoltage ?? 'N/A'}',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                DropdownSearch<Bay>(
                  items: hvCompatibleBusbars,
                  itemAsString: (Bay b) => '${b.name} (${b.voltageLevel})',
                  selectedItem: hvCompatibleBusbars.firstWhere(
                    (b) => b.id == _selectedHvBusId,
                    orElse: () => Bay(
                      // Dummy Bay for orElse
                      id: '',
                      name: 'N/A',
                      substationId: '',
                      voltageLevel: '',
                      bayType: BayType.Busbar, // FIX: Use BayType enum
                      createdBy: '',
                      createdAt: Timestamp.now(),
                    ),
                  ),
                  onChanged: (Bay? data) =>
                      setState(() => _selectedHvBusId = data?.id),
                  validator: (v) => v == null ? 'HV Bus is required' : null,
                  dropdownDecoratorProps: const DropDownDecoratorProps(
                    dropdownSearchDecoration: InputDecoration(
                      labelText: 'Connect HV to Bus',
                    ),
                  ),
                  popupProps: PopupProps.menu(showSearchBox: true),
                ),
                const SizedBox(height: 16),
                Text(
                  // Display lvVoltage from bay model
                  'LV Voltage: ${bay.lvVoltage ?? 'N/A'}',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                DropdownSearch<Bay>(
                  items: lvCompatibleBusbars,
                  itemAsString: (Bay b) => '${b.name} (${b.voltageLevel})',
                  selectedItem: lvCompatibleBusbars.firstWhere(
                    (b) => b.id == _selectedLvBusId,
                    orElse: () => Bay(
                      // Dummy Bay for orElse
                      id: '',
                      name: 'N/A',
                      substationId: '',
                      voltageLevel: '',
                      bayType: BayType.Busbar, // FIX: Use BayType enum
                      createdBy: '',
                      createdAt: Timestamp.now(),
                    ),
                  ),
                  onChanged: (Bay? data) =>
                      setState(() => _selectedLvBusId = data?.id),
                  validator: (v) => v == null ? 'LV Bus is required' : null,
                  dropdownDecoratorProps: const DropDownDecoratorProps(
                    dropdownSearchDecoration: InputDecoration(
                      labelText: 'Connect LV to Bus',
                    ),
                  ),
                  popupProps: PopupProps.menu(showSearchBox: true),
                ),
              ] else if (!isBusbarOrBattery) ...[
                // For other equipment, connect to a single bus
                DropdownSearch<Bay>(
                  items: singleConnectBusbars, // Already filtered above
                  itemAsString: (Bay b) => '${b.name} (${b.voltageLevel})',
                  selectedItem: singleConnectBusbars.firstWhere(
                    (b) => b.id == _selectedSingleBusId,
                    orElse: () => Bay(
                      // Dummy Bay for orElse
                      id: '',
                      name: 'N/A',
                      substationId: '',
                      voltageLevel: '',
                      bayType: BayType.Busbar, // FIX: Use BayType enum
                      createdBy: '',
                      createdAt: Timestamp.now(),
                    ),
                  ),
                  onChanged: (Bay? data) =>
                      setState(() => _selectedSingleBusId = data?.id),
                  validator: (v) =>
                      v == null ? 'Bus connection is required' : null,
                  dropdownDecoratorProps: const DropDownDecoratorProps(
                    dropdownSearchDecoration: InputDecoration(
                      labelText: 'Connect to Bus',
                    ),
                  ),
                  popupProps: PopupProps.menu(showSearchBox: true),
                ),
              ] else ...[
                const Padding(
                  padding: EdgeInsets.all(8.0),
                  child: Text(
                    'Busbars and Batteries do not require bus connections here.',
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isSaving ? null : _saveConnections,
          child: const Text('Save'),
        ),
      ],
    );
  }
}

class BayRelationshipManagementScreen extends StatefulWidget {
  final AppUser currentUser;

  const BayRelationshipManagementScreen({super.key, required this.currentUser});

  @override
  _BayRelationshipManagementScreenState createState() =>
      _BayRelationshipManagementScreenState();
}

class _BayRelationshipManagementScreenState
    extends State<BayRelationshipManagementScreen> {
  Substation? _selectedSubstation;
  List<Substation> _substations = [];
  List<Bay> _baysInSubstation = [];
  List<Bay> _busbarsInSubstation = []; // List to hold only busbar bays
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchSubstations();
  }

  Future<void> _fetchSubstations() async {
    setState(() => _isLoading = true);
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('substations')
          .orderBy('name')
          .get();
      _substations = snapshot.docs
          .map((doc) => Substation.fromFirestore(doc))
          .toList();
    } catch (e) {
      SnackBarUtils.showSnackBar(
        context,
        'Error fetching substations: $e',
        isError: true,
      );
    }
    setState(() => _isLoading = false);
  }

  Future<void> _onSubstationSelected(Substation? substation) async {
    if (substation == null) return;
    setState(() {
      _selectedSubstation = substation;
      _isLoading = true;
      _baysInSubstation.clear();
      _busbarsInSubstation.clear();
    });

    try {
      final baySnapshot = await FirebaseFirestore.instance
          .collection('bays')
          .where('substationId', isEqualTo: substation.id)
          .get();

      _baysInSubstation = baySnapshot.docs
          .map((doc) => Bay.fromFirestore(doc))
          .toList();

      // FIX: Use BayType enum directly for comparison
      _busbarsInSubstation = _baysInSubstation
          .where((bay) => bay.bayType == BayType.Busbar)
          .toList();
    } catch (e) {
      SnackBarUtils.showSnackBar(
        context,
        'Error fetching bays: $e',
        isError: true,
      );
    }

    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Bay Connection Management')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: DropdownSearch<Substation>(
              items: _substations,
              itemAsString: (Substation s) => '${s.voltageLevel} - ${s.name}',
              onChanged: _onSubstationSelected,
              selectedItem: _selectedSubstation,
              popupProps: PopupProps.menu(showSearchBox: true),
              dropdownDecoratorProps: const DropDownDecoratorProps(
                dropdownSearchDecoration: InputDecoration(
                  labelText: "Select Substation",
                  hintText: "Choose the substation to manage",
                ),
              ),
            ),
          ),
          if (_isLoading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else if (_selectedSubstation != null)
            Expanded(
              // Display list of all bays in the substation for connection management
              child: _baysInSubstation.isEmpty
                  ? const Center(
                      child: Text(
                        'No bays found in this substation to manage connections.',
                      ),
                    )
                  : ListView.builder(
                      itemCount: _baysInSubstation.length,
                      itemBuilder: (context, index) {
                        final bay = _baysInSubstation[index];
                        // FIX: Use BayType enum directly for comparison
                        if (bay.bayType == BayType.Busbar) {
                          return const SizedBox.shrink(); // Hide busbars from the list
                        }

                        // Determine current connections for display
                        String currentConnections = '';
                        // FIX: Use BayType enum directly for comparison
                        if (bay.bayType == BayType.Transformer) {
                          final hvBus = _busbarsInSubstation.firstWhere(
                            (b) => b.id == bay.hvBusId,
                            orElse: () => Bay(
                              // Dummy Bay for orElse
                              id: '',
                              name: 'N/A',
                              substationId: '',
                              voltageLevel: '',
                              bayType: BayType.Busbar, // FIX: Use BayType enum
                              createdBy: '',
                              createdAt: Timestamp.now(),
                            ),
                          );
                          final lvBus = _busbarsInSubstation.firstWhere(
                            (b) => b.id == bay.lvBusId,
                            orElse: () => Bay(
                              // Dummy Bay for orElse
                              id: '',
                              name: 'N/A',
                              substationId: '',
                              voltageLevel: '',
                              bayType: BayType.Busbar, // FIX: Use BayType enum
                              createdBy: '',
                              createdAt: Timestamp.now(),
                            ),
                          );
                          currentConnections =
                              'HV: ${hvBus.name} (${hvBus.voltageLevel}), LV: ${lvBus.name} (${lvBus.voltageLevel})';
                          // FIX: Use BayType enum directly for comparison
                        } else if (bay.bayType != BayType.Battery) {
                          // For other equipment (non-busbar, non-battery)
                          // If a single bus connection was implemented directly on Bay model, retrieve it here
                          // For now, it will just show if it has a bus connection conceptually.
                          currentConnections =
                              'Single Bus: N/A (Manage via Edit)'; // Placeholder
                        }

                        return Card(
                          margin: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          child: ListTile(
                            title: Text(
                              '${bay.name} (${bay.bayType.toString().split('.').last})',
                            ), // Display enum as string
                            subtitle: Text('Connections: $currentConnections'),
                            trailing: IconButton(
                              icon: const Icon(Icons.edit),
                              onPressed: () => _showBayConnectionDialog(bay),
                            ),
                          ),
                        );
                      },
                    ),
            ),
        ],
      ),
      // Floating action button removed, as connections are managed per-bay via edit icon
      // You could add a FAB to "Add new Bay" which then takes them to SubstationDetailScreen
      floatingActionButton: null,
    );
  }

  // Renamed _showRelationshipDialog to _showBayConnectionDialog
  void _showBayConnectionDialog(Bay bay) {
    showDialog(
      context: context,
      builder: (context) => _BayConnectionDialog(
        currentUser: widget.currentUser,
        substationId: _selectedSubstation!.id,
        bays: _baysInSubstation, // Pass all bays
        busbars: _busbarsInSubstation, // Pass only busbars
        bayToEdit: bay, // Pass the bay to edit
        onSave: () {
          Navigator.of(context).pop();
          _onSubstationSelected(_selectedSubstation); // Refresh data
        },
      ),
    );
  }
}
