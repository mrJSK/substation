// lib/widgets/bay_form_card.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dropdown_search/dropdown_search.dart';

import '../models/bay_connection_model.dart';
import '../models/bay_model.dart';
import '../models/user_model.dart';
import '../models/hierarchy_models.dart';
import '../utils/snackbar_utils.dart';
import 'add_hierarchy_dialog.dart';

enum DateType { commissioning, manufacturing, erection }

class BayFormCard extends StatefulWidget {
  final Bay? bayToEdit;
  final String substationId;
  final AppUser currentUser;
  final Function() onSaveSuccess;
  final Function() onCancel;
  final List<Bay> availableBusbars;

  const BayFormCard({
    super.key,
    this.bayToEdit,
    required this.substationId,
    required this.currentUser,
    required this.onSaveSuccess,
    required this.onCancel,
    required this.availableBusbars,
  });

  @override
  State<BayFormCard> createState() => _BayFormCardState();
}

class _BayFormCardState extends State<BayFormCard> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _bayNameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _landmarkController = TextEditingController();
  final TextEditingController _contactNumberController =
      TextEditingController();
  final TextEditingController _contactPersonController =
      TextEditingController();
  final TextEditingController _bayNumberController = TextEditingController();
  final TextEditingController _multiplyingFactorController =
      TextEditingController();
  final TextEditingController _lineLengthController = TextEditingController();
  final TextEditingController _otherConductorController =
      TextEditingController();
  String? _selectedCircuit;
  String? _selectedConductor;
  final TextEditingController _makeController = TextEditingController();
  final TextEditingController _capacityController = TextEditingController();
  String? _selectedHvVoltage;
  String? _selectedLvVoltage;
  String? _selectedHvBusId;
  String? _selectedLvBusId;
  final TextEditingController _commissioningDateController =
      TextEditingController();
  final TextEditingController _manufacturingDateController =
      TextEditingController();
  final TextEditingController _erectionDateController = TextEditingController();
  DateTime? _commissioningDate;
  DateTime? _erectionDate;
  DateTime? _manufacturingDate;
  String? _selectedVoltageLevel;
  String? _selectedBayType;
  bool _isGovernmentFeeder = false;
  String? _selectedFeederType;
  String? _selectedBusbarId;
  bool _isSavingBay = false;

  // State for Distribution Hierarchy selection for Feeders
  String? _selectedDistributionZoneId;
  String? _selectedDistributionCircleId;
  String? _selectedDistributionDivisionId;
  String? _selectedDistributionSubdivisionId;

  // Maps for Distribution Hierarchy lookup (populated on init)
  Map<String, DistributionZone> _distributionZonesMap = {};
  Map<String, DistributionCircle> _distributionCirclesMap = {};
  Map<String, DistributionDivision> _distributionDivisionsMap = {};
  Map<String, DistributionSubdivision> _distributionSubdivisionsMap = {};

  final List<String> _voltageLevels = [
    '765kV',
    '400kV',
    '220kV',
    '132kV',
    '33kV',
    '11kV',
    '800kV',
    '25kV',
    '400V',
  ];
  final List<String> _bayTypes = [
    'Busbar',
    'Transformer',
    'Line',
    'Feeder',
    'Capacitor Bank',
    'Reactor',
    'Bus Coupler',
    'Battery',
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
  final List<String> _circuitTypes = ['Single', 'Double'];
  final List<String> _conductorTypes = [
    'Panther',
    'Zebra',
    'Moose',
    'Twin Moose',
    'Quad Moose',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    _fetchDistributionHierarchyData();
    _initializeFormFields();
  }

  @override
  void dispose() {
    _bayNameController.dispose();
    _descriptionController.dispose();
    _landmarkController.dispose();
    _contactNumberController.dispose();
    _contactPersonController.dispose();
    _bayNumberController.dispose();
    _multiplyingFactorController.dispose();
    _lineLengthController.dispose();
    _otherConductorController.dispose();
    _makeController.dispose();
    _capacityController.dispose();
    _commissioningDateController.dispose();
    _manufacturingDateController.dispose();
    _erectionDateController.dispose();
    super.dispose();
  }

  void _initializeFormFields() {
    final bay = widget.bayToEdit;
    if (bay != null) {
      _bayNameController.text = bay.name;
      _descriptionController.text = bay.description ?? '';
      _landmarkController.text = bay.landmark ?? '';
      _contactNumberController.text = bay.contactNumber ?? '';
      _contactPersonController.text = bay.contactPerson ?? '';
      _bayNumberController.text = bay.bayNumber ?? '';
      _multiplyingFactorController.text =
          bay.multiplyingFactor?.toString() ?? '';
      _selectedVoltageLevel = bay.voltageLevel;
      _selectedBayType = bay.bayType;
      _isGovernmentFeeder = bay.isGovernmentFeeder ?? false;
      _selectedFeederType = bay.feederType;
      if (bay.bayType == 'Line') {
        _lineLengthController.text = bay.lineLength?.toString() ?? '';
        _selectedCircuit = bay.circuitType;
        _selectedConductor = bay.conductorType;
        _otherConductorController.text = bay.conductorDetail ?? '';
        if (bay.erectionDate != null) {
          _erectionDate = bay.erectionDate!.toDate();
          _erectionDateController.text = _erectionDate!
              .toLocal()
              .toString()
              .split(' ')[0];
        }
      }
      if (bay.bayType == 'Transformer') {
        _selectedHvVoltage = bay.hvVoltage;
        _selectedLvVoltage = bay.lvVoltage;
        _makeController.text = bay.make ?? '';
        _capacityController.text = bay.capacity?.toString() ?? '';
        _selectedHvBusId = bay.hvBusId;
        _selectedLvBusId = bay.lvBusId;
        if (bay.manufacturingDate != null) {
          _manufacturingDate = bay.manufacturingDate!.toDate();
          _manufacturingDateController.text = _manufacturingDate!
              .toLocal()
              .toString()
              .split(' ')[0];
        }
      }
      if (bay.commissioningDate != null) {
        _commissioningDate = bay.commissioningDate!.toDate();
        _commissioningDateController.text = _commissioningDate!
            .toLocal()
            .toString()
            .split(' ')[0];
      }
      // Initialize distribution hierarchy for Feeder bays
      if (bay.bayType == 'Feeder') {
        _selectedDistributionZoneId = bay.distributionZoneId;
        _selectedDistributionCircleId = bay.distributionCircleId;
        _selectedDistributionDivisionId = bay.distributionDivisionId;
        _selectedDistributionSubdivisionId = bay.distributionSubdivisionId;
      }
    }
  }

  Future<void> _fetchDistributionHierarchyData() async {
    _distributionZonesMap.clear();
    _distributionCirclesMap.clear();
    _distributionDivisionsMap.clear();
    _distributionSubdivisionsMap.clear();

    final zonesSnapshot = await FirebaseFirestore.instance
        .collection('distributionZones')
        .get();
    _distributionZonesMap = {
      for (var doc in zonesSnapshot.docs)
        doc.id: DistributionZone.fromFirestore(doc),
    };

    final circlesSnapshot = await FirebaseFirestore.instance
        .collection('distributionCircles')
        .get();
    _distributionCirclesMap = {
      for (var doc in circlesSnapshot.docs)
        doc.id: DistributionCircle.fromFirestore(doc),
    };

    final divisionsSnapshot = await FirebaseFirestore.instance
        .collection('distributionDivisions')
        .get();
    _distributionDivisionsMap = {
      for (var doc in divisionsSnapshot.docs)
        doc.id: DistributionDivision.fromFirestore(doc),
    };

    final subdivisionsSnapshot = await FirebaseFirestore.instance
        .collection('distributionSubdivisions')
        .get();
    _distributionSubdivisionsMap = {
      for (var doc in subdivisionsSnapshot.docs)
        doc.id: DistributionSubdivision.fromFirestore(doc),
    };

    setState(() {}); // Rebuild to update dropdowns with fetched data
  }

  Future<void> _saveBay() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedBayType != 'Busbar' && widget.availableBusbars.isEmpty) {
      SnackBarUtils.showSnackBar(
        context,
        'Please create a Busbar first.',
        isError: true,
      );
      return;
    }
    if (_selectedBayType == 'Transformer' &&
        (_selectedHvBusId == null || _selectedLvBusId == null)) {
      SnackBarUtils.showSnackBar(
        context,
        'Please connect both HV and LV sides of the transformer to a busbar.',
        isError: true,
      );
      return;
    }

    // Validation for Feeder distribution hierarchy
    if (_selectedBayType == 'Feeder' &&
        (_selectedDistributionZoneId == null ||
            _selectedDistributionCircleId == null ||
            _selectedDistributionDivisionId == null ||
            _selectedDistributionSubdivisionId == null)) {
      SnackBarUtils.showSnackBar(
        context,
        'Please select all Distribution hierarchy levels for this feeder.',
        isError: true,
      );
      return;
    }

    setState(() => _isSavingBay = true);
    final firebaseUser = widget.currentUser;
    if (firebaseUser == null) {
      if (mounted) {
        SnackBarUtils.showSnackBar(
          context,
          'User not authenticated.',
          isError: true,
        );
      }
      setState(() => _isSavingBay = false);
      return;
    }

    try {
      final bayData = {
        'name': _bayNameController.text.trim(),
        'substationId': widget.substationId,
        'voltageLevel': _selectedBayType == 'Transformer'
            ? _selectedHvVoltage
            : _selectedVoltageLevel,
        'bayType': _selectedBayType!,
        'description': _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        'bayNumber': _bayNumberController.text.trim().isEmpty
            ? null
            : _bayNumberController.text.trim(),
        'multiplyingFactor': _multiplyingFactorController.text.isNotEmpty
            ? double.tryParse(_multiplyingFactorController.text.trim())
            : null,
        'isGovernmentFeeder': _selectedBayType == 'Feeder'
            ? _isGovernmentFeeder
            : null,
        'feederType': _selectedBayType == 'Feeder' ? _selectedFeederType : null,
        'lineLength': _selectedBayType == 'Line'
            ? double.tryParse(_lineLengthController.text.trim())
            : null,
        'circuitType': _selectedBayType == 'Line' ? _selectedCircuit : null,
        'conductorType': _selectedBayType == 'Line' ? _selectedConductor : null,
        'conductorDetail':
            _selectedBayType == 'Line' && _selectedConductor == 'Other'
            ? (_otherConductorController.text.trim().isEmpty
                  ? null
                  : _otherConductorController.text.trim())
            : null,
        'erectionDate': _selectedBayType == 'Line' && _erectionDate != null
            ? Timestamp.fromDate(_erectionDate!)
            : null,
        'hvVoltage': _selectedBayType == 'Transformer'
            ? _selectedHvVoltage
            : null,
        'lvVoltage': _selectedBayType == 'Transformer'
            ? _selectedLvVoltage
            : null,
        'make':
            _selectedBayType == 'Transformer' && _makeController.text.isNotEmpty
            ? _makeController.text.trim()
            : null,
        'capacity':
            _selectedBayType == 'Transformer' &&
                _capacityController.text.isNotEmpty
            ? double.tryParse(_capacityController.text.trim())
            : null,
        'manufacturingDate':
            _selectedBayType == 'Transformer' && _manufacturingDate != null
            ? Timestamp.fromDate(_manufacturingDate!)
            : null,
        'hvBusId': _selectedBayType == 'Transformer' ? _selectedHvBusId : null,
        'lvBusId': _selectedBayType == 'Transformer' ? _selectedLvBusId : null,
        'commissioningDate':
            (_selectedBayType == 'Line' || _selectedBayType == 'Transformer') &&
                _commissioningDate != null
            ? Timestamp.fromDate(_commissioningDate!)
            : null,
        // Save Distribution Hierarchy IDs if it's a Feeder
        'distributionZoneId': _selectedBayType == 'Feeder'
            ? _selectedDistributionZoneId
            : null,
        'distributionCircleId': _selectedBayType == 'Feeder'
            ? _selectedDistributionCircleId
            : null,
        'distributionDivisionId': _selectedBayType == 'Feeder'
            ? _selectedDistributionDivisionId
            : null,
        'distributionSubdivisionId': _selectedBayType == 'Feeder'
            ? _selectedDistributionSubdivisionId
            : null,
      };

      if (widget.bayToEdit != null) {
        final bayId = widget.bayToEdit!.id;
        // Preserve existing position when editing other properties
        bayData['xPosition'] = widget.bayToEdit!.xPosition;
        bayData['yPosition'] = widget.bayToEdit!.yPosition;

        await FirebaseFirestore.instance
            .collection('bays')
            .doc(bayId)
            .update(bayData);

        // Manage connections based on current and new bay types
        final batch = FirebaseFirestore.instance.batch();

        // Always delete existing connections for the bay being edited to simplify updates
        final existingConnectionsSnapshot = await FirebaseFirestore.instance
            .collection('bay_connections')
            .where('substationId', isEqualTo: widget.substationId)
            .where(
              Filter.or(
                Filter('sourceBayId', isEqualTo: bayId),
                Filter('targetBayId', isEqualTo: bayId),
              ),
            )
            .get();
        for (var doc in existingConnectionsSnapshot.docs) {
          batch.delete(doc.reference);
        }
        await batch.commit(); // Commit deletions first

        // Add new connections based on the updated bay type and selections
        if (_selectedBayType == 'Transformer') {
          if (_selectedHvBusId != null) {
            await FirebaseFirestore.instance
                .collection('bay_connections')
                .add(
                  BayConnection(
                    substationId: widget.substationId,
                    sourceBayId:
                        _selectedHvBusId!, // Bus connects to HV side of TF
                    targetBayId: bayId,
                    createdBy: firebaseUser.uid,
                    createdAt: Timestamp.now(),
                  ).toFirestore(),
                );
          }
          if (_selectedLvBusId != null) {
            await FirebaseFirestore.instance
                .collection('bay_connections')
                .add(
                  BayConnection(
                    substationId: widget.substationId,
                    sourceBayId: bayId, // LV side of TF connects to Bus
                    targetBayId: _selectedLvBusId!,
                    createdBy: firebaseUser.uid,
                    createdAt: Timestamp.now(),
                  ).toFirestore(),
                );
          }
        } else if (_selectedBayType != 'Busbar' && _selectedBusbarId != null) {
          // For other bays (Line, Feeder, etc.) that connect to a single busbar
          await FirebaseFirestore.instance
              .collection('bay_connections')
              .add(
                BayConnection(
                  substationId: widget.substationId,
                  sourceBayId: _selectedBusbarId!, // Bus connects to bay
                  targetBayId: bayId,
                  createdBy: firebaseUser.uid,
                  createdAt: Timestamp.now(),
                ).toFirestore(),
              );
        }
        // If the bay becomes a Busbar or another type that doesn't connect, no new connections are added here.

        if (mounted) {
          SnackBarUtils.showSnackBar(context, 'Bay updated successfully!');
          widget.onSaveSuccess();
        }
      } else {
        // This is for adding a new bay
        final newBayRef = FirebaseFirestore.instance.collection('bays').doc();
        bayData['createdBy'] = firebaseUser.uid;
        bayData['createdAt'] = Timestamp.now();
        // New bays don't have a position yet, so these will be null initially
        bayData['xPosition'] = null;
        bayData['yPosition'] = null;
        await newBayRef.set(bayData);

        if (_selectedBayType == 'Transformer') {
          if (_selectedHvBusId != null) {
            await FirebaseFirestore.instance
                .collection('bay_connections')
                .add(
                  BayConnection(
                    substationId: widget.substationId,
                    sourceBayId: _selectedHvBusId!,
                    targetBayId: newBayRef.id,
                    createdBy: firebaseUser.uid,
                    createdAt: Timestamp.now(),
                  ).toFirestore(),
                );
          }
          if (_selectedLvBusId != null) {
            await FirebaseFirestore.instance
                .collection('bay_connections')
                .add(
                  BayConnection(
                    substationId: widget.substationId,
                    sourceBayId: newBayRef.id,
                    targetBayId: _selectedLvBusId!,
                    createdBy: firebaseUser.uid,
                    createdAt: Timestamp.now(),
                  ).toFirestore(),
                );
          }
        } else if (_selectedBayType != 'Busbar' && _selectedBusbarId != null) {
          await FirebaseFirestore.instance
              .collection('bay_connections')
              .add(
                BayConnection(
                  substationId: widget.substationId,
                  sourceBayId: _selectedBusbarId!,
                  targetBayId: newBayRef.id,
                  createdBy: firebaseUser.uid,
                  createdAt: Timestamp.now(),
                ).toFirestore(),
              );
        }

        final createdBayDoc = await newBayRef.get();
        await _createDefaultReadingAssignment(
          Bay.fromFirestore(createdBayDoc),
          firebaseUser.uid,
        );
        if (mounted) {
          SnackBarUtils.showSnackBar(context, 'Bay created successfully!');
          widget.onSaveSuccess();
        }
      }
    } catch (e) {
      if (mounted) {
        SnackBarUtils.showSnackBar(
          context,
          'Failed to save bay: $e',
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _isSavingBay = false);
    }
  }

  Future<void> _selectDate(BuildContext context, DateType type) async {
    DateTime initial = DateTime.now();
    if (type == DateType.commissioning && _commissioningDate != null)
      initial = _commissioningDate!;
    if (type == DateType.manufacturing && _manufacturingDate != null)
      initial = _manufacturingDate!;
    if (type == DateType.erection && _erectionDate != null)
      initial = _erectionDate!;

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1950),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
    );
    if (picked != null) {
      setState(() {
        String formattedDate = picked.toLocal().toString().split(' ')[0];
        switch (type) {
          case DateType.commissioning:
            _commissioningDate = picked;
            _commissioningDateController.text = formattedDate;
            break;
          case DateType.manufacturing:
            _manufacturingDate = picked;
            _manufacturingDateController.text = formattedDate;
            break;
          case DateType.erection:
            _erectionDate = picked;
            _erectionDateController.text = formattedDate;
            break;
        }
      });
    }
  }

  Future<void> _createDefaultReadingAssignment(Bay bay, String userId) async {
    /* Placeholder for default reading assignment creation */
  }

  // Helper to build distribution hierarchy dropdowns
  Widget _buildDistributionHierarchyDropdown<T extends HierarchyItem>({
    required String label,
    required String collectionName,
    required String? parentId,
    required String parentIdFieldName,
    required Function(String? value) onChanged,
    required String? currentValue,
    required T Function(DocumentSnapshot) fromFirestore,
    required String? Function(T?) validator,
    required Map<String, T> lookupMap,
    required String addHierarchyType, // e.g., 'DistributionZone'
  }) {
    // Only show if selected bay type is 'Feeder'
    if (_selectedBayType != 'Feeder') {
      return const SizedBox.shrink();
    }

    Query query = FirebaseFirestore.instance.collection(collectionName);
    if (parentId != null && parentIdFieldName.isNotEmpty) {
      query = query.where(parentIdFieldName, isEqualTo: parentId);
    }
    query = query.orderBy('name');

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: DropdownSearch<T>(
        selectedItem: currentValue != null ? lookupMap[currentValue] : null,
        itemAsString: (T item) => item.name,
        compareFn: (item1, item2) =>
            item1.id == item2.id, // FIX: Added compareFn
        asyncItems: (String filter) async {
          if (parentId != null &&
              parentIdFieldName.isNotEmpty &&
              parentId.isEmpty) {
            return []; // Don't fetch if parent is not selected
          }
          final snapshot = await query.get();
          return snapshot.docs
              .map((doc) => fromFirestore(doc))
              .where(
                (item) =>
                    item.name.toLowerCase().contains(filter.toLowerCase()),
              )
              .toList();
        },
        onChanged: (newValue) {
          onChanged(newValue?.id);
          // Clear child selections when a parent changes
          if (collectionName == 'distributionZones') {
            setState(() {
              _selectedDistributionCircleId = null;
              _selectedDistributionDivisionId = null;
              _selectedDistributionSubdivisionId = null;
            });
          } else if (collectionName == 'distributionCircles') {
            setState(() {
              _selectedDistributionDivisionId = null;
              _selectedDistributionSubdivisionId = null;
            });
          } else if (collectionName == 'distributionDivisions') {
            setState(() {
              _selectedDistributionSubdivisionId = null;
            });
          }
        },
        validator: validator,
        enabled:
            (parentId == null || (parentId != null && parentId.isNotEmpty)),
        dropdownDecoratorProps: DropDownDecoratorProps(
          dropdownSearchDecoration: InputDecoration(
            labelText: label,
            prefixIcon: Icon(Icons.location_on),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            filled: true,
            fillColor: Theme.of(context).colorScheme.primary.withOpacity(0.05),
          ),
        ),
        popupProps: PopupProps.menu(
          showSearchBox: true,
          menuProps: MenuProps(borderRadius: BorderRadius.circular(10)),
          searchFieldProps: TextFieldProps(
            decoration: InputDecoration(
              labelText: 'Search $label',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          showSelectedItems: true,
          emptyBuilder: (context, searchEntry) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('No $label found.'),
                    ElevatedButton.icon(
                      onPressed: () async {
                        final newCreatedItem = await showDialog<HierarchyItem>(
                          context: context,
                          builder: (context) => AddHierarchyDialog(
                            hierarchyType: addHierarchyType,
                            parentId: parentId,
                            parentIdFieldName: parentIdFieldName,
                            currentUser: widget.currentUser,
                          ),
                        );
                        if (newCreatedItem != null) {
                          // Manually update the map after creation
                          if (newCreatedItem is DistributionZone) {
                            lookupMap[newCreatedItem.id] = newCreatedItem as T;
                          } else if (newCreatedItem is DistributionCircle) {
                            lookupMap[newCreatedItem.id] = newCreatedItem as T;
                          } else if (newCreatedItem is DistributionDivision) {
                            lookupMap[newCreatedItem.id] = newCreatedItem as T;
                          } else if (newCreatedItem
                              is DistributionSubdivision) {
                            lookupMap[newCreatedItem.id] = newCreatedItem as T;
                          }
                          // Manually call onChanged to select the new item
                          onChanged(newCreatedItem.id);
                          // Rebuild the dropdown to show the new item
                          setState(() {});
                          if (mounted)
                            Navigator.pop(context); // Close the popup
                        }
                      },
                      icon: const Icon(Icons.add),
                      label: Text('Create New $label'),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.bayToEdit == null ? 'Add New Bay' : 'Edit Bay',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 24),
            TextFormField(
              controller: _bayNameController,
              decoration: const InputDecoration(
                labelText: 'Bay Name',
                prefixIcon: Icon(Icons.grid_on),
              ),
              validator: (v) => v!.isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 16),
            if (_selectedBayType != 'Transformer' &&
                _selectedBayType != 'Battery') ...[
              DropdownButtonFormField<String>(
                value: _selectedVoltageLevel,
                decoration: const InputDecoration(
                  labelText: 'Voltage Level',
                  prefixIcon: Icon(Icons.flash_on),
                ),
                items: _voltageLevels
                    .map((l) => DropdownMenuItem(value: l, child: Text(l)))
                    .toList(),
                onChanged: (v) => setState(() => _selectedVoltageLevel = v),
                validator: (v) => v == null ? 'Required' : null,
              ),
              const SizedBox(height: 16),
            ],
            DropdownButtonFormField<String>(
              value: _selectedBayType,
              decoration: const InputDecoration(
                labelText: 'Bay Type',
                prefixIcon: Icon(Icons.category),
              ),
              items: _bayTypes
                  .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                  .toList(),
              onChanged: (v) => setState(() {
                _selectedBayType = v;
                if (v != 'Feeder') {
                  _isGovernmentFeeder = false;
                  _selectedFeederType = null;
                  _selectedDistributionZoneId = null;
                  _selectedDistributionCircleId = null;
                  _selectedDistributionDivisionId = null;
                  _selectedDistributionSubdivisionId = null;
                }
                if (v != 'Line') {
                  _lineLengthController.clear();
                  _selectedCircuit = null;
                  _selectedConductor = null;
                  _otherConductorController.clear();
                  _erectionDateController.clear();
                  _erectionDate = null;
                }
                if (v != 'Transformer') {
                  _selectedHvVoltage = null;
                  _selectedLvVoltage = null;
                  _makeController.clear();
                  _capacityController.clear();
                  _selectedHvBusId = null;
                  _selectedLvBusId = null;
                  _manufacturingDateController.clear();
                  _manufacturingDate = null;
                }
                if (v == 'Busbar' || v == 'Transformer' || v == 'Battery') {
                  _selectedBusbarId = null;
                }
              }),
              validator: (v) => v == null ? 'Required' : null,
            ),
            const SizedBox(height: 16),
            if (_selectedBayType != null &&
                _selectedBayType != 'Busbar' &&
                _selectedBayType != 'Battery') ...[
              TextFormField(
                controller: _bayNumberController,
                decoration: const InputDecoration(
                  labelText: 'Bay Number (Optional)',
                  prefixIcon: Icon(Icons.tag),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _multiplyingFactorController,
                decoration: const InputDecoration(
                  labelText: 'Multiplying Factor',
                  prefixIcon: Icon(Icons.clear),
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) {
                    return 'Multiplying Factor is required';
                  }
                  if (double.tryParse(v) == null) {
                    return 'Please enter a valid number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
            ],
            if (_selectedBayType != null &&
                _selectedBayType != 'Busbar' &&
                _selectedBayType != 'Transformer' &&
                _selectedBayType != 'Battery') ...[
              DropdownButtonFormField<String>(
                value: _selectedBusbarId,
                decoration: const InputDecoration(
                  labelText: 'Connect to Busbar',
                  prefixIcon: Icon(Icons.electrical_services_sharp),
                ),
                items: widget.availableBusbars
                    .map(
                      (b) => DropdownMenuItem(value: b.id, child: Text(b.name)),
                    )
                    .toList(),
                onChanged: (v) => setState(() => _selectedBusbarId = v),
                validator: (v) =>
                    widget.bayToEdit == null && v == null ? 'Required' : null,
              ),
              const SizedBox(height: 16),
            ],
            if (_selectedBayType == 'Transformer') ...[
              DropdownButtonFormField<String>(
                value: _selectedHvVoltage,
                decoration: const InputDecoration(
                  labelText: 'HV Voltage',
                  prefixIcon: Icon(Icons.electric_bolt),
                ),
                items: _voltageLevels
                    .map((l) => DropdownMenuItem(value: l, child: Text(l)))
                    .toList(),
                onChanged: (v) => setState(() => _selectedHvVoltage = v),
                validator: (v) => v == null ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedHvBusId,
                decoration: const InputDecoration(
                  labelText: 'Connect HV to Bus',
                  prefixIcon: Icon(Icons.power),
                ),
                items: widget.availableBusbars
                    .where((b) => b.voltageLevel == _selectedHvVoltage)
                    .map(
                      (b) => DropdownMenuItem(
                        value: b.id,
                        child: Text('${b.name} (${b.voltageLevel})'),
                      ),
                    )
                    .toList(),
                onChanged: (v) => setState(() => _selectedHvBusId = v),
                validator: (v) {
                  if (v == null) return 'HV bus connection is required';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedLvVoltage,
                decoration: const InputDecoration(
                  labelText: 'LV Voltage',
                  prefixIcon: Icon(Icons.electric_bolt_outlined),
                ),
                items: _voltageLevels
                    .map((l) => DropdownMenuItem(value: l, child: Text(l)))
                    .toList(),
                onChanged: (v) => setState(() => _selectedLvVoltage = v),
                validator: (v) => v == null ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedLvBusId,
                decoration: const InputDecoration(
                  labelText: 'Connect LV to Bus',
                  prefixIcon: Icon(Icons.power_off),
                ),
                items: widget.availableBusbars
                    .where((b) => b.voltageLevel == _selectedLvVoltage)
                    .map(
                      (b) => DropdownMenuItem(
                        value: b.id,
                        child: Text('${b.name} (${b.voltageLevel})'),
                      ),
                    )
                    .toList(),
                onChanged: (v) => setState(() => _selectedLvBusId = v),
                validator: (v) {
                  if (v == null) return 'LV bus connection is required';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _makeController,
                decoration: const InputDecoration(
                  labelText: 'Make',
                  prefixIcon: Icon(Icons.factory),
                ),
                validator: (v) => v!.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _capacityController,
                decoration: const InputDecoration(
                  labelText: 'Capacity',
                  suffixText: 'MVA',
                  prefixIcon: Icon(Icons.storage),
                ),
                keyboardType: TextInputType.number,
                validator: (v) => v!.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _manufacturingDateController,
                decoration: const InputDecoration(
                  labelText: 'Date of Manufacturing',
                  prefixIcon: Icon(Icons.calendar_today),
                ),
                readOnly: true,
                onTap: () => _selectDate(context, DateType.manufacturing),
                validator: (v) => v!.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),
            ],
            if (_selectedBayType == 'Line') ...[
              TextFormField(
                controller: _lineLengthController,
                decoration: const InputDecoration(
                  labelText: 'Line Length (km)',
                  prefixIcon: Icon(Icons.straighten),
                ),
                keyboardType: TextInputType.number,
                validator: (v) => v!.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedCircuit,
                decoration: const InputDecoration(
                  labelText: 'Circuit',
                  prefixIcon: Icon(Icons.electrical_services),
                ),
                items: _circuitTypes
                    .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                    .toList(),
                onChanged: (v) => setState(() => _selectedCircuit = v),
                validator: (v) => v == null ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedConductor,
                decoration: const InputDecoration(
                  labelText: 'Conductor',
                  prefixIcon: Icon(Icons.waves),
                ),
                items: _conductorTypes
                    .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                    .toList(),
                onChanged: (v) => setState(() => _selectedConductor = v),
                validator: (v) => v == null ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              if (_selectedConductor == 'Other') ...[
                TextFormField(
                  controller: _otherConductorController,
                  decoration: const InputDecoration(
                    labelText: 'Specify Conductor Type',
                    prefixIcon: Icon(Icons.edit),
                  ),
                  validator: (v) => v!.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 16),
              ],
              TextFormField(
                controller: _erectionDateController,
                decoration: const InputDecoration(
                  labelText: 'Date of Erection',
                  prefixIcon: Icon(Icons.calendar_today),
                ),
                readOnly: true,
                onTap: () => _selectDate(context, DateType.erection),
                validator: (v) => v!.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),
            ],
            if (_selectedBayType == 'Line' ||
                _selectedBayType == 'Transformer') ...[
              TextFormField(
                controller: _commissioningDateController,
                decoration: const InputDecoration(
                  labelText: 'Date of Commissioning',
                  prefixIcon: Icon(Icons.calendar_today),
                ),
                readOnly: true,
                onTap: () => _selectDate(context, DateType.commissioning),
                validator: (v) => v!.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),
            ],
            if (_selectedBayType == 'Feeder')
              ..._buildFeederDistributionHierarchyFields(),
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
                        (widget.bayToEdit != null) ? Icons.save : Icons.add,
                      ),
                      label: Text(
                        (widget.bayToEdit != null)
                            ? 'Update Bay'
                            : 'Create Bay',
                      ),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 50),
                      ),
                    ),
            ),
            const SizedBox(height: 16),
            Center(
              child: TextButton(
                onPressed: widget.onCancel,
                child: const Text('Cancel'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Extracted method for building feeder distribution hierarchy fields
  List<Widget> _buildFeederDistributionHierarchyFields() {
    return [
      SwitchListTile(
        title: const Text('Government Feeder'),
        value: _isGovernmentFeeder,
        onChanged: (v) => setState(() {
          _isGovernmentFeeder = v;
          _selectedFeederType = null;
        }),
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
                .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                .toList(),
        onChanged: (v) => setState(() => _selectedFeederType = v),
        validator: (v) => v == null ? 'Required' : null,
      ),
      const SizedBox(height: 16),
      Text(
        'Distribution Hierarchy (For Feeder)',
        style: Theme.of(context).textTheme.titleMedium,
      ),
      const SizedBox(height: 10),
      _buildDistributionHierarchyDropdown<DistributionZone>(
        label: 'Distribution Zone',
        collectionName: 'distributionZones',
        parentId: null,
        parentIdFieldName: '',
        onChanged: (value) =>
            setState(() => _selectedDistributionZoneId = value),
        currentValue: _selectedDistributionZoneId,
        fromFirestore: DistributionZone.fromFirestore,
        validator: (value) => value == null ? 'Required' : null,
        lookupMap: _distributionZonesMap,
        addHierarchyType: 'DistributionZone',
      ),
      _buildDistributionHierarchyDropdown<DistributionCircle>(
        label: 'Distribution Circle',
        collectionName: 'distributionCircles',
        parentId: _selectedDistributionZoneId,
        parentIdFieldName: 'distributionZoneId',
        onChanged: (value) =>
            setState(() => _selectedDistributionCircleId = value),
        currentValue: _selectedDistributionCircleId,
        fromFirestore: DistributionCircle.fromFirestore,
        validator: (value) => value == null ? 'Required' : null,
        lookupMap: _distributionCirclesMap,
        addHierarchyType: 'DistributionCircle',
      ),
      _buildDistributionHierarchyDropdown<DistributionDivision>(
        label: 'Distribution Division',
        collectionName: 'distributionDivisions',
        parentId: _selectedDistributionCircleId,
        parentIdFieldName: 'distributionCircleId',
        onChanged: (value) =>
            setState(() => _selectedDistributionDivisionId = value),
        currentValue: _selectedDistributionDivisionId,
        fromFirestore: DistributionDivision.fromFirestore,
        validator: (value) => value == null ? 'Required' : null,
        lookupMap: _distributionDivisionsMap,
        addHierarchyType: 'DistributionDivision',
      ),
      // Dropdown for Distribution Subdivision
      _buildDistributionHierarchyDropdown<DistributionSubdivision>(
        label: 'Distribution Subdivision',
        collectionName: 'distributionSubdivisions',
        parentId: _selectedDistributionDivisionId,
        parentIdFieldName: 'distributionDivisionId',
        onChanged: (value) =>
            setState(() => _selectedDistributionSubdivisionId = value),
        currentValue: _selectedDistributionSubdivisionId,
        fromFirestore: DistributionSubdivision.fromFirestore,
        validator: (value) => value == null ? 'Required' : null,
        lookupMap: _distributionSubdivisionsMap,
        addHierarchyType: 'DistributionSubdivision',
      ),
      const SizedBox(height: 16),
    ];
  }
}
