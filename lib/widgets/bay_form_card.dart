import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dropdown_search/dropdown_search.dart';
import 'package:substation_manager/equipment_icons/busbar_icon.dart';
import 'package:substation_manager/equipment_icons/line_icon.dart';
import 'package:substation_manager/equipment_icons/reactor_icon.dart';

import '../equipment_icons/transformer_icon.dart';
import '../models/bay_connection_model.dart';
import '../models/bay_model.dart';
import '../models/user_model.dart';
import '../models/hierarchy_models.dart';
import '../widgets/add_hierarchy_dialog.dart';
import '../utils/snackbar_utils.dart';
import '../equipment_icons/feeder_icon.dart';
import '../equipment_icons/ground_icon.dart';
import '../equipment_icons/ct_icon.dart';
import '../equipment_icons/isolator_icon.dart';
import '../equipment_icons/energy_meter_icon.dart';
import '../equipment_icons/capacitor_bank_icon.dart';
import '../equipment_icons/circuit_breaker_icon.dart';

enum DateType { commissioning, manufacturing, erection }

// Widget to render equipment icons based on bay type
class _EquipmentIcon extends StatelessWidget {
  final String bayType;
  final double size;
  final Color color;

  const _EquipmentIcon({
    required this.bayType,
    this.size = 24.0,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    CustomPainter painter;

    switch (bayType.toLowerCase()) {
      case 'feeder':
        painter = FeederIconPainter(
          color: color,
          strokeWidth: 2.5,
          equipmentSize: Size(size, size),
          symbolSize: Size(size, size),
        );
        break;
      case 'transformer':
        painter = TransformerIconPainter(
          color: color,
          strokeWidth: 2.5,
          equipmentSize: Size(size, size),
          symbolSize: Size(size, size),
        );
        break;
      case 'line':
        painter = LineIconPainter(
          color: color,
          strokeWidth: 2.5,
          equipmentSize: Size(size, size),
          symbolSize: Size(size, size),
        );
        break;
      case 'capacitor bank':
        painter = CapacitorBankIconPainter(
          color: color,
          strokeWidth: 2.5,
          equipmentSize: Size(size, size),
          symbolSize: Size(size, size),
        );
        break;
      case 'busbar':
        painter = BusbarIconPainter(
          color: color,
          strokeWidth: 2.5,
          equipmentSize: Size(size, size),
          symbolSize: Size(size, size),
        );
        break;
      case 'reactor':
        painter = ReactorIconPainter(
          color: color,
          strokeWidth: 2.5,
          equipmentSize: Size(size, size),
          symbolSize: Size(size, size),
        );
      case 'bus coupler':
        painter = CircuitBreakerIconPainter(
          color: color,
          strokeWidth: 2.5,
          equipmentSize: Size(size, size),
          symbolSize: Size(size, size),
        );
      case 'battery':
        return Icon(Icons.battery_full, size: size, color: color);
      default:
        // For cases where you don't have a custom painter, use a fallback icon
        return Icon(Icons.device_unknown, size: size, color: color);
    }

    // Wrap the CustomPainter in a CustomPaint widget
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: painter, size: Size(size, size)),
    );
  }
}

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

class _BayFormCardState extends State<BayFormCard>
    with SingleTickerProviderStateMixin {
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
  bool _isLoadingConnections = false;
  String? _selectedDistributionZoneId;
  String? _selectedDistributionCircleId;
  String? _selectedDistributionDivisionId;
  String? _selectedDistributionSubdivisionId;
  late AnimationController _animationController;

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
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _loadInitialDataForForm();
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
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialDataForForm() async {
    setState(() => _isLoadingConnections = true);
    try {
      await _fetchDistributionHierarchyData();
      await _initializeFormFields();
      _animationController.forward();
    } catch (e) {
      print("Error in _loadInitialDataForForm: $e");
      if (mounted) {
        SnackBarUtils.showSnackBar(
          context,
          "Error initializing bay form data: $e",
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _isLoadingConnections = false);
    }
  }

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
        if (bay.hvBusId != null &&
            widget.availableBusbars.any((b) => b.id == bay.hvBusId)) {
          _selectedHvBusId = bay.hvBusId;
        }
        if (bay.lvBusId != null &&
            widget.availableBusbars.any((b) => b.id == bay.lvBusId)) {
          _selectedLvBusId = bay.lvBusId;
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
      if (bay.bayType == 'Feeder') {
        _selectedDistributionZoneId = bay.distributionZoneId;
        _selectedDistributionCircleId = bay.distributionCircleId;
        _selectedDistributionDivisionId = bay.distributionDivisionId;
        _selectedDistributionSubdivisionId = bay.distributionSubdivisionId;
      }
      if (bay.id.isNotEmpty &&
          bay.bayType != 'Busbar' &&
          bay.bayType != 'Transformer' &&
          bay.bayType != 'Battery') {
        await _fetchAndSetSingleBusbarConnection(bay.id);
      }
    }
  }

  Future<void> _fetchAndSetSingleBusbarConnection(String bayId) async {
    setState(() => _isLoadingConnections = true);
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
          connectedBusId = null;
        }
        if (connectedBusId != null && mounted) {
          setState(() => _selectedBusbarId = connectedBusId);
        }
      } else if (mounted) {
        setState(() => _selectedBusbarId = null);
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
      if (mounted) setState(() => _isLoadingConnections = false);
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
    if (_selectedBayType == 'Line' &&
        _erectionDate != null &&
        _commissioningDate != null &&
        _erectionDate!.isAfter(_commissioningDate!)) {
      SnackBarUtils.showSnackBar(
        context,
        'Date of Erection cannot be after Date of Commissioning.',
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
          lvBusId: lvBusId,
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
          lvBusId: lvBusId,
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
    final theme = Theme.of(context);
    DateTime initial = DateTime.now();
    if (type == DateType.commissioning && _commissioningDate != null) {
      initial = _commissioningDate!;
    } else if (type == DateType.manufacturing && _manufacturingDate != null) {
      initial = _manufacturingDate!;
    } else if (type == DateType.erection && _erectionDate != null) {
      initial = _erectionDate!;
    }

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1950),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: theme.copyWith(
            colorScheme: theme.colorScheme.copyWith(
              primary: theme.colorScheme.primary,
              onPrimary: theme.colorScheme.onPrimary,
              surface: theme.colorScheme.surface,
              onSurface: theme.colorScheme.onSurface,
            ),
            dialogBackgroundColor: theme.colorScheme.surface,
          ),
          child: child!,
        );
      },
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
            setState(() => _selectedDistributionSubdivisionId = null);
          }
        },
        validator: validator,
        enabled:
            (parentId == null || (parentId != null && parentId.isNotEmpty)),
        dropdownDecoratorProps: DropDownDecoratorProps(
          dropdownSearchDecoration: InputDecoration(
            labelText: label,
            prefixIcon: Icon(
              Icons.location_on,
              color: Theme.of(context).colorScheme.primary,
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            filled: true,
            fillColor: Theme.of(context).colorScheme.primary.withOpacity(0.05),
            errorStyle: TextStyle(
              color: Theme.of(context).colorScheme.error,
              fontFamily: 'Roboto',
            ),
          ),
        ),
        popupProps: PopupProps.menu(
          showSearchBox: true,
          menuProps: MenuProps(
            borderRadius: BorderRadius.circular(12),
            elevation: 4,
            backgroundColor: Theme.of(context).colorScheme.surface,
          ),
          searchFieldProps: TextFieldProps(
            decoration: InputDecoration(
              labelText: 'Search $label',
              prefixIcon: Icon(
                Icons.search,
                color: Theme.of(context).colorScheme.primary,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: Theme.of(context).colorScheme.surface,
            ),
          ),
          showSelectedItems: true,
          emptyBuilder: (context, searchEntry) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'No $label found.',
                      style: TextStyle(
                        fontFamily: 'Roboto',
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 12),
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
                      icon: Icon(
                        Icons.add,
                        color: Theme.of(context).colorScheme.onPrimary,
                      ),
                      label: Text(
                        'Create New $label',
                        style: const TextStyle(fontFamily: 'Roboto'),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor: Theme.of(
                          context,
                        ).colorScheme.onPrimary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
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
    final theme = Theme.of(context);
    if (_isLoadingConnections) {
      return Center(
        child: Card(
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: theme.colorScheme.primary),
                const SizedBox(height: 12),
                Text(
                  'Loading bay data...',
                  style: TextStyle(
                    fontFamily: 'Roboto',
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _EquipmentIcon(
                          bayType: _selectedBayType ?? 'default',
                          color: theme.colorScheme.primary,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          widget.bayToEdit == null ? 'Add New Bay' : 'Edit Bay',
                          style: TextStyle(
                            fontFamily: 'Roboto',
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    TextFormField(
                      controller: _bayNameController,
                      decoration: InputDecoration(
                        labelText: 'Bay Name',
                        prefixIcon: Icon(
                          Icons.grid_on,
                          color: theme.colorScheme.primary,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: theme.colorScheme.primary.withOpacity(0.05),
                        errorStyle: TextStyle(
                          color: theme.colorScheme.error,
                          fontFamily: 'Roboto',
                        ),
                      ),
                      validator: (v) => v!.isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: _selectedBayType,
                      decoration: InputDecoration(
                        labelText: 'Bay Type',
                        prefixIcon: _EquipmentIcon(
                          bayType: _selectedBayType ?? 'default',
                          color: theme.colorScheme.primary,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: theme.colorScheme.primary.withOpacity(0.05),
                        errorStyle: TextStyle(
                          color: theme.colorScheme.error,
                          fontFamily: 'Roboto',
                        ),
                      ),
                      items: _bayTypes
                          .map(
                            (t) => DropdownMenuItem(
                              value: t,
                              child: Text(
                                t,
                                style: const TextStyle(fontFamily: 'Roboto'),
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (v) {
                        setState(() {
                          _selectedBayType = v;
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
                          if (v == 'Transformer' && _voltageLevels.isNotEmpty) {
                            _selectedHvVoltage = null;
                            _selectedLvVoltage = null;
                          }
                          _animationController.forward();
                        });
                      },
                      validator: (v) => v == null ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),
                    AnimatedCrossFade(
                      firstChild: const SizedBox.shrink(),
                      secondChild: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (_selectedBayType != 'Transformer' &&
                              _selectedBayType != 'Battery') ...[
                            DropdownButtonFormField<String>(
                              value: _selectedVoltageLevel,
                              decoration: InputDecoration(
                                labelText: 'Voltage Level',
                                prefixIcon: Icon(
                                  Icons.flash_on,
                                  color: theme.colorScheme.primary,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                filled: true,
                                fillColor: theme.colorScheme.primary
                                    .withOpacity(0.05),
                                errorStyle: TextStyle(
                                  color: theme.colorScheme.error,
                                  fontFamily: 'Roboto',
                                ),
                              ),
                              items: _voltageLevels
                                  .map(
                                    (l) => DropdownMenuItem(
                                      value: l,
                                      child: Text(
                                        l,
                                        style: const TextStyle(
                                          fontFamily: 'Roboto',
                                        ),
                                      ),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (v) =>
                                  setState(() => _selectedVoltageLevel = v),
                              validator: (v) => v == null ? 'Required' : null,
                            ),
                            const SizedBox(height: 16),
                          ],
                          if (_selectedBayType != 'Busbar' &&
                              _selectedBayType != 'Transformer' &&
                              _selectedBayType != 'Battery') ...[
                            DropdownButtonFormField<String>(
                              value: _selectedBusbarId,
                              decoration: InputDecoration(
                                labelText: 'Connect to Busbar',
                                prefixIcon: Icon(
                                  Icons.electrical_services_sharp,
                                  color: theme.colorScheme.primary,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                filled: true,
                                fillColor: theme.colorScheme.primary
                                    .withOpacity(0.05),
                                errorStyle: TextStyle(
                                  color: theme.colorScheme.error,
                                  fontFamily: 'Roboto',
                                ),
                              ),
                              items: widget.availableBusbars
                                  .map(
                                    (b) => DropdownMenuItem(
                                      value: b.id,
                                      child: Text(
                                        '${b.name} (${b.voltageLevel})',
                                        style: const TextStyle(
                                          fontFamily: 'Roboto',
                                        ),
                                      ),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (v) =>
                                  setState(() => _selectedBusbarId = v),
                              validator: (v) =>
                                  v == null &&
                                      widget.availableBusbars.isNotEmpty
                                  ? 'Required'
                                  : null,
                            ),
                            const SizedBox(height: 16),
                          ],
                          if (_selectedBayType == 'Transformer') ...[
                            ExpansionTile(
                              leading: _EquipmentIcon(
                                bayType: 'transformer',
                                color: theme.colorScheme.secondary,
                                size: 24,
                              ),
                              title: Text(
                                'Transformer Details',
                                style: TextStyle(
                                  fontFamily: 'Roboto',
                                  fontWeight: FontWeight.w600,
                                  color: theme.colorScheme.secondary,
                                ),
                              ),
                              children: [
                                DropdownButtonFormField<String>(
                                  value: _selectedHvVoltage,
                                  decoration: InputDecoration(
                                    labelText: 'HV Voltage',
                                    prefixIcon: Icon(
                                      Icons.electric_bolt,
                                      color: theme.colorScheme.secondary,
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    filled: true,
                                    fillColor: theme.colorScheme.secondary
                                        .withOpacity(0.05),
                                  ),
                                  items: _voltageLevels
                                      .map(
                                        (l) => DropdownMenuItem(
                                          value: l,
                                          child: Text(
                                            l,
                                            style: const TextStyle(
                                              fontFamily: 'Roboto',
                                            ),
                                          ),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: (v) {
                                    setState(() {
                                      _selectedHvVoltage = v;
                                      _selectedHvBusId = null;
                                    });
                                  },
                                  validator: (v) =>
                                      v == null ? 'Required' : null,
                                ),
                                const SizedBox(height: 12),
                                DropdownButtonFormField<String>(
                                  value: _selectedHvBusId,
                                  decoration: InputDecoration(
                                    labelText: 'Connect HV to Bus',
                                    prefixIcon: Icon(
                                      Icons.power,
                                      color: theme.colorScheme.secondary,
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    filled: true,
                                    fillColor: theme.colorScheme.secondary
                                        .withOpacity(0.05),
                                  ),
                                  items: widget.availableBusbars
                                      .where(
                                        (b) =>
                                            b.voltageLevel ==
                                            _selectedHvVoltage,
                                      )
                                      .map(
                                        (b) => DropdownMenuItem(
                                          value: b.id,
                                          child: Text(
                                            '${b.name} (${b.voltageLevel})',
                                            style: const TextStyle(
                                              fontFamily: 'Roboto',
                                            ),
                                          ),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: (v) =>
                                      setState(() => _selectedHvBusId = v),
                                  validator: (v) => v == null
                                      ? 'HV bus connection is required'
                                      : null,
                                ),
                                const SizedBox(height: 12),
                                DropdownButtonFormField<String>(
                                  value: _selectedLvVoltage,
                                  decoration: InputDecoration(
                                    labelText: 'LV Voltage',
                                    prefixIcon: Icon(
                                      Icons.electric_bolt_outlined,
                                      color: theme.colorScheme.secondary,
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    filled: true,
                                    fillColor: theme.colorScheme.secondary
                                        .withOpacity(0.05),
                                  ),
                                  items: _voltageLevels
                                      .map(
                                        (l) => DropdownMenuItem(
                                          value: l,
                                          child: Text(
                                            l,
                                            style: const TextStyle(
                                              fontFamily: 'Roboto',
                                            ),
                                          ),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: (v) {
                                    setState(() {
                                      _selectedLvVoltage = v;
                                      _selectedLvBusId = null;
                                    });
                                  },
                                  validator: (v) =>
                                      v == null ? 'Required' : null,
                                ),
                                const SizedBox(height: 12),
                                DropdownButtonFormField<String>(
                                  value: _selectedLvBusId,
                                  decoration: InputDecoration(
                                    labelText: 'Connect LV to Bus',
                                    prefixIcon: Icon(
                                      Icons.power_off,
                                      color: theme.colorScheme.secondary,
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    filled: true,
                                    fillColor: theme.colorScheme.secondary
                                        .withOpacity(0.05),
                                  ),
                                  items: widget.availableBusbars
                                      .where(
                                        (b) =>
                                            b.voltageLevel ==
                                            _selectedLvVoltage,
                                      )
                                      .map(
                                        (b) => DropdownMenuItem(
                                          value: b.id,
                                          child: Text(
                                            '${b.name} (${b.voltageLevel})',
                                            style: const TextStyle(
                                              fontFamily: 'Roboto',
                                            ),
                                          ),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: (v) =>
                                      setState(() => _selectedLvBusId = v),
                                  validator: (v) => v == null
                                      ? 'LV bus connection is required'
                                      : null,
                                ),
                                const SizedBox(height: 12),
                                TextFormField(
                                  controller: _makeController,
                                  decoration: InputDecoration(
                                    labelText: 'Make',
                                    prefixIcon: Icon(
                                      Icons.factory,
                                      color: theme.colorScheme.secondary,
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    filled: true,
                                    fillColor: theme.colorScheme.secondary
                                        .withOpacity(0.05),
                                  ),
                                  validator: (v) =>
                                      v!.isEmpty ? 'Required' : null,
                                ),
                                const SizedBox(height: 12),
                                TextFormField(
                                  controller: _capacityController,
                                  decoration: InputDecoration(
                                    labelText: 'Capacity',
                                    suffixText: 'MVA',
                                    prefixIcon: Icon(
                                      Icons.storage,
                                      color: theme.colorScheme.secondary,
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    filled: true,
                                    fillColor: theme.colorScheme.secondary
                                        .withOpacity(0.05),
                                  ),
                                  keyboardType: TextInputType.number,
                                  validator: (v) =>
                                      v!.isEmpty ? 'Required' : null,
                                ),
                                const SizedBox(height: 12),
                                TextFormField(
                                  controller: _manufacturingDateController,
                                  decoration: InputDecoration(
                                    labelText: 'Date of Manufacturing',
                                    prefixIcon: Icon(
                                      Icons.calendar_today,
                                      color: theme.colorScheme.secondary,
                                    ),
                                    suffixIcon: IconButton(
                                      icon: Icon(
                                        Icons.clear,
                                        color:
                                            theme.colorScheme.onSurfaceVariant,
                                      ),
                                      onPressed: () {
                                        setState(() {
                                          _manufacturingDateController.clear();
                                          _manufacturingDate = null;
                                        });
                                      },
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    filled: true,
                                    fillColor: theme.colorScheme.secondary
                                        .withOpacity(0.05),
                                  ),
                                  readOnly: true,
                                  onTap: () => _selectDate(
                                    context,
                                    DateType.manufacturing,
                                  ),
                                  validator: (v) =>
                                      v!.isEmpty ? 'Required' : null,
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                          ],
                          if (_selectedBayType == 'Line') ...[
                            ExpansionTile(
                              leading: _EquipmentIcon(
                                bayType: 'line',
                                color: theme.colorScheme.primary,
                                size: 24,
                              ),
                              title: Text(
                                'Line Details',
                                style: TextStyle(
                                  fontFamily: 'Roboto',
                                  fontWeight: FontWeight.w600,
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                              children: [
                                TextFormField(
                                  controller: _lineLengthController,
                                  decoration: InputDecoration(
                                    labelText: 'Line Length (km)',
                                    prefixIcon: Icon(
                                      Icons.straighten,
                                      color: theme.colorScheme.primary,
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    filled: true,
                                    fillColor: theme.colorScheme.primary
                                        .withOpacity(0.05),
                                  ),
                                  keyboardType: TextInputType.number,
                                  validator: (v) =>
                                      v!.isEmpty ? 'Required' : null,
                                ),
                                const SizedBox(height: 12),
                                DropdownButtonFormField<String>(
                                  value: _selectedCircuit,
                                  decoration: InputDecoration(
                                    labelText: 'Circuit',
                                    prefixIcon: Icon(
                                      Icons.electrical_services,
                                      color: theme.colorScheme.primary,
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    filled: true,
                                    fillColor: theme.colorScheme.primary
                                        .withOpacity(0.05),
                                  ),
                                  items: _circuitTypes
                                      .map(
                                        (t) => DropdownMenuItem(
                                          value: t,
                                          child: Text(
                                            t,
                                            style: const TextStyle(
                                              fontFamily: 'Roboto',
                                            ),
                                          ),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: (v) =>
                                      setState(() => _selectedCircuit = v),
                                  validator: (v) =>
                                      v == null ? 'Required' : null,
                                ),
                                const SizedBox(height: 12),
                                DropdownButtonFormField<String>(
                                  value: _selectedConductor,
                                  decoration: InputDecoration(
                                    labelText: 'Conductor',
                                    prefixIcon: Icon(
                                      Icons.waves,
                                      color: theme.colorScheme.primary,
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    filled: true,
                                    fillColor: theme.colorScheme.primary
                                        .withOpacity(0.05),
                                  ),
                                  items: _conductorTypes
                                      .map(
                                        (t) => DropdownMenuItem(
                                          value: t,
                                          child: Text(
                                            t,
                                            style: const TextStyle(
                                              fontFamily: 'Roboto',
                                            ),
                                          ),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: (v) =>
                                      setState(() => _selectedConductor = v),
                                  validator: (v) =>
                                      v == null ? 'Required' : null,
                                ),
                                const SizedBox(height: 12),
                                if (_selectedConductor == 'Other') ...[
                                  TextFormField(
                                    controller: _otherConductorController,
                                    decoration: InputDecoration(
                                      labelText: 'Specify Conductor Type',
                                      prefixIcon: Icon(
                                        Icons.edit,
                                        color: theme.colorScheme.primary,
                                      ),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      filled: true,
                                      fillColor: theme.colorScheme.primary
                                          .withOpacity(0.05),
                                    ),
                                    validator: (v) =>
                                        v!.isEmpty ? 'Required' : null,
                                  ),
                                  const SizedBox(height: 12),
                                ],
                                TextFormField(
                                  controller: _erectionDateController,
                                  decoration: InputDecoration(
                                    labelText: 'Date of Erection',
                                    prefixIcon: Icon(
                                      Icons.calendar_today,
                                      color: theme.colorScheme.primary,
                                    ),
                                    suffixIcon: IconButton(
                                      icon: Icon(
                                        Icons.clear,
                                        color:
                                            theme.colorScheme.onSurfaceVariant,
                                      ),
                                      onPressed: () {
                                        setState(() {
                                          _erectionDateController.clear();
                                          _erectionDate = null;
                                        });
                                      },
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    filled: true,
                                    fillColor: theme.colorScheme.primary
                                        .withOpacity(0.05),
                                  ),
                                  readOnly: true,
                                  onTap: () =>
                                      _selectDate(context, DateType.erection),
                                  validator: (v) =>
                                      v!.isEmpty ? 'Required' : null,
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                          ],
                          if (_selectedBayType == 'Line' ||
                              _selectedBayType == 'Transformer') ...[
                            TextFormField(
                              controller: _commissioningDateController,
                              decoration: InputDecoration(
                                labelText: 'Date of Commissioning',
                                prefixIcon: Icon(
                                  Icons.calendar_today,
                                  color: theme.colorScheme.primary,
                                ),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    Icons.clear,
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _commissioningDateController.clear();
                                      _commissioningDate = null;
                                    });
                                  },
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                filled: true,
                                fillColor: theme.colorScheme.primary
                                    .withOpacity(0.05),
                              ),
                              readOnly: true,
                              onTap: () =>
                                  _selectDate(context, DateType.commissioning),
                              validator: (v) => v!.isEmpty ? 'Required' : null,
                            ),
                            const SizedBox(height: 16),
                          ],
                          if (_selectedBayType == 'Feeder') ...[
                            ExpansionTile(
                              leading: _EquipmentIcon(
                                bayType: 'feeder',
                                color: Colors.purple[700]!,
                                size: 24,
                              ),
                              title: Text(
                                'Feeder Details',
                                style: TextStyle(
                                  fontFamily: 'Roboto',
                                  fontWeight: FontWeight.w600,
                                  color: Colors.purple[700],
                                ),
                              ),
                              children:
                                  _buildFeederDistributionHierarchyFields(),
                            ),
                            const SizedBox(height: 16),
                          ],
                          ExpansionTile(
                            leading: Icon(
                              Icons.info,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            title: Text(
                              'Additional Details (Optional)',
                              style: TextStyle(
                                fontFamily: 'Roboto',
                                fontWeight: FontWeight.w600,
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                            children: [
                              TextFormField(
                                controller: _descriptionController,
                                decoration: InputDecoration(
                                  labelText: 'Description',
                                  prefixIcon: Icon(
                                    Icons.description,
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  filled: true,
                                  fillColor: theme.colorScheme.primary
                                      .withOpacity(0.05),
                                ),
                                maxLines: 3,
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: _landmarkController,
                                decoration: InputDecoration(
                                  labelText: 'Landmark',
                                  prefixIcon: Icon(
                                    Icons.flag,
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  filled: true,
                                  fillColor: theme.colorScheme.primary
                                      .withOpacity(0.05),
                                ),
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: _contactNumberController,
                                decoration: InputDecoration(
                                  labelText: 'Contact Number',
                                  prefixIcon: Icon(
                                    Icons.phone,
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  filled: true,
                                  fillColor: theme.colorScheme.primary
                                      .withOpacity(0.05),
                                ),
                                keyboardType: TextInputType.phone,
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: _contactPersonController,
                                decoration: InputDecoration(
                                  labelText: 'Contact Person',
                                  prefixIcon: Icon(
                                    Icons.person,
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  filled: true,
                                  fillColor: theme.colorScheme.primary
                                      .withOpacity(0.05),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      crossFadeState: _selectedBayType != null
                          ? CrossFadeState.showSecond
                          : CrossFadeState.showFirst,
                      duration: const Duration(milliseconds: 300),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(12),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: _isSavingBay
                      ? Center(
                          child: CircularProgressIndicator(
                            color: theme.colorScheme.primary,
                          ),
                        )
                      : ElevatedButton.icon(
                          onPressed: _saveBay,
                          icon: Icon(
                            widget.bayToEdit != null ? Icons.save : Icons.add,
                            color: theme.colorScheme.onPrimary,
                          ),
                          label: Text(
                            widget.bayToEdit != null
                                ? 'Update Bay'
                                : 'Create Bay',
                            style: const TextStyle(fontFamily: 'Roboto'),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: theme.colorScheme.primary,
                            foregroundColor: theme.colorScheme.onPrimary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                ),
                const SizedBox(width: 12),
                TextButton(
                  onPressed: widget.onCancel,
                  style: TextButton.styleFrom(
                    foregroundColor: theme.colorScheme.onSurface,
                    padding: const EdgeInsets.symmetric(
                      vertical: 12,
                      horizontal: 16,
                    ),
                  ),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(fontFamily: 'Roboto'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildFeederDistributionHierarchyFields() {
    final theme = Theme.of(context);
    return [
      SwitchListTile(
        title: const Text(
          'Government Feeder',
          style: TextStyle(fontFamily: 'Roboto'),
        ),
        value: _isGovernmentFeeder,
        activeColor: Colors.purple[700],
        onChanged: (v) => setState(() {
          _isGovernmentFeeder = v;
          _selectedFeederType = null;
        }),
      ),
      const SizedBox(height: 12),
      DropdownButtonFormField<String>(
        value: _selectedFeederType,
        decoration: InputDecoration(
          labelText: 'Feeder Type',
          prefixIcon: Icon(Icons.location_city, color: Colors.purple[700]),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          filled: true,
          fillColor: Colors.purple[50],
        ),
        items:
            (_isGovernmentFeeder
                    ? _governmentFeederTypes
                    : _nonGovernmentFeederTypes)
                .map(
                  (t) => DropdownMenuItem(
                    value: t,
                    child: Text(
                      t,
                      style: const TextStyle(fontFamily: 'Roboto'),
                    ),
                  ),
                )
                .toList(),
        onChanged: (v) => setState(() => _selectedFeederType = v),
        validator: (v) => v == null ? 'Required' : null,
      ),
      const SizedBox(height: 16),
      Text(
        'Distribution Hierarchy',
        style: TextStyle(
          fontFamily: 'Roboto',
          fontWeight: FontWeight.w600,
          color: Colors.purple[700],
        ),
      ),
      const SizedBox(height: 12),
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
      const SizedBox(height: 12),
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
      const SizedBox(height: 12),
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
      const SizedBox(height: 12),
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
    ];
  }
}
