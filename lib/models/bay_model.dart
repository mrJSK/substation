// lib/models/bay_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

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

  // --- Universal Bay Number ---
  final String? bayNumber;

  // --- Fields for Line bay type ---
  final double? lineLength;
  final String? circuitType;
  final String? conductorType;
  final String? conductorDetail; // For "Other" conductor type
  final Timestamp? erectionDate;

  // --- Fields for Transformer bay type ---
  final String? hvVoltage;
  final String? lvVoltage;
  final String? make;
  final double? capacity; // In MVA
  final Timestamp? manufacturingDate;
  final String? hvBusId; // NEW: For HV bus connection
  final String? lvBusId; // NEW: For LV bus connection

  // --- SHARED: Used by Line, Transformer, etc. ---
  final Timestamp? commissioningDate;

  // --- NEW: Fields for custom position ---
  final double? xPosition;
  final double? yPosition;

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
    this.xPosition,
    this.yPosition,
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
      xPosition: (data['xPosition'] as num?)?.toDouble(),
      yPosition: (data['yPosition'] as num?)?.toDouble(),
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
      'xPosition': xPosition,
      'yPosition': yPosition,
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
      xPosition: xPosition ?? this.xPosition,
      yPosition: yPosition ?? this.yPosition,
    );
  }
}
