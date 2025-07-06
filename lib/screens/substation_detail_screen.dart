// lib/screens/substation_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'dart:math'; // For min and max

import '../models/bay_model.dart';
import '../models/user_model.dart';
import '../models/hierarchy_models.dart';
import '../models/app_state_data.dart';
import '../utils/snackbar_utils.dart';
import '../screens/bay_equipment_management_screen.dart';
import '../screens/bay_reading_assignment_screen.dart';
import '../models/bay_connection_model.dart';
import '../models/reading_models.dart';

// Import all your equipment icon painters here
// Ensure these files exist and contain a CustomPainter class
// e.g., class TransformerIconPainter extends CustomPainter { ... }
import '../equipment_icons/transformer_icon.dart';
import '../equipment_icons/busbar_icon.dart';
import '../equipment_icons/circuit_breaker_icon.dart';
import '../equipment_icons/ct_icon.dart';
import '../equipment_icons/disconnector_icon.dart';
import '../equipment_icons/ground_icon.dart';
import '../equipment_icons/isolator_icon.dart';
import '../equipment_icons/pt_icon.dart';

enum BayDetailViewMode { list, add, edit }

// Enum to manage which date is being picked
enum DateType { commissioning, manufacturing, erection }

// Helper class to store rendering data for each bay on the SLD
class BayRenderData {
  final Bay bay;
  final Rect rect; // Bounding box for drawing and hit-testing
  final Offset center; // Center point of the symbol
  // Specific connection points on the symbol's bounding box for cleaner lines
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

// Custom Painter for the Single Line Diagram
class SingleLineDiagramPainter extends CustomPainter {
  final List<BayRenderData> bayRenderDataList;
  final List<BayConnection> bayConnections;
  final Map<String, Bay> baysMap; // For quick lookup of bays by ID
  final BayRenderData Function() createDummyBayRenderData;
  final BayConnection Function() createDummyBayConnection;
  final Map<String, Rect> busbarRects; // Actual calculated busbar rects
  // NEW: Map to store specific connection points on busbars
  final Map<String, Map<String, Offset>> busbarConnectionPoints;

  SingleLineDiagramPainter({
    required this.bayRenderDataList,
    required this.bayConnections,
    required this.baysMap,
    required this.createDummyBayRenderData,
    required this.createDummyBayConnection,
    required this.busbarRects, // Pass busbar rects from layout
    required this.busbarConnectionPoints, // Pass calculated connection points
  });

  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = Colors.blueGrey.shade700
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    final busbarPaint = Paint()
      ..color = Colors.blueGrey.shade900
      ..strokeWidth =
          4.0 // Thicker busbar lines
      ..style = PaintingStyle.stroke;

    final connectionDotPaint = Paint()
      ..color = Colors.blueGrey.shade900
      ..style = PaintingStyle.fill; // Solid dot

    // Draw all busbars first with their calculated dynamic lengths
    for (var renderData in bayRenderDataList) {
      if (renderData.bay.bayType == 'Busbar') {
        final busbarRect = busbarRects[renderData.bay.id] ?? renderData.rect;
        // Draw the main busbar line
        canvas.drawLine(
          busbarRect.centerLeft,
          busbarRect.centerRight,
          busbarPaint,
        );

        // Draw voltage label on the busbar
        final voltageTextSpan = TextSpan(
          text: renderData.bay.voltageLevel,
          style: TextStyle(
            color: Colors.black87,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        );
        final voltageTextPainter = TextPainter(
          text: voltageTextSpan,
          textDirection: TextDirection.ltr,
        );
        voltageTextPainter.layout();
        voltageTextPainter.paint(
          canvas,
          Offset(
            busbarRect.center.dx - voltageTextPainter.width / 2,
            busbarRect.center.dy -
                voltageTextPainter.height / 2 -
                5, // Slightly above the line
          ),
        );

        // Draw busbar name label below busbar
        final nameTextSpan = TextSpan(
          text: renderData.bay.name,
          style: TextStyle(
            color: Colors.black87,
            fontSize: 10,
            fontWeight: FontWeight.normal,
          ),
        );
        final nameTextPainter = TextPainter(
          text: nameTextSpan,
          textDirection: TextDirection.ltr,
        );
        nameTextPainter.layout();
        nameTextPainter.paint(
          canvas,
          Offset(
            busbarRect.center.dx - nameTextPainter.width / 2,
            busbarRect.bottom + 2,
          ),
        );
      }
    }

    // Draw all symbols (excluding busbars, already drawn) and their labels
    for (var renderData in bayRenderDataList) {
      final bay = renderData.bay;
      final rect = renderData.rect;

      if (bay.bayType == 'Busbar') continue; // Already drawn

      CustomPainter painter;
      const Size equipmentDrawingSize = Size(100, 100); // Base size for icons

      switch (bay.bayType) {
        case 'Transformer':
          painter = TransformerIconPainter(
            color: Colors.blue,
            equipmentSize: equipmentDrawingSize,
            symbolSize: equipmentDrawingSize,
          );
          break;
        case 'Circuit Breaker':
          painter = CircuitBreakerIconPainter(
            color: Colors.blue,
            equipmentSize: equipmentDrawingSize,
            symbolSize: equipmentDrawingSize,
          );
          break;
        case 'Line':
          painter = _GenericIconPainter(
            color: Colors.blue,
          ); // Placeholder, ideally specific LinePainter
          break;
        case 'Feeder':
          painter = _GenericIconPainter(
            color: Colors.blue,
          ); // Placeholder, ideally specific FeederPainter
          break;
        case 'Capacitor Bank':
          painter = _GenericIconPainter(color: Colors.blue); // Placeholder
          break;
        case 'Reactor':
          painter = _GenericIconPainter(color: Colors.blue); // Placeholder
          break;
        case 'Bus Coupler':
          painter = _GenericIconPainter(color: Colors.blue); // Placeholder
          break;
        case 'Battery':
          painter = _GenericIconPainter(color: Colors.blue); // Placeholder
          break;
        default:
          painter = _GenericIconPainter(
            color: Colors.blue,
          ); // Fallback for unknown types
      }

      // Draw the symbol
      canvas.save();
      canvas.translate(rect.topLeft.dx, rect.topLeft.dy);
      painter.paint(
        canvas,
        rect.size,
      ); // Pass the actual size of the rect for drawing
      canvas.restore();

      // Draw bay type / name label above symbol, touching the symbol
      String labelText = bay.bayType == 'Transformer'
          ? '${bay.capacity?.round() ?? ''}MVA TF' // Display capacity for transformers
          : bay.name; // For others, use the name

      final textSpan = TextSpan(
        text: labelText,
        style: TextStyle(
          color: Colors.black87,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      );
      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(
          rect.center.dx - textPainter.width / 2,
          rect.top - textPainter.height,
        ), // Directly above symbol
      );
    }

    // Draw all connections after symbols and busbars
    for (var connection in bayConnections) {
      final sourceBay = baysMap[connection.sourceBayId];
      final targetBay = baysMap[connection.targetBayId];

      if (sourceBay == null || targetBay == null) continue;

      final sourceRenderData = bayRenderDataList.firstWhere(
        (data) => data.bay.id == sourceBay.id,
        orElse: () => createDummyBayRenderData(),
      );
      final targetRenderData = bayRenderDataList.firstWhere(
        (data) => data.bay.id == targetBay.id,
        orElse: () => createDummyBayRenderData(),
      );

      if (sourceRenderData.bay.id == 'dummy' ||
          targetRenderData.bay.id == 'dummy')
        continue;

      Offset startPoint;
      Offset endPoint;

      // Determine precise connection points based on bay type and pre-calculated busbar points
      if (sourceBay.bayType == 'Busbar') {
        // Source is a busbar, target is a bay (line, feeder, transformer LV)
        startPoint =
            busbarConnectionPoints[sourceBay.id]?[targetBay.id] ??
            sourceRenderData.rect.bottomCenter;
        endPoint = targetRenderData.topCenter;
      } else if (targetBay.bayType == 'Busbar') {
        // Source is a bay (line, feeder, transformer HV), target is a busbar
        startPoint = sourceRenderData.bottomCenter;
        endPoint =
            busbarConnectionPoints[targetBay.id]?[sourceBay.id] ??
            targetRenderData.rect.bottomCenter;
      } else {
        // Bay to Bay connection (not typical in a simple SLD but for completeness)
        startPoint = sourceRenderData.bottomCenter;
        endPoint = targetRenderData.topCenter;
      }

      // Draw the connection line with 90-degree bends
      _drawConnectionLine(
        canvas,
        startPoint,
        endPoint,
        linePaint,
        connectionDotPaint,
        sourceBay.bayType,
        targetBay.bayType,
      );

      // Draw arrowhead on the target side if it's not a busbar connecting to a bay
      // or if it's a transformer connecting to a busbar (direction makes sense)
      // This is generally for power flow direction.
      if (targetBay.bayType != 'Busbar' || sourceBay.bayType == 'Transformer') {
        _drawArrowhead(canvas, startPoint, endPoint, linePaint);
      }
    }
  }

  // Helper to draw an arrowhead
  void _drawArrowhead(Canvas canvas, Offset p1, Offset p2, Paint paint) {
    const double arrowSize = 8;
    // Calculate angle of the last segment of the line
    final double angle = atan2(
      p2.dy -
          (p1.dy + (p2.dy - p1.dy).sign * 20).clamp(
            min(p1.dy, p2.dy),
            max(p1.dy, p2.dy),
          ),
      p2.dx - p2.dx,
    ); // Simplified for vertical line
    if (p1.dx == p2.dx) {
      // Vertical line
      final path = Path();
      path.moveTo(p2.dx, p2.dy);
      path.lineTo(
        p2.dx - arrowSize / 2,
        p2.dy - (p2.dy - p1.dy).sign * arrowSize,
      );
      path.lineTo(
        p2.dx + arrowSize / 2,
        p2.dy - (p2.dy - p1.dy).sign * arrowSize,
      );
      path.close();
      canvas.drawPath(path, paint..style = PaintingStyle.fill);
    } else {
      // Horizontal or angled line (fallback to original)
      final path = Path();
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
      canvas.drawPath(path, paint..style = PaintingStyle.fill);
    }
  }

  // Helper to draw lines with 90-degree bends and busbar dots
  void _drawConnectionLine(
    Canvas canvas,
    Offset p1,
    Offset p2,
    Paint linePaint,
    Paint dotPaint,
    String sourceBayType,
    String targetBayType,
  ) {
    if (p1 == p2) return; // No line if points are the same

    Path path = Path();
    path.moveTo(p1.dx, p1.dy);

    // Prioritize vertical then horizontal for connections to/from busbars
    if (sourceBayType == 'Busbar' && targetBayType != 'Busbar') {
      // From Busbar (source) to Bay (target)
      // Path: Down from busbar (p1.dx, X), then horizontally (p2.dx, X), then down to bay (p2.dx, p2.dy)
      final double midY = p1.dy + 30; // Small vertical drop from busbar
      path.lineTo(p1.dx, midY); // Vertical segment from busbar
      path.lineTo(p2.dx, midY); // Horizontal segment to bay's X coordinate
      path.lineTo(p2.dx, p2.dy); // Vertical segment to bay's top
      canvas.drawPath(path, linePaint);
      canvas.drawCircle(p1, 4.0, dotPaint); // Dot at busbar connection
      canvas.drawCircle(p2, 4.0, dotPaint); // Dot at bay connection
    } else if (targetBayType == 'Busbar' && sourceBayType != 'Busbar') {
      // From Bay (source) to Busbar (target)
      // Path: Down from bay (p1.dx, Y), then horizontally (p2.dx, Y), then up to busbar (p2.dx, p2.dy)
      final double midY = p1.dy + 30; // Small vertical drop from bay
      path.lineTo(p1.dx, midY); // Vertical segment from bay
      path.lineTo(p2.dx, midY); // Horizontal segment to busbar's X coordinate
      path.lineTo(p2.dx, p2.dy); // Vertical segment up to busbar's bottom
      canvas.drawPath(path, linePaint);
      canvas.drawCircle(p1, 4.0, dotPaint); // Dot at bay connection
      canvas.drawCircle(p2, 4.0, dotPaint); // Dot at busbar connection
    } else if (sourceBayType == 'Transformer' && targetBayType == 'Busbar') {
      // From Transformer to Busbar (HV or LV)
      // Vertical line from transformer connection point (p1) to target busbar's Y
      // Then horizontal to target busbar's X
      path.lineTo(p1.dx, p2.dy); // Vertical to busbar Y
      path.lineTo(p2.dx, p2.dy); // Horizontal to busbar X
      canvas.drawPath(path, linePaint);
      canvas.drawCircle(p1, 4.0, dotPaint); // Dot at transformer connection
      canvas.drawCircle(p2, 4.0, dotPaint); // Dot at busbar connection
    } else if (targetBayType == 'Transformer' && sourceBayType == 'Busbar') {
      // From Busbar to Transformer
      // Vertical line from busbar connection point (p1) to transformer's Y
      // Then horizontal to transformer's X
      path.lineTo(p1.dx, p2.dy); // Vertical to transformer Y
      path.lineTo(p2.dx, p2.dy); // Horizontal to transformer X
      canvas.drawPath(path, linePaint);
      canvas.drawCircle(p1, 4.0, dotPaint); // Dot at busbar connection
      canvas.drawCircle(p2, 4.0, dotPaint); // Dot at transformer connection
    } else {
      // Default: straight line for any other direct bay-to-bay connection
      canvas.drawLine(p1, p2, linePaint);
    }
  }

  @override
  bool shouldRepaint(covariant SingleLineDiagramPainter oldDelegate) {
    // Repaint if any relevant data changes
    return oldDelegate.bayRenderDataList.length != bayRenderDataList.length ||
        oldDelegate.bayConnections.length != bayConnections.length ||
        oldDelegate.baysMap.length != baysMap.length ||
        oldDelegate.busbarRects.length != busbarRects.length ||
        oldDelegate.busbarConnectionPoints.length !=
            busbarConnectionPoints.length;
  }
}

// Generic Painter fallback for unrecognized symbols
class _GenericIconPainter extends CustomPainter {
  final Color color;
  _GenericIconPainter({required this.color});
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle
          .stroke // Make sure it's stroke here too
      ..strokeWidth = 2.0;

    final double centerX = size.width / 2;
    final double centerY = size.height / 2;
    final double halfWidth = size.width / 3;
    final double halfHeight = size.height / 3;

    canvas.drawRect(
      Rect.fromCenter(
        center: Offset(centerX, centerY),
        width: halfWidth * 2,
        height: halfHeight * 2,
      ),
      paint,
    );
    canvas.drawLine(
      Offset(centerX - halfWidth, centerY - halfHeight),
      Offset(centerX + halfWidth, centerY + halfHeight),
      paint,
    );
    canvas.drawLine(
      Offset(centerX + halfWidth, centerY - halfHeight),
      Offset(centerX - halfWidth, centerY + halfHeight),
      paint,
    );
  }

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
      TextEditingController();

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
  String? _selectedHvBusId; // For HV bus connection
  String? _selectedLvBusId; // For LV bus connection

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

  void _clearAllFormFields() {
    // Common
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
    _selectedHvBusId = null;
    _selectedLvBusId = null;
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
            bay.multiplyingFactor?.toString() ?? '';
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
        _selectedBayType != 'Transformer' &&
        _selectedBusbarId == null &&
        _viewMode == BayDetailViewMode.add) {
      SnackBarUtils.showSnackBar(
        context,
        'Please connect this bay to a busbar.',
        isError: true,
      );
      return;
    }
    if (_selectedBayType == 'Transformer' && _selectedHvBusId == null) {
      SnackBarUtils.showSnackBar(
        context,
        'Please connect HV to a busbar.',
        isError: true,
      );
      return;
    }
    if (_selectedBayType == 'Transformer' && _selectedLvBusId == null) {
      SnackBarUtils.showSnackBar(
        context,
        'Please connect LV to a busbar.',
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
        'voltageLevel': _selectedBayType == 'Transformer'
            ? _selectedHvVoltage
            : _selectedBayType == 'Battery'
            ? null
            : _selectedVoltageLevel,
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

        // For non-transformer bays, save single connection if applicable
        if (_selectedBayType != 'Transformer' && _selectedBusbarId != null) {
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
          if (mounted) {
            SnackBarUtils.showSnackBar(
              context,
              'Bay connected to busbar "${_availableBusbars.firstWhere((b) => b.id == _selectedBusbarId).name}"',
            );
          }
        } else if (_selectedBayType == 'Transformer') {
          // For transformers, save two connections (HV and LV)
          if (_selectedHvBusId != null) {
            final hvConnection = BayConnection(
              substationId: widget.substationId,
              sourceBayId: _selectedHvBusId!, // HV Bus
              targetBayId: newBayRef.id, // Transformer Bay
              createdBy: firebaseUser.uid,
              createdAt: Timestamp.now(),
            );
            await FirebaseFirestore.instance
                .collection('bay_connections')
                .add(hvConnection.toFirestore());
            if (mounted) {
              SnackBarUtils.showSnackBar(
                context,
                'HV side connected to busbar "${_availableBusbars.firstWhere((b) => b.id == _selectedHvBusId).name}"',
              );
            }
          }
          if (_selectedLvBusId != null) {
            final lvConnection = BayConnection(
              substationId: widget.substationId,
              sourceBayId: _selectedLvBusId!, // LV Bus
              targetBayId: newBayRef.id, // Transformer Bay
              createdBy: firebaseUser.uid,
              createdAt: Timestamp.now(),
            );
            await FirebaseFirestore.instance
                .collection('bay_connections')
                .add(lvConnection.toFirestore());
            if (mounted) {
              SnackBarUtils.showSnackBar(
                context,
                'LV side connected to busbar "${_availableBusbars.firstWhere((b) => b.id == _selectedLvBusId).name}"',
              );
            }
          }
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
        // Also delete associated connections
        final batch = FirebaseFirestore.instance.batch();
        final connectionsSnapshot = await FirebaseFirestore.instance
            .collection('bay_connections')
            .where('substationId', isEqualTo: widget.substationId)
            .where('sourceBayId', isEqualTo: bay.id)
            .get();
        for (var doc in connectionsSnapshot.docs) {
          batch.delete(doc.reference);
        }
        final targetConnectionsSnapshot = await FirebaseFirestore.instance
            .collection('bay_connections')
            .where('substationId', isEqualTo: widget.substationId)
            .where('targetBayId', isEqualTo: bay.id)
            .get();
        for (var doc in targetConnectionsSnapshot.docs) {
          batch.delete(doc.reference);
        }
        await batch.commit();

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

  // Define _createDummyBayRenderData - crucial for orElse in firstWhere
  BayRenderData _createDummyBayRenderData() {
    return BayRenderData(
      bay: Bay(
        id: 'dummy',
        name: 'Dummy Bay',
        substationId: 'dummy',
        bayType: 'Dummy',
        voltageLevel: '',
        createdBy: 'dummy',
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

  // Define _createDummyBayConnection - crucial for orElse in firstWhere
  BayConnection _createDummyBayConnection() {
    return BayConnection(
      id: 'dummy',
      substationId: 'dummy',
      sourceBayId: 'dummy',
      targetBayId: 'dummy',
      createdBy: 'dummy',
      createdAt: Timestamp.now(),
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
                SnackBarUtils.showSnackBar(
                  context,
                  'Viewing details for ${widget.substationName}.',
                );
              },
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

  // NEW METHOD: Builds the Single Line Diagram View
  Widget _buildSLDView() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('bays')
          .where('substationId', isEqualTo: widget.substationId)
          .snapshots(), // Get all bays
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

        final List<Bay> allBays = baysSnapshot.data!.docs
            .map((doc) => Bay.fromFirestore(doc))
            .toList();
        final Map<String, Bay> baysMap = {for (var bay in allBays) bay.id: bay};

        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('bay_connections')
              .where('substationId', isEqualTo: widget.substationId)
              .snapshots(),
          builder: (context, connectionsSnapshot) {
            if (connectionsSnapshot.hasError) {
              return Center(
                child: Text(
                  'Error: ${connectionsSnapshot.error}',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              );
            }
            if (connectionsSnapshot.connectionState ==
                ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final List<BayConnection> allConnections = connectionsSnapshot
                .data!
                .docs
                .map((doc) => BayConnection.fromFirestore(doc))
                .toList();

            // --- SLD Layout Calculation ---
            final List<BayRenderData> bayRenderDataList = [];
            final Map<String, Rect> busbarRects =
                {}; // To store final calculated busbar rects
            final Map<String, Map<String, Offset>> busbarConnectionPoints =
                {}; // Busbar ID -> Bay ID -> Connection Point

            final double symbolWidth = 80; // Width of a bay symbol
            final double symbolHeight = 80; // Height of a bay symbol
            final double busbarHeight = 10; // Height (thickness) of busbar line
            final double symbolPadding =
                40; // Horizontal/vertical padding around symbols
            final double bayVerticalOffsetFromBus =
                100; // Vertical space from busbar to connected bays
            final double horizontalBaySpacing =
                120; // Horizontal space between bays connected to same bus
            final double verticalBusbarSpacing =
                150; // Vertical space between different voltage busbars
            const double busbarSidePadding = 50; // Padding at ends of busbar

            // Sort voltages from highest to lowest for top-down layout
            final List<String> sortedVoltages = _voltageLevels.toList()
              ..sort((a, b) {
                double getNumericVoltage(String v) {
                  if (v.endsWith('kV'))
                    return double.parse(v.replaceAll('kV', '')) * 1000;
                  if (v.endsWith('V'))
                    return double.parse(v.replaceAll('V', ''));
                  return 0.0;
                }

                return getNumericVoltage(
                  b,
                ).compareTo(getNumericVoltage(a)); // Descending
              });

            Map<String, double> voltageLevelY =
                {}; // Tracks Y position for each voltage level
            Map<String, double> nextXForBusbarGroup =
                {}; // Tracks next horizontal position for bays connected to a bus
            Map<String, List<String>> busbarConnectedBayOrder =
                {}; // Busbar ID -> List of Bay IDs in order of connection

            double currentY =
                symbolPadding *
                2; // Initial Y position for the first (highest voltage) busbar

            // 1. Initial positioning of Busbars and mapping their Y-levels
            // Also, pre-populate busbarMinX and busbarMaxX to include default padding
            Map<String, double> busbarMinX = {};
            Map<String, double> busbarMaxX = {};

            for (String voltage in sortedVoltages) {
              final busbarsAtVoltage = allBays
                  .where(
                    (b) => b.bayType == 'Busbar' && b.voltageLevel == voltage,
                  )
                  .toList();

              if (busbarsAtVoltage.isNotEmpty) {
                // Assuming one busbar per voltage level for simplicity here.
                // If multiple busbars for same voltage (e.g., Main Bus 1, Main Bus 2),
                // they would need horizontal placement relative to each other.
                final busbar = busbarsAtVoltage.first; // Or iterate if multiple
                final tempBusbarRect = Rect.fromLTWH(
                  symbolPadding,
                  currentY,
                  200,
                  busbarHeight,
                ); // Arbitrary initial width
                busbarRects[busbar.id] = tempBusbarRect;
                voltageLevelY[voltage] =
                    currentY; // Store Y position for this voltage

                // Initialize min/max X for this busbar with some default padding
                busbarMinX[busbar.id] = symbolPadding;
                busbarMaxX[busbar.id] = symbolPadding + tempBusbarRect.width;

                // Add a dummy render data for the busbar. Its rect will be updated later.
                bayRenderDataList.add(
                  BayRenderData(
                    bay: busbar,
                    rect: tempBusbarRect,
                    center: tempBusbarRect.center,
                    topCenter: tempBusbarRect.topCenter,
                    bottomCenter: tempBusbarRect.bottomCenter,
                    leftCenter: tempBusbarRect.centerLeft,
                    rightCenter: tempBusbarRect.centerRight,
                  ),
                );

                currentY +=
                    symbolHeight +
                    verticalBusbarSpacing; // Move down for the next voltage busbar group
              }
            }

            // 2. Position other Bays (Lines, Feeders, etc.) connected to busbars
            // and determine the busbar connection points.
            Map<String, List<Bay>> baysConnectedToBus =
                {}; // Busbar ID -> List of Bays
            Map<String, List<Bay>> baysConnectedFromBus =
                {}; // Busbar ID -> List of Bays (for transformers HV side)

            for (var conn in allConnections) {
              final sourceBay = baysMap[conn.sourceBayId];
              final targetBay = baysMap[conn.targetBayId];

              if (sourceBay == null || targetBay == null) continue;

              if (sourceBay.bayType == 'Busbar') {
                baysConnectedToBus
                    .putIfAbsent(sourceBay.id, () => [])
                    .add(targetBay);
              } else if (targetBay.bayType == 'Busbar') {
                // For a bay connected to a busbar, consider the busbar as the source
                // or just manage this as a connection TO the bus.
                // This logic simplifies to "bays below a bus connect to that bus"
                baysConnectedToBus
                    .putIfAbsent(targetBay.id, () => [])
                    .add(sourceBay);
              }
            }

            // Sort bays connected to each busbar for consistent spacing
            baysConnectedToBus.forEach((busbarId, bays) {
              bays.sort((a, b) => a.name.compareTo(b.name));
            });

            // Calculate initial X positions for all bays (non-transformers) and populate render data
            for (String voltage in sortedVoltages) {
              final busbarsInVoltage = allBays
                  .where(
                    (b) => b.bayType == 'Busbar' && b.voltageLevel == voltage,
                  )
                  .toList();
              if (busbarsInVoltage.isEmpty)
                continue; // No busbar at this voltage level

              final busbar = busbarsInVoltage
                  .first; // Again, assuming one busbar per voltage group
              final List<Bay> connectedBays =
                  baysConnectedToBus[busbar.id] ?? [];

              double currentX = symbolPadding;
              for (var bay in connectedBays) {
                if (bay.bayType == 'Transformer')
                  continue; // Transformers handled separately

                final bayRect = Rect.fromLTWH(
                  currentX,
                  voltageLevelY[voltage]! + bayVerticalOffsetFromBus,
                  symbolWidth,
                  symbolHeight,
                );
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

                // Store the connection point on the busbar for this bay
                busbarConnectionPoints.putIfAbsent(
                  busbar.id,
                  () => {},
                )[bay.id] = Offset(
                  currentX + symbolWidth / 2,
                  busbarRects[busbar.id]!.bottom,
                );

                // Update busbar's required X span
                busbarMinX[busbar.id] = min(
                  busbarMinX[busbar.id]!,
                  bayRect.left,
                );
                busbarMaxX[busbar.id] = max(
                  busbarMaxX[busbar.id]!,
                  bayRect.right,
                );

                currentX += horizontalBaySpacing;
              }
              nextXForBusbarGroup[busbar.id] =
                  currentX; // Save for next pass (transformers might use it)
            }

            // 3. Position Transformers and update busbar extents with their connections
            final List<Bay> transformers = allBays
                .where((b) => b.bayType == 'Transformer')
                .toList();

            for (var transformer in transformers) {
              final hvBus = baysMap[transformer.hvBusId];
              final lvBus = baysMap[transformer.lvBusId];

              if (hvBus != null &&
                  lvBus != null &&
                  voltageLevelY.containsKey(hvBus.voltageLevel) &&
                  voltageLevelY.containsKey(lvBus.voltageLevel)) {
                final hvBusY = voltageLevelY[hvBus.voltageLevel]!;
                final lvBusY = voltageLevelY[lvBus.voltageLevel]!;

                // Position transformer horizontally to the right of last placed element on HV bus line,
                // or just to the right of the HV bus starting point.
                double transformerX =
                    nextXForBusbarGroup[hvBus.id] ?? symbolPadding;
                double transformerY =
                    (hvBusY + lvBusY) / 2 - (symbolHeight / 2);

                final transformerRect = Rect.fromLTWH(
                  transformerX,
                  transformerY,
                  symbolWidth,
                  symbolHeight,
                );
                bayRenderDataList.add(
                  BayRenderData(
                    bay: transformer,
                    rect: transformerRect,
                    center: transformerRect.center,
                    topCenter: transformerRect.topCenter,
                    bottomCenter: transformerRect.bottomCenter,
                    leftCenter: transformerRect.centerLeft,
                    rightCenter: transformerRect.centerRight,
                  ),
                );

                // Update nextX for the HV bus line to account for this transformer's placement
                nextXForBusbarGroup[hvBus.id] =
                    transformerX + symbolWidth + horizontalBaySpacing;
                // For the LV bus, also ensure it extends to accommodate the transformer
                nextXForBusbarGroup[lvBus.id] = max(
                  nextXForBusbarGroup[lvBus.id] ?? 0,
                  transformerX + symbolWidth + horizontalBaySpacing,
                );

                // Store specific connection points for transformer on busbars
                busbarConnectionPoints.putIfAbsent(
                  hvBus.id,
                  () => {},
                )[transformer.id] = Offset(
                  transformerRect.center.dx,
                  busbarRects[hvBus.id]!.bottom,
                ); // Transformer HV side to busbar bottom
                busbarConnectionPoints.putIfAbsent(
                  lvBus.id,
                  () => {},
                )[transformer.id] = Offset(
                  transformerRect.center.dx,
                  busbarRects[lvBus.id]!.top,
                ); // Transformer LV side to busbar top

                // Update min/max X for both connected busbars to include transformer's X-span
                busbarMinX[hvBus.id] = min(
                  busbarMinX[hvBus.id] ?? transformerRect.left,
                  transformerRect.left,
                );
                busbarMaxX[hvBus.id] = max(
                  busbarMaxX[hvBus.id] ?? transformerRect.right,
                  transformerRect.right,
                );
                busbarMinX[lvBus.id] = min(
                  busbarMinX[lvBus.id] ?? transformerRect.left,
                  transformerRect.left,
                );
                busbarMaxX[lvBus.id] = max(
                  busbarMaxX[lvBus.id] ?? transformerRect.right,
                  transformerRect.right,
                );
              } else {
                // If transformer not connected to two known busbars, place it in an 'unconnected' area
                double isolatedX = symbolPadding;
                double isolatedY = currentY + 50; // Place below last busbar row
                for (var existingData in bayRenderDataList) {
                  if (existingData.bay.bayType != 'Busbar' &&
                      (existingData.rect.left - isolatedX).abs() <
                          symbolWidth + symbolPadding / 2 &&
                      (existingData.rect.top - isolatedY).abs() <
                          symbolHeight + symbolPadding / 2) {
                    isolatedX +=
                        symbolWidth +
                        symbolPadding; // Simple horizontal stacking
                  }
                }
                final transformerRect = Rect.fromLTWH(
                  isolatedX,
                  isolatedY,
                  symbolWidth,
                  symbolHeight,
                );
                bayRenderDataList.add(
                  BayRenderData(
                    bay: transformer,
                    rect: transformerRect,
                    center: transformerRect.center,
                    topCenter: transformerRect.topCenter,
                    bottomCenter: transformerRect.bottomCenter,
                    leftCenter: transformerRect.centerLeft,
                    rightCenter: transformerRect.centerRight,
                  ),
                );
              }
            }

            // Final pass: Update busbar rects based on determined min/max X values
            double maxOverallX = 0;
            double maxOverallY = 0;

            for (var renderData in bayRenderDataList) {
              if (renderData.bay.bayType == 'Busbar') {
                final busbarId = renderData.bay.id;
                final currentRect = renderData.rect;

                double finalMinX = busbarMinX[busbarId] ?? currentRect.left;
                double finalMaxX = busbarMaxX[busbarId] ?? currentRect.right;

                // Ensure busbar spans at least its default length (e.g., if no connections)
                double effectiveLength = finalMaxX - finalMinX;
                if (effectiveLength < symbolWidth * 2) {
                  // Minimum length for busbar
                  finalMaxX = finalMinX + symbolWidth * 2;
                }

                // Add side padding to the busbar
                finalMinX -= busbarSidePadding;
                finalMaxX += busbarSidePadding;

                final updatedBusbarRect = Rect.fromLTRB(
                  finalMinX,
                  currentRect.top,
                  finalMaxX,
                  currentRect.bottom,
                );
                busbarRects[busbarId] = updatedBusbarRect;
                maxOverallX = max(maxOverallX, updatedBusbarRect.right);
              } else {
                maxOverallX = max(maxOverallX, renderData.rect.right);
                maxOverallY = max(maxOverallY, renderData.rect.bottom);
              }
            }

            // Add extra padding to overall canvas size
            maxOverallX += symbolPadding * 2;
            maxOverallY += symbolPadding * 2;

            double canvasWidth = max(
              MediaQuery.of(context).size.width,
              maxOverallX,
            );
            double canvasHeight = max(
              MediaQuery.of(context).size.height,
              maxOverallY,
            );

            // --- End SLD Layout Calculation ---

            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SingleChildScrollView(
                scrollDirection: Axis.vertical,
                child: GestureDetector(
                  onTapUp: (details) {
                    // Adjust tap position for scrolling
                    final tappedLocalPosition = Offset(
                      details.localPosition.dx,
                      details.localPosition.dy,
                    );

                    final tappedBayRenderData = bayRenderDataList.firstWhere(
                      (data) => data.rect.contains(tappedLocalPosition),
                      orElse: () => _createDummyBayRenderData(),
                    );

                    if (tappedBayRenderData.bay.id != 'dummy') {
                      SnackBarUtils.showSnackBar(
                        context,
                        'Tapped on Bay: ${tappedBayRenderData.bay.name}',
                      );
                      _initializeFormAndHierarchyForViewMode(
                        BayDetailViewMode.edit,
                        bay: tappedBayRenderData.bay,
                      );
                    }
                  },
                  onLongPressStart: (details) {
                    // Adjust tap position for scrolling
                    final tappedLocalPosition = Offset(
                      details.localPosition.dx,
                      details.localPosition.dy,
                    );

                    final tappedBayRenderData = bayRenderDataList.firstWhere(
                      (data) => data.rect.contains(tappedLocalPosition),
                      orElse: () => _createDummyBayRenderData(),
                    );

                    if (tappedBayRenderData.bay.id != 'dummy') {
                      _showBaySymbolActions(
                        context,
                        tappedBayRenderData.bay,
                        details
                            .globalPosition, // Use global position for showMenu
                      );
                    }
                  },
                  child: CustomPaint(
                    size: Size(canvasWidth, canvasHeight),
                    painter: SingleLineDiagramPainter(
                      bayRenderDataList: bayRenderDataList,
                      bayConnections: allConnections,
                      baysMap: baysMap,
                      createDummyBayRenderData: _createDummyBayRenderData,
                      createDummyBayConnection: _createDummyBayConnection,
                      busbarRects:
                          busbarRects, // Pass the calculated busbar rects
                      busbarConnectionPoints:
                          busbarConnectionPoints, // Pass calculated connection points
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  // Method to show context menu on long press
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

  // Define _buildBayFormView method
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

            // Conditional Voltage Level Field
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

            // --- Connect to Busbar (Single connection, hidden for Transformer) ---
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

            // --- Transformer Fields (including dual bus connections) ---
            if (_selectedBayType == 'Transformer') ...[
              DropdownButtonFormField<String>(
                value: _selectedHvVoltage,
                decoration: const InputDecoration(
                  labelText: 'HV Voltage',
                  prefixIcon: Icon(Icons.electric_bolt),
                ),
                items:
                    _voltageLevels // Use consolidated list
                        .map((l) => DropdownMenuItem(value: l, child: Text(l)))
                        .toList(),
                onChanged: (v) => setState(() => _selectedHvVoltage = v),
                validator: (v) => v == null ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              // Connect HV to Bus
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
                  if (v == null) {
                    return 'HV bus connection is required';
                  }
                  final selectedBus = _availableBusbars.firstWhere(
                    (b) => b.id == v,
                  );
                  if (selectedBus.voltageLevel != _selectedHvVoltage) {
                    return 'HV bus voltage must match selected HV voltage';
                  }
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
                items:
                    _voltageLevels // Use consolidated list
                        .map((l) => DropdownMenuItem(value: l, child: Text(l)))
                        .toList(),
                onChanged: (v) => setState(() => _selectedLvVoltage = v),
                validator: (v) => v == null ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              // Connect LV to Bus
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
                  if (v == null) {
                    return 'LV bus connection is required';
                  }
                  final selectedBus = _availableBusbars.firstWhere(
                    (b) => b.id == v,
                  );
                  if (selectedBus.voltageLevel != _selectedLvVoltage) {
                    return 'LV bus voltage must match selected LV voltage';
                  }
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
}
