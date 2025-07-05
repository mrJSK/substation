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
  final double? multiplyingFactor; // **NEW**: Added for energy calculations

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
    this.multiplyingFactor, // **NEW**
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
      multiplyingFactor: (data['multiplyingFactor'] as num?)
          ?.toDouble(), // **NEW**
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
      'multiplyingFactor': multiplyingFactor, // **NEW**
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
    double? multiplyingFactor, // **NEW**
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
      multiplyingFactor: multiplyingFactor ?? this.multiplyingFactor, // **NEW**
    );
  }
}
