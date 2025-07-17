// lib/widgets/bay_form_card.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dropdown_search/dropdown_search.dart';

import '../models/bay_connection_model.dart';
import '../models/bay_model.dart';
import '../models/user_model.dart';
// Corrected imports for hierarchy models and dialog
import '../models/hierarchy_models.dart';
import '../widgets/add_hierarchy_dialog.dart';
import '../utils/snackbar_utils.dart';

enum DateType { commissioning, manufacturing, erection }

class BayFormCard extends StatefulWidget {
  final Bay? bayToEdit;
  final String substationId;
  final AppUser currentUser;
  final Function() onSaveSuccess;
  final Function() onCancel;
  final List<Bay>
  availableBusbars; // Passed from parent (SubstationDetailScreen)
  // Removed the onFormLoaded callback as it's no longer needed for parent's loading state.

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
  String? _selectedBayType; // Initialize as null to force selection
  bool _isGovernmentFeeder = false;
  String? _selectedFeederType;
  String?
  _selectedBusbarId; // This holds the ID of the connected busbar for non-transformer bays
  bool _isSavingBay = false;
  bool _isLoadingConnections = false; // Loading state for connections

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
    print("BayFormCard: initState entered");
    _loadInitialDataForForm(); // Call new method to load all data
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

  // NEW method to load all initial data needed for the form
  Future<void> _loadInitialDataForForm() async {
    print("BayFormCard: _loadInitialDataForForm started");
    setState(() {
      _isLoadingConnections = true; // Set loading state for connections
    });
    try {
      // Add try-catch around the whole loading process
      print("BayFormCard: Calling _fetchDistributionHierarchyData");
      await _fetchDistributionHierarchyData();
      print("BayFormCard: _fetchDistributionHierarchyData completed");
      // Initialize form fields after hierarchy data is potentially loaded
      print("BayFormCard: Calling _initializeFormFields");
      await _initializeFormFields(); // AWAIT this call
      print("BayFormCard: _initializeFormFields completed");
    } catch (e) {
      print("BayFormCard: Error in _loadInitialDataForForm: $e");
      if (mounted) {
        SnackBarUtils.showSnackBar(
          context,
          "Error initializing bay form data: $e",
          isError: true,
        );
      }
    } finally {
      print("BayFormCard: _loadInitialDataForForm finally block entered");
      if (mounted) {
        setState(() {
          _isLoadingConnections = false; // Clear loading state
        });
      }
      // The onFormLoaded callback is no longer needed here as the parent
      // SubstationDetailScreen no longer manages BayFormCard's loading state.
      print(
        "BayFormCard: _loadInitialDataForForm completed (onFormLoaded removed)",
      );
    }
  }

  // Make this method async as it now contains an await call
  Future<void> _initializeFormFields() async {
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
        // Only set if the HV bus ID exists in the available busbars
        if (bay.hvBusId != null &&
            widget.availableBusbars.any((b) => b.id == bay.hvBusId)) {
          _selectedHvBusId = bay.hvBusId;
        } else {
          _selectedHvBusId = null; // Clear if not found
        }
        // Only set if the LV bus ID exists in the available busbars
        if (bay.lvBusId != null &&
            widget.availableBusbars.any((b) => b.id == bay.lvBusId)) {
          _selectedLvBusId = bay.lvBusId;
        } else {
          _selectedLvBusId = null; // Clear if not found
        }
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

      // NEW FIX: For non-transformer, non-busbar, non-battery bays, fetch and set their single connected busbar
      if (bay.id.isNotEmpty &&
          bay.bayType != 'Busbar' &&
          bay.bayType != 'Transformer' &&
          bay.bayType != 'Battery') {
        await _fetchAndSetSingleBusbarConnection(bay.id); // AWAIT THIS CALL
      }
    }
  }

  // NEW: Method to fetch and set the single busbar connection for non-transformer bays
  Future<void> _fetchAndSetSingleBusbarConnection(String bayId) async {
    setState(() {
      _isLoadingConnections = true; // Indicate loading for this specific fetch
    });
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
        final String? connectedBusId;

        // Determine which side is the busbar from the connection and if it's in the available list
        if (connectionDoc.data().containsKey('targetBayId') &&
            widget.availableBusbars.any(
              (b) => b.id == connectionDoc['targetBayId'],
            )) {
          connectedBusId = connectionDoc['targetBayId'] as String;
        } else if (connectionDoc.data().containsKey('sourceBayId') &&
            widget.availableBusbars.any(
              (b) => b.id == connectionDoc['sourceBayId'],
            )) {
          connectedBusId = connectionDoc['sourceBayId'] as String;
        } else {
          connectedBusId =
              null; // Busbar might not be in available list or connection is invalid
        }

        if (connectedBusId != null) {
          if (mounted) {
            setState(() {
              _selectedBusbarId = connectedBusId;
            });
          }
        }
      } else {
        // If no connection found, ensure _selectedBusbarId is null
        if (mounted) {
          setState(() {
            _selectedBusbarId = null;
          });
        }
      }
    } catch (e) {
      print("Error fetching single busbar connection: $e");
      if (mounted) {
        SnackBarUtils.showSnackBar(
          context,
          "Error loading bay connections: $e",
          isError: true,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingConnections = false; // Clear loading state
        });
      }
    }
  }

  Future<void> _fetchDistributionHierarchyData() async {
    _distributionZonesMap.clear();
    _distributionCirclesMap.clear();
    _distributionDivisionsMap.clear();
    _distributionSubdivisionsMap.clear();

    try {
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
    } catch (e) {
      print("Error fetching distribution hierarchy data: $e");
      if (mounted) {
        SnackBarUtils.showSnackBar(
          context,
          "Error loading distribution hierarchy data: $e",
          isError: true,
        );
      }
    } finally {
      // Ensure UI update even if there was an error, to clear loading state.
      if (mounted) setState(() {});
    }
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
    // Re-added check for non-transformer/non-busbar bays if _selectedBusbarId is null
    if (_selectedBayType != 'Busbar' &&
        _selectedBayType != 'Transformer' &&
        _selectedBayType != 'Battery' &&
        _selectedBusbarId == null) {
      SnackBarUtils.showSnackBar(
        context,
        'Please connect to a Busbar for this bay type.',
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

    // NEW VALIDATION: Date of Erection cannot be after Date of Commissioning for Line bays.
    if (_selectedBayType == 'Line') {
      if (_erectionDate != null && _commissioningDate != null) {
        if (_erectionDate!.isAfter(_commissioningDate!)) {
          SnackBarUtils.showSnackBar(
            context,
            'Date of Erection cannot be after Date of Commissioning.',
            isError: true,
          );
          return;
        }
      }
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
      final String? bayName = _bayNameController.text.trim();
      final String? description = _descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text.trim();
      final String? landmark = _landmarkController.text.trim().isEmpty
          ? null
          : _landmarkController.text.trim();
      final String? contactNumber = _contactNumberController.text.trim().isEmpty
          ? null
          : _contactNumberController.text.trim();
      final String? contactPerson = _contactPersonController.text.trim().isEmpty
          ? null
          : _contactPersonController.text.trim();
      final String? bayNumber = _bayNumberController.text.trim().isEmpty
          ? null
          : _bayNumberController.text.trim();
      final double? multiplyingFactor =
          _multiplyingFactorController.text.isNotEmpty
          ? double.tryParse(_multiplyingFactorController.text.trim())
          : null;
      final bool? isGovernmentFeeder = _selectedBayType == 'Feeder'
          ? _isGovernmentFeeder
          : null;
      final String? feederType = _selectedBayType == 'Feeder'
          ? _selectedFeederType
          : null;
      final double? lineLength = _selectedBayType == 'Line'
          ? double.tryParse(_lineLengthController.text.trim())
          : null;
      final String? circuitType = _selectedBayType == 'Line'
          ? _selectedCircuit
          : null;
      final String? conductorType = _selectedBayType == 'Line'
          ? _selectedConductor
          : null;
      final String? conductorDetail = _selectedConductor == 'Other'
          ? (_otherConductorController.text.trim().isEmpty
                ? null
                : _otherConductorController.text.trim())
          : null;
      final Timestamp? erectionDate =
          _selectedBayType == 'Line' && _erectionDate != null
          ? Timestamp.fromDate(_erectionDate!)
          : null;
      final String? hvVoltage = _selectedBayType == 'Transformer'
          ? _selectedHvVoltage
          : null;
      final String? lvVoltage = _selectedBayType == 'Transformer'
          ? _selectedLvVoltage
          : null;
      final String? make =
          _selectedBayType == 'Transformer' && _makeController.text.isNotEmpty
          ? _makeController.text.trim()
          : null;
      final double? capacity =
          _selectedBayType == 'Transformer' &&
              _capacityController.text.isNotEmpty
          ? double.tryParse(_capacityController.text.trim())
          : null;
      final Timestamp? manufacturingDate =
          _selectedBayType == 'Transformer' && _manufacturingDate != null
          ? Timestamp.fromDate(_manufacturingDate!)
          : null;
      final String? hvBusId = _selectedBayType == 'Transformer'
          ? _selectedHvBusId
          : null;
      final String? lvBusId = _selectedBayType == 'Transformer'
          ? _selectedLvBusId
          : null;
      final Timestamp? commissioningDateVal =
          (_selectedBayType == 'Line' || _selectedBayType == 'Transformer') &&
              _commissioningDate != null
          ? Timestamp.fromDate(_commissioningDate!)
          : null;
      final String? distributionZoneId = _selectedBayType == 'Feeder'
          ? _selectedDistributionZoneId
          : null;
      final String? distributionCircleId = _selectedBayType == 'Feeder'
          ? _selectedDistributionCircleId
          : null;
      final String? distributionDivisionId = _selectedBayType == 'Feeder'
          ? _selectedDistributionDivisionId
          : null;
      final String? distributionSubdivisionId = _selectedBayType == 'Feeder'
          ? _selectedDistributionSubdivisionId
          : null;

      if (widget.bayToEdit != null) {
        final Bay existingBay = widget.bayToEdit!;

        final updatedBay = existingBay.copyWith(
          name: bayName,
          voltageLevel: _selectedBayType == 'Transformer'
              ? hvVoltage
              : _selectedVoltageLevel,
          bayType: _selectedBayType!,
          description: description,
          landmark: landmark,
          contactNumber: contactNumber,
          contactPerson: contactPerson,
          isGovernmentFeeder: isGovernmentFeeder,
          feederType: feederType,
          multiplyingFactor: multiplyingFactor,
          bayNumber: bayNumber,
          lineLength: lineLength,
          circuitType: circuitType,
          conductorType: conductorType,
          conductorDetail: conductorDetail,
          erectionDate: erectionDate,
          hvVoltage: hvVoltage,
          lvVoltage: lvVoltage,
          make: make,
          capacity: capacity,
          manufacturingDate: manufacturingDate,
          hvBusId: hvBusId,
          lvBusId: lvBusId, // Corrected from lvLvBusId
          commissioningDate: commissioningDateVal,
          distributionZoneId: distributionZoneId,
          distributionCircleId: distributionCircleId,
          distributionDivisionId: distributionDivisionId,
          distributionSubdivisionId: distributionSubdivisionId,
        );

        await FirebaseFirestore.instance
            .collection('bays')
            .doc(updatedBay.id)
            .update(updatedBay.toFirestore());

        final batch = FirebaseFirestore.instance.batch();

        final existingConnectionsSnapshot = await FirebaseFirestore.instance
            .collection('bay_connections')
            .where('substationId', isEqualTo: widget.substationId)
            .where(
              Filter.or(
                Filter('sourceBayId', isEqualTo: existingBay.id),
                Filter('targetBayId', isEqualTo: existingBay.id),
              ),
            )
            .get();
        for (var doc in existingConnectionsSnapshot.docs) {
          batch.delete(doc.reference);
        }
        await batch.commit();

        if (_selectedBayType == 'Transformer') {
          if (_selectedHvBusId != null) {
            await FirebaseFirestore.instance
                .collection('bay_connections')
                .add(
                  BayConnection(
                    substationId: widget.substationId,
                    sourceBayId: _selectedHvBusId!,
                    targetBayId: existingBay.id,
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
                    sourceBayId: existingBay.id,
                    targetBayId: _selectedLvBusId!,
                    createdBy: firebaseUser.uid,
                    createdAt: Timestamp.now(),
                  ).toFirestore(),
                );
          }
        } else if (_selectedBayType != 'Busbar' &&
            _selectedBayType != 'Battery' &&
            _selectedBusbarId != null) {
          await FirebaseFirestore.instance
              .collection('bay_connections')
              .add(
                BayConnection(
                  substationId: widget.substationId,
                  sourceBayId: _selectedBusbarId!,
                  targetBayId: existingBay.id,
                  createdBy: firebaseUser.uid,
                  createdAt: Timestamp.now(),
                ).toFirestore(),
              );
        }

        if (mounted) {
          SnackBarUtils.showSnackBar(context, 'Bay updated successfully!');
          widget.onSaveSuccess();
        }
      } else {
        final newBayRef = FirebaseFirestore.instance.collection('bays').doc();

        final newBay = Bay(
          id: newBayRef.id,
          name: bayName!,
          substationId: widget.substationId,
          voltageLevel: _selectedBayType == 'Transformer'
              ? hvVoltage!
              : _selectedVoltageLevel!,
          bayType: _selectedBayType!,
          createdBy: firebaseUser.uid,
          createdAt: Timestamp.now(),
          description: description,
          landmark: landmark,
          contactNumber: contactNumber,
          contactPerson: contactPerson,
          isGovernmentFeeder: isGovernmentFeeder,
          feederType: feederType,
          multiplyingFactor: multiplyingFactor,
          bayNumber: bayNumber,
          lineLength: lineLength,
          circuitType: circuitType,
          conductorType: conductorType,
          conductorDetail: conductorDetail,
          erectionDate: erectionDate,
          hvVoltage: hvVoltage,
          lvVoltage: lvVoltage,
          make: make,
          capacity: capacity,
          manufacturingDate: manufacturingDate,
          hvBusId: hvBusId,
          lvBusId: lvBusId, // Corrected from lvLvBusId
          commissioningDate: commissioningDateVal,
          xPosition: null,
          yPosition: null,
          distributionZoneId: distributionZoneId,
          distributionCircleId: distributionCircleId,
          distributionDivisionId: distributionDivisionId,
          distributionSubdivisionId: distributionSubdivisionId,
        );

        await newBayRef.set(newBay.toFirestore());

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
        } else if (_selectedBayType != 'Busbar' &&
            _selectedBayType != 'Battery' &&
            _selectedBusbarId != null) {
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

        await _createDefaultReadingAssignment(newBay, firebaseUser.uid);
        if (mounted) {
          SnackBarUtils.showSnackBar(context, 'Bay created successfully!');
          widget.onSaveSuccess();
        }
      }
    } catch (e) {
      print('Error saving bay: $e');
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
    DateTime lastSelectableDate =
        DateTime.now(); // Initialize to current date (today)

    if (type == DateType.commissioning && _commissioningDate != null) {
      initial = _commissioningDate!;
    } else if (type == DateType.manufacturing && _manufacturingDate != null) {
      initial = _manufacturingDate!;
    } else if (type == DateType.erection && _erectionDate != null) {
      initial = _erectionDate!;
    }

    // All date pickers will now only allow dates up to today.
    // The previous logic for manufacturing allowing future dates has been removed
    // to comply with the new requirement to disable future dates for it as well.
    // If you need to revert manufacturing to allow future dates, you would re-add:
    // if (type == DateType.manufacturing) {
    //   lastSelectableDate = DateTime.now().add(const Duration(days: 365 * 5));
    // }

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1950),
      lastDate:
          lastSelectableDate, // Use the dynamically set lastSelectableDate (which is now always today)
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
    required String addHierarchyType,
  }) {
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
        compareFn: (item1, item2) => item1.id == item2.id,
        asyncItems: (String filter) async {
          if (parentId != null &&
              parentIdFieldName.isNotEmpty &&
              parentId.isEmpty) {
            return [];
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
                          onChanged(newCreatedItem.id);
                          setState(() {});
                          if (mounted) Navigator.pop(context);
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
    // Show a loading indicator if initial data is still being fetched by BayFormCard
    if (_isLoadingConnections) {
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
            DropdownButtonFormField<String>(
              value: _selectedBayType,
              decoration: const InputDecoration(
                labelText: 'Bay Type',
                prefixIcon: Icon(Icons.category),
              ),
              items: _bayTypes
                  .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                  .toList(),
              onChanged: (v) {
                setState(() {
                  _selectedBayType = v;
                  // Reset all conditional fields when bay type changes
                  _selectedVoltageLevel = null;
                  _selectedBusbarId = null;
                  _selectedHvVoltage = null;
                  _selectedLvVoltage = null;
                  _selectedHvBusId = null;
                  _selectedLvBusId = null;
                  _makeController.clear();
                  _capacityController.clear();
                  _manufacturingDateController.clear();
                  _manufacturingDate = null;
                  _lineLengthController.clear();
                  _selectedCircuit = null;
                  _selectedConductor = null;
                  _otherConductorController.clear();
                  _erectionDateController.clear();
                  _erectionDate = null;
                  _commissioningDateController.clear();
                  _commissioningDate = null;
                  _isGovernmentFeeder = false;
                  _selectedFeederType = null;
                  _selectedDistributionZoneId = null;
                  _selectedDistributionCircleId = null;
                  _selectedDistributionDivisionId = null;
                  _selectedDistributionSubdivisionId = null;

                  // If Transformer is selected, initialize voltages to prevent immediate error
                  if (v == 'Transformer') {
                    if (_voltageLevels.isNotEmpty) {
                      _selectedHvVoltage = null;
                      _selectedLvVoltage = null;
                    }
                  }
                });
              },
              validator: (v) => v == null ? 'Required' : null,
            ),
            const SizedBox(height: 16),

            // START OF NEW CONDITIONAL BLOCK: Only show other fields if a Bay Type is selected
            if (_selectedBayType != null) ...[
              // Common fields that depend on voltage level, unless it's a transformer or battery
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

              // Connection to Busbar for non-Busbar, non-Transformer, non-Battery types
              if (_selectedBayType != 'Busbar' &&
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
                        // MODIFIED LINE: Include voltageLevel in the display text
                        (b) => DropdownMenuItem(
                          value: b.id,
                          child: Text('${b.name} (${b.voltageLevel})'),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setState(() => _selectedBusbarId = v),
                  validator: (v) =>
                      v == null && widget.availableBusbars.isNotEmpty
                      ? 'Required'
                      : null,
                ),
                const SizedBox(height: 16),
              ],

              // Transformer specific fields
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
                  onChanged: (v) {
                    setState(() {
                      _selectedHvVoltage = v;
                      _selectedHvBusId =
                          null; // Reset bus selection if voltage changes
                    });
                  },
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
                  onChanged: (v) {
                    setState(() {
                      _selectedLvVoltage = v;
                      _selectedLvBusId =
                          null; // Reset bus selection if voltage changes
                    });
                  },
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

              // Line specific fields
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

              // Commissioning Date for Line or Transformer
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

              // Feeder specific fields
              if (_selectedBayType == 'Feeder')
                ..._buildFeederDistributionHierarchyFields(),

              // General optional fields
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
            ], // END OF NEW CONDITIONAL BLOCK
            // Buttons should always be visible
            Center(
              child: _isSavingBay || _isLoadingConnections
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
