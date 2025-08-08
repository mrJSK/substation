import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dropdown_search/dropdown_search.dart';
import 'package:substation_manager/equipment_icons/busbar_icon.dart';
import 'package:substation_manager/equipment_icons/line_icon.dart';
import 'package:substation_manager/equipment_icons/reactor_icon.dart';
import 'package:substation_manager/equipment_icons/transformer_icon.dart';
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
        break;
      case 'bus coupler':
        painter = CircuitBreakerIconPainter(
          color: color,
          strokeWidth: 2.5,
          equipmentSize: Size(size, size),
          symbolSize: Size(size, size),
        );
        break;
      case 'battery':
        return Icon(Icons.battery_full, size: size, color: color);
      default:
        return Icon(Icons.device_unknown, size: size, color: color);
    }

    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: painter, size: Size(size, size)),
    );
  }
}

class BayFormScreen extends StatefulWidget {
  final Bay? bayToEdit;
  final String substationId;
  final AppUser currentUser;
  final Function() onSaveSuccess;
  final Function() onCancel;
  final List<Bay> availableBusbars;

  const BayFormScreen({
    super.key,
    this.bayToEdit,
    required this.substationId,
    required this.currentUser,
    required this.onSaveSuccess,
    required this.onCancel,
    required this.availableBusbars,
  });

  @override
  State<BayFormScreen> createState() => _BayFormScreenState();
}

class _BayFormScreenState extends State<BayFormScreen>
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
          Navigator.of(context).pop();
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
          Navigator.of(context).pop();
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
            fillColor: Theme.of(context).colorScheme.surfaceContainerLow,
            errorStyle: const TextStyle(fontFamily: 'Roboto'),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
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
                      label: const Text(
                        'Create New',
                        style: TextStyle(fontFamily: 'Roboto'),
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
    final isDarkMode = theme.brightness == Brightness.dark;

    if (_isLoadingConnections) {
      return Scaffold(
        appBar: AppBar(
          title: const Text(
            'Loading...',
            style: TextStyle(fontFamily: 'Roboto'),
          ),
          backgroundColor: theme.colorScheme.primary,
          foregroundColor: theme.colorScheme.onPrimary,
        ),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: theme.colorScheme.primary),
              const SizedBox(height: 16),
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
      );
    }

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: theme.colorScheme.onPrimary),
          onPressed: widget.onCancel,
        ),
        title: Row(
          children: [
            _EquipmentIcon(
              bayType: _selectedBayType ?? 'default',
              color: theme.colorScheme.onPrimary,
              size: 24,
            ),
            const SizedBox(width: 12),
            Text(
              widget.bayToEdit == null ? 'Add New Bay' : 'Edit Bay',
              style: TextStyle(
                fontFamily: 'Roboto',
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onPrimary,
              ),
            ),
          ],
        ),
        backgroundColor: theme.colorScheme.primary,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.save, color: theme.colorScheme.onPrimary),
            onPressed: _isSavingBay ? null : _saveBay,
            tooltip: 'Save Bay',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSection(
                title: 'Basic Information',
                icon: Icons.info,
                children: [
                  _buildTextField(
                    controller: _bayNameController,
                    label: 'Bay Name*',
                    icon: Icon(Icons.grid_on, color: theme.colorScheme.primary),
                    validator: (v) => v!.isEmpty ? 'Required' : null,
                    theme: theme,
                    isDarkMode: isDarkMode,
                  ),
                  const SizedBox(height: 16),
                  _buildDropdownField(
                    value: _selectedBayType,
                    label: 'Bay Type*',
                    icon: _EquipmentIcon(
                      bayType: _selectedBayType ?? 'default',
                      color: theme.colorScheme.primary,
                    ),
                    items: _bayTypes,
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
                        _animationController.forward();
                      });
                    },
                    validator: (v) => v == null ? 'Required' : null,
                    theme: theme,
                    isDarkMode: isDarkMode,
                  ),
                ],
              ),
              const SizedBox(height: 24),
              AnimatedCrossFade(
                firstChild: const SizedBox.shrink(),
                secondChild: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_selectedBayType != 'Transformer' &&
                        _selectedBayType != 'Battery') ...[
                      _buildSection(
                        title: 'Voltage Details',
                        icon: Icons.flash_on,
                        children: [
                          _buildDropdownField(
                            value: _selectedVoltageLevel,
                            label: 'Voltage Level*',
                            icon: Icon(
                              Icons.flash_on,
                              color: theme.colorScheme.primary,
                            ),
                            items: _voltageLevels,
                            onChanged: (v) =>
                                setState(() => _selectedVoltageLevel = v),
                            validator: (v) => v == null ? 'Required' : null,
                            theme: theme,
                            isDarkMode: isDarkMode,
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                    ],
                    if (_selectedBayType != 'Busbar' &&
                        _selectedBayType != 'Transformer' &&
                        _selectedBayType != 'Battery') ...[
                      _buildSection(
                        title: 'Busbar Connection',
                        icon: Icons.electrical_services_sharp,
                        children: [
                          _buildDropdownField(
                            value: _selectedBusbarId,
                            label: 'Connect to Busbar*',
                            icon: Icon(
                              Icons.electrical_services_sharp,
                              color: theme.colorScheme.primary,
                            ),
                            items: widget.availableBusbars
                                .map((b) => '${b.name} (${b.voltageLevel})')
                                .toList(),
                            itemValues: widget.availableBusbars
                                .map((b) => b.id)
                                .toList(),
                            onChanged: (v) =>
                                setState(() => _selectedBusbarId = v),
                            validator: (v) =>
                                v == null && widget.availableBusbars.isNotEmpty
                                ? 'Required'
                                : null,
                            theme: theme,
                            isDarkMode: isDarkMode,
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                    ],
                    if (_selectedBayType == 'Transformer') ...[
                      _buildSection(
                        title: 'Transformer Details',
                        icon: Icons.transform,
                        children: [
                          _buildDropdownField(
                            value: _selectedHvVoltage,
                            label: 'HV Voltage*',
                            icon: Icon(
                              Icons.electric_bolt,
                              color: theme.colorScheme.secondary,
                            ),
                            items: _voltageLevels,
                            onChanged: (v) {
                              setState(() {
                                _selectedHvVoltage = v;
                                _selectedHvBusId = null;
                              });
                            },
                            validator: (v) => v == null ? 'Required' : null,
                            theme: theme,
                            isDarkMode: isDarkMode,
                          ),
                          const SizedBox(height: 12),
                          _buildDropdownField(
                            value: _selectedHvBusId,
                            label: 'Connect HV to Bus*',
                            icon: Icon(
                              Icons.power,
                              color: theme.colorScheme.secondary,
                            ),
                            items: widget.availableBusbars
                                .where(
                                  (b) => b.voltageLevel == _selectedHvVoltage,
                                )
                                .map((b) => '${b.name} (${b.voltageLevel})')
                                .toList(),
                            itemValues: widget.availableBusbars
                                .where(
                                  (b) => b.voltageLevel == _selectedHvVoltage,
                                )
                                .map((b) => b.id)
                                .toList(),
                            onChanged: (v) =>
                                setState(() => _selectedHvBusId = v),
                            validator: (v) => v == null ? 'Required' : null,
                            theme: theme,
                            isDarkMode: isDarkMode,
                          ),
                          const SizedBox(height: 12),
                          _buildDropdownField(
                            value: _selectedLvVoltage,
                            label: 'LV Voltage*',
                            icon: Icon(
                              Icons.electric_bolt_outlined,
                              color: theme.colorScheme.secondary,
                            ),
                            items: _voltageLevels,
                            onChanged: (v) {
                              setState(() {
                                _selectedLvVoltage = v;
                                _selectedLvBusId = null;
                              });
                            },
                            validator: (v) => v == null ? 'Required' : null,
                            theme: theme,
                            isDarkMode: isDarkMode,
                          ),
                          const SizedBox(height: 12),
                          _buildDropdownField(
                            value: _selectedLvBusId,
                            label: 'Connect LV to Bus*',
                            icon: Icon(
                              Icons.power_off,
                              color: theme.colorScheme.secondary,
                            ),
                            items: widget.availableBusbars
                                .where(
                                  (b) => b.voltageLevel == _selectedLvVoltage,
                                )
                                .map((b) => '${b.name} (${b.voltageLevel})')
                                .toList(),
                            itemValues: widget.availableBusbars
                                .where(
                                  (b) => b.voltageLevel == _selectedLvVoltage,
                                )
                                .map((b) => b.id)
                                .toList(),
                            onChanged: (v) =>
                                setState(() => _selectedLvBusId = v),
                            validator: (v) => v == null ? 'Required' : null,
                            theme: theme,
                            isDarkMode: isDarkMode,
                          ),
                          const SizedBox(height: 12),
                          _buildTextField(
                            controller: _makeController,
                            label: 'Make*',
                            icon: Icon(
                              Icons.factory,
                              color: theme.colorScheme.secondary,
                            ),
                            validator: (v) => v!.isEmpty ? 'Required' : null,
                            theme: theme,
                            isDarkMode: isDarkMode,
                          ),
                          const SizedBox(height: 12),
                          _buildTextField(
                            controller: _capacityController,
                            label: 'Capacity*',
                            suffixText: 'MVA',
                            icon: Icon(
                              Icons.storage,
                              color: theme.colorScheme.secondary,
                            ),
                            keyboardType: TextInputType.number,
                            validator: (v) => v!.isEmpty ? 'Required' : null,
                            theme: theme,
                            isDarkMode: isDarkMode,
                          ),
                          const SizedBox(height: 12),
                          _buildTextField(
                            controller: _manufacturingDateController,
                            label: 'Date of Manufacturing*',
                            icon: Icon(
                              Icons.calendar_today,
                              color: theme.colorScheme.secondary,
                            ),
                            readOnly: true,
                            onTap: () =>
                                _selectDate(context, DateType.manufacturing),
                            suffixIcon: IconButton(
                              icon: Icon(
                                Icons.clear,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                              onPressed: () => setState(() {
                                _manufacturingDateController.clear();
                                _manufacturingDate = null;
                              }),
                            ),
                            validator: (v) => v!.isEmpty ? 'Required' : null,
                            theme: theme,
                            isDarkMode: isDarkMode,
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                    ],
                    if (_selectedBayType == 'Line') ...[
                      _buildSection(
                        title: 'Line Details',
                        icon: Icons.straighten,
                        children: [
                          _buildTextField(
                            controller: _lineLengthController,
                            label: 'Line Length (km)*',
                            icon: Icon(
                              Icons.straighten,
                              color: theme.colorScheme.primary,
                            ),
                            keyboardType: TextInputType.number,
                            validator: (v) => v!.isEmpty ? 'Required' : null,
                            theme: theme,
                            isDarkMode: isDarkMode,
                          ),
                          const SizedBox(height: 12),
                          _buildDropdownField(
                            value: _selectedCircuit,
                            label: 'Circuit*',
                            icon: Icon(
                              Icons.electrical_services,
                              color: theme.colorScheme.primary,
                            ),
                            items: _circuitTypes,
                            onChanged: (v) =>
                                setState(() => _selectedCircuit = v),
                            validator: (v) => v == null ? 'Required' : null,
                            theme: theme,
                            isDarkMode: isDarkMode,
                          ),
                          const SizedBox(height: 12),
                          _buildDropdownField(
                            value: _selectedConductor,
                            label: 'Conductor*',
                            icon: Icon(
                              Icons.waves,
                              color: theme.colorScheme.primary,
                            ),
                            items: _conductorTypes,
                            onChanged: (v) =>
                                setState(() => _selectedConductor = v),
                            validator: (v) => v == null ? 'Required' : null,
                            theme: theme,
                            isDarkMode: isDarkMode,
                          ),
                          if (_selectedConductor == 'Other') ...[
                            const SizedBox(height: 12),
                            _buildTextField(
                              controller: _otherConductorController,
                              label: 'Specify Conductor Type*',
                              icon: Icon(
                                Icons.edit,
                                color: theme.colorScheme.primary,
                              ),
                              validator: (v) => v!.isEmpty ? 'Required' : null,
                              theme: theme,
                              isDarkMode: isDarkMode,
                            ),
                          ],
                          const SizedBox(height: 12),
                          _buildTextField(
                            controller: _erectionDateController,
                            label: 'Date of Erection*',
                            icon: Icon(
                              Icons.calendar_today,
                              color: theme.colorScheme.primary,
                            ),
                            readOnly: true,
                            onTap: () =>
                                _selectDate(context, DateType.erection),
                            suffixIcon: IconButton(
                              icon: Icon(
                                Icons.clear,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                              onPressed: () => setState(() {
                                _erectionDateController.clear();
                                _erectionDate = null;
                              }),
                            ),
                            validator: (v) => v!.isEmpty ? 'Required' : null,
                            theme: theme,
                            isDarkMode: isDarkMode,
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                    ],
                    if (_selectedBayType == 'Line' ||
                        _selectedBayType == 'Transformer') ...[
                      _buildSection(
                        title: 'Commissioning Details',
                        icon: Icons.calendar_today,
                        children: [
                          _buildTextField(
                            controller: _commissioningDateController,
                            label: 'Date of Commissioning*',
                            icon: Icon(
                              Icons.calendar_today,
                              color: theme.colorScheme.primary,
                            ),
                            readOnly: true,
                            onTap: () =>
                                _selectDate(context, DateType.commissioning),
                            suffixIcon: IconButton(
                              icon: Icon(
                                Icons.clear,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                              onPressed: () => setState(() {
                                _commissioningDateController.clear();
                                _commissioningDate = null;
                              }),
                            ),
                            validator: (v) => v!.isEmpty ? 'Required' : null,
                            theme: theme,
                            isDarkMode: isDarkMode,
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                    ],
                    if (_selectedBayType == 'Feeder') ...[
                      _buildSection(
                        title: 'Feeder Details',
                        icon: Icons.location_city,
                        iconColor: Colors.purple[700]!,
                        children: _buildFeederDistributionHierarchyFields(),
                      ),
                      const SizedBox(height: 24),
                    ],
                    _buildSection(
                      title: 'Additional Details (Optional)',
                      icon: Icons.info_outline,
                      children: [
                        _buildTextField(
                          controller: _descriptionController,
                          label: 'Description',
                          icon: Icon(
                            Icons.description,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          maxLines: 3,
                          theme: theme,
                          isDarkMode: isDarkMode,
                        ),
                        const SizedBox(height: 12),
                        _buildTextField(
                          controller: _landmarkController,
                          label: 'Landmark',
                          icon: Icon(
                            Icons.flag,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          theme: theme,
                          isDarkMode: isDarkMode,
                        ),
                        const SizedBox(height: 12),
                        _buildTextField(
                          controller: _contactNumberController,
                          label: 'Contact Number',
                          icon: Icon(
                            Icons.phone,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          keyboardType: TextInputType.phone,
                          theme: theme,
                          isDarkMode: isDarkMode,
                        ),
                        const SizedBox(height: 12),
                        _buildTextField(
                          controller: _contactPersonController,
                          label: 'Contact Person',
                          icon: Icon(
                            Icons.person,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          theme: theme,
                          isDarkMode: isDarkMode,
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
              const SizedBox(height: 24),
              Row(
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
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              textStyle: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                  ),
                  const SizedBox(width: 12),
                  TextButton(
                    onPressed: widget.onCancel,
                    style: TextButton.styleFrom(
                      foregroundColor: theme.colorScheme.onSurface,
                      padding: const EdgeInsets.symmetric(
                        vertical: 16,
                        horizontal: 16,
                      ),
                      textStyle: const TextStyle(
                        fontFamily: 'Roboto',
                        fontSize: 16,
                      ),
                    ),
                    child: const Text('Cancel'),
                  ),
                ],
              ),
            ],
          ),
        ),
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
      _buildDropdownField(
        value: _selectedFeederType,
        label: 'Feeder Type*',
        icon: Icon(Icons.location_city, color: Colors.purple[700]),
        items: _isGovernmentFeeder
            ? _governmentFeederTypes
            : _nonGovernmentFeederTypes,
        onChanged: (v) => setState(() => _selectedFeederType = v),
        validator: (v) => v == null ? 'Required' : null,
        theme: theme,
        isDarkMode: Theme.of(context).brightness == Brightness.dark,
        fillColor: Colors.purple[50],
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
        label: 'Distribution Zone*',
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
        label: 'Distribution Circle*',
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
        label: 'Distribution Division*',
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
        label: 'Distribution Subdivision*',
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

  Widget _buildSection({
    required String title,
    required IconData icon,
    Color? iconColor,
    required List<Widget> children,
  }) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: iconColor ?? theme.colorScheme.primary, size: 24),
            const SizedBox(width: 12),
            Text(
              title,
              style: TextStyle(
                fontFamily: 'Roboto',
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainer,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: theme.colorScheme.outlineVariant,
              width: 1,
            ),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    Icon? icon,
    String? suffixText,
    String? Function(String?)? validator,
    int maxLines = 1,
    TextInputType? keyboardType,
    bool readOnly = false,
    VoidCallback? onTap,
    Widget? suffixIcon,
    required ThemeData theme,
    required bool isDarkMode,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      validator: validator,
      keyboardType: keyboardType,
      readOnly: readOnly,
      onTap: onTap,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: icon,
        suffixText: suffixText,
        suffixIcon: suffixIcon,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: isDarkMode ? Colors.grey[700]! : Colors.grey[300]!,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: theme.colorScheme.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: theme.colorScheme.error, width: 2),
        ),
        filled: true,
        fillColor: theme.colorScheme.surfaceContainerLow,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
        labelStyle: TextStyle(
          fontFamily: 'Roboto',
          color: theme.colorScheme.onSurface,
        ),
        errorStyle: TextStyle(
          fontFamily: 'Roboto',
          color: theme.colorScheme.error,
        ),
      ),
    );
  }

  Widget _buildDropdownField({
    required String? value,
    required String label,
    required Widget icon,
    required List<String> items,
    List<String>? itemValues,
    required Function(String?) onChanged,
    String? Function(String?)? validator,
    required ThemeData theme,
    required bool isDarkMode,
    Color? fillColor,
  }) {
    return DropdownButtonFormField<String>(
      value: value,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: icon,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: isDarkMode ? Colors.grey[700]! : Colors.grey[300]!,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: theme.colorScheme.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: theme.colorScheme.error, width: 2),
        ),
        filled: true,
        fillColor: fillColor ?? theme.colorScheme.surfaceContainerLow,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
        labelStyle: TextStyle(
          fontFamily: 'Roboto',
          color: theme.colorScheme.onSurface,
        ),
        errorStyle: TextStyle(
          fontFamily: 'Roboto',
          color: theme.colorScheme.error,
        ),
      ),
      items: items
          .asMap()
          .entries
          .map(
            (entry) => DropdownMenuItem(
              value: itemValues != null ? itemValues[entry.key] : entry.value,
              child: Text(
                entry.value,
                style: const TextStyle(fontFamily: 'Roboto'),
              ),
            ),
          )
          .toList(),
      onChanged: _isSavingBay ? null : onChanged,
      validator: validator,
      dropdownColor: isDarkMode ? theme.colorScheme.surface : Colors.white,
    );
  }
}
