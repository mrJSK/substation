// lib/screens/substation_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'dart:math';

import '../models/bay_model.dart';
import '../models/user_model.dart';
import '../models/hierarchy_models.dart';
import '../models/app_state_data.dart';
import '../utils/snackbar_utils.dart';
import '../screens/bay_equipment_management_screen.dart';
import '../screens/bay_reading_assignment_screen.dart';
import '../models/bay_connection_model.dart';
import '../models/reading_models.dart';

import '../equipment_icons/transformer_icon.dart';

enum BayDetailViewMode { list, add, edit }

enum DateType { commissioning, manufacturing, erection }

class BayRenderData {
  final Bay bay;
  final Rect rect;
  final Offset center;
  final Offset topCenter;
  final Offset bottomCenter;
  final Offset leftCenter;
  final Offset rightCenter;

  BayRenderData({
    required this.bay,
    required this.rect,
    required this.center,
    required this.topCenter,
    required this.bottomCenter,
    required this.leftCenter,
    required this.rightCenter,
  });
}

class SingleLineDiagramPainter extends CustomPainter {
  final List<BayRenderData> bayRenderDataList;
  final List<BayConnection> bayConnections;
  final Map<String, Bay> baysMap;
  final BayRenderData Function() createDummyBayRenderData;
  final Map<String, Rect> busbarRects;
  final Map<String, Map<String, Offset>> busbarConnectionPoints;

  SingleLineDiagramPainter({
    required this.bayRenderDataList,
    required this.bayConnections,
    required this.baysMap,
    required this.createDummyBayRenderData,
    required this.busbarRects,
    required this.busbarConnectionPoints,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = Colors.black87
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final busbarPaint = Paint()
      ..color = Colors.black
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke;

    final connectionDotPaint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.fill;

    // 1. Draw Busbars
    for (var renderData in bayRenderDataList) {
      if (renderData.bay.bayType == 'Busbar') {
        final busbarRect = busbarRects[renderData.bay.id] ?? renderData.rect;
        canvas.drawLine(
          busbarRect.centerLeft,
          busbarRect.centerRight,
          busbarPaint,
        );
        _drawText(
          canvas,
          '${renderData.bay.voltageLevel} ${renderData.bay.name}',
          Offset(busbarRect.left - 8, busbarRect.center.dy),
          textAlign: TextAlign.right,
        );
      }
    }

    // 2. Draw Connections
    for (var connection in bayConnections) {
      final sourceBay = baysMap[connection.sourceBayId];
      final targetBay = baysMap[connection.targetBayId];
      if (sourceBay == null || targetBay == null) continue;

      final sourceRenderData = bayRenderDataList.firstWhere(
        (d) => d.bay.id == sourceBay.id,
        orElse: createDummyBayRenderData,
      );
      final targetRenderData = bayRenderDataList.firstWhere(
        (d) => d.bay.id == targetBay.id,
        orElse: createDummyBayRenderData,
      );
      if (sourceRenderData.bay.id == 'dummy' ||
          targetRenderData.bay.id == 'dummy')
        continue;

      Offset startPoint;
      Offset endPoint;

      // Handle the special case of a Line connecting TO a busbar
      if (sourceBay.bayType == 'Busbar' && targetBay.bayType == 'Line') {
        final busConnectionPoint =
            busbarConnectionPoints[sourceBay.id]?[targetBay.id] ??
            sourceRenderData.center;

        // The line starts from above and the arrow points to the bus.
        // p1 = line start (above bus), p2 = arrow tip (on bus)
        _drawConnectionLine(
          canvas,
          targetRenderData.topCenter, // The start of the line from above
          busConnectionPoint, // The end of the line on the bus
          linePaint,
          connectionDotPaint,
          sourceBay.bayType,
          targetBay.bayType,
        );
        // We've drawn this connection, so skip to the next one.
        continue;
      }

      // --- Standard connection logic for everything else ---
      if (sourceBay.bayType == 'Busbar') {
        startPoint =
            busbarConnectionPoints[sourceBay.id]?[targetBay.id] ??
            sourceRenderData.center;

        // The 'Line' case is handled above, so this applies to Feeder and Transformer
        if (targetBay.bayType == 'Feeder') {
          endPoint = targetRenderData.bottomCenter;
        } else {
          // For transformers connected to a bus
          endPoint = targetRenderData.topCenter;
        }
      } else if (targetBay.bayType == 'Busbar') {
        startPoint = sourceRenderData.bottomCenter;
        endPoint =
            busbarConnectionPoints[targetBay.id]?[sourceBay.id] ??
            targetRenderData.center;
      } else {
        // Connection between non-busbar elements (e.g., TF to TF)
        startPoint = sourceRenderData.bottomCenter;
        endPoint = targetRenderData.topCenter;
      }

      _drawConnectionLine(
        canvas,
        startPoint,
        endPoint,
        linePaint,
        connectionDotPaint,
        sourceBay.bayType,
        targetBay.bayType,
      );
    }

    // 3. Draw Symbols and Labels
    for (var renderData in bayRenderDataList) {
      final bay = renderData.bay;
      final rect = renderData.rect;

      if (bay.bayType == 'Transformer') {
        final painter = TransformerIconPainter(
          color: Colors.blue,
          equipmentSize: rect.size,
          symbolSize: rect.size,
        );
        canvas.save();
        canvas.translate(rect.topLeft.dx, rect.topLeft.dy);
        painter.paint(canvas, rect.size);
        canvas.restore();

        final label = '${bay.capacity?.round() ?? ''}MVA TF\n${bay.name}';
        _drawText(canvas, label, rect.bottomCenter, offsetY: 4);
      } else if (bay.bayType == 'Line') {
        // The rect is now above the bus. Draw text above the start of the line.
        _drawText(canvas, bay.name, rect.topCenter, offsetY: -12, isBold: true);
      } else if (bay.bayType == 'Feeder') {
        // Draw text BELOW the arrow. The rect's bottomCenter is where the arrow tip is.
        _drawText(
          canvas,
          bay.name,
          rect.bottomCenter,
          offsetY: 4,
          isBold: true,
        );
      }
    }
  }

  void _drawArrowhead(Canvas canvas, Offset p1, Offset p2, Paint paint) {
    const double arrowSize = 6.0;
    final double angle = atan2(p2.dy - p1.dy, p2.dx - p1.dx);
    final Path path = Path();
    path.moveTo(p2.dx, p2.dy);
    path.lineTo(
      p2.dx - arrowSize * cos(angle - pi / 6),
      p2.dy - arrowSize * sin(angle - pi / 6),
    );
    path.lineTo(
      p2.dx - arrowSize * cos(angle + pi / 6),
      p2.dy - arrowSize * sin(angle + pi / 6),
    );
    path.close();
    canvas.drawPath(
      path,
      Paint()
        ..color = paint.color
        ..style = PaintingStyle.fill,
    );
  }

  void _drawConnectionLine(
    Canvas canvas,
    Offset startPoint,
    Offset endPoint,
    Paint linePaint,
    Paint dotPaint,
    String sourceBayType,
    String targetBayType,
  ) {
    canvas.drawLine(startPoint, endPoint, linePaint);

    if (sourceBayType == 'Busbar') {
      // For lines connecting TO a bus, the endpoint is the bus connection.
      if (targetBayType == 'Line') {
        canvas.drawCircle(endPoint, 4.0, dotPaint);
      } else {
        canvas.drawCircle(startPoint, 4.0, dotPaint);
      }
    } else if (targetBayType == 'Busbar') {
      canvas.drawCircle(endPoint, 4.0, dotPaint);
    }

    if (targetBayType == 'Line' ||
        targetBayType == 'Feeder' ||
        (sourceBayType == 'Transformer' && targetBayType != 'Busbar')) {
      _drawArrowhead(canvas, startPoint, endPoint, linePaint);
    }
  }

  void _drawText(
    Canvas canvas,
    String text,
    Offset position, {
    double offsetY = 0,
    bool isBold = false,
    TextAlign textAlign = TextAlign.center,
  }) {
    final textStyle = TextStyle(
      color: Colors.black87,
      fontSize: 9,
      fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
    );
    final textSpan = TextSpan(text: text, style: textStyle);
    final textPainter = TextPainter(
      text: textSpan,
      textAlign: textAlign,
      textDirection: TextDirection.ltr,
    );
    textPainter.layout(maxWidth: 100);

    double x = position.dx;
    if (textAlign == TextAlign.center) {
      x -= textPainter.width / 2;
    } else if (textAlign == TextAlign.right) {
      x -= textPainter.width;
    }

    textPainter.paint(canvas, Offset(x, position.dy + offsetY));
  }

  @override
  bool shouldRepaint(covariant SingleLineDiagramPainter oldDelegate) => true;
}

class _GenericIconPainter extends CustomPainter {
  final Color color;
  _GenericIconPainter({required this.color});
  @override
  void paint(Canvas canvas, Size size) {}
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

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
  String? _selectedSubstationIdForm;
  String? _selectedVoltageLevel;
  String? _selectedBayType;
  bool _isGovernmentFeeder = false;
  String? _selectedFeederType;
  List<Bay> _availableBusbars = [];
  String? _selectedBusbarId;
  bool _isLoadingFormHierarchy = true;
  bool _isSavingBay = false;

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
    );
  }

  BayConnection _createDummyBayConnection() {
    return BayConnection(
      id: 'dummy',
      substationId: '',
      sourceBayId: '',
      targetBayId: '',
      createdBy: '',
      createdAt: Timestamp.now(),
    );
  }

  void _clearAllFormFields() {
    _bayNameController.clear();
    _descriptionController.clear();
    _landmarkController.clear();
    _contactNumberController.clear();
    _contactPersonController.clear();
    _bayNumberController.clear();
    _multiplyingFactorController.clear();
    _selectedVoltageLevel = null;
    _selectedBayType = null;
    _selectedBusbarId = null;
    _availableBusbars = [];
    _isGovernmentFeeder = false;
    _selectedFeederType = null;
    _lineLengthController.clear();
    _otherConductorController.clear();
    _selectedCircuit = null;
    _selectedConductor = null;
    _erectionDateController.clear();
    _erectionDate = null;
    _makeController.clear();
    _capacityController.clear();
    _selectedHvVoltage = null;
    _selectedLvVoltage = null;
    _selectedHvBusId = null;
    _selectedLvBusId = null;
    _manufacturingDateController.clear();
    _manufacturingDate = null;
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
    if (_selectedBayType != 'Busbar' && _availableBusbars.isEmpty) {
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
        'hvBusId': _selectedBayType == 'Transformer' ? _selectedHvBusId : null,
        'lvBusId': _selectedBayType == 'Transformer' ? _selectedLvBusId : null,
        'commissioningDate':
            (_selectedBayType == 'Line' || _selectedBayType == 'Transformer') &&
                _commissioningDate != null
            ? Timestamp.fromDate(_commissioningDate!)
            : null,
      };

      if (_viewMode == BayDetailViewMode.edit && _bayToEdit != null) {
        final bayId = _bayToEdit!.id;
        await FirebaseFirestore.instance
            .collection('bays')
            .doc(bayId)
            .update(bayData);
        if (_bayToEdit!.bayType == 'Transformer') {
          final batch = FirebaseFirestore.instance.batch();
          final connectionsSnapshot = await FirebaseFirestore.instance
              .collection('bay_connections')
              .where('substationId', isEqualTo: widget.substationId)
              .where(
                Filter.or(
                  Filter('sourceBayId', isEqualTo: bayId),
                  Filter('targetBayId', isEqualTo: bayId),
                ),
              )
              .get();
          for (var doc in connectionsSnapshot.docs) {
            batch.delete(doc.reference);
          }
          await batch.commit();

          if (_selectedHvBusId != null) {
            await FirebaseFirestore.instance
                .collection('bay_connections')
                .add(
                  BayConnection(
                    substationId: widget.substationId,
                    sourceBayId: _selectedHvBusId!,
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
                    sourceBayId: bayId,
                    targetBayId: _selectedLvBusId!,
                    createdBy: firebaseUser.uid,
                    createdAt: Timestamp.now(),
                  ).toFirestore(),
                );
          }
        }
        if (mounted) {
          SnackBarUtils.showSnackBar(context, 'Bay updated successfully!');
          _initializeFormAndHierarchyForViewMode(BayDetailViewMode.list);
        }
      } else {
        final newBayRef = FirebaseFirestore.instance.collection('bays').doc();
        bayData['createdBy'] = firebaseUser.uid;
        bayData['createdAt'] = Timestamp.now();
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
        if (mounted)
          SnackBarUtils.showSnackBar(
            context,
            'Bay "${bay.name}" deleted successfully!',
          );
      } catch (e) {
        if (mounted)
          SnackBarUtils.showSnackBar(
            context,
            'Failed to delete bay: $e',
            isError: true,
          );
      }
    }
  }

  Future<void> _createDefaultReadingAssignment(Bay bay, String userId) async {
    /* Placeholder */
  }

  void _showBaySymbolActions(
    BuildContext context,
    Bay bay,
    Offset tapPosition,
  ) {
    showMenu(
      context: context,
      position: RelativeRect.fromLTRB(
        tapPosition.dx,
        tapPosition.dy,
        MediaQuery.of(context).size.width - tapPosition.dx,
        MediaQuery.of(context).size.height - tapPosition.dy,
      ),
      items: <PopupMenuEntry<String>>[
        const PopupMenuItem<String>(
          value: 'edit',
          child: ListTile(
            leading: Icon(Icons.edit),
            title: Text('Edit Bay Details'),
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
      ],
    ).then((value) {
      if (value == 'edit') {
        _initializeFormAndHierarchyForViewMode(
          BayDetailViewMode.edit,
          bay: bay,
        );
      } else if (value == 'manage_equipment') {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => BayEquipmentManagementScreen(
              bayId: bay.id,
              bayName: bay.name,
              currentUser: widget.currentUser,
              substationId: widget.substationId,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Substation: ${widget.substationName}'),
        actions: [
          if (_viewMode == BayDetailViewMode.list)
            IconButton(
              icon: const Icon(Icons.info_outline),
              onPressed: () => SnackBarUtils.showSnackBar(
                context,
                'Viewing details for ${widget.substationName}.',
              ),
            ),
        ],
      ),
      body: (_viewMode == BayDetailViewMode.list)
          ? _buildSLDView()
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

  Widget _buildSLDView() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('bays')
          .where('substationId', isEqualTo: widget.substationId)
          .snapshots(),
      builder: (context, baysSnapshot) {
        if (baysSnapshot.hasError)
          return Center(child: Text('Error: ${baysSnapshot.error}'));
        if (baysSnapshot.connectionState == ConnectionState.waiting)
          return const Center(child: CircularProgressIndicator());
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

        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('bay_connections')
              .where('substationId', isEqualTo: widget.substationId)
              .snapshots(),
          builder: (context, connectionsSnapshot) {
            if (connectionsSnapshot.hasError)
              return Center(child: Text('Error: ${connectionsSnapshot.error}'));
            if (connectionsSnapshot.connectionState == ConnectionState.waiting)
              return const Center(child: CircularProgressIndicator());

            final allConnections =
                connectionsSnapshot.data?.docs
                    .map((doc) => BayConnection.fromFirestore(doc))
                    .toList() ??
                [];

            final bayRenderDataList = <BayRenderData>[];
            final busbarRects = <String, Rect>{};
            final busbarConnectionPoints = <String, Map<String, Offset>>{};

            const double symbolWidth = 60, symbolHeight = 60;
            const double horizontalSpacing = 80, verticalBusbarSpacing = 200;
            const double topPadding = 80, sidePadding = 60;

            final busbars = allBays
                .where((b) => b.bayType == 'Busbar')
                .toList();
            busbars.sort((a, b) {
              double getV(String v) =>
                  double.tryParse(v.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0;
              return getV(b.voltageLevel).compareTo(getV(a.voltageLevel));
            });

            Map<String, double> busYPositions = {};
            for (int i = 0; i < busbars.length; i++) {
              busYPositions[busbars[i].id] =
                  topPadding + i * verticalBusbarSpacing;
            }

            double globalCurrentX = sidePadding;

            final transformers = allBays
                .where((b) => b.bayType == 'Transformer')
                .toList();
            for (var tf in transformers) {
              final hvBus = busbars.firstWhere(
                (b) => b.id == tf.hvBusId,
                orElse: () => busbars.first,
              );
              final lvBus = busbars.firstWhere(
                (b) => b.id == tf.lvBusId,
                orElse: () => busbars.last,
              );

              final hvY = busYPositions[hvBus.id]!;
              final lvY = busYPositions[lvBus.id]!;

              final tfRect = Rect.fromCenter(
                center: Offset(
                  globalCurrentX + symbolWidth / 2,
                  (hvY + lvY) / 2,
                ),
                width: symbolWidth,
                height: symbolHeight,
              );
              bayRenderDataList.add(
                BayRenderData(
                  bay: tf,
                  rect: tfRect,
                  center: tfRect.center,
                  topCenter: tfRect.topCenter,
                  bottomCenter: tfRect.bottomCenter,
                  leftCenter: tfRect.centerLeft,
                  rightCenter: tfRect.centerRight,
                ),
              );
              busbarConnectionPoints.putIfAbsent(hvBus.id, () => {})[tf.id] =
                  Offset(tfRect.center.dx, hvY);
              busbarConnectionPoints.putIfAbsent(lvBus.id, () => {})[tf.id] =
                  Offset(tfRect.center.dx, lvY);
              globalCurrentX += horizontalSpacing;
            }

            for (var busbar in busbars) {
              final connectedBays = allBays
                  .where(
                    (bay) =>
                        bay.bayType != 'Busbar' &&
                        bay.bayType != 'Transformer' &&
                        allConnections.any(
                          (c) =>
                              (c.sourceBayId == busbar.id &&
                                  c.targetBayId == bay.id) ||
                              (c.sourceBayId == bay.id &&
                                  c.targetBayId == busbar.id),
                        ),
                  )
                  .toList();

              for (var bay in connectedBays) {
                Rect bayRect;
                const double lineFeederHeight = 40.0;
                final double busY = busYPositions[busbar.id]!;

                if (bay.bayType == 'Line') {
                  // Line bay is represented as an arrow pointing UP TO the busbar.
                  // The layout rect should be positioned above the bus.
                  bayRect = Rect.fromLTWH(
                    globalCurrentX,
                    busY - lineFeederHeight, // Positioned above the bus
                    symbolWidth,
                    lineFeederHeight,
                  );
                } else if (bay.bayType == 'Feeder') {
                  // Feeder bay is an arrow pointing DOWN FROM the busbar.
                  // The layout rect starts on the bus and extends downwards.
                  bayRect = Rect.fromLTWH(
                    globalCurrentX,
                    busY, // Starts on the bus
                    symbolWidth,
                    lineFeederHeight,
                  );
                } else {
                  // This case should not be reached with the current filters
                  bayRect = Rect.zero;
                }

                bayRenderDataList.add(
                  BayRenderData(
                    bay: bay,
                    rect: bayRect,
                    center: bayRect.center,
                    topCenter: bayRect.topCenter,
                    bottomCenter: bayRect.bottomCenter,
                    leftCenter: bayRect.centerLeft,
                    rightCenter: bayRect.centerRight,
                  ),
                );
                busbarConnectionPoints.putIfAbsent(
                  busbar.id,
                  () => {},
                )[bay.id] = Offset(
                  bayRect.center.dx,
                  busY, // Connection point is always on the bus line
                );
                globalCurrentX += horizontalSpacing;
              }
            }

            for (var busbar in busbars) {
              final rect = Rect.fromLTWH(
                sidePadding,
                busYPositions[busbar.id]!,
                max(0, globalCurrentX - sidePadding),
                0,
              );
              busbarRects[busbar.id] = rect;
              bayRenderDataList.add(
                BayRenderData(
                  bay: busbar,
                  rect: rect,
                  center: rect.center,
                  topCenter: rect.topCenter,
                  bottomCenter: rect.bottomCenter,
                  leftCenter: rect.centerLeft,
                  rightCenter: rect.centerRight,
                ),
              );
            }

            double canvasWidth = globalCurrentX + sidePadding;
            double canvasHeight =
                (busbars.length) * verticalBusbarSpacing + topPadding;

            return InteractiveViewer(
              boundaryMargin: const EdgeInsets.all(20),
              minScale: 0.2,
              maxScale: 4.0,
              child: GestureDetector(
                onTapUp: (details) {
                  final tappedBay = bayRenderDataList
                      .where((data) => data.bay.bayType != 'Busbar')
                      .firstWhere(
                        (data) => data.rect.contains(details.localPosition),
                        orElse: _createDummyBayRenderData,
                      );
                  if (tappedBay.bay.id != 'dummy')
                    _initializeFormAndHierarchyForViewMode(
                      BayDetailViewMode.edit,
                      bay: tappedBay.bay,
                    );
                },
                onLongPressStart: (details) {
                  final tappedBay = bayRenderDataList
                      .where((data) => data.bay.bayType != 'Busbar')
                      .firstWhere(
                        (data) => data.rect.contains(details.localPosition),
                        orElse: _createDummyBayRenderData,
                      );
                  if (tappedBay.bay.id != 'dummy')
                    _showBaySymbolActions(
                      context,
                      tappedBay.bay,
                      details.globalPosition,
                    );
                },
                child: CustomPaint(
                  size: Size(canvasWidth, canvasHeight),
                  painter: SingleLineDiagramPainter(
                    bayRenderDataList: bayRenderDataList,
                    bayConnections: allConnections,
                    baysMap: baysMap,
                    createDummyBayRenderData: _createDummyBayRenderData,
                    busbarRects: busbarRects,
                    busbarConnectionPoints: busbarConnectionPoints,
                  ),
                ),
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
              _viewMode == BayDetailViewMode.add ? 'Add New Bay' : 'Edit Bay',
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
              onChanged: (v) => setState(() => _selectedBayType = v),
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
                _selectedBayType != 'Transformer') ...[
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
                items: _availableBusbars
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
                items: _availableBusbars
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
}
