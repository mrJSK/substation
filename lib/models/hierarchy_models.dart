// lib/models/hierarchy_models.dart
import 'package:cloud_firestore/cloud_firestore.dart';

abstract class HierarchyItem {
  final String id;
  final String name;
  final String? description;
  final String createdBy;
  final Timestamp createdAt;

  final String? landmark;
  final String? contactNumber;
  final String? contactPerson;

  HierarchyItem({
    required this.id,
    required this.name,
    this.description,
    required this.createdBy,
    required this.createdAt,
    this.landmark,
    this.contactNumber,
    this.contactPerson,
  });

  Map<String, dynamic> toFirestore();
}

class Zone extends HierarchyItem {
  final String stateName;

  Zone({
    required super.id,
    required super.name,
    super.description,
    required super.createdBy,
    required super.createdAt,
    required this.stateName,
    super.landmark,
    super.contactNumber,
    super.contactPerson,
  });

  factory Zone.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map<String, dynamic>;
    return Zone(
      id: doc.id,
      name: data['name'] ?? '',
      description: data['description'],
      createdBy: data['createdBy'] ?? '',
      createdAt: data['createdAt'] ?? Timestamp.now(),
      stateName: data['stateName'] ?? '',
      landmark: data['landmark'],
      contactNumber: data['contactNumber'],
      contactPerson: data['contactPerson'],
    );
  }

  @override
  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'description': description,
      'createdBy': createdBy,
      'createdAt': createdAt,
      'stateName': stateName,
      'landmark': landmark,
      'contactNumber': contactNumber,
      'contactPerson': contactPerson,
    };
  }

  Zone copyWith({
    String? id,
    String? name,
    String? description,
    String? createdBy,
    Timestamp? createdAt,
    String? stateName,
    String? landmark,
    String? contactNumber,
    String? contactPerson,
  }) {
    return Zone(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      stateName: stateName ?? this.stateName,
      landmark: landmark ?? this.landmark,
      contactNumber: contactNumber ?? this.contactNumber,
      contactPerson: contactPerson ?? this.contactPerson,
    );
  }
}

class Circle extends HierarchyItem {
  final String zoneId;

  Circle({
    required super.id,
    required super.name,
    super.description,
    required super.createdBy,
    required super.createdAt,
    required this.zoneId,
    super.landmark,
    super.contactNumber,
    super.contactPerson,
  });

  factory Circle.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map<String, dynamic>;
    return Circle(
      id: doc.id,
      name: data['name'] ?? '',
      description: data['description'],
      createdBy: data['createdBy'] ?? '',
      createdAt: data['createdAt'] ?? Timestamp.now(),
      zoneId: data['zoneId'] ?? '',
      landmark: data['landmark'],
      contactNumber: data['contactNumber'],
      contactPerson: data['contactPerson'],
    );
  }

  @override
  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'description': description,
      'createdBy': createdBy,
      'createdAt': createdAt,
      'zoneId': zoneId,
      'landmark': landmark,
      'contactNumber': contactNumber,
      'contactPerson': contactPerson,
    };
  }

  Circle copyWith({
    String? id,
    String? name,
    String? description,
    String? createdBy,
    Timestamp? createdAt,
    String? zoneId,
    String? landmark,
    String? contactNumber,
    String? contactPerson,
  }) {
    return Circle(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      zoneId: zoneId ?? this.zoneId,
      landmark: landmark ?? this.landmark,
      contactNumber: contactNumber ?? this.contactNumber,
      contactPerson: contactPerson ?? this.contactPerson,
    );
  }
}

class Division extends HierarchyItem {
  final String circleId;

  Division({
    required super.id,
    required super.name,
    super.description,
    required super.createdBy,
    required super.createdAt,
    required this.circleId,
    super.landmark,
    super.contactNumber,
    super.contactPerson,
  });

  factory Division.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map<String, dynamic>;
    return Division(
      id: doc.id,
      name: data['name'] ?? '',
      description: data['description'],
      createdBy: data['createdBy'] ?? '',
      createdAt: data['createdAt'] ?? Timestamp.now(),
      circleId: data['circleId'] ?? '',
      landmark: data['landmark'],
      contactNumber: data['contactNumber'],
      contactPerson: data['contactPerson'],
    );
  }

  @override
  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'description': description,
      'createdBy': createdBy,
      'createdAt': createdAt,
      'circleId': circleId,
      'landmark': landmark,
      'contactNumber': contactNumber,
      'contactPerson': contactPerson,
    };
  }

  Division copyWith({
    String? id,
    String? name,
    String? description,
    String? createdBy,
    Timestamp? createdAt,
    String? circleId,
    String? landmark,
    String? contactNumber,
    String? contactPerson,
  }) {
    return Division(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      circleId: circleId ?? this.circleId,
      landmark: landmark ?? this.landmark,
      contactNumber: contactNumber ?? this.contactNumber,
      contactPerson: contactPerson ?? this.contactPerson,
    );
  }
}

class Subdivision extends HierarchyItem {
  final String divisionId;

  Subdivision({
    required super.id,
    required super.name,
    super.description,
    required super.createdBy,
    required super.createdAt,
    required this.divisionId,
    super.landmark,
    super.contactNumber,
    super.contactPerson,
  });

  factory Subdivision.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map<String, dynamic>;
    return Subdivision(
      id: doc.id,
      name: data['name'] ?? '',
      description: data['description'],
      createdBy: data['createdBy'] ?? '',
      createdAt: data['createdAt'] ?? Timestamp.now(),
      divisionId: data['divisionId'] ?? '',
      landmark: data['landmark'],
      contactNumber: data['contactNumber'],
      contactPerson: data['contactPerson'],
    );
  }

  @override
  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'description': description,
      'createdBy': createdBy,
      'createdAt': createdAt,
      'divisionId': divisionId,
      'landmark': landmark,
      'contactNumber': contactNumber,
      'contactPerson': contactPerson,
    };
  }

  Subdivision copyWith({
    String? id,
    String? name,
    String? description,
    String? createdBy,
    Timestamp? createdAt,
    String? divisionId,
    String? landmark,
    String? contactNumber,
    String? contactPerson,
  }) {
    return Subdivision(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      divisionId: divisionId ?? this.divisionId,
      landmark: landmark ?? this.landmark,
      contactNumber: contactNumber ?? this.contactNumber,
      contactPerson: contactPerson ?? this.contactPerson,
    );
  }
}

class Substation extends HierarchyItem {
  final String subdivisionId;
  final String? address;
  final String? cityId;

  final String? voltageLevel;
  final String? type;
  final String? operation;
  final String? sasMake;
  final Timestamp? commissioningDate;
  final String? status;
  final String? statusDescription;
  final String? contactDesignation; // NEW FIELD: Contact Designation

  Substation({
    required super.id,
    required super.name,
    super.description,
    required super.createdBy,
    required super.createdAt,
    required this.subdivisionId,
    this.address,
    this.cityId,
    super.landmark,
    super.contactNumber,
    super.contactPerson,
    this.voltageLevel,
    this.type,
    this.operation,
    this.sasMake,
    this.commissioningDate,
    this.status,
    this.statusDescription,
    this.contactDesignation, // NEW FIELD: Initialize
  });

  factory Substation.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map<String, dynamic>;
    return Substation(
      id: doc.id,
      name: data['name'] ?? '',
      description: data['description'],
      createdBy: data['createdBy'] ?? '',
      createdAt: data['createdAt'] ?? Timestamp.now(),
      subdivisionId: data['subdivisionId'] ?? '',
      address: data['address'],
      cityId: data['cityId'],
      landmark: data['landmark'],
      contactNumber: data['contactNumber'],
      contactPerson: data['contactPerson'],
      voltageLevel: data['voltageLevel'],
      type: data['type'],
      operation: data['operation'],
      sasMake: data['sasMake'],
      commissioningDate: data['commissioningDate'] as Timestamp?,
      status: data['status'],
      statusDescription: data['statusDescription'],
      contactDesignation: data['contactDesignation'], // NEW FIELD: Read
    );
  }

  @override
  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'description': description,
      'createdBy': createdBy,
      'createdAt': createdAt,
      'subdivisionId': subdivisionId,
      'address': address,
      'cityId': cityId,
      'landmark': landmark,
      'contactNumber': contactNumber,
      'contactPerson': contactPerson,
      'voltageLevel': voltageLevel,
      'type': type,
      'operation': operation,
      'sasMake': sasMake,
      'commissioningDate': commissioningDate,
      'status': status,
      'statusDescription': statusDescription,
      'contactDesignation': contactDesignation, // NEW FIELD: Write
    };
  }

  Substation copyWith({
    String? id,
    String? name,
    String? description,
    String? createdBy,
    Timestamp? createdAt,
    String? subdivisionId,
    String? address,
    String? cityId,
    String? landmark,
    String? contactNumber,
    String? contactPerson,
    String? voltageLevel,
    String? type,
    String? operation,
    String? sasMake,
    Timestamp? commissioningDate,
    String? status,
    String? statusDescription,
    String? contactDesignation, // NEW FIELD: CopyWith
  }) {
    return Substation(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      subdivisionId: subdivisionId ?? this.subdivisionId,
      address: address ?? this.address,
      cityId: cityId ?? this.cityId,
      landmark: landmark ?? this.landmark,
      contactNumber: contactNumber ?? this.contactNumber,
      contactPerson: contactPerson ?? this.contactPerson,
      voltageLevel: voltageLevel ?? this.voltageLevel,
      type: type ?? this.type,
      operation: operation ?? this.operation,
      sasMake: sasMake ?? this.sasMake,
      commissioningDate: commissioningDate ?? this.commissioningDate,
      status: status ?? this.status,
      statusDescription: statusDescription ?? this.statusDescription,
      contactDesignation:
          contactDesignation ?? this.contactDesignation, // NEW FIELD: CopyWith
    );
  }
}
