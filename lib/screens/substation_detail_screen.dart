// lib/screens/substation_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Ensure AppUser is accessible
import 'package:collection/collection.dart'; // For .firstWhereOrNull if used elsewhere

// Core Models
import '../models/bay_model.dart'; // For Bay model
import '../models/user_model.dart'; // For AppUser model
import '../models/equipment_model.dart'; // Potentially needed if listing equipment directly
import '../utils/snackbar_utils.dart'; // For snackbars

// Screens
import '../screens/bay_equipment_management_screen.dart'; // Still relevant for equipment management
import '../screens/bay_reading_assignment_screen.dart'; // Still relevant for reading assignment
import 'energy_sld_screen.dart'; // The new central SLD screen

// Widgets
import '../widgets/bay_form_card.dart'; // For add/edit bay form

// REMOVED: import '../painters/single_line_diagram_painter.dart'; // Not needed here anymore

enum BayDetailViewMode { list, add, edit }

// REMOVED: MovementMode enum as it's now internal to EnergySldScreen and SldEditorState

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

  // REMOVED: TransformationController as it's now owned by EnergySldScreen
  // REMOVED: Maps for _bayPositions, _textOffsets, _busbarLengths as they are now managed by SldEditorState
  // REMOVED: _selectedBayForMovementId, _movementMode, _movementStep, _busbarLengthStep
  // REMOVED: _currentBayRenderDataList

  List<Bay> _availableBusbars = []; // Still needed for BayFormCard
  bool _isLoadingBusbars = true;

  @override
  void initState() {
    super.initState();
    _fetchBusbarsInSubstation(); // Still needed for BayFormCard
  }

  @override
  void dispose() {
    // REMOVED: _transformationController.dispose();
    super.dispose();
  }

  // REMOVED: _createDummyBayRenderData() as it's no longer used here

  Future<void> _fetchBusbarsInSubstation() async {
    setState(() {
      _isLoadingBusbars = true;
    });
    try {
      final busbarSnapshot = await FirebaseFirestore.instance
          .collection('bays')
          .where('substationId', isEqualTo: widget.substationId)
          .where(
            'bayType',
            isEqualTo: BayType.Busbar.toString().split('.').last,
          ) // Use enum string
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
      // When changing view modes, ensure no bay is selected for movement (in the old context)
      // This is now implicitly handled as movement logic is no longer here.
    });
    if (mode != BayDetailViewMode.list) {
      _fetchBusbarsInSubstation(); // Fetch busbars if going to add/edit form
    }
  }

  void _onBayFormSaveSuccess() {
    _setViewMode(BayDetailViewMode.list); // Return to list view after save
  }

  // NEW: Helper method to confirm bay deletion (from old _buildSLDView logic, now a direct method)
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
            if (_viewMode ==
                BayDetailViewMode.list) // Only show info icon in list mode
              IconButton(
                icon: const Icon(Icons.info_outline),
                onPressed: () => SnackBarUtils.showSnackBar(
                  context,
                  'Viewing details for ${widget.substationName}.',
                ),
              ),
            // Button to navigate to the centralized EnergySldScreen
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
            // Back button logic (simplified, only if not in list mode)
            if (_viewMode != BayDetailViewMode.list)
              IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () {
                  _setViewMode(BayDetailViewMode.list);
                },
              ),
          ],
        ),
        body: (_viewMode == BayDetailViewMode.list)
            ? _buildBayListAndSummary() // New method to build the list view
            : BayFormCard(
                bayToEdit: _bayToEdit,
                substationId: widget.substationId,
                currentUser: widget.currentUser,
                onSaveSuccess: _onBayFormSaveSuccess,
                onCancel: () => _setViewMode(BayDetailViewMode.list),
                availableBusbars: _availableBusbars, // Pass fetched busbars
              ),
        floatingActionButton: (_viewMode == BayDetailViewMode.list)
            ? FloatingActionButton.extended(
                onPressed: () => _setViewMode(BayDetailViewMode.add),
                label: const Text('Add New Bay'),
                icon: const Icon(Icons.add),
              )
            : null,
        // Removed bottomNavigationBar for movement controls, as they are in EnergySldScreen
        bottomNavigationBar: null,
      ),
    );
  }

  // NEW: Method to build the list view of bays
  Widget _buildBayListAndSummary() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('bays')
          .where('substationId', isEqualTo: widget.substationId)
          .orderBy('name')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                'No bays found in this substation. Click "+" to add one.',
              ),
            ),
          );
        }

        final bays = snapshot.data!.docs
            .map((doc) => Bay.fromFirestore(doc))
            .toList();

        return ListView.builder(
          padding: const EdgeInsets.all(16.0),
          itemCount: bays.length,
          itemBuilder: (context, index) {
            final bay = bays[index];
            return Card(
              margin: const EdgeInsets.symmetric(vertical: 8.0),
              child: ExpansionTile(
                leading: Icon(
                  Icons.category,
                  color: Theme.of(context).colorScheme.primary,
                ),
                title: Text(
                  '${bay.name} (${bay.bayType.toString().split('.').last})',
                ),
                subtitle: Text('Voltage: ${bay.voltageLevel}'),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (bay.description != null &&
                            bay.description!.isNotEmpty)
                          Text('Description: ${bay.description}'),
                        if (bay.make != null && bay.make!.isNotEmpty)
                          Text('Make: ${bay.make}'),
                        if (bay.capacity != null) // Use capacityMVA
                          Text('Capacity: ${bay.capacity} MVA'),
                        if (bay.lineLength != null) // Use lineLengthKm
                          Text('Line Length: ${bay.lineLength} km'),
                        // Display other relevant bay properties here
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: () => _setViewMode(
                                BayDetailViewMode.edit,
                                bay: bay,
                              ),
                              child: const Text('Edit'),
                            ),
                            TextButton(
                              onPressed: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        BayEquipmentManagementScreen(
                                          bayId: bay.id,
                                          bayName: bay.name,
                                          substationId: widget.substationId,
                                          currentUser: widget.currentUser,
                                        ),
                                  ),
                                );
                              },
                              child: const Text('Equipment'),
                            ),
                            TextButton(
                              onPressed: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        BayReadingAssignmentScreen(
                                          bayId: bay.id,
                                          bayName: bay.name,
                                          currentUser: widget.currentUser,
                                        ),
                                  ),
                                );
                              },
                              child: const Text('Readings'),
                            ),
                            IconButton(
                              icon: Icon(
                                Icons.delete,
                                color: Theme.of(context).colorScheme.error,
                              ),
                              onPressed: () => _confirmDeleteBay(context, bay),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
