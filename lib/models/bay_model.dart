import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart'; // Keep if Offset is used elsewhere in the app for non-layout purposes

class Bay {
  final String id;
  final String name;
  final String substationId;
  final String voltageLevel;
  final String bayType;
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
  // Removed layout properties:
  // final double? xPosition;
  // final double? yPosition;
  // final double? busbarLength;
  // final Offset? textOffset;
  // final Offset? energyTextOffset;
  final String? distributionZoneId;
  final String? distributionCircleId;
  final String? distributionDivisionId;
  final String? distributionSubdivisionId;

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
    // Removed from constructor:
    // this.xPosition,
    // this.yPosition,
    // this.busbarLength,
    // this.textOffset,
    // this.energyTextOffset,
    this.distributionZoneId,
    this.distributionCircleId,
    this.distributionDivisionId,
    this.distributionSubdivisionId,
  });

  factory Bay.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
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
      // Removed from fromFirestore:
      // xPosition: (data['xPosition'] as num?)?.toDouble(),
      // yPosition: (data['yPosition'] as num?)?.toDouble(),
      // busbarLength: (data['busbarLength'] as num?)?.toDouble(),
      // textOffset: data['textOffset'] != null
      //     ? Offset(
      //         (data['textOffset']['dx'] as num).toDouble(),
      //         (data['textOffset']['dy'] as num).toDouble(),
      //       )
      //     : null,
      // energyTextOffset: data['energyTextOffset'] != null
      //     ? Offset(
      //         (data['energyTextOffset']['dx'] as num).toDouble(),
      //         (data['energyTextOffset']['dy'] as num).toDouble(),
      //       )
      //     : null,
      distributionZoneId: data['distributionZoneId'] as String?,
      distributionCircleId: data['distributionCircleId'] as String?,
      distributionDivisionId: data['distributionDivisionId'] as String?,
      distributionSubdivisionId: data['distributionSubdivisionId'] as String?,
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
      // Removed from toFirestore:
      // 'xPosition': xPosition,
      // 'yPosition': yPosition,
      // 'busbarLength': busbarLength,
      // 'textOffset': textOffset != null
      //     ? {'dx': textOffset!.dx, 'dy': textOffset!.dy}
      //     : null,
      // 'energyTextOffset': energyTextOffset != null
      //     ? {'dx': energyTextOffset!.dx, 'dy': energyTextOffset!.dy}
      //     : null,
      'distributionZoneId': distributionZoneId,
      'distributionCircleId': distributionCircleId,
      'distributionDivisionId': distributionDivisionId,
      'distributionSubdivisionId': distributionSubdivisionId,
    };
  }

  // The copyWith method also needs to be updated to reflect the removal of these fields.
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
    // Removed from copyWith:
    // double? xPosition,
    // double? yPosition,
    // double? busbarLength,
    // Offset? textOffset,
    // Offset? energyTextOffset,
    String? distributionZoneId,
    String? distributionCircleId,
    String? distributionDivisionId,
    String? distributionSubdivisionId,
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
      // Removed from copyWith:
      // xPosition: xPosition ?? this.xPosition,
      // yPosition: yPosition ?? this.yPosition,
      // busbarLength: busbarLength ?? this.busbarLength,
      // textOffset: textOffset ?? this.textOffset,
      // energyTextOffset: energyTextOffset ?? this.energyTextOffset,
      distributionZoneId: distributionZoneId ?? this.distributionZoneId,
      distributionCircleId: distributionCircleId ?? this.distributionCircleId,
      distributionDivisionId:
          distributionDivisionId ?? this.distributionDivisionId,
      distributionSubdivisionId:
          distributionSubdivisionId ?? this.distributionSubdivisionId,
    );
  }
}
