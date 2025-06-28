// lib/screens/substation_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../models/bay_model.dart';
import '../models/user_model.dart';
import '../models/hierarchy_models.dart';
import '../models/app_state_data.dart';
import '../utils/snackbar_utils.dart';
import '../screens/bay_equipment_management_screen.dart';

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

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _bayNameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _landmarkController = TextEditingController();
  final TextEditingController _contactNumberController =
      TextEditingController();
  final TextEditingController _contactPersonController =
      TextEditingController();

  String? _selectedStateName;
  String? _selectedZoneId;
  String? _selectedCircleId;
  String? _selectedDivisionId;
  String? _selectedSubdivisionId;
  String? _selectedSubstationIdForm;
  String? _selectedVoltageLevel;
  String? _selectedBayType;
  bool _isGovernmentFeeder = false;
  String? _selectedFeederType;

  bool _isLoadingFormHierarchy = true;
  bool _isSavingBay = false;

  final List<String> _voltageLevels = [
    '765kV',
    '400kV',
    '220kV',
    '132kV',
    '33kV',
    '11kV',
  ];

  final List<String> _bayTypes = [
    'Transformer',
    'Line',
    'Feeder',
    'Capacitor Bank',
    'Reactor',
    'Bus Coupler',
  ];

  final List<String> _nonGovernmentFeederTypes = [
    'Industry',
    'Open Access',
    'Co-Gen',
    'Solar',
    'Wind',
    'Department',
  ];

  final List<String> _governmentFeederTypes = [
    'Rural',
    'Town',
    'Tehsil',
    'City',
  ];

  @override
  void initState() {
    super.initState();
    _selectedSubstationIdForm = widget.substationId;
    _initializeFormAndHierarchyForViewMode(BayDetailViewMode.list);
  }

  @override
  void dispose() {
    _bayNameController.dispose();
    _descriptionController.dispose();
    _landmarkController.dispose();
    _contactNumberController.dispose();
    _contactPersonController.dispose();
    super.dispose();
  }

  void _initializeFormAndHierarchyForViewMode(
    BayDetailViewMode mode, {
    Bay? bay,
  }) async {
    setState(() {
      _isLoadingFormHierarchy = true;
      _viewMode = mode;
      _bayToEdit = bay;
    });

    _bayNameController.clear();
    _descriptionController.clear();
    _landmarkController.clear();
    _contactNumberController.clear();
    _contactPersonController.clear();
    _selectedVoltageLevel = null;
    _selectedBayType = null;
    _isGovernmentFeeder = false;
    _selectedFeederType = null;

    _selectedStateName = null;
    _selectedZoneId = null;
    _selectedCircleId = null;
    _selectedDivisionId = null;
    _selectedSubdivisionId = null;
    _selectedSubstationIdForm = widget.substationId;

    if (mode == BayDetailViewMode.add) {
      await _traceHierarchyForSubstation(_selectedSubstationIdForm!);
    } else if (mode == BayDetailViewMode.edit && bay != null) {
      _bayNameController.text = bay.name;
      _descriptionController.text = bay.description ?? '';
      _landmarkController.text = bay.landmark ?? '';
      _contactNumberController.text = bay.contactNumber ?? '';
      _contactPersonController.text = bay.contactPerson ?? '';
      _selectedVoltageLevel = bay.voltageLevel;
      _selectedBayType = bay.bayType;
      _isGovernmentFeeder = bay.isGovernmentFeeder ?? false;
      _selectedFeederType = bay.feederType;
      _selectedSubstationIdForm = bay.substationId;

      await _traceHierarchyForSubstation(_selectedSubstationIdForm!);
    } else {
      _isLoadingFormHierarchy = false;
    }

    if (mounted &&
        (mode == BayDetailViewMode.add || mode == BayDetailViewMode.edit)) {
      setState(() {
        _isLoadingFormHierarchy = false;
      });
    }
  }

  Future<void> _traceHierarchyForSubstation(String substationId) async {
    try {
      final substationDoc = await FirebaseFirestore.instance
          .collection('substations')
          .doc(substationId)
          .get();
      if (substationDoc.exists) {
        final subdivisionId =
            (substationDoc.data() as Map<String, dynamic>)['subdivisionId'];
        _selectedSubdivisionId = subdivisionId;

        final subdivisionDoc = await FirebaseFirestore.instance
            .collection('subdivisions')
            .doc(subdivisionId)
            .get();
        if (subdivisionDoc.exists) {
          final divisionId =
              (subdivisionDoc.data() as Map<String, dynamic>)['divisionId'];
          _selectedDivisionId = divisionId;

          final divisionDoc = await FirebaseFirestore.instance
              .collection('divisions')
              .doc(divisionId)
              .get();
          if (divisionDoc.exists) {
            final circleId =
                (divisionDoc.data() as Map<String, dynamic>)['circleId'];
            _selectedCircleId = circleId;

            final circleDoc = await FirebaseFirestore.instance
                .collection('circles')
                .doc(circleId)
                .get();
            if (circleDoc.exists) {
              final zoneId =
                  (circleDoc.data() as Map<String, dynamic>)['zoneId'];
              _selectedZoneId = zoneId;

              final zoneDoc = await FirebaseFirestore.instance
                  .collection('zones')
                  .doc(zoneId)
                  .get();
              if (zoneDoc.exists) {
                _selectedStateName =
                    (zoneDoc.data() as Map<String, dynamic>)['stateName'];
              }
            }
          }
        }
      }
    } catch (e) {
      print('Error tracing hierarchy for substation: $e');
      if (mounted) {
        SnackBarUtils.showSnackBar(
          context,
          'Failed to load hierarchy: $e',
          isError: true,
        );
      }
    }
  }

  Future<void> _saveBay() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedSubstationIdForm == null) {
      SnackBarUtils.showSnackBar(
        context,
        'Substation not selected. Please report this error.',
        isError: true,
      );
      return;
    }

    if (_selectedBayType == 'Feeder' && _selectedFeederType == null) {
      SnackBarUtils.showSnackBar(
        context,
        'Please select a Feeder Bay Type.',
        isError: true,
      );
      return;
    }

    setState(() {
      _isSavingBay = true;
    });

    final firebaseUser = FirebaseAuth.instance.currentUser;
    if (firebaseUser == null) {
      if (mounted) {
        SnackBarUtils.showSnackBar(
          context,
          'User not authenticated.',
          isError: true,
        );
      }
      setState(() {
        _isSavingBay = false;
      });
      return;
    }

    try {
      if (_viewMode == BayDetailViewMode.edit && _bayToEdit != null) {
        final updatedBay = _bayToEdit!.copyWith(
          name: _bayNameController.text.trim(),
          substationId: _selectedSubstationIdForm!,
          voltageLevel: _selectedVoltageLevel!,
          bayType: _selectedBayType!,
          description: _descriptionController.text.trim().isEmpty
              ? null
              : _descriptionController.text.trim(),
          landmark: _landmarkController.text.trim().isEmpty
              ? null
              : _landmarkController.text.trim(),
          contactNumber: _contactNumberController.text.trim().isEmpty
              ? null
              : _contactNumberController.text.trim(),
          contactPerson: _contactPersonController.text.trim().isEmpty
              ? null
              : _contactPersonController.text.trim(),
          isGovernmentFeeder: _selectedBayType == 'Feeder'
              ? _isGovernmentFeeder
              : null,
          feederType: _selectedBayType == 'Feeder' ? _selectedFeederType : null,
        );
        await FirebaseFirestore.instance
            .collection('bays')
            .doc(updatedBay.id)
            .update(updatedBay.toFirestore());

        if (mounted) {
          SnackBarUtils.showSnackBar(
            context,
            'Bay "${_bayNameController.text}" updated successfully!',
          );
          _initializeFormAndHierarchyForViewMode(BayDetailViewMode.list);
        }
      } else {
        final newBayRef = FirebaseFirestore.instance.collection('bays').doc();
        final newBay = Bay(
          id: newBayRef.id,
          name: _bayNameController.text.trim(),
          substationId: _selectedSubstationIdForm!,
          voltageLevel: _selectedVoltageLevel!,
          bayType: _selectedBayType!,
          createdBy: firebaseUser.uid,
          createdAt: Timestamp.now(),
          description: _descriptionController.text.trim().isEmpty
              ? null
              : _descriptionController.text.trim(),
          landmark: _landmarkController.text.trim().isEmpty
              ? null
              : _landmarkController.text.trim(),
          contactNumber: _contactNumberController.text.trim().isEmpty
              ? null
              : _contactNumberController.text.trim(),
          contactPerson: _contactPersonController.text.trim().isEmpty
              ? null
              : _contactPersonController.text.trim(),
          isGovernmentFeeder: _selectedBayType == 'Feeder'
              ? _isGovernmentFeeder
              : null,
          feederType: _selectedBayType == 'Feeder' ? _selectedFeederType : null,
        );

        await newBayRef.set(newBay.toFirestore());

        if (mounted) {
          SnackBarUtils.showSnackBar(
            context,
            'Bay "${_bayNameController.text}" created successfully!',
          );
          _initializeFormAndHierarchyForViewMode(BayDetailViewMode.list);
        }
      }
    } catch (e) {
      print('Error saving bay: $e');
      if (mounted) {
        SnackBarUtils.showSnackBar(
          context,
          'Failed to ${(_viewMode == BayDetailViewMode.edit) ? 'update' : 'create'} bay: $e',
          isError: true,
        );
      }
    } finally {
      setState(() {
        _isSavingBay = false;
      });
    }
  }

  Future<void> _confirmDeleteBay(
    BuildContext context,
    Bay bay,
    String bayName,
  ) async {
    final bool confirm =
        await showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text('Confirm Deletion'),
              content: Text(
                'Are you sure you want to delete bay "$bayName"? '
                'This will also remove all equipment associated with it. This action cannot be undone.',
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
            .collection('bays')
            .doc(bay.id)
            .delete();

        if (mounted) {
          SnackBarUtils.showSnackBar(
            context,
            'Bay "$bayName" deleted successfully!',
          );
        }
      } catch (e) {
        print("Error deleting bay: $e");
        if (mounted) {
          SnackBarUtils.showSnackBar(
            context,
            'Failed to delete bay "$bayName": $e',
            isError: true,
          );
        }
      }
    }
  }

  Widget _buildHierarchyDropdown<T extends HierarchyItem>({
    required String collectionName,
    required String parentIdField,
    required String? parentId,
    required String label,
    required IconData icon,
    required Function(String?) onChanged,
    required String? currentValue,
    AppUser? currentUser,
  }) {
    Query query = FirebaseFirestore.instance.collection(collectionName);

    if (parentIdField != null &&
        parentId == null &&
        collectionName != 'zones') {
      return DropdownButtonFormField<String>(
        decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon)),
        items: const [],
        onChanged: null,
        value: null,
        hint: Text('Select a ${parentIdField.replaceAll('Id', '')} first'),
      );
    } else if (collectionName == 'zones' && parentId != null) {
      query = query.where(parentIdField, isEqualTo: parentId);
    } else if (parentIdField != null && parentId != null) {
      query = query.where(parentIdField, isEqualTo: parentId);
    }

    if (collectionName == 'substations' &&
        currentUser?.role == UserRole.subdivisionManager &&
        currentUser?.assignedLevels != null &&
        currentUser!.assignedLevels!.containsKey('subdivisionId')) {
      query = query.where(
        'subdivisionId',
        isEqualTo: currentUser.assignedLevels!['subdivisionId'],
      );
    } else if (collectionName == 'substations' &&
        currentUser?.role != UserRole.admin &&
        currentUser?.role != UserRole.subdivisionManager) {
      return DropdownButtonFormField<String>(
        decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon)),
        items: const [],
        onChanged: null,
        value: null,
        validator: (value) => value == null ? 'Please select a $label' : null,
        hint: Text('No $label available'),
      );
    }

    query = query.orderBy('name');

    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Text('Error: ${snapshot.error}');
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return DropdownButtonFormField<String>(
            decoration: InputDecoration(
              labelText: label,
              prefixIcon: Icon(icon),
            ),
            items: const [],
            onChanged: null,
            value: null,
            hint: const CircularProgressIndicator(strokeWidth: 2),
          );
        }

        List<DropdownMenuItem<String>> items = [];
        if (collectionName == 'zones') {
          items = snapshot.data!.docs.map((doc) {
            final zone = Zone.fromFirestore(doc);
            return DropdownMenuItem(value: zone.id, child: Text(zone.name));
          }).toList();
        } else if (collectionName == 'circles') {
          items = snapshot.data!.docs.map((doc) {
            final circle = Circle.fromFirestore(doc);
            return DropdownMenuItem(value: circle.id, child: Text(circle.name));
          }).toList();
        } else if (collectionName == 'divisions') {
          items = snapshot.data!.docs.map((doc) {
            final division = Division.fromFirestore(doc);
            return DropdownMenuItem(
              value: division.id,
              child: Text(division.name),
            );
          }).toList();
        } else if (collectionName == 'subdivisions') {
          items = snapshot.data!.docs.map((doc) {
            final subdivision = Subdivision.fromFirestore(doc);
            return DropdownMenuItem(
              value: subdivision.id,
              child: Text(subdivision.name),
            );
          }).toList();
        } else if (collectionName == 'substations') {
          items = snapshot.data!.docs.map((doc) {
            final substation = Substation.fromFirestore(doc);
            return DropdownMenuItem(
              value: substation.id,
              child: Text(substation.name),
            );
          }).toList();
        }

        return DropdownButtonFormField<String>(
          decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon)),
          value: currentValue,
          items: items.isEmpty
              ? [
                  const DropdownMenuItem(
                    value: null,
                    enabled: false,
                    child: Text('No options available'),
                  ),
                ]
              : items,
          onChanged: items.isEmpty ? null : onChanged,
          validator: (value) => value == null ? 'Please select a $label' : null,
          hint: Text('Select $label'),
        );
      },
    );
  }

  // --- Build Methods for different View Modes ---
  Widget _buildBayListView() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('bays')
          .where('substationId', isEqualTo: widget.substationId)
          .orderBy('voltageLevel', descending: true) // Order by voltage level
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Error: ${snapshot.error}',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                'No bays found for ${widget.substationName}. Click the "+" button to add one.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontStyle: FontStyle.italic,
                  color: Colors.grey.shade600,
                ),
              ),
            ),
          );
        }

        final bays = snapshot.data!.docs
            .map((doc) => Bay.fromFirestore(doc))
            .toList();

        // Group bays by voltage level
        final Map<String, List<Bay>> groupedBays = {};
        for (var bay in bays) {
          groupedBays.putIfAbsent(bay.voltageLevel, () => []).add(bay);
        }

        // Sort voltage levels (e.g., 765kV, 400kV, ...)
        final List<String> sortedVoltageLevels = _voltageLevels
            .where((level) => groupedBays.containsKey(level))
            .toList();

        return ListView.builder(
          padding: const EdgeInsets.all(16.0),
          itemCount: sortedVoltageLevels.length,
          itemBuilder: (context, levelIndex) {
            final voltageLevel = sortedVoltageLevels[levelIndex];
            final baysInLevel = groupedBays[voltageLevel]!;

            return Card(
              margin: const EdgeInsets.symmetric(vertical: 8.0),
              elevation: 3,
              child: ExpansionTile(
                initiallyExpanded: true, // Expand all groups by default
                title: Text(
                  '$voltageLevel Bays',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                leading: Icon(
                  Icons.flash_on,
                  color: Theme.of(context).colorScheme.primary,
                ),
                children: baysInLevel.map((bay) {
                  return ListTile(
                    title: Text(bay.name),
                    subtitle: Text('Type: ${bay.bayType}'),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => BayEquipmentManagementScreen(
                            bayId: bay.id,
                            bayName: bay.name,
                            substationId: bay.substationId,
                          ),
                        ),
                      );
                    },
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit),
                          color: Theme.of(context).colorScheme.tertiary,
                          onPressed: () {
                            _initializeFormAndHierarchyForViewMode(
                              BayDetailViewMode.edit,
                              bay: bay,
                            );
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline),
                          color: Theme.of(context).colorScheme.error,
                          onPressed: () =>
                              _confirmDeleteBay(context, bay, bay.name),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildBayFormView() {
    if (_isLoadingFormHierarchy) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              (_viewMode == BayDetailViewMode.edit)
                  ? 'Edit Bay Details'
                  : 'Bay Details',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            if (_viewMode == BayDetailViewMode.edit)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  'Bay ID: ${_bayToEdit!.id}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: AbsorbPointer(
                child: DropdownButtonFormField<String>(
                  value: _selectedSubstationIdForm,
                  decoration: const InputDecoration(
                    labelText: 'Substation (Selected)',
                    prefixIcon: Icon(Icons.electrical_services),
                  ),
                  items: [
                    DropdownMenuItem(
                      value: _selectedSubstationIdForm,
                      child: Text(widget.substationName),
                    ),
                  ],
                  onChanged: null,
                ),
              ),
            ),

            TextFormField(
              controller: _bayNameController,
              decoration: const InputDecoration(
                labelText: 'Bay Name',
                prefixIcon: Icon(Icons.grid_on),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter bay name';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _selectedVoltageLevel,
              decoration: const InputDecoration(
                labelText: 'Voltage Level',
                prefixIcon: Icon(Icons.flash_on),
              ),
              items: _voltageLevels.map((level) {
                return DropdownMenuItem(value: level, child: Text(level));
              }).toList(),
              onChanged: (newValue) {
                setState(() {
                  _selectedVoltageLevel = newValue;
                });
              },
              validator: (value) =>
                  value == null ? 'Please select voltage level' : null,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _selectedBayType,
              decoration: const InputDecoration(
                labelText: 'Bay Type',
                prefixIcon: Icon(Icons.category),
              ),
              items: _bayTypes.map((type) {
                return DropdownMenuItem(value: type, child: Text(type));
              }).toList(),
              onChanged: (newValue) {
                setState(() {
                  _selectedBayType = newValue;
                  if (newValue != 'Feeder') {
                    _isGovernmentFeeder = false;
                    _selectedFeederType = null;
                  }
                });
              },
              validator: (value) =>
                  value == null ? 'Please select bay type' : null,
            ),
            if (_selectedBayType == 'Feeder') ...[
              const SizedBox(height: 16),
              SwitchListTile(
                title: const Text('Government Feeder'),
                value: _isGovernmentFeeder,
                onChanged: (value) {
                  setState(() {
                    _isGovernmentFeeder = value;
                    _selectedFeederType = null;
                  });
                },
                secondary: const Icon(Icons.account_balance),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedFeederType,
                decoration: const InputDecoration(
                  labelText: 'Feeder Type',
                  prefixIcon: Icon(Icons.location_city),
                ),
                items:
                    (_isGovernmentFeeder
                            ? _governmentFeederTypes
                            : _nonGovernmentFeederTypes)
                        .map((type) {
                          return DropdownMenuItem(
                            value: type,
                            child: Text(type),
                          );
                        })
                        .toList(),
                onChanged: (newValue) {
                  setState(() {
                    _selectedFeederType = newValue;
                  });
                },
                validator: (value) =>
                    value == null ? 'Please select feeder type' : null,
              ),
            ],
            const SizedBox(height: 16),
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description (Optional)',
                prefixIcon: Icon(Icons.description),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _landmarkController,
              decoration: const InputDecoration(
                labelText: 'Landmark (Optional)',
                prefixIcon: Icon(Icons.flag),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _contactNumberController,
              decoration: const InputDecoration(
                labelText: 'Contact Number (Optional)',
                prefixIcon: Icon(Icons.phone),
              ),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _contactPersonController,
              decoration: const InputDecoration(
                labelText: 'Contact Person (Optional)',
                prefixIcon: Icon(Icons.person),
              ),
            ),
            const SizedBox(height: 32),
            Center(
              child: _isSavingBay
                  ? const CircularProgressIndicator()
                  : ElevatedButton.icon(
                      onPressed: _saveBay,
                      icon: Icon(
                        (_viewMode == BayDetailViewMode.edit)
                            ? Icons.save
                            : Icons.add,
                      ),
                      label: Text(
                        (_viewMode == BayDetailViewMode.edit)
                            ? 'Update Bay'
                            : 'Create Bay',
                      ),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 50),
                      ),
                    ),
            ),
            const SizedBox(height: 16),
            if (_viewMode != BayDetailViewMode.list)
              Center(
                child: TextButton(
                  onPressed: () => _initializeFormAndHierarchyForViewMode(
                    BayDetailViewMode.list,
                  ),
                  child: const Text('Cancel'),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Substation: ${widget.substationName}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () {
              SnackBarUtils.showSnackBar(
                context,
                'Substation details coming soon!',
              );
            },
          ),
        ],
      ),
      body: (_viewMode == BayDetailViewMode.list)
          ? _buildBayListView()
          : _buildBayFormView(),
      floatingActionButton: (_viewMode == BayDetailViewMode.list)
          ? FloatingActionButton.extended(
              onPressed: () =>
                  _initializeFormAndHierarchyForViewMode(BayDetailViewMode.add),
              label: const Text('Add New Bay'),
              icon: const Icon(Icons.add),
              backgroundColor: Theme.of(context).colorScheme.primary,
            )
          : null,
    );
  }
}
