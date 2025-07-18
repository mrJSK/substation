// lib/models/bay_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'hierarchy_models.dart'; // Import the file containing HierarchyItem

class Bay implements HierarchyItem {
  @override
  final String id;
  @override
  final String name;
  final String substationId;
  final String voltageLevel;
  final String bayType;
  final String createdBy;
  final Timestamp createdAt;
  @override
  final String? description;
  @override
  final String? landmark;
  @override
  final String? contactNumber;
  @override
  final String? contactPerson;
  @override
  final String? contactDesignation;
  final bool? isGovernmentFeeder;
  final String? feederType;
  final double? multiplyingFactor;
  final String? bayNumber;
  final double? lineLength;
  final String? circuitType;
  final String? conductorType;
  final String? conductorDetail;
  final Timestamp? erectionDate;
  final String? hvVoltage;
  final String? lvVoltage;
  final String? make;
  final double? capacity;
  final Timestamp? manufacturingDate;
  final String? hvBusId;
  final String? lvBusId;
  final Timestamp? commissioningDate;
  final double? xPosition;
  final double? yPosition;
  final double? busbarLength;
  final Offset? textOffset;
  final String? distributionZoneId;
  final String? distributionCircleId;
  final String? distributionDivisionId;
  final String? distributionSubdivisionId;

  // Properties for Energy Reading Text Styling
  final Offset? energyReadingOffset;
  final double? energyReadingFontSize;
  final bool? energyReadingIsBold;

  Bay({
    required this.id,
    required this.name,
    required this.substationId,
    required this.voltageLevel,
    required this.bayType,
    required this.createdBy,
    required this.createdAt,
    this.description,
    this.landmark,
    this.contactNumber,
    this.contactPerson,
    this.contactDesignation,
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
    this.distributionZoneId,
    this.distributionCircleId,
    this.distributionDivisionId,
    this.distributionSubdivisionId,
    this.energyReadingOffset,
    this.energyReadingFontSize,
    this.energyReadingIsBold,
  });

  factory Bay.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

    // Helper function to parse Offset from Firestore map
    Offset? parseOffset(Map<String, dynamic>? offsetData) {
      if (offsetData == null) return null;
      return Offset(
        (offsetData['dx'] as num?)?.toDouble() ?? 0.0,
        (offsetData['dy'] as num?)?.toDouble() ?? 0.0,
      );
    }

    return Bay(
      id: doc.id,
      name: data['name'] ?? '',
      substationId: data['substationId'] ?? '',
      voltageLevel: data['voltageLevel'] ?? '',
      bayType: data['bayType'] ?? '',
      createdBy: data['createdBy'] ?? '',
      createdAt: data['createdAt'] ?? Timestamp.now(),
      description: data['description'],
      landmark: data['landmark'],
      contactNumber: data['contactNumber'],
      contactPerson: data['contactPerson'],
      contactDesignation: data['contactDesignation'],
      isGovernmentFeeder: data['isGovernmentFeeder'],
      feederType: data['feederType'],
      multiplyingFactor: (data['multiplyingFactor'] as num?)?.toDouble(),
      bayNumber: data['bayNumber'],
      lineLength: (data['lineLength'] as num?)?.toDouble(),
      circuitType: data['circuitType'],
      conductorType: data['conductorType'],
      conductorDetail: data['conductorDetail'],
      erectionDate: data['erectionDate'],
      hvVoltage: data['hvVoltage'],
      lvVoltage: data['lvVoltage'],
      make: data['make'],
      capacity: (data['capacity'] as num?)?.toDouble(),
      manufacturingDate: data['manufacturingDate'],
      hvBusId: data['hvBusId'] as String?,
      lvBusId: data['lvBusId'] as String?,
      commissioningDate: data['commissioningDate'],
      xPosition: (data['xPosition'] as num?)?.toDouble(),
      yPosition: (data['yPosition'] as num?)?.toDouble(),
      busbarLength: (data['busbarLength'] as num?)?.toDouble(),
      textOffset: parseOffset(data['textOffset']),
      distributionZoneId: data['distributionZoneId'] as String?,
      distributionCircleId: data['distributionCircleId'] as String?,
      distributionDivisionId: data['distributionDivisionId'] as String?,
      distributionSubdivisionId: data['distributionSubdivisionId'] as String?,
      energyReadingOffset: parseOffset(data['energyReadingOffset']),
      energyReadingFontSize: (data['energyReadingFontSize'] as num?)
          ?.toDouble(),
      energyReadingIsBold: data['energyReadingIsBold'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'substationId': substationId,
      'voltageLevel': voltageLevel,
      'bayType': bayType,
      'createdBy': createdBy,
      'createdAt': createdAt,
      'description': description,
      'landmark': landmark,
      'contactNumber': contactNumber,
      'contactPerson': contactPerson,
      'contactDesignation': contactDesignation,
      'isGovernmentFeeder': isGovernmentFeeder,
      'feederType': feederType,
      'multiplyingFactor': multiplyingFactor,
      'bayNumber': bayNumber,
      'lineLength': lineLength,
      'circuitType': circuitType,
      'conductorType': conductorType,
      'conductorDetail': conductorDetail,
      'erectionDate': erectionDate,
      'hvVoltage': hvVoltage,
      'lvVoltage': lvVoltage,
      'make': make,
      'capacity': capacity,
      'manufacturingDate': manufacturingDate,
      'hvBusId': hvBusId,
      'lvBusId': lvBusId,
      'commissioningDate': commissioningDate,
      'xPosition': xPosition,
      'yPosition': yPosition,
      'busbarLength': busbarLength,
      if (textOffset != null)
        'textOffset': {'dx': textOffset!.dx, 'dy': textOffset!.dy},
      'distributionZoneId': distributionZoneId,
      'distributionCircleId': distributionCircleId,
      'distributionDivisionId': distributionDivisionId,
      'distributionSubdivisionId': distributionSubdivisionId,
      if (energyReadingOffset != null)
        'energyReadingOffset': {
          'dx': energyReadingOffset!.dx,
          'dy': energyReadingOffset!.dy,
        },
      'energyReadingFontSize': energyReadingFontSize,
      'energyReadingIsBold': energyReadingIsBold,
    };
  }

  Bay copyWith({
    String? id,
    String? name,
    String? substationId,
    String? voltageLevel,
    String? bayType,
    String? createdBy,
    Timestamp? createdAt,
    String? description,
    String? landmark,
    String? contactNumber,
    String? contactPerson,
    String? contactDesignation,
    bool? isGovernmentFeeder,
    String? feederType,
    double? multiplyingFactor,
    String? bayNumber,
    double? lineLength,
    String? circuitType,
    String? conductorType,
    String? conductorDetail,
    Timestamp? erectionDate,
    String? hvVoltage,
    String? lvVoltage,
    String? make,
    double? capacity,
    Timestamp? manufacturingDate,
    String? hvBusId,
    String? lvBusId,
    Timestamp? commissioningDate,
    double? xPosition,
    double? yPosition,
    double? busbarLength,
    Offset? textOffset,
    String? distributionZoneId,
    String? distributionCircleId,
    String? distributionDivisionId,
    String? distributionSubdivisionId,
    Offset? energyReadingOffset,
    double? energyReadingFontSize,
    bool? energyReadingIsBold,
  }) {
    return Bay(
      id: id ?? this.id,
      name: name ?? this.name,
      substationId: substationId ?? this.substationId,
      voltageLevel: voltageLevel ?? this.voltageLevel,
      bayType: bayType ?? this.bayType,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      description: description ?? this.description,
      landmark: landmark ?? this.landmark,
      contactNumber: contactNumber ?? this.contactNumber,
      contactPerson: contactPerson ?? this.contactPerson,
      contactDesignation: contactDesignation ?? this.contactDesignation,
      isGovernmentFeeder: isGovernmentFeeder ?? this.isGovernmentFeeder,
      feederType: feederType ?? this.feederType,
      multiplyingFactor: multiplyingFactor ?? this.multiplyingFactor,
      bayNumber: bayNumber ?? this.bayNumber,
      lineLength: lineLength ?? this.lineLength,
      circuitType: circuitType ?? this.circuitType,
      conductorType: conductorType ?? this.conductorType,
      conductorDetail: conductorDetail ?? this.conductorDetail,
      erectionDate: erectionDate ?? this.erectionDate,
      hvVoltage: hvVoltage ?? this.hvVoltage,
      lvVoltage: lvVoltage ?? this.lvVoltage,
      make: make ?? this.make,
      capacity: capacity ?? this.capacity,
      manufacturingDate: manufacturingDate ?? this.manufacturingDate,
      hvBusId: hvBusId ?? this.hvBusId,
      lvBusId: lvBusId ?? this.lvBusId,
      commissioningDate: commissioningDate ?? this.commissioningDate,
      xPosition: xPosition ?? this.xPosition,
      yPosition: yPosition ?? this.yPosition,
      busbarLength: busbarLength ?? this.busbarLength,
      textOffset: textOffset ?? this.textOffset,
      distributionZoneId: distributionZoneId ?? this.distributionZoneId,
      distributionCircleId: distributionCircleId ?? this.distributionCircleId,
      distributionDivisionId:
          distributionDivisionId ?? this.distributionDivisionId,
      distributionSubdivisionId:
          distributionSubdivisionId ?? this.distributionSubdivisionId,
      energyReadingOffset: energyReadingOffset ?? this.energyReadingOffset,
      energyReadingFontSize:
          energyReadingFontSize ?? this.energyReadingFontSize,
      energyReadingIsBold: energyReadingIsBold ?? this.energyReadingIsBold,
    );
  }
}
