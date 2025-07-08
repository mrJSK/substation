// lib/screens/substation_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'dart:math'; // Ensure this is imported for 'max'

import '../models/bay_model.dart';
import '../models/user_model.dart';
import '../models/hierarchy_models.dart';
import '../models/app_state_data.dart';
import '../utils/snackbar_utils.dart';
import '../screens/bay_equipment_management_screen.dart'; // To manage equipment list
import '../screens/bay_reading_assignment_screen.dart';
import '../models/bay_connection_model.dart';
import '../models/reading_models.dart';
import '../models/equipment_model.dart'; // NEW: Import EquipmentInstance

// Import your custom equipment icon painters
import '../equipment_icons/transformer_icon.dart';
import '../equipment_icons/line_icon.dart';
import '../equipment_icons/feeder_icon.dart';
// Also import other equipment icons that might be displayed directly by the painter
import '../equipment_icons/busbar_icon.dart';
import '../equipment_icons/circuit_breaker_icon.dart';
import '../equipment_icons/ct_icon.dart';
import '../equipment_icons/disconnector_icon.dart';
import '../equipment_icons/ground_icon.dart';
import '../equipment_icons/isolator_icon.dart';
import '../equipment_icons/pt_icon.dart';

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
  final List<EquipmentInstance> equipmentInstances; // Equipment in this bay

  BayRenderData({
    required this.bay,
    required this.rect,
    required this.center,
    required this.topCenter,
    required this.bottomCenter,
    required this.leftCenter,
    required this.rightCenter,
    this.equipmentInstances = const [], // Initialize
  });
}

class SingleLineDiagramPainter extends CustomPainter {
  final List<BayRenderData> bayRenderDataList;
  final List<BayConnection> bayConnections;
  final Map<String, Bay> baysMap;
  final BayRenderData Function() createDummyBayRenderData;
  final Map<String, Rect> busbarRects;
  final Map<String, Map<String, Offset>> busbarConnectionPoints;
  final bool debugDrawHitboxes; // Added for debugging
  final String? selectedBayForMovementId; // To highlight the selected bay

  SingleLineDiagramPainter({
    required this.bayRenderDataList,
    required this.bayConnections,
    required this.baysMap,
    required this.createDummyBayRenderData,
    required this.busbarRects,
    required this.busbarConnectionPoints,
    this.debugDrawHitboxes =
        false, // Default to false, but we'll enable in _buildSLDView for testing
    this.selectedBayForMovementId, // Initialize new parameter
  });

  Color _getBusbarColor(String voltageLevel) {
    final double voltage =
        double.tryParse(voltageLevel.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0;

    if (voltage >= 765) {
      return Colors.red.shade700;
    } else if (voltage >= 400) {
      return Colors.orange.shade700;
    } else if (voltage >= 220) {
      return Colors.blue.shade700;
    } else if (voltage >= 132) {
      return Colors.purple.shade700;
    } else if (voltage >= 33) {
      return Colors.green.shade700;
    } else if (voltage >= 11) {
      return Colors.teal.shade700;
    } else {
      return Colors.black; // Default color
    }
  }

  // Helper to get CustomPainter for equipment symbol (similar to SLD screen)
  CustomPainter _getSymbolPainter(String symbolKey, Color color, Size size) {
    switch (symbolKey.toLowerCase()) {
      case 'transformer':
        return TransformerIconPainter(
          color: color,
          equipmentSize: size,
          symbolSize: size,
        );
      case 'circuit breaker':
        return CircuitBreakerIconPainter(
          color: color,
          equipmentSize: size,
          symbolSize: size,
        );
      case 'current transformer':
      case 'ct':
        return CurrentTransformerIconPainter(
          color: color,
          equipmentSize: size,
          symbolSize: size,
        );
      case 'disconnector':
        return DisconnectorIconPainter(
          color: color,
          equipmentSize: size,
          symbolSize: size,
        );
      case 'ground':
        return GroundIconPainter(
          color: color,
          equipmentSize: size,
          symbolSize: size,
        );
      case 'isolator':
        return IsolatorIconPainter(
          color: color,
          equipmentSize: size,
          symbolSize: size,
        );
      case 'voltage transformer':
      case 'pt':
        return PotentialTransformerIconPainter(
          color: color,
          equipmentSize: size,
          symbolSize: size,
        );
      case 'line':
        return LineIconPainter(
          color: color,
          equipmentSize: size,
          symbolSize: size,
        );
      case 'feeder':
        return FeederIconPainter(
          color: color,
          equipmentSize: size,
          symbolSize: size,
        );
      case 'busbar':
        return BusbarIconPainter(
          color: color,
          equipmentSize: size,
          symbolSize: size,
        );
      default:
        return _GenericIconPainter(color: color); // Generic placeholder
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = Colors.black87
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final thickLinePaint =
        Paint() // New paint for thick lines (for connections)
          ..color = Colors.black87
          ..strokeWidth = 2.5
          ..style = PaintingStyle.stroke;

    final busbarPaint = Paint()
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke;

    final connectionDotPaint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.fill;

    // 1. Draw Busbars with voltage-based colors
    for (var renderData in bayRenderDataList) {
      if (renderData.bay.bayType == 'Busbar') {
        final busbarDrawingRect = busbarRects[renderData.bay.id];
        if (busbarDrawingRect != null) {
          busbarPaint.color = _getBusbarColor(renderData.bay.voltageLevel);

          canvas.drawLine(
            busbarDrawingRect.centerLeft,
            busbarDrawingRect.centerRight,
            busbarPaint,
          );
          _drawText(
            canvas,
            '${renderData.bay.voltageLevel} ${renderData.bay.name}',
            Offset(busbarDrawingRect.left - 8, busbarDrawingRect.center.dy),
            textAlign: TextAlign.right,
          );
        }
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

      // Determine connection points based on bay types and calculated positions
      if (sourceBay.bayType == 'Busbar' && targetBay.bayType == 'Transformer') {
        startPoint =
            busbarConnectionPoints[sourceBay.id]?[targetBay.id] ??
            sourceRenderData.center;
        endPoint = targetRenderData.topCenter;
      } else if (sourceBay.bayType == 'Transformer' &&
          targetBay.bayType == 'Busbar') {
        startPoint = sourceRenderData.bottomCenter;
        endPoint =
            busbarConnectionPoints[targetBay.id]?[sourceBay.id] ??
            targetRenderData.center;
      } else if (sourceBay.bayType == 'Busbar' && targetBay.bayType == 'Line') {
        startPoint =
            busbarConnectionPoints[sourceBay.id]?[targetBay.id] ??
            sourceRenderData.center;
        endPoint =
            targetRenderData.bottomCenter; // Line's bottom (closer to busbar)
      } else if (sourceBay.bayType == 'Line' && targetBay.bayType == 'Busbar') {
        startPoint = sourceRenderData.bottomCenter;
        endPoint =
            busbarConnectionPoints[targetBay.id]?[sourceBay.id] ??
            targetRenderData.center;
      } else if (sourceBay.bayType == 'Busbar' &&
          targetBay.bayType == 'Feeder') {
        startPoint =
            busbarConnectionPoints[sourceBay.id]?[targetBay.id] ??
            sourceRenderData.center;
        endPoint =
            targetRenderData.topCenter; // Feeder's top (closer to busbar)
      } else if (sourceBay.bayType == 'Feeder' &&
          targetBay.bayType == 'Busbar') {
        startPoint = sourceRenderData.topCenter;
        endPoint =
            busbarConnectionPoints[targetBay.id]?[sourceBay.id] ??
            targetRenderData.center;
      } else {
        startPoint = sourceRenderData.bottomCenter;
        endPoint = targetRenderData.topCenter;
      }

      _drawConnectionLine(
        canvas,
        startPoint,
        endPoint,
        linePaint, // Use thin linePaint for connections
        connectionDotPaint,
        sourceBay.bayType,
        targetBay.bayType,
        busbarConnectionPoints, // Pass this to the drawing function
        connection.sourceBayId,
        connection.targetBayId,
      );
    }

    // 3. Draw Symbols and Labels (and potentially sub-equipment)
    for (var renderData in bayRenderDataList) {
      final bay = renderData.bay;
      final rect = renderData.rect; // This rect is the tappable rect

      // Check if this bay is currently selected for movement
      final bool isSelectedForMovement = bay.id == selectedBayForMovementId;

      // Draw Bay's main symbol or placeholder
      if (bay.bayType == 'Transformer') {
        final painter = TransformerIconPainter(
          color: isSelectedForMovement
              ? Colors.green
              : Colors.blue, // Highlight if selected
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
        final painter = LineIconPainter(
          color: isSelectedForMovement
              ? Colors.green
              : Colors.black87, // Highlight if selected
          equipmentSize: rect.size,
          symbolSize: rect.size,
        );
        canvas.save();
        canvas.translate(rect.topLeft.dx, rect.topLeft.dy);
        painter.paint(canvas, rect.size);
        canvas.restore();
        _drawText(
          canvas,
          bay.name,
          rect.topCenter,
          offsetY: -12,
          isBold: true,
        ); // Label above the line
      } else if (bay.bayType == 'Feeder') {
        final painter = FeederIconPainter(
          color: isSelectedForMovement
              ? Colors.green
              : Colors.black87, // Highlight if selected
          equipmentSize: rect.size,
          symbolSize: rect.size,
        );
        canvas.save();
        canvas.translate(rect.topLeft.dx, rect.topLeft.dy);
        painter.paint(canvas, rect.size);
        canvas.restore();
        _drawText(
          canvas,
          bay.name,
          rect.bottomCenter,
          offsetY: 4, // Label below the line
          isBold: true,
        );
      } else if (bay.bayType != 'Busbar') {
        // For other non-busbar bays, draw a generic rectangle (or customize further)
        canvas.drawRect(
          rect,
          Paint()
            ..color = isSelectedForMovement
                ? Colors.lightGreen.shade100
                : Colors.orange.shade100
            ..style = PaintingStyle.fill,
        );
        canvas.drawRect(
          rect,
          Paint()
            ..color = isSelectedForMovement ? Colors.green : Colors.black
            ..style = PaintingStyle.stroke
            ..strokeWidth = isSelectedForMovement
                ? 2.0
                : 1.0, // Thicker border if selected
        );
        _drawText(canvas, bay.name, rect.center, isBold: true);
      }

      // NEW: Draw individual equipment within the bay's rectangle
      if (renderData.equipmentInstances.isNotEmpty) {
        // Define spacing and size for sub-equipment icons
        const double subIconSize = 25; // Smaller size for sub-equipment icons
        const double subIconSpacing = 5;

        // Calculate available space within the bay rect for sub-icons
        final double availableWidth = rect.width - (2 * subIconSpacing);
        final double startX = rect.left + subIconSpacing;
        double currentY =
            rect.top +
            (bay.bayType == 'Line' || bay.bayType == 'Feeder'
                ? 20
                : 0); // Start below main symbol/label

        // Filter and sort equipment for display
        final List<EquipmentInstance> sortedEquipment =
            List.from(renderData.equipmentInstances)..sort(
              (a, b) =>
                  (a.positionIndex ?? 999).compareTo(b.positionIndex ?? 999),
            );

        for (var equipment in sortedEquipment) {
          if (currentY + subIconSize > rect.bottom) {
            // Avoid overflowing the bay rectangle vertically
            break;
          }

          final Offset iconTopLeft = Offset(
            startX + (availableWidth - subIconSize) / 2,
            currentY,
          ); // Center horizontally
          final Rect subIconRect = Rect.fromLTWH(
            iconTopLeft.dx,
            iconTopLeft.dy,
            subIconSize,
            subIconSize,
          );

          final subPainter = _getSymbolPainter(
            equipment.symbolKey,
            Colors.black87,
            subIconRect.size,
          );
          canvas.save();
          canvas.translate(subIconRect.topLeft.dx, subIconRect.topLeft.dy);
          subPainter.paint(canvas, subIconRect.size);
          canvas.restore();

          // Optionally draw a tiny label for the sub-equipment if space allows
          _drawText(
            canvas,
            equipment.symbolKey.split(' ').first,
            subIconRect.bottomCenter,
            offsetY: 2,
            isBold: false,
            textAlign: TextAlign.center,
          );

          currentY += subIconSize + subIconSpacing;
        }
      }
    }

    // DEBUGGING STEP: Draw hitboxes if debugDrawHitboxes is true
    // if (debugDrawHitboxes) {
    //   final debugHitboxPaint = Paint()
    //     ..color = Colors.red
    //         .withOpacity(0.3) // Semi-transparent red
    //     ..style = PaintingStyle.fill;
    //   for (var renderData in bayRenderDataList) {
    //     canvas.drawRect(renderData.rect, debugHitboxPaint);
    //   }
    // }
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
    Paint linePaint, // This is the paint for the connection line itself
    Paint dotPaint,
    String sourceBayType,
    String targetBayType,
    Map<String, Map<String, Offset>> busbarConnectionPoints,
    String sourceBayId,
    String targetBayId,
  ) {
    canvas.drawLine(startPoint, endPoint, linePaint);

    // Draw dots at the busbar connection points for all non-busbar bays
    if (sourceBayType == 'Busbar' && targetBayType != 'Busbar') {
      final busConnectionPoint =
          busbarConnectionPoints[sourceBayId]?[targetBayId];
      if (busConnectionPoint != null) {
        canvas.drawCircle(busConnectionPoint, 4.0, dotPaint);
      }
    } else if (targetBayType == 'Busbar' && sourceBayType != 'Busbar') {
      final busConnectionPoint =
          busbarConnectionPoints[targetBayId]?[sourceBayId];
      if (busConnectionPoint != null) {
        canvas.drawCircle(busConnectionPoint, 4.0, dotPaint);
      }
    }

    // Draw arrowheads based on typical power flow or convention
    // I'm keeping the transformer arrow for now, as it's common.
    if ((sourceBayType == 'Busbar' && targetBayType == 'Transformer') ||
        (sourceBayType == 'Transformer' && targetBayType == 'Busbar')) {
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
  bool shouldRepaint(covariant SingleLineDiagramPainter oldDelegate) {
    // Repaint if selectedBayForMovementId changes, or if anything else changes
    return oldDelegate.selectedBayForMovementId != selectedBayForMovementId ||
        oldDelegate.bayRenderDataList != bayRenderDataList ||
        oldDelegate.bayConnections != bayConnections ||
        oldDelegate.baysMap != baysMap ||
        oldDelegate.busbarRects != busbarRects ||
        oldDelegate.busbarConnectionPoints != busbarConnectionPoints;
  }
}

// This _GenericIconPainter needs to be a top-level class, outside of any State or other class.
class _GenericIconPainter extends CustomPainter {
  final Color color;
  _GenericIconPainter({required this.color});
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
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
  bool shouldRepaint(covariant _GenericIconPainter oldDelegate) =>
      oldDelegate.color != color;
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

  final TransformationController _transformationController =
      TransformationController();

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

  // New state variables for movement
  Map<String, Offset> _bayPositions = {}; // Stores x,y for each bay ID
  String?
  _selectedBayForMovementId; // ID of the bay currently selected for movement
  static const double _movementStep =
      10.0; // How many pixels to move per button press

  // This variable needs to be accessible in _buildMovementControls, so it must be a class member
  List<BayRenderData> _currentBayRenderDataList = [];

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
    _transformationController.dispose();
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
      _selectedBayForMovementId =
          null; // Exit movement mode when changing views
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
        // Preserve existing position when editing other properties
        bayData['xPosition'] = _bayToEdit!.xPosition;
        bayData['yPosition'] = _bayToEdit!.yPosition;

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
          _initializeFormAndHierarchyForViewMode(BayDetailViewMode.list);
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
          _initializeFormAndHierarchyForViewMode(BayDetailViewMode.list);
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
    /* Placeholder for default reading assignment creation */
  }

  void _showBaySymbolActions(
    BuildContext context,
    Bay bay,
    Offset tapPosition,
  ) {
    final List<PopupMenuEntry<String>> menuItems = [
      const PopupMenuItem<String>(
        value: 'edit',
        child: ListTile(
          leading: Icon(Icons.edit),
          title: Text('Edit Bay Details'),
        ),
      ),
    ];

    if (bay.bayType != 'Busbar') {
      // Only allow movement for non-busbar bays
      menuItems.add(
        const PopupMenuItem<String>(
          value: 'move',
          child: ListTile(
            leading: Icon(Icons.open_with),
            title: Text('Move Bay'),
          ),
        ),
      );
    }

    if (bay.bayType != 'Busbar') {
      menuItems.add(
        const PopupMenuItem<String>(
          value: 'manage_equipment',
          child: ListTile(
            leading: Icon(Icons.settings),
            title: Text('Manage Equipment'),
          ),
        ),
      );
    }

    menuItems.add(
      const PopupMenuItem<String>(
        value: 'readings',
        child: ListTile(
          leading: Icon(Icons.menu_book),
          title: Text('Manage Reading Assignments'),
        ),
      ),
    );

    menuItems.add(
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
    );

    showMenu(
      context: context,
      position: RelativeRect.fromLTRB(
        tapPosition.dx,
        tapPosition.dy,
        MediaQuery.of(context).size.width - tapPosition.dx,
        MediaQuery.of(context).size.height - tapPosition.dy,
      ),
      items: menuItems,
    ).then((value) {
      if (value == 'edit') {
        _initializeFormAndHierarchyForViewMode(
          BayDetailViewMode.edit,
          bay: bay,
        );
      } else if (value == 'move') {
        setState(() {
          _selectedBayForMovementId = bay.id;
        });
        SnackBarUtils.showSnackBar(
          context,
          'Selected "${bay.name}" for movement. Use controls below.',
        );
      } else if (value == 'manage_equipment') {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => BayEquipmentManagementScreen(
              bayId: bay.id,
              bayName: bay.name,
              substationId: widget.substationId, // Pass substationId
              currentUser: widget.currentUser, // Pass currentUser
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

  // Helper to get BayRenderData from the list
  // The bayRenderDataList is now passed as an argument to ensure it's the most current.
  BayRenderData? _getBayRenderData(
    String bayId,
    List<BayRenderData> bayRenderDataList,
  ) {
    try {
      return bayRenderDataList.firstWhere((data) => data.bay.id == bayId);
    } catch (e) {
      return null;
    }
  }

  // New method to update bay position in Firestore
  Future<void> _updateBayPositionInFirestore(
    String bayId,
    Offset newPosition,
  ) async {
    try {
      await FirebaseFirestore.instance.collection('bays').doc(bayId).update({
        'xPosition': newPosition.dx,
        'yPosition': newPosition.dy,
      });
      SnackBarUtils.showSnackBar(context, 'Bay position saved!');
    } catch (e) {
      if (mounted) {
        SnackBarUtils.showSnackBar(
          context,
          'Failed to save bay position: $e',
          isError: true,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _viewMode == BayDetailViewMode.list,
      onPopInvoked: (didPop) {
        if (!didPop && _viewMode != BayDetailViewMode.list) {
          _initializeFormAndHierarchyForViewMode(BayDetailViewMode.list);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text('Substation: ${widget.substationName}'),
          actions: [
            if (_viewMode == BayDetailViewMode.list &&
                _selectedBayForMovementId == null) // Hide info when moving
              IconButton(
                icon: const Icon(Icons.info_outline),
                onPressed: () => SnackBarUtils.showSnackBar(
                  context,
                  'Viewing details for ${widget.substationName}.',
                ),
              ),
            if (_viewMode != BayDetailViewMode.list ||
                _selectedBayForMovementId !=
                    null) // Show back/cancel when in form or move mode
              IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () {
                  if (_selectedBayForMovementId != null) {
                    // If in movement mode, cancel movement
                    setState(() {
                      _selectedBayForMovementId = null;
                      _bayPositions
                          .clear(); // Clear local positions to re-read from Firestore
                    });
                    SnackBarUtils.showSnackBar(
                      context,
                      'Movement cancelled. Position not saved.',
                    );
                  } else {
                    // Otherwise, go back to list view
                    _initializeFormAndHierarchyForViewMode(
                      BayDetailViewMode.list,
                    );
                  }
                },
              ),
          ],
        ),
        body: (_viewMode == BayDetailViewMode.list)
            ? _buildSLDView()
            : _buildBayFormView(),
        floatingActionButton:
            (_viewMode == BayDetailViewMode.list &&
                _selectedBayForMovementId == null)
            ? FloatingActionButton.extended(
                onPressed: () => _initializeFormAndHierarchyForViewMode(
                  BayDetailViewMode.add,
                ),
                label: const Text('Add New Bay'),
                icon: const Icon(Icons.add),
              )
            : null,
        bottomNavigationBar: _selectedBayForMovementId != null
            ? _buildMovementControls()
            : null,
      ),
    );
  }

  Widget _buildMovementControls() {
    return Container(
      padding: const EdgeInsets.all(8.0),
      color: Colors.blueGrey.shade800,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            // Use _getBayRenderData with _currentBayRenderDataList to get the bay name
            'Moving: ${_getBayRenderData(_selectedBayForMovementId!, _currentBayRenderDataList)?.bay.name ?? "Bay"}',
            style: const TextStyle(color: Colors.white, fontSize: 16),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back),
                color: Colors.white,
                onPressed: () {
                  setState(() {
                    final currentOffset =
                        _bayPositions[_selectedBayForMovementId];
                    if (currentOffset != null) {
                      _bayPositions[_selectedBayForMovementId!] = Offset(
                        currentOffset.dx - _movementStep,
                        currentOffset.dy,
                      );
                    }
                  });
                },
              ),
              Column(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_upward),
                    color: Colors.white,
                    onPressed: () {
                      setState(() {
                        final currentOffset =
                            _bayPositions[_selectedBayForMovementId];
                        if (currentOffset != null) {
                          _bayPositions[_selectedBayForMovementId!] = Offset(
                            currentOffset.dx,
                            currentOffset.dy - _movementStep,
                          );
                        }
                      });
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.arrow_downward),
                    color: Colors.white,
                    onPressed: () {
                      setState(() {
                        final currentOffset =
                            _bayPositions[_selectedBayForMovementId];
                        if (currentOffset != null) {
                          _bayPositions[_selectedBayForMovementId!] = Offset(
                            currentOffset.dx,
                            currentOffset.dy + _movementStep,
                          );
                        }
                      });
                    },
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.arrow_forward),
                color: Colors.white,
                onPressed: () {
                  setState(() {
                    final currentOffset =
                        _bayPositions[_selectedBayForMovementId];
                    if (currentOffset != null) {
                      _bayPositions[_selectedBayForMovementId!] = Offset(
                        currentOffset.dx + _movementStep,
                        currentOffset.dy,
                      );
                    }
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 10),
          ElevatedButton(
            onPressed: () async {
              if (_selectedBayForMovementId != null &&
                  _bayPositions.containsKey(_selectedBayForMovementId!)) {
                await _updateBayPositionInFirestore(
                  _selectedBayForMovementId!,
                  _bayPositions[_selectedBayForMovementId!]!,
                );
              }
              setState(() {
                _selectedBayForMovementId = null;
                _bayPositions
                    .clear(); // Clear local cache to re-read from Firestore on next load
              });
            },
            child: const Text('Done Moving & Save'),
          ),
        ],
      ),
    );
  }

  Widget _buildSLDView() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('bays')
          .where('substationId', isEqualTo: widget.substationId)
          .snapshots(),
      builder: (context, baysSnapshot) {
        if (baysSnapshot.hasError) {
          return Center(child: Text('Error: ${baysSnapshot.error}'));
        }
        if (baysSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
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

        // Initialize _bayPositions from Firestore data on initial load
        // Only do this if we are not actively moving a bay, otherwise
        // the local _bayPositions map would be overwritten by old data.
        if (_selectedBayForMovementId == null && _bayPositions.isEmpty) {
          for (var bay in allBays) {
            if (bay.xPosition != null && bay.yPosition != null) {
              _bayPositions[bay.id] = Offset(bay.xPosition!, bay.yPosition!);
            }
          }
        }

        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('bay_connections')
              .where('substationId', isEqualTo: widget.substationId)
              .snapshots(),
          builder: (context, connectionsSnapshot) {
            if (connectionsSnapshot.hasError) {
              return Center(child: Text('Error: ${connectionsSnapshot.error}'));
            }
            if (connectionsSnapshot.connectionState ==
                ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final allConnections =
                connectionsSnapshot.data?.docs
                    .map((doc) => BayConnection.fromFirestore(doc))
                    .toList() ??
                [];

            // NEW: Fetch all equipment instances for this substation
            return StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('equipmentInstances')
                  .where(
                    'substationId',
                    isEqualTo: widget.substationId,
                  ) // Ensure substationId is saved on equipment instance
                  .snapshots(),
              builder: (context, equipmentSnapshot) {
                if (equipmentSnapshot.hasError) {
                  return Center(
                    child: Text('Error: ${equipmentSnapshot.error}'),
                  );
                }
                if (equipmentSnapshot.connectionState ==
                    ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final allEquipmentInstances =
                    equipmentSnapshot.data?.docs
                        .map((doc) => EquipmentInstance.fromFirestore(doc))
                        .toList() ??
                    [];

                // Group equipment instances by bayId for easy lookup
                final Map<String, List<EquipmentInstance>> equipmentByBayId =
                    {};
                for (var eq in allEquipmentInstances) {
                  equipmentByBayId.putIfAbsent(eq.bayId, () => []).add(eq);
                }

                final bayRenderDataList = <BayRenderData>[];
                final busbarRects =
                    <
                      String,
                      Rect
                    >{}; // Used by painter for drawing busbar lines
                final busbarConnectionPoints = <String, Map<String, Offset>>{};

                const double symbolWidth = 60;
                const double symbolHeight = 60;
                const double horizontalSpacing = 100;
                const double verticalBusbarSpacing = 200;
                const double topPadding = 80;
                const double sidePadding = 100;
                const double busbarHitboxHeight = 20.0;
                const double lineFeederHeight = 40.0;

                final busbars = allBays
                    .where((b) => b.bayType == 'Busbar')
                    .toList();
                busbars.sort((a, b) {
                  double getV(String v) =>
                      double.tryParse(v.replaceAll(RegExp(r'[^0-9.]'), '')) ??
                      0;
                  return getV(b.voltageLevel).compareTo(getV(a.voltageLevel));
                });

                Map<String, double> busYPositions = {};
                for (int i = 0; i < busbars.length; i++) {
                  busYPositions[busbars[i].id] =
                      topPadding + i * verticalBusbarSpacing;
                }

                // Group bays connected to busbars
                Map<String, List<Bay>> busbarToConnectedBaysAbove = {}; // Lines
                Map<String, List<Bay>> busbarToConnectedBaysBelow =
                    {}; // Feeders, others
                // Map transformers by their HV and LV bus IDs
                Map<String, Map<String, List<Bay>>> transformersByBusPair = {};

                for (var bay in allBays) {
                  if (bay.bayType == 'Transformer') {
                    if (bay.hvBusId != null && bay.lvBusId != null) {
                      final hvBus = baysMap[bay.hvBusId];
                      final lvBus = baysMap[bay.lvBusId];
                      if (hvBus != null && lvBus != null) {
                        // Extract voltage values safely
                        final double hvVoltage =
                            double.tryParse(
                              hvBus.voltageLevel.replaceAll(
                                RegExp(r'[^0-9.]'),
                                '',
                              ),
                            ) ??
                            0;
                        final double lvVoltage =
                            double.tryParse(
                              lvBus.voltageLevel.replaceAll(
                                RegExp(r'[^0-9.]'),
                                '',
                              ),
                            ) ??
                            0;

                        String key = "";
                        // Now the condition is clearly boolean
                        if (hvVoltage > lvVoltage) {
                          key = "${hvBus.id}-${lvBus.id}";
                        } else {
                          key = "${lvBus.id}-${hvBus.id}";
                        }
                        transformersByBusPair
                            .putIfAbsent(key, () => {})
                            .putIfAbsent(
                              hvBus.id,
                              () => [],
                            ) // Store by actual HV bus ID for later retrieval
                            .add(bay);
                      }
                    }
                  } else if (bay.bayType != 'Busbar') {
                    final connectionToBus = allConnections.firstWhereOrNull((
                      c,
                    ) {
                      final sourceIsBay = c.sourceBayId == bay.id;
                      final targetIsBay = c.targetBayId == bay.id;
                      final sourceIsBus =
                          baysMap[c.sourceBayId]?.bayType == 'Busbar';
                      final targetIsBus =
                          baysMap[c.targetBayId]?.bayType == 'Busbar';

                      return (sourceIsBay && targetIsBus) ||
                          (targetIsBay && sourceIsBus);
                    });

                    if (connectionToBus != null) {
                      String connectedBusId =
                          baysMap[connectionToBus.sourceBayId]?.bayType ==
                              'Busbar'
                          ? connectionToBus.sourceBayId
                          : connectionToBus.targetBayId;

                      if (bay.bayType == 'Line') {
                        busbarToConnectedBaysAbove
                            .putIfAbsent(connectedBusId, () => [])
                            .add(bay);
                      } else {
                        busbarToConnectedBaysBelow
                            .putIfAbsent(connectedBusId, () => [])
                            .add(bay);
                      }
                    }
                  }
                }

                // Sort the connected bays for consistent rendering
                busbarToConnectedBaysAbove.forEach(
                  (key, value) =>
                      value.sort((a, b) => a.name.compareTo(b.name)),
                );
                busbarToConnectedBaysBelow.forEach(
                  (key, value) =>
                      value.sort((a, b) => a.name.compareTo(b.name)),
                );
                transformersByBusPair.forEach((pairKey, transformersMap) {
                  transformersMap.forEach((busId, transformers) {
                    transformers.sort((a, b) => a.name.compareTo(b.name));
                  });
                });

                Map<String, Rect> finalBayRects = {};
                double maxOverallXForCanvas =
                    sidePadding; // Tracks the maximum X coordinate used for layout

                // Store horizontal offsets for transformers for drawing connections later
                Map<String, double> transformerColumnX = {};
                double nextTransformerX =
                    sidePadding; // Starting X for the first transformer column

                // Pre-calculate transformer positions to ensure they are grouped together
                // and determine the maximum X for other bays
                List<Bay> placedTransformers = [];
                for (var busPairEntry in transformersByBusPair.entries) {
                  final String pairKey = busPairEntry.key;
                  final Map<String, List<Bay>> transformersForPair =
                      busPairEntry.value;

                  // Find the HV bus and LV bus from the pair key to get their Y positions
                  List<String> busIdsInPair = pairKey.split('-');
                  String hvBusId = busIdsInPair[0];
                  String lvBusId = busIdsInPair[1];

                  // Safely get the Bay objects for the bus IDs
                  final Bay? currentHvBus = baysMap[hvBusId];
                  final Bay? currentLvBus = baysMap[lvBusId];

                  if (currentHvBus != null && currentLvBus != null) {
                    // Parse voltage levels safely for comparison
                    final double hvVoltageValue =
                        double.tryParse(
                          currentHvBus.voltageLevel.replaceAll(
                            RegExp(r'[^0-9.]'),
                            '',
                          ),
                        ) ??
                        0;
                    final double lvVoltageValue =
                        double.tryParse(
                          currentLvBus.voltageLevel.replaceAll(
                            RegExp(r'[^0-9.]'),
                            '',
                          ),
                        ) ??
                        0;

                    String key = "";
                    // Now the condition is clearly boolean
                    if (hvVoltageValue < lvVoltageValue) {
                      // Compare the actual double values
                      String temp = hvBusId;
                      hvBusId = lvBusId;
                      lvBusId = temp;
                    }
                  } else {
                    // Handle cases where a bus ID in the pair key is invalid/missing in baysMap
                    // This could indicate a data inconsistency. You might want to log this or skip.
                    debugPrint(
                      'Warning: One of the bus IDs (${hvBusId}, ${lvBusId}) in bus pair key ${pairKey} not found in baysMap.',
                    );
                    continue; // Skip this transformer pair if buses are not found
                  }

                  final double hvBusY = busYPositions[hvBusId]!;
                  final double lvBusY = busYPositions[lvBusId]!;

                  final List<Bay> transformers =
                      transformersForPair[hvBusId] ??
                      transformersForPair[lvBusId] ??
                      [];
                  for (var tf in transformers) {
                    if (!placedTransformers.contains(tf)) {
                      // Prevent placing the same transformer twice
                      Offset calculatedOffset = Offset(
                        nextTransformerX + symbolWidth / 2,
                        (hvBusY + lvBusY) /
                            2, // Vertically center between HV and LV bus
                      );

                      // Use stored position if available (from _bayPositions map), otherwise calculate
                      // If we are actively moving this bay, use the _bayPositions value.
                      // Otherwise, if bay.xPosition/yPosition are available, use them.
                      // Else, use the calculated default.
                      Offset finalOffset =
                          _bayPositions[tf.id] ??
                          (tf.xPosition != null && tf.yPosition != null
                              ? Offset(tf.xPosition!, tf.yPosition!)
                              : calculatedOffset);

                      // Update _bayPositions if it's currently using default, so movement buttons work on it
                      if (!_bayPositions.containsKey(tf.id) &&
                          (tf.xPosition == null || tf.yPosition == null)) {
                        _bayPositions[tf.id] = finalOffset;
                      }

                      final tfRect = Rect.fromCenter(
                        center: finalOffset,
                        width: symbolWidth,
                        height: symbolHeight,
                      );
                      finalBayRects[tf.id] = tfRect;
                      transformerColumnX[tf.id] =
                          finalOffset.dx; // Store center X
                      nextTransformerX += horizontalSpacing;
                      placedTransformers.add(tf);
                      maxOverallXForCanvas = max(
                        maxOverallXForCanvas,
                        tfRect.right,
                      );
                    }
                  }
                }

                // Now place other bays (Lines, Feeders, etc.)
                // This `currentLaneX` will now start *after* the transformers
                double currentLaneXForOtherBays =
                    nextTransformerX; // Start after transformers

                for (var busbar in busbars) {
                  final busY = busYPositions[busbar.id]!;

                  // Place Bays above this busbar (Lines)
                  final baysAbove = busbarToConnectedBaysAbove[busbar.id] ?? [];
                  double currentX =
                      currentLaneXForOtherBays; // Use a temporary X for this busbar's lane
                  for (var bay in baysAbove) {
                    Offset calculatedOffset = Offset(
                      currentX,
                      busY - lineFeederHeight - 10, // Place above the busbar
                    );
                    // Use stored position if available, otherwise calculate
                    Offset finalOffset =
                        _bayPositions[bay.id] ??
                        (bay.xPosition != null && bay.yPosition != null
                            ? Offset(bay.xPosition!, bay.yPosition!)
                            : calculatedOffset);

                    // Update _bayPositions if it's currently using default
                    if (!_bayPositions.containsKey(bay.id) &&
                        (bay.xPosition == null || bay.yPosition == null)) {
                      _bayPositions[bay.id] = finalOffset;
                    }

                    final bayRect = Rect.fromLTWH(
                      finalOffset.dx,
                      finalOffset.dy,
                      symbolWidth,
                      lineFeederHeight,
                    );
                    finalBayRects[bay.id] = bayRect;
                    currentX += horizontalSpacing;
                  }
                  maxOverallXForCanvas = max(maxOverallXForCanvas, currentX);

                  // Place Bays below this busbar (Feeders, etc.)
                  final baysBelow = busbarToConnectedBaysBelow[busbar.id] ?? [];
                  currentX = currentLaneXForOtherBays; // Reset for below bays
                  for (var bay in baysBelow) {
                    Offset calculatedOffset = Offset(
                      currentX,
                      busY + 10, // Place below the busbar
                    );
                    // Use stored position if available, otherwise calculate
                    Offset finalOffset =
                        _bayPositions[bay.id] ??
                        (bay.xPosition != null && bay.yPosition != null
                            ? Offset(bay.xPosition!, bay.yPosition!)
                            : calculatedOffset);

                    // Update _bayPositions if it's currently using default
                    if (!_bayPositions.containsKey(bay.id) &&
                        (bay.xPosition == null || bay.yPosition == null)) {
                      _bayPositions[bay.id] = finalOffset;
                    }

                    final bayRect = Rect.fromLTWH(
                      finalOffset.dx,
                      finalOffset.dy,
                      symbolWidth,
                      lineFeederHeight,
                    );
                    finalBayRects[bay.id] = bayRect;
                    currentX += horizontalSpacing;
                  }
                  maxOverallXForCanvas = max(maxOverallXForCanvas, currentX);
                }

                // After all bays are placed and maxOverallXForCanvas is determined,
                // now determine the actual drawing/tappable rect for busbars based on
                // the max X used by bays connected to them.
                for (var busbar in busbars) {
                  final busY = busYPositions[busbar.id]!;
                  double maxConnectedBayX =
                      sidePadding; // Start from left padding

                  // Consider all bays connected to this busbar when determining its width
                  // This includes transformers (both HV and LV side connections) and other bays
                  allBays.where((b) => b.bayType != 'Busbar').forEach((bay) {
                    if (bay.bayType == 'Transformer') {
                      if ((bay.hvBusId == busbar.id ||
                              bay.lvBusId == busbar.id) &&
                          finalBayRects.containsKey(bay.id)) {
                        maxConnectedBayX = max(
                          maxConnectedBayX,
                          finalBayRects[bay.id]!.right,
                        );
                      }
                    } else {
                      // Lines, Feeders, etc.
                      final connectionToBus = allConnections.firstWhereOrNull((
                        c,
                      ) {
                        return (c.sourceBayId == bay.id &&
                                c.targetBayId == busbar.id) ||
                            (c.targetBayId == bay.id &&
                                c.sourceBayId == busbar.id);
                      });
                      if (connectionToBus != null &&
                          finalBayRects.containsKey(bay.id)) {
                        maxConnectedBayX = max(
                          maxConnectedBayX,
                          finalBayRects[bay.id]!.right,
                        );
                      }
                    }
                  });

                  final effectiveBusWidth = max(
                    maxConnectedBayX -
                        sidePadding +
                        horizontalSpacing, // Ensure enough width for connected bays
                    symbolWidth * 2, // Minimum width for a busbar itself
                  ).toDouble();

                  // Drawing rectangle for the busbar line
                  final drawingRect = Rect.fromLTWH(
                    sidePadding,
                    busY,
                    effectiveBusWidth,
                    0, // Busbar is a line, so 0 height for drawing purposes, but strokeWidth makes it visible
                  );
                  busbarRects[busbar.id] = drawingRect;

                  // Tappable rectangle for the busbar. This needs a height.
                  final tappableRect = Rect.fromCenter(
                    center: Offset(sidePadding + effectiveBusWidth / 2, busY),
                    width: effectiveBusWidth,
                    height: busbarHitboxHeight, // Use the defined hitbox height
                  );
                  finalBayRects[busbar.id] = tappableRect;
                }

                // Populate bayRenderDataList after all finalBayRects are determined
                for (var bay in allBays) {
                  final rect = finalBayRects[bay.id];
                  if (rect != null) {
                    bayRenderDataList.add(
                      BayRenderData(
                        bay: bay,
                        rect: rect,
                        center: rect.center,
                        topCenter: rect.topCenter,
                        bottomCenter: rect.bottomCenter,
                        leftCenter: rect.centerLeft,
                        rightCenter: rect.centerRight,
                        equipmentInstances:
                            equipmentByBayId[bay.id] ??
                            [], // Pass equipment for this bay
                      ),
                    );
                  }
                }

                // --- FIX FOR UNDEFINED NAME ---
                // Assign the generated list to _currentBayRenderDataList here
                // It must be done within the builder to ensure it's always up-to-date
                // with the current snapshot data.
                _currentBayRenderDataList = bayRenderDataList;
                // --- END FIX ---

                // Recalculate busbar connection points for transformers based on their new fixed X positions
                for (var connection in allConnections) {
                  final sourceBay = baysMap[connection.sourceBayId];
                  final targetBay = baysMap[connection.targetBayId];
                  if (sourceBay == null || targetBay == null) continue;

                  // If source is a Busbar and target is a Transformer (HV side)
                  if (sourceBay.bayType == 'Busbar' &&
                      targetBay.bayType == 'Transformer') {
                    final targetRect = finalBayRects[targetBay.id];
                    final busY = busYPositions[sourceBay.id];
                    if (targetRect != null && busY != null) {
                      busbarConnectionPoints.putIfAbsent(
                        sourceBay.id,
                        () => {},
                      )[targetBay.id] = Offset(
                        targetRect.center.dx, // Transformer's center X
                        busY, // Busbar's Y
                      );
                    }
                  }
                  // If target is a Busbar and source is a Transformer (LV side)
                  else if (targetBay.bayType == 'Busbar' &&
                      sourceBay.bayType == 'Transformer') {
                    final sourceRect = finalBayRects[sourceBay.id];
                    final busY = busYPositions[targetBay.id];
                    if (sourceRect != null && busY != null) {
                      busbarConnectionPoints.putIfAbsent(
                        targetBay.id,
                        () => {},
                      )[sourceBay.id] = Offset(
                        sourceRect.center.dx, // Transformer's center X
                        busY, // Busbar's Y
                      );
                    }
                  }
                  // For other connections (Line/Feeder to Busbar)
                  else if (sourceBay.bayType == 'Busbar' &&
                      targetBay.bayType != 'Busbar') {
                    final targetRect = finalBayRects[targetBay.id];
                    final busY = busYPositions[sourceBay.id];
                    if (targetRect != null && busY != null) {
                      busbarConnectionPoints.putIfAbsent(
                        sourceBay.id,
                        () => {},
                      )[targetBay.id] = Offset(
                        targetRect
                            .center
                            .dx, // Align X with the center of the connected bay
                        busY, // Align Y with the busbar
                      );
                    }
                  } else if (targetBay.bayType == 'Busbar' &&
                      sourceBay.bayType != 'Busbar') {
                    final sourceRect = finalBayRects[sourceBay.id];
                    final busY = busYPositions[targetBay.id];
                    if (sourceRect != null && busY != null) {
                      busbarConnectionPoints.putIfAbsent(
                        targetBay.id,
                        () => {},
                      )[sourceBay.id] = Offset(
                        sourceRect
                            .center
                            .dx, // Align X with the center of the connected bay
                        busY, // Align Y with the busbar
                      );
                    }
                  }
                }

                double canvasWidth = maxOverallXForCanvas + sidePadding + 50;
                double canvasHeight = busYPositions.values.isNotEmpty
                    ? busYPositions.values.last +
                          verticalBusbarSpacing / 2 +
                          100
                    : topPadding + verticalBusbarSpacing;

                canvasWidth = max(
                  MediaQuery.of(context).size.width,
                  canvasWidth,
                );
                canvasHeight = max(
                  MediaQuery.of(context).size.height,
                  canvasHeight,
                );

                return InteractiveViewer(
                  transformationController: _transformationController,
                  boundaryMargin: const EdgeInsets.all(double.infinity),
                  minScale: 0.1,
                  maxScale: 4.0,
                  constrained:
                      false, // Allows content to exceed viewport bounds
                  child: GestureDetector(
                    onTapUp: (details) {
                      // Important: Get the local position relative to the CustomPaint
                      // and then transform it to the scene coordinate system.
                      final RenderBox renderBox =
                          context.findRenderObject() as RenderBox;
                      final Offset localPosition = renderBox.globalToLocal(
                        details.globalPosition,
                      );
                      final scenePosition = _transformationController.toScene(
                        localPosition,
                      );

                      final tappedBay = _currentBayRenderDataList.firstWhere(
                        (data) => data.rect.contains(scenePosition),
                        orElse: _createDummyBayRenderData,
                      );

                      if (tappedBay.bay.id != 'dummy') {
                        debugPrint(
                          'Tapped Bay: ${tappedBay.bay.name} at ${scenePosition}',
                        ); // Debug print
                        // If a bay is selected for movement, tapping on it again or another bay does nothing
                        // If no bay is selected for movement, proceed to edit mode
                        if (_selectedBayForMovementId == null) {
                          _initializeFormAndHierarchyForViewMode(
                            BayDetailViewMode.edit,
                            bay: tappedBay.bay,
                          );
                        }
                      } else {
                        debugPrint(
                          'Tapped: No Bay found at ${scenePosition}',
                        ); // Debug print
                        // If not tapping on a bay, and a bay is selected for movement, this means user tapped outside to deselect
                        if (_selectedBayForMovementId != null) {
                          setState(() {
                            _selectedBayForMovementId = null;
                            _bayPositions
                                .clear(); // Clear local cache to re-read from Firestore
                          });
                          SnackBarUtils.showSnackBar(
                            context,
                            'Movement cancelled. Position not saved.',
                          );
                        }
                      }
                    },
                    onLongPressStart: (details) {
                      // Important: Get the local position relative to the CustomPaint
                      // and then transform it to the scene coordinate system.
                      final RenderBox renderBox =
                          context.findRenderObject() as RenderBox;
                      final Offset localPosition = renderBox.globalToLocal(
                        details.globalPosition,
                      );
                      final scenePosition = _transformationController.toScene(
                        localPosition,
                      );

                      final tappedBay = _currentBayRenderDataList.firstWhere(
                        (data) => data.rect.contains(scenePosition),
                        orElse: _createDummyBayRenderData,
                      );
                      if (tappedBay.bay.id != 'dummy') {
                        debugPrint(
                          'Long Pressed Bay: ${tappedBay.bay.name} at ${scenePosition}',
                        ); // Debug print
                        _showBaySymbolActions(
                          context,
                          tappedBay.bay,
                          details
                              .globalPosition, // Use global position for menu
                        );
                      } else {
                        debugPrint(
                          'Long pressed: No Bay found at ${scenePosition}',
                        ); // Debug print
                      }
                    },
                    child: CustomPaint(
                      size: Size(canvasWidth, canvasHeight),
                      painter: SingleLineDiagramPainter(
                        bayRenderDataList:
                            _currentBayRenderDataList, // Pass the assigned list
                        bayConnections: allConnections,
                        baysMap: baysMap,
                        createDummyBayRenderData: _createDummyBayRenderData,
                        busbarRects: busbarRects,
                        busbarConnectionPoints: busbarConnectionPoints,
                        debugDrawHitboxes:
                            true, // KEEP THIS TRUE FOR TESTING! Set to false later.
                        selectedBayForMovementId:
                            _selectedBayForMovementId, // Pass the selected ID to the painter
                      ),
                    ),
                  ),
                );
              },
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
              onChanged: (v) => setState(() {
                _selectedBayType = v;
                if (v != 'Feeder') {
                  _isGovernmentFeeder = false;
                  _selectedFeederType = null;
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

extension IterableExtension<T> on Iterable<T> {
  T? firstWhereOrNull(bool Function(T element) test) {
    for (var element in this) {
      if (test(element)) {
        return element;
      }
    }
    return null;
  }
}
