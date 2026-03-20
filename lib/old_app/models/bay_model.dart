// lib/old_app/models/bay_model.dart
//
// Bay is now embedded inside a Substation document (no separate collection).
// fromMap() is used when deserializing the embedded array.
// toMap() is used when writing the bay back into the substation document.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class Bay {
  final String id;
  final String name;
  final String voltageLevel;
  final String bayType;

  // Metadata
  final String? description;
  final String? address;
  final String? contactPerson;
  final String? contactNumber;
  final String? contactDesignation;

  // Feeder/Line specifics
  final bool? isGovernmentFeeder;
  final String? feederType;
  final double? multiplyingFactor;
  final String? bayNumber;
  final double? lineLength;
  final String? circuitType;
  final String? conductorType;
  final String? conductorDetail;

  // Transformer specifics
  final String? hvVoltage;
  final String? lvVoltage;
  final String? make;
  final double? capacity;
  final String? hvBusId;
  final String? lvBusId;

  // Dates
  final Timestamp? commissioningDate;
  final Timestamp? erectionDate;
  final Timestamp? manufacturingDate;
  final String? createdBy;
  final Timestamp? createdAt;

  // SLD layout
  final double? xPosition;
  final double? yPosition;
  final Offset? textOffset;
  final Offset? energyReadingOffset;
  final double? energyReadingFontSize;
  final bool? energyReadingIsBold;

  // Distribution linkage
  final String? distributionZoneId;
  final String? distributionCircleId;
  final String? distributionDivisionId;
  final String? distributionSubdivisionId;

  // Backward-compat fields (kept so old screens don't break)
  final String? substationId;
  final String? landmark;
  final double? busbarLength;

  const Bay({
    required this.id,
    required this.name,
    required this.voltageLevel,
    required this.bayType,
    this.description,
    this.address,
    this.contactPerson,
    this.contactNumber,
    this.contactDesignation,
    this.isGovernmentFeeder,
    this.feederType,
    this.multiplyingFactor,
    this.bayNumber,
    this.lineLength,
    this.circuitType,
    this.conductorType,
    this.conductorDetail,
    this.hvVoltage,
    this.lvVoltage,
    this.make,
    this.capacity,
    this.hvBusId,
    this.lvBusId,
    this.commissioningDate,
    this.erectionDate,
    this.manufacturingDate,
    this.createdBy,
    this.createdAt,
    this.xPosition,
    this.yPosition,
    this.textOffset,
    this.energyReadingOffset,
    this.energyReadingFontSize,
    this.energyReadingIsBold,
    this.distributionZoneId,
    this.distributionCircleId,
    this.distributionDivisionId,
    this.distributionSubdivisionId,
    this.substationId,
    this.landmark,
    this.busbarLength,
  });

  static Offset? _parseOffset(dynamic data) {
    if (data == null) return null;
    final map = data as Map<String, dynamic>;
    return Offset(
      (map['dx'] as num?)?.toDouble() ?? 0,
      (map['dy'] as num?)?.toDouble() ?? 0,
    );
  }

  /// Used when Bay is embedded inside a Substation document (array element).
  factory Bay.fromMap(Map<String, dynamic> data) => Bay(
    id: data['id'] ?? '',
    name: data['name'] ?? '',
    voltageLevel: data['voltageLevel'] ?? '',
    bayType: data['bayType'] ?? '',
    description: data['description'],
    address: data['address'],
    contactPerson: data['contactPerson'],
    contactNumber: data['contactNumber'],
    contactDesignation: data['contactDesignation'],
    isGovernmentFeeder: data['isGovernmentFeeder'],
    feederType: data['feederType'],
    multiplyingFactor: (data['multiplyingFactor'] as num?)?.toDouble(),
    bayNumber: data['bayNumber'],
    lineLength: (data['lineLength'] as num?)?.toDouble(),
    circuitType: data['circuitType'],
    conductorType: data['conductorType'],
    conductorDetail: data['conductorDetail'],
    hvVoltage: data['hvVoltage'],
    lvVoltage: data['lvVoltage'],
    make: data['make'],
    capacity: (data['capacity'] as num?)?.toDouble(),
    hvBusId: data['hvBusId'],
    lvBusId: data['lvBusId'],
    commissioningDate: data['commissioningDate'] as Timestamp?,
    erectionDate: data['erectionDate'] as Timestamp?,
    manufacturingDate: data['manufacturingDate'] as Timestamp?,
    createdBy: data['createdBy'],
    createdAt: data['createdAt'] as Timestamp?,
    xPosition: (data['xPosition'] as num?)?.toDouble(),
    yPosition: (data['yPosition'] as num?)?.toDouble(),
    textOffset: _parseOffset(data['textOffset']),
    energyReadingOffset: _parseOffset(data['energyReadingOffset']),
    energyReadingFontSize: (data['energyReadingFontSize'] as num?)?.toDouble(),
    energyReadingIsBold: data['energyReadingIsBold'],
    distributionZoneId: data['distributionZoneId'],
    distributionCircleId: data['distributionCircleId'],
    distributionDivisionId: data['distributionDivisionId'],
    distributionSubdivisionId: data['distributionSubdivisionId'],
    substationId: data['substationId'],
    landmark: data['landmark'],
    busbarLength: (data['busbarLength'] as num?)?.toDouble(),
  );

  /// Backward-compat: deserialize a standalone Bay Firestore document.
  factory Bay.fromFirestore(DocumentSnapshot doc) =>
      Bay.fromMap({...doc.data() as Map<String, dynamic>, 'id': doc.id});

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'voltageLevel': voltageLevel,
    'bayType': bayType,
    if (description != null) 'description': description,
    if (address != null) 'address': address,
    if (contactPerson != null) 'contactPerson': contactPerson,
    if (contactNumber != null) 'contactNumber': contactNumber,
    if (contactDesignation != null) 'contactDesignation': contactDesignation,
    if (isGovernmentFeeder != null) 'isGovernmentFeeder': isGovernmentFeeder,
    if (feederType != null) 'feederType': feederType,
    if (multiplyingFactor != null) 'multiplyingFactor': multiplyingFactor,
    if (bayNumber != null) 'bayNumber': bayNumber,
    if (lineLength != null) 'lineLength': lineLength,
    if (circuitType != null) 'circuitType': circuitType,
    if (conductorType != null) 'conductorType': conductorType,
    if (conductorDetail != null) 'conductorDetail': conductorDetail,
    if (hvVoltage != null) 'hvVoltage': hvVoltage,
    if (lvVoltage != null) 'lvVoltage': lvVoltage,
    if (make != null) 'make': make,
    if (capacity != null) 'capacity': capacity,
    if (hvBusId != null) 'hvBusId': hvBusId,
    if (lvBusId != null) 'lvBusId': lvBusId,
    if (commissioningDate != null) 'commissioningDate': commissioningDate,
    if (erectionDate != null) 'erectionDate': erectionDate,
    if (manufacturingDate != null) 'manufacturingDate': manufacturingDate,
    if (createdBy != null) 'createdBy': createdBy,
    if (createdAt != null) 'createdAt': createdAt,
    if (xPosition != null) 'xPosition': xPosition,
    if (yPosition != null) 'yPosition': yPosition,
    if (textOffset != null)
      'textOffset': {'dx': textOffset!.dx, 'dy': textOffset!.dy},
    if (energyReadingOffset != null)
      'energyReadingOffset': {
        'dx': energyReadingOffset!.dx,
        'dy': energyReadingOffset!.dy,
      },
    if (energyReadingFontSize != null)
      'energyReadingFontSize': energyReadingFontSize,
    if (energyReadingIsBold != null) 'energyReadingIsBold': energyReadingIsBold,
    if (distributionZoneId != null) 'distributionZoneId': distributionZoneId,
    if (distributionCircleId != null)
      'distributionCircleId': distributionCircleId,
    if (distributionDivisionId != null)
      'distributionDivisionId': distributionDivisionId,
    if (distributionSubdivisionId != null)
      'distributionSubdivisionId': distributionSubdivisionId,
    if (substationId != null) 'substationId': substationId,
    if (landmark != null) 'landmark': landmark,
    if (busbarLength != null) 'busbarLength': busbarLength,
  };

  /// Backward-compat alias for toMap().
  Map<String, dynamic> toFirestore() => toMap();

  Bay copyWith({
    String? id,
    String? name,
    String? voltageLevel,
    String? bayType,
    String? description,
    String? address,
    String? contactPerson,
    String? contactNumber,
    String? contactDesignation,
    bool? isGovernmentFeeder,
    String? feederType,
    double? multiplyingFactor,
    String? bayNumber,
    double? lineLength,
    String? circuitType,
    String? conductorType,
    String? conductorDetail,
    String? hvVoltage,
    String? lvVoltage,
    String? make,
    double? capacity,
    String? hvBusId,
    String? lvBusId,
    Timestamp? commissioningDate,
    Timestamp? erectionDate,
    Timestamp? manufacturingDate,
    String? createdBy,
    Timestamp? createdAt,
    double? xPosition,
    double? yPosition,
    Offset? textOffset,
    Offset? energyReadingOffset,
    double? energyReadingFontSize,
    bool? energyReadingIsBold,
    String? distributionZoneId,
    String? distributionCircleId,
    String? distributionDivisionId,
    String? distributionSubdivisionId,
    String? substationId,
    String? landmark,
    double? busbarLength,
  }) => Bay(
    id: id ?? this.id,
    name: name ?? this.name,
    voltageLevel: voltageLevel ?? this.voltageLevel,
    bayType: bayType ?? this.bayType,
    description: description ?? this.description,
    address: address ?? this.address,
    contactPerson: contactPerson ?? this.contactPerson,
    contactNumber: contactNumber ?? this.contactNumber,
    contactDesignation: contactDesignation ?? this.contactDesignation,
    isGovernmentFeeder: isGovernmentFeeder ?? this.isGovernmentFeeder,
    feederType: feederType ?? this.feederType,
    multiplyingFactor: multiplyingFactor ?? this.multiplyingFactor,
    bayNumber: bayNumber ?? this.bayNumber,
    lineLength: lineLength ?? this.lineLength,
    circuitType: circuitType ?? this.circuitType,
    conductorType: conductorType ?? this.conductorType,
    conductorDetail: conductorDetail ?? this.conductorDetail,
    hvVoltage: hvVoltage ?? this.hvVoltage,
    lvVoltage: lvVoltage ?? this.lvVoltage,
    make: make ?? this.make,
    capacity: capacity ?? this.capacity,
    hvBusId: hvBusId ?? this.hvBusId,
    lvBusId: lvBusId ?? this.lvBusId,
    commissioningDate: commissioningDate ?? this.commissioningDate,
    erectionDate: erectionDate ?? this.erectionDate,
    manufacturingDate: manufacturingDate ?? this.manufacturingDate,
    createdBy: createdBy ?? this.createdBy,
    createdAt: createdAt ?? this.createdAt,
    xPosition: xPosition ?? this.xPosition,
    yPosition: yPosition ?? this.yPosition,
    textOffset: textOffset ?? this.textOffset,
    energyReadingOffset: energyReadingOffset ?? this.energyReadingOffset,
    energyReadingFontSize: energyReadingFontSize ?? this.energyReadingFontSize,
    energyReadingIsBold: energyReadingIsBold ?? this.energyReadingIsBold,
    distributionZoneId: distributionZoneId ?? this.distributionZoneId,
    distributionCircleId: distributionCircleId ?? this.distributionCircleId,
    distributionDivisionId:
        distributionDivisionId ?? this.distributionDivisionId,
    distributionSubdivisionId:
        distributionSubdivisionId ?? this.distributionSubdivisionId,
    substationId: substationId ?? this.substationId,
    landmark: landmark ?? this.landmark,
    busbarLength: busbarLength ?? this.busbarLength,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is Bay && other.id == id);

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Bay($id, $name, $bayType)';
}
