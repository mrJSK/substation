// lib/models/bay_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart'; // Import flutter material for Color and Size and Offset
// NEW: Import the sld_models to use SldNode, SldNodeShape, SldConnectionPoint, etc.
import './sld_models.dart';
// Keep existing imports as per your provided code
// import './equipment_model.dart'; // Assuming this is imported if used directly here, but not in provided snippet

// NEW: Define the BayType enum if it's not globally defined elsewhere
// (It's crucial for `bayType` property to be an enum for type safety and clarity)
enum BayType {
  Busbar,
  Transformer,
  Line,
  Feeder,
  CapacitorBank,
  Reactor,
  BusCoupler,
  Battery,
  // Add other types as needed
}

class Bay {
  final String id;
  final String name;
  final String substationId;
  final String voltageLevel;
  // MODIFIED: Change bayType from String to BayType enum
  final BayType bayType; // Changed type from String to enum
  final String createdBy;
  final Timestamp createdAt;
  final String? description;
  final String? landmark;
  final String? contactNumber;
  final String? contactPerson;
  final bool? isGovernmentFeeder;
  final String? feederType;
  final double? multiplyingFactor;
  final String? bayNumber;
  final double? lineLength; // Assuming this is the field for line length (km)
  final String? circuitType;
  final String? conductorType;
  final String? conductorDetail;
  final Timestamp? erectionDate;
  final String? hvVoltage;
  final String? lvVoltage;
  final String? make;
  final double? capacity; // Assuming this is the field for capacity (MVA)
  final Timestamp? manufacturingDate;
  final String? hvBusId;
  final String? lvBusId;
  final Timestamp? commissioningDate;
  final double? xPosition;
  final double? yPosition;
  final double? busbarLength;
  final Offset? textOffset;
  final Offset? energyTextOffset; // New field for energy text
  final String? distributionZoneId;
  final String? distributionCircleId;
  final String? distributionDivisionId;
  final String? distributionSubdivisionId;

  // NEW: Default SLD Node properties for this Bay Type (for new requirement)
  final Map<String, dynamic>? defaultSldNodeProperties;

  Bay({
    required this.id,
    required this.name,
    required this.substationId,
    required this.voltageLevel,
    // MODIFIED: Accept BayType enum in constructor
    required this.bayType,
    required this.createdBy,
    required this.createdAt,
    this.description,
    this.landmark,
    this.contactNumber,
    this.contactPerson,
    this.isGovernmentFeeder,
    this.feederType,
    this.multiplyingFactor,
    this.bayNumber,
    this.lineLength,
    this.circuitType,
    this.conductorType,
    this.conductorDetail,
    this.erectionDate,
    this.hvVoltage,
    this.lvVoltage,
    this.make,
    this.capacity,
    this.manufacturingDate,
    this.hvBusId,
    this.lvBusId,
    this.commissioningDate,
    this.xPosition,
    this.yPosition,
    this.busbarLength,
    this.textOffset,
    this.energyTextOffset, // Add to constructor
    this.distributionZoneId,
    this.distributionCircleId,
    this.distributionDivisionId,
    this.distributionSubdivisionId,
    this.defaultSldNodeProperties,
    double? lineLengthKm,
    double? capacityMVA, // NEW: Add to constructor
  });

  factory Bay.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return Bay(
      id: doc.id,
      name: data['name'] ?? '',
      substationId: data['substationId'] ?? '',
      voltageLevel: data['voltageLevel'] ?? '',
      // MODIFIED: Convert string from Firestore to BayType enum
      bayType: BayType.values.firstWhere(
        (e) => e.toString().split('.').last == data['bayType'],
        orElse: () => BayType.Feeder,
      ), // Provide a default if not found
      createdBy: data['createdBy'] ?? '',
      createdAt: data['createdAt'] ?? Timestamp.now(),
      description: data['description'],
      landmark: data['landmark'],
      contactNumber: data['contactNumber'],
      contactPerson: data['contactPerson'],
      isGovernmentFeeder: data['isGovernmentFeeder'],
      feederType: data['feederType'],
      multiplyingFactor: (data['multiplyingFactor'] as num?)?.toDouble(),
      bayNumber: data['bayNumber'],
      lineLength: (data['lineLength'] as num?)
          ?.toDouble(), // Assuming lineLength is in km
      circuitType: data['circuitType'],
      conductorType: data['conductorType'],
      conductorDetail: data['conductorDetail'],
      erectionDate: data['erectionDate'],
      hvVoltage: data['hvVoltage'],
      lvVoltage: data['lvVoltage'],
      make: data['make'],
      capacity: (data['capacity'] as num?)
          ?.toDouble(), // Assuming capacity is in MVA
      manufacturingDate: data['manufacturingDate'],
      hvBusId: data['hvBusId'] as String?,
      lvBusId: data['lvBusId'] as String?,
      commissioningDate: data['commissioningDate'],
      xPosition: (data['xPosition'] as num?)?.toDouble(),
      yPosition: (data['yPosition'] as num?)?.toDouble(),
      busbarLength: (data['busbarLength'] as num?)?.toDouble(),
      textOffset: data['textOffset'] != null
          ? Offset(
              (data['textOffset']['dx'] as num).toDouble(),
              (data['textOffset']['dy'] as num).toDouble(),
            )
          : null,
      energyTextOffset: data['energyTextOffset'] != null
          ? Offset(
              (data['energyTextOffset']['dx'] as num).toDouble(),
              (data['energyTextOffset']['dy'] as num).toDouble(),
            )
          : null,
      distributionZoneId: data['distributionZoneId'] as String?,
      distributionCircleId: data['distributionCircleId'] as String?,
      distributionDivisionId: data['distributionDivisionId'] as String?,
      distributionSubdivisionId: data['distributionSubdivisionId'] as String?,
      // NEW: Deserialize defaultSldNodeProperties
      defaultSldNodeProperties:
          (data['defaultSldNodeProperties'] as Map<String, dynamic>?)
              ?.cast<String, dynamic>(),
    );
  }

  // MODIFIED: Rename to toJson() for consistency with Firestore best practices
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'substationId': substationId,
      'voltageLevel': voltageLevel,
      // MODIFIED: Convert BayType enum to its string representation for Firestore
      'bayType': bayType.toString().split('.').last,
      'createdBy': createdBy,
      'createdAt': createdAt,
      'description': description,
      'landmark': landmark,
      'contactNumber': contactNumber,
      'contactPerson': contactPerson,
      'isGovernmentFeeder': isGovernmentFeeder,
      'feederType': feederType,
      'multiplyingFactor': multiplyingFactor,
      'bayNumber': bayNumber,
      'lineLength': lineLength, // Harmonized name
      'circuitType': circuitType,
      'conductorType': conductorType,
      'conductorDetail': conductorDetail,
      'erectionDate': erectionDate,
      'hvVoltage': hvVoltage,
      'lvVoltage': lvVoltage,
      'make': make,
      'capacity': capacity, // Harmonized name
      'manufacturingDate': manufacturingDate,
      'hvBusId': hvBusId,
      'lvBusId': lvBusId,
      'commissioningDate': commissioningDate,
      'xPosition': xPosition,
      'yPosition': yPosition,
      'busbarLength': busbarLength,
      'textOffset': textOffset != null
          ? {'dx': textOffset!.dx, 'dy': textOffset!.dy}
          : null,
      'energyTextOffset': energyTextOffset != null
          ? {'dx': energyTextOffset!.dx, 'dy': energyTextOffset!.dy}
          : null,
      'distributionZoneId': distributionZoneId,
      'distributionCircleId': distributionCircleId,
      'distributionDivisionId': distributionDivisionId,
      'distributionSubdivisionId': distributionSubdivisionId,
      // NEW: Serialize defaultSldNodeProperties
      'defaultSldNodeProperties': defaultSldNodeProperties,
    };
  }

  Bay copyWith({
    String? id,
    String? name,
    String? substationId,
    String? voltageLevel,
    // MODIFIED: Accept BayType enum in copyWith
    BayType? bayType,
    String? createdBy,
    Timestamp? createdAt,
    String? description,
    String? landmark,
    String? contactNumber,
    String? contactPerson,
    bool? isGovernmentFeeder,
    String? feederType,
    double? multiplyingFactor,
    String? bayNumber,
    double? lineLength, // Harmonized name
    String? circuitType,
    String? conductorType,
    String? conductorDetail,
    Timestamp? erectionDate,
    String? hvVoltage,
    String? lvVoltage,
    String? make,
    double? capacity, // Harmonized name
    Timestamp? manufacturingDate,
    String? hvBusId,
    String? lvBusId,
    Timestamp? commissioningDate,
    double? xPosition,
    double? yPosition,
    double? busbarLength,
    Offset? textOffset,
    Offset? energyTextOffset,
    String? distributionZoneId,
    String? distributionCircleId,
    String? distributionDivisionId,
    String? distributionSubdivisionId,
    // NEW: Add defaultSldNodeProperties to copyWith
    Map<String, dynamic>? defaultSldNodeProperties,
    double? lineLengthKm,
    double? capacityMVA,
  }) {
    return Bay(
      id: id ?? this.id,
      name: name ?? this.name,
      substationId: substationId ?? this.substationId,
      voltageLevel: voltageLevel ?? this.voltageLevel,
      // MODIFIED: Use enum directly
      bayType: bayType ?? this.bayType,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      description: description ?? this.description,
      landmark: landmark ?? this.landmark,
      contactNumber: contactNumber ?? this.contactNumber,
      contactPerson: contactPerson ?? this.contactPerson,
      isGovernmentFeeder: isGovernmentFeeder ?? this.isGovernmentFeeder,
      feederType: feederType ?? this.feederType,
      multiplyingFactor: multiplyingFactor ?? this.multiplyingFactor,
      bayNumber: bayNumber ?? this.bayNumber,
      lineLength: lineLength ?? this.lineLength, // Harmonized name
      circuitType: circuitType ?? this.circuitType,
      conductorType: conductorType ?? this.conductorType,
      conductorDetail: conductorDetail ?? this.conductorDetail,
      erectionDate: erectionDate ?? this.erectionDate,
      hvVoltage: hvVoltage ?? this.hvVoltage,
      lvVoltage: lvVoltage ?? this.lvVoltage,
      make: make ?? this.make,
      capacity: capacity ?? this.capacity, // Harmonized name
      manufacturingDate: manufacturingDate ?? this.manufacturingDate,
      hvBusId: hvBusId ?? this.hvBusId,
      lvBusId: lvBusId ?? this.lvBusId,
      commissioningDate: commissioningDate ?? this.commissioningDate,
      xPosition: xPosition ?? this.xPosition,
      yPosition: yPosition ?? this.yPosition,
      busbarLength: busbarLength ?? this.busbarLength,
      textOffset: textOffset ?? this.textOffset,
      energyTextOffset: energyTextOffset ?? this.energyTextOffset,
      distributionZoneId: distributionZoneId ?? this.distributionZoneId,
      distributionCircleId: distributionCircleId ?? this.distributionCircleId,
      distributionDivisionId:
          distributionDivisionId ?? this.distributionDivisionId,
      distributionSubdivisionId:
          distributionSubdivisionId ?? this.distributionSubdivisionId,
      // NEW: Add defaultSldNodeProperties to copyWith
      defaultSldNodeProperties:
          defaultSldNodeProperties ?? this.defaultSldNodeProperties,
    );
  }

  // NEW: Helper method to create an SldNode from this Bay (for SLD builder)
  SldNode toSldNode({
    required Offset position,
    Size? size,
    Map<String, dynamic>? additionalProperties,
  }) {
    final SldNodeShape nodeShape;
    final Map<String, SldConnectionPoint> connectionPoints;
    final double defaultWidth;
    final double defaultHeight;

    // Determine default shape, size, and connection points based on bay type
    switch (bayType) {
      case BayType.Busbar:
        nodeShape = SldNodeShape.busbar;
        defaultWidth = 150;
        defaultHeight = 40;
        connectionPoints = SldNode.createRectConnectionPoints(
          Size(defaultWidth, defaultHeight),
        );
        break;
      case BayType.Transformer:
        nodeShape = SldNodeShape.custom; // Will use a custom icon painter
        defaultWidth = 80;
        defaultHeight = 100;
        // Example: Specific connection points for a transformer HV/LV side
        connectionPoints = {
          'hv_top': SldConnectionPoint(
            id: 'hv_top',
            localOffset: Offset(defaultWidth / 2, 0),
            direction: ConnectionDirection.north,
          ),
          'lv_bottom': SldConnectionPoint(
            id: 'lv_bottom',
            localOffset: Offset(defaultWidth / 2, defaultHeight),
            direction: ConnectionDirection.south,
          ),
        };
        break;
      case BayType.Line:
      case BayType.Feeder:
        nodeShape = SldNodeShape.custom; // Will use a custom icon painter
        defaultWidth = 60;
        defaultHeight = 80;
        connectionPoints = SldNode.createRectConnectionPoints(
          Size(defaultWidth, defaultHeight),
        );
        break;
      case BayType.CapacitorBank: // Added specific cases for other BayTypes
      case BayType.Reactor:
      case BayType.BusCoupler:
      case BayType.Battery:
        nodeShape = SldNodeShape.custom; // Assume custom icon for these too
        defaultWidth = 80;
        defaultHeight = 80;
        connectionPoints = SldNode.createRectConnectionPoints(
          Size(defaultWidth, defaultHeight),
        );
        break;
      default:
        nodeShape = SldNodeShape.rectangle; // Fallback
        defaultWidth = 100;
        defaultHeight = 100;
        connectionPoints = SldNode.createRectConnectionPoints(
          Size(defaultWidth, defaultHeight),
        );
        break;
    }

    final finalSize = size ?? Size(defaultWidth, defaultHeight);

    // Merge properties: existing Bay properties, default SLD properties, and any additional
    final Map<String, dynamic> mergedProperties = {
      'name': name,
      'voltageLevel': voltageLevel,
      'bayType': bayType.toString().split('.').last, // Store enum as string
      // Include specific fields directly used by SldNodeWidget or for display
      'hvVoltage': hvVoltage,
      'lvVoltage': lvVoltage,
      'make': make,
      'capacityMVA': capacity, // Map original capacity to capacityMVA
      'bayNumber': bayNumber,
      'lineLengthKm': lineLength, // Map original lineLength to lineLengthKm
      'circuitType': circuitType,
      'conductorType': conductorType,
      'conductorDetail': conductorDetail,
      'feederType': feederType,
      'isGovernmentFeeder': isGovernmentFeeder,
      'description': description,
      'landmark': landmark,
      'contactNumber': contactNumber,
      'contactPerson': contactPerson,
      // Add other relevant properties you want accessible via SldNode.properties
      // from the original Bay model.

      // Overlay default SLD node properties and any additional properties
      ...(defaultSldNodeProperties ?? {}),
      ...(additionalProperties ?? {}),
    };

    return SldNode(
      position: position,
      size: finalSize,
      nodeShape: nodeShape,
      properties: mergedProperties,
      associatedBayId: id, // Link back to this Bay
      connectionPoints: connectionPoints,
      bayId: id, // Pass the Bay ID for SLD connections
      // You can also set default colors or stroke widths here if needed
      // fillColor: Colors.blue.withOpacity(0.1),
      // strokeColor: Colors.blue,
    );
  }
}
