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
import '../screens/bay_reading_assignment_screen.dart';
import '../models/bay_connection_model.dart';
import '../models/reading_models.dart';

enum BayDetailViewMode { list, add, edit }

// Enum to manage which date is being picked
enum DateType { commissioning, manufacturing, erection }

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
  // --- Common Controllers ---
  final TextEditingController _bayNameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _landmarkController = TextEditingController();
  final TextEditingController _contactNumberController =
      TextEditingController();
  final TextEditingController _contactPersonController =
      TextEditingController();
  final TextEditingController _bayNumberController = TextEditingController();
  final TextEditingController _multiplyingFactorController =
      TextEditingController(); // **NEW**

  // --- Line Controllers & State ---
  final TextEditingController _lineLengthController = TextEditingController();
  final TextEditingController _otherConductorController =
      TextEditingController();
  String? _selectedCircuit;
  String? _selectedConductor;

  // --- Transformer Controllers & State ---
  final TextEditingController _makeController = TextEditingController();
  final TextEditingController _capacityController = TextEditingController();
  String? _selectedHvVoltage;
  String? _selectedLvVoltage;

  // --- Date Controllers & State (Shared by Line & Transformer) ---
  final TextEditingController _commissioningDateController =
      TextEditingController();
  final TextEditingController _manufacturingDateController =
      TextEditingController();
  final TextEditingController _erectionDateController = TextEditingController();
  DateTime? _commissioningDate;
  DateTime? _erectionDate;
  DateTime? _manufacturingDate;

  // --- General State ---
  String? _selectedSubstationIdForm;
  String? _selectedVoltageLevel;
  String? _selectedBayType;
  bool _isGovernmentFeeder = false;
  String? _selectedFeederType;
  List<Bay> _availableBusbars = [];
  String? _selectedBusbarId;
  bool _isLoadingFormHierarchy = true;
  bool _isSavingBay = false;

  // --- Data Lists ---
  final List<String> _voltageLevels = [
    '765kV',
    '400kV',
    '220kV',
    '132kV',
    '33kV',
    '11kV',
  ];
  final List<String> _transformerVoltageLevels = [
    '800kV',
    '765kV',
    '400kV',
    '220kV',
    '132kV',
    '33kV',
    '25kV',
    '11kV',
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
    _bayNumberController.dispose();
    _multiplyingFactorController.dispose(); // **NEW**
    _lineLengthController.dispose();
    _otherConductorController.dispose();
    _makeController.dispose();
    _capacityController.dispose();
    _commissioningDateController.dispose();
    _manufacturingDateController.dispose();
    _erectionDateController.dispose();
    super.dispose();
  }

  void _clearAllFormFields() {
    // Common
    _bayNameController.clear();
    _descriptionController.clear();
    _landmarkController.clear();
    _contactNumberController.clear();
    _contactPersonController.clear();
    _bayNumberController.clear();
    _multiplyingFactorController.clear(); // **NEW**
    _selectedVoltageLevel = null;
    _selectedBayType = null;
    _selectedBusbarId = null;
    _availableBusbars = [];

    // Feeder
    _isGovernmentFeeder = false;
    _selectedFeederType = null;

    // Line
    _lineLengthController.clear();
    _otherConductorController.clear();
    _selectedCircuit = null;
    _selectedConductor = null;
    _erectionDateController.clear();
    _erectionDate = null;

    // Transformer
    _makeController.clear();
    _capacityController.clear();
    _selectedHvVoltage = null;
    _selectedLvVoltage = null;
    _manufacturingDateController.clear();
    _manufacturingDate = null;

    // Shared
    _commissioningDateController.clear();
    _commissioningDate = null;
  }

  Future<void> _initializeFormAndHierarchyForViewMode(
    BayDetailViewMode mode, {
    Bay? bay,
  }) async {
    setState(() {
      _isLoadingFormHierarchy = true;
      _viewMode = mode;
      _bayToEdit = bay;
    });

    _clearAllFormFields();

    if (mode == BayDetailViewMode.add ||
        (mode == BayDetailViewMode.edit && bay != null)) {
      await _fetchBusbarsInSubstation();
      if (bay != null) {
        // Populate common fields
        _bayNameController.text = bay.name;
        _descriptionController.text = bay.description ?? '';
        _landmarkController.text = bay.landmark ?? '';
        _contactNumberController.text = bay.contactNumber ?? '';
        _contactPersonController.text = bay.contactPerson ?? '';
        _bayNumberController.text = bay.bayNumber ?? '';
        _multiplyingFactorController.text =
            bay.multiplyingFactor?.toString() ?? ''; // **NEW**
        _selectedVoltageLevel = bay.voltageLevel;
        _selectedBayType = bay.bayType;

        // Populate Feeder fields
        _isGovernmentFeeder = bay.isGovernmentFeeder ?? false;
        _selectedFeederType = bay.feederType;

        // Populate Line fields
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

        // Populate Transformer fields
        if (bay.bayType == 'Transformer') {
          _selectedHvVoltage = bay.hvVoltage;
          _selectedLvVoltage = bay.lvVoltage;
          _makeController.text = bay.make ?? '';
          _capacityController.text = bay.capacity?.toString() ?? '';
          if (bay.manufacturingDate != null) {
            _manufacturingDate = bay.manufacturingDate!.toDate();
            _manufacturingDateController.text = _manufacturingDate!
                .toLocal()
                .toString()
                .split(' ')[0];
          }
        }

        // Populate shared Commissioning Date
        if (bay.commissioningDate != null) {
          _commissioningDate = bay.commissioningDate!.toDate();
          _commissioningDateController.text = _commissioningDate!
              .toLocal()
              .toString()
              .split(' ')[0];
        }
      }
    }

    setState(() => _isLoadingFormHierarchy = false);
  }

  Future<void> _fetchBusbarsInSubstation() async {
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
    }
  }

  Future<void> _saveBay() async {
    if (!_formKey.currentState!.validate()) return;

    // Validations
    if (_selectedBayType != 'Busbar' && _availableBusbars.isEmpty) {
      SnackBarUtils.showSnackBar(
        context,
        'Please create a Busbar first.',
        isError: true,
      );
      return;
    }
    if (_selectedBayType != 'Busbar' &&
        _selectedBusbarId == null &&
        _viewMode == BayDetailViewMode.add) {
      SnackBarUtils.showSnackBar(
        context,
        'Please connect this bay to a busbar.',
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

    setState(() => _isSavingBay = true);

    final firebaseUser = FirebaseAuth.instance.currentUser;
    if (firebaseUser == null) {
      if (mounted)
        SnackBarUtils.showSnackBar(
          context,
          'User not authenticated.',
          isError: true,
        );
      setState(() => _isSavingBay = false);
      return;
    }

    try {
      final bayData = {
        'name': _bayNameController.text.trim(),
        'substationId': widget.substationId,
        'voltageLevel': _selectedVoltageLevel!,
        'bayType': _selectedBayType!,
        'description': _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        'landmark': _landmarkController.text.trim().isEmpty
            ? null
            : _landmarkController.text.trim(),
        'contactNumber': _contactNumberController.text.trim().isEmpty
            ? null
            : _contactNumberController.text.trim(),
        'contactPerson': _contactPersonController.text.trim().isEmpty
            ? null
            : _contactPersonController.text.trim(),
        'bayNumber': _bayNumberController.text.trim().isEmpty
            ? null
            : _bayNumberController.text.trim(),
        'multiplyingFactor': _multiplyingFactorController.text.isNotEmpty
            ? double.tryParse(_multiplyingFactorController.text.trim())
            : null, // **NEW**
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
            ? _otherConductorController.text.trim()
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
        'commissioningDate':
            (_selectedBayType == 'Line' || _selectedBayType == 'Transformer') &&
                _commissioningDate != null
            ? Timestamp.fromDate(_commissioningDate!)
            : null,
      };

      if (_viewMode == BayDetailViewMode.edit && _bayToEdit != null) {
        await FirebaseFirestore.instance
            .collection('bays')
            .doc(_bayToEdit!.id)
            .update(bayData);
        if (mounted) {
          SnackBarUtils.showSnackBar(
            context,
            'Bay "${bayData['name']}" updated successfully!',
          );
          _initializeFormAndHierarchyForViewMode(BayDetailViewMode.list);
        }
      } else {
        final newBayRef = FirebaseFirestore.instance.collection('bays').doc();

        bayData['createdBy'] = firebaseUser.uid;
        bayData['createdAt'] = Timestamp.now();
        await newBayRef.set(bayData);

        if (_selectedBusbarId != null) {
          final newConnection = BayConnection(
            substationId: widget.substationId,
            sourceBayId: _selectedBusbarId!,
            targetBayId: newBayRef.id,
            createdBy: firebaseUser.uid,
            createdAt: Timestamp.now(),
          );
          await FirebaseFirestore.instance
              .collection('bay_connections')
              .add(newConnection.toFirestore());
        }

        // Refetch the created bay to pass to assignment function
        final createdBayDoc = await newBayRef.get();
        await _createDefaultReadingAssignment(
          Bay.fromFirestore(createdBayDoc),
          firebaseUser.uid,
        );

        if (mounted) {
          SnackBarUtils.showSnackBar(
            context,
            'Bay "${bayData['name']}" created successfully!',
          );
          _initializeFormAndHierarchyForViewMode(BayDetailViewMode.list);
        }
      }
    } catch (e) {
      if (mounted)
        SnackBarUtils.showSnackBar(
          context,
          'Failed to save bay: $e',
          isError: true,
        );
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

  Future<void> _createDefaultReadingAssignment(Bay bay, String userId) async {
    // This method can remain as is, since it defines readings, not bay properties.
    // You can add your reading field logic here.
  }

  Widget _buildBayListView() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('bays')
          .where('substationId', isEqualTo: widget.substationId)
          .orderBy('voltageLevel', descending: true)
          .snapshots(),
      builder: (context, baysSnapshot) {
        if (baysSnapshot.hasError) {
          return Center(
            child: Text(
              'Error: ${baysSnapshot.error}',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          );
        }
        if (baysSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!baysSnapshot.hasData || baysSnapshot.data!.docs.isEmpty) {
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
        final bays = baysSnapshot.data!.docs
            .map((doc) => Bay.fromFirestore(doc))
            .toList();
        final bayIds = bays.map((bay) => bay.id).toList();

        return StreamBuilder<QuerySnapshot>(
          stream: bayIds.isEmpty
              ? null
              : FirebaseFirestore.instance
                    .collection('bayReadingAssignments')
                    .where('bayId', whereIn: bayIds)
                    .snapshots(),
          builder: (context, assignmentsSnapshot) {
            final Set<String> baysWithAssignments = {};
            if (assignmentsSnapshot.hasData) {
              for (var doc in assignmentsSnapshot.data!.docs) {
                baysWithAssignments.add(doc['bayId'] as String);
              }
            }
            return _buildBayListWithAssignments(bays, baysWithAssignments);
          },
        );
      },
    );
  }

  Widget _buildBayListWithAssignments(
    List<Bay> bays,
    Set<String> baysWithAssignments,
  ) {
    final Map<String, List<Bay>> groupedBays = {};
    for (var bay in bays) {
      groupedBays.putIfAbsent(bay.voltageLevel, () => []).add(bay);
    }
    final sortedVoltageLevels = _voltageLevels
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
            initiallyExpanded: true,
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
              final hasReadingAssignment = baysWithAssignments.contains(bay.id);
              return ListTile(
                title: Text(bay.name),
                subtitle: Text('Type: ${bay.bayType}'),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => BayEquipmentManagementScreen(
                      bayId: bay.id,
                      bayName: bay.name,
                      substationId: bay.substationId,
                    ),
                  ),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (widget.currentUser.role == UserRole.admin ||
                        widget.currentUser.role == UserRole.subdivisionManager)
                      IconButton(
                        icon: const Icon(Icons.menu_book),
                        tooltip: hasReadingAssignment
                            ? 'Manage Reading Assignments'
                            : 'Assign Readings',
                        color: hasReadingAssignment
                            ? Colors.green
                            : Theme.of(context).colorScheme.tertiary,
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => BayReadingAssignmentScreen(
                              bayId: bay.id,
                              bayName: bay.name,
                              currentUser: widget.currentUser,
                            ),
                          ),
                        ),
                      ),
                    IconButton(
                      icon: const Icon(Icons.edit),
                      color: Theme.of(context).colorScheme.tertiary,
                      onPressed: () => _initializeFormAndHierarchyForViewMode(
                        BayDetailViewMode.edit,
                        bay: bay,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline),
                      color: Theme.of(context).colorScheme.error,
                      onPressed: () => _confirmDeleteBay(context, bay),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
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
            // --- Form Header ---
            Text(
              _viewMode == BayDetailViewMode.add ? 'Add New Bay' : 'Edit Bay',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 24),

            // --- Common Fields ---
            TextFormField(
              controller: _bayNameController,
              decoration: const InputDecoration(
                labelText: 'Bay Name',
                prefixIcon: Icon(Icons.grid_on),
              ),
              validator: (v) => v!.isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 16),
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
            DropdownButtonFormField<String>(
              value: _selectedBayType,
              decoration: const InputDecoration(
                labelText: 'Bay Type',
                prefixIcon: Icon(Icons.category),
              ),
              items: _bayTypes
                  .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                  .toList(),
              onChanged: (v) => setState(() => _selectedBayType = v),
              validator: (v) => v == null ? 'Required' : null,
            ),
            const SizedBox(height: 16),

            // --- Bay Number Field ---
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
            ],

            // --- Multiplying Factor Field ---
            if (_selectedBayType != null &&
                _selectedBayType != 'Busbar' &&
                _selectedBayType != 'Battery') ...[
              TextFormField(
                controller: _multiplyingFactorController,
                decoration: const InputDecoration(
                  labelText: 'Multiplying Factor',
                  prefixIcon: Icon(Icons.clear), // 'x' icon
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

            // --- Connect to Busbar ---
            if (_selectedBayType != null && _selectedBayType != 'Busbar') ...[
              DropdownButtonFormField<String>(
                value: _selectedBusbarId,
                decoration: const InputDecoration(
                  labelText: 'Connect to Busbar',
                  prefixIcon: Icon(Icons.electrical_services_sharp),
                ),
                items: _availableBusbars
                    .map(
                      (b) => DropdownMenuItem(value: b.id, child: Text(b.name)),
                    )
                    .toList(),
                onChanged: (v) => setState(() => _selectedBusbarId = v),
                validator: (v) =>
                    _viewMode == BayDetailViewMode.add && v == null
                    ? 'Required'
                    : null,
              ),
              const SizedBox(height: 16),
            ],

            // --- Transformer Fields ---
            if (_selectedBayType == 'Transformer') ...[
              DropdownButtonFormField<String>(
                value: _selectedHvVoltage,
                decoration: const InputDecoration(
                  labelText: 'HV Voltage',
                  prefixIcon: Icon(Icons.electric_bolt),
                ),
                items: _transformerVoltageLevels
                    .map((l) => DropdownMenuItem(value: l, child: Text(l)))
                    .toList(),
                onChanged: (v) => setState(() => _selectedHvVoltage = v),
                validator: (v) => v == null ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedLvVoltage,
                decoration: const InputDecoration(
                  labelText: 'LV Voltage',
                  prefixIcon: Icon(Icons.electric_bolt_outlined),
                ),
                items: _transformerVoltageLevels
                    .map((l) => DropdownMenuItem(value: l, child: Text(l)))
                    .toList(),
                onChanged: (v) => setState(() => _selectedLvVoltage = v),
                validator: (v) => v == null ? 'Required' : null,
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

            // --- Line Fields ---
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

            // --- Shared Commissioning Date Field ---
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

            // --- Feeder Fields ---
            if (_selectedBayType == 'Feeder') ...[
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
            ],

            // --- Optional Common Fields ---
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

            // --- Action Buttons ---
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
          if (_viewMode == BayDetailViewMode.list)
            IconButton(
              icon: const Icon(Icons.info_outline),
              onPressed: () {
                // Here you could show a dialog with substation details
                SnackBarUtils.showSnackBar(
                  context,
                  'Viewing details for ${widget.substationName}.',
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
            )
          : null,
    );
  }
}
