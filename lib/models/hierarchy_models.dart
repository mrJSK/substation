// lib/models/hierarchy_models.dart
import 'package:cloud_firestore/cloud_firestore.dart';

abstract class HierarchyItem {
  final String id;
  final String name;
  final String? description;
  final String? createdBy; // Changed to optional
  final Timestamp? createdAt; // Changed to optional

  final String? landmark;
  final String? contactNumber;
  final String? contactPerson;
  final String? contactDesignation;

  HierarchyItem({
    required this.id,
    required this.name,
    this.description,
    this.createdBy, // Changed to optional in constructor
    this.createdAt, // Changed to optional in constructor
    this.landmark,
    this.contactNumber,
    this.contactPerson,
    this.contactDesignation,
  });

  Map<String, dynamic> toFirestore();
}

// NEW: AppScreenState Model for the top-level 'State' in the hierarchy
class AppScreenState extends HierarchyItem {
  AppScreenState({
    required super.id,
    required super.name,
    super.description,
    super.createdBy, // Now optional, matches superclass
    super.createdAt, // Now optional, matches superclass
    super.landmark,
    super.contactNumber,
    super.contactPerson,
    super.contactDesignation,
  });

  factory AppScreenState.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map<String, dynamic>;
    return AppScreenState(
      id: doc.id,
      name: data['name'] ?? '',
      description: data['description'],
      createdBy:
          data['createdBy'], // Will be null if not present, handled by optional type
      createdAt:
          data['createdAt'], // Will be null if not present, handled by optional type
      landmark: data['landmark'],
      contactNumber: data['contactNumber'],
      contactPerson: data['contactPerson'],
      contactDesignation: data['contactDesignation'],
    );
  }

  @override
  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'description': description,
      'createdBy': createdBy,
      'createdAt': createdAt,
      'landmark': landmark,
      'contactNumber': contactNumber,
      'contactPerson': contactPerson,
      'contactDesignation': contactDesignation,
    };
  }

  AppScreenState copyWith({
    String? id,
    String? name,
    String? description,
    String? createdBy,
    Timestamp? createdAt,
    String? landmark,
    String? contactNumber,
    String? contactPerson,
    String? contactDesignation,
  }) {
    return AppScreenState(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      landmark: landmark ?? this.landmark,
      contactNumber: contactNumber ?? this.contactNumber,
      contactPerson: contactPerson ?? this.contactPerson,
      contactDesignation: contactDesignation ?? this.contactDesignation,
    );
  }
}

class Zone extends HierarchyItem {
  final String stateName; // Assuming stateName is stored in Zone

  Zone({
    required super.id,
    required super.name,
    super.description,
    super.createdBy, // Now optional, matches superclass
    super.createdAt, // Now optional, matches superclass
    required this.stateName,
    super.landmark,
    super.contactNumber,
    super.contactPerson,
    super.contactDesignation,
  });

  factory Zone.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map<String, dynamic>;
    return Zone(
      id: doc.id,
      name: data['name'] ?? '',
      description: data['description'],
      createdBy:
          data['createdBy'], // No default needed here, as it's from Firestore
      createdAt:
          data['createdAt'], // No default needed here, as it's from Firestore
      stateName: data['stateName'] ?? '',
      landmark: data['landmark'],
      contactNumber: data['contactNumber'],
      contactPerson: data['contactPerson'],
      contactDesignation: data['contactDesignation'],
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
      'contactDesignation': contactDesignation,
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
    String? contactDesignation,
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
      contactDesignation: contactDesignation ?? this.contactDesignation,
    );
  }
}

class Circle extends HierarchyItem {
  final String zoneId;

  Circle({
    required super.id,
    required super.name,
    super.description,
    super.createdBy, // Now optional, matches superclass
    super.createdAt, // Now optional, matches superclass
    required this.zoneId,
    super.landmark,
    super.contactNumber,
    super.contactPerson,
    super.contactDesignation,
  });

  factory Circle.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map<String, dynamic>;
    return Circle(
      id: doc.id,
      name: data['name'] ?? '',
      description: data['description'],
      createdBy:
          data['createdBy'], // No default needed here, as it's from Firestore
      createdAt:
          data['createdAt'], // No default needed here, as it's from Firestore
      zoneId: data['zoneId'] ?? '',
      landmark: data['landmark'],
      contactNumber: data['contactNumber'],
      contactPerson: data['contactPerson'],
      contactDesignation: data['contactDesignation'],
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
      'contactDesignation': contactDesignation,
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
    String? contactDesignation,
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
      contactDesignation: contactDesignation ?? this.contactDesignation,
    );
  }
}

class Division extends HierarchyItem {
  final String circleId;

  Division({
    required super.id,
    required super.name,
    super.description,
    super.createdBy, // Now optional, matches superclass
    super.createdAt, // Now optional, matches superclass
    required this.circleId,
    super.landmark,
    super.contactNumber,
    super.contactPerson,
    super.contactDesignation,
  });

  factory Division.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map<String, dynamic>;
    return Division(
      id: doc.id,
      name: data['name'] ?? '',
      description: data['description'],
      createdBy:
          data['createdBy'], // No default needed here, as it's from Firestore
      createdAt:
          data['createdAt'], // No default needed here, as it's from Firestore
      circleId: data['circleId'] ?? '',
      landmark: data['landmark'],
      contactNumber: data['contactNumber'],
      contactPerson: data['contactPerson'],
      contactDesignation: data['contactDesignation'],
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
      'contactDesignation': contactDesignation,
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
    String? contactDesignation,
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
      contactDesignation: contactDesignation ?? this.contactDesignation,
    );
  }
}

class Subdivision extends HierarchyItem {
  final String divisionId;

  Subdivision({
    required super.id,
    required super.name,
    super.description,
    super.createdBy, // Now optional, matches superclass
    super.createdAt, // Now optional, matches superclass
    required this.divisionId,
    super.landmark,
    super.contactNumber,
    super.contactPerson,
    super.contactDesignation,
  });

  factory Subdivision.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map<String, dynamic>;
    return Subdivision(
      id: doc.id,
      name: data['name'] ?? '',
      description: data['description'],
      createdBy:
          data['createdBy'], // No default needed here, as it's from Firestore
      createdAt:
          data['createdAt'], // No default needed here, as it's from Firestore
      divisionId: data['divisionId'] ?? '',
      landmark: data['landmark'],
      contactNumber: data['contactNumber'],
      contactPerson: data['contactPerson'],
      contactDesignation: data['contactDesignation'],
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
      'contactDesignation': contactDesignation,
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
    String? contactDesignation,
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
      contactDesignation: contactDesignation ?? this.contactDesignation,
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

  Substation({
    required super.id,
    required super.name,
    super.description,
    super.createdBy, // Now optional, matches superclass
    super.createdAt, // Now optional, matches superclass
    required this.subdivisionId,
    this.address,
    this.cityId,
    super.landmark,
    super.contactNumber,
    super.contactPerson,
    super.contactDesignation,
    this.voltageLevel,
    this.type,
    this.operation,
    this.sasMake,
    this.commissioningDate,
    this.status,
    this.statusDescription,
  });

  factory Substation.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map<String, dynamic>;
    return Substation(
      id: doc.id,
      name: data['name'] ?? '',
      description: data['description'],
      createdBy:
          data['createdBy'], // No default needed here, as it's from Firestore
      createdAt:
          data['createdAt'], // No default needed here, as it's from Firestore
      subdivisionId: data['subdivisionId'] ?? '',
      address: data['address'],
      cityId: data['cityId'],
      landmark: data['landmark'],
      contactNumber: data['contactNumber'],
      contactPerson: data['contactPerson'],
      contactDesignation: data['contactDesignation'],
      voltageLevel: data['voltageLevel'],
      type: data['type'],
      operation: data['operation'],
      sasMake: data['sasMake'],
      commissioningDate: data['commissioningDate'] as Timestamp?,
      status: data['status'],
      statusDescription: data['statusDescription'],
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
      'contactDesignation': contactDesignation,
      'voltageLevel': voltageLevel,
      'type': type,
      'operation': operation,
      'sasMake': sasMake,
      'commissioningDate': commissioningDate,
      'status': status,
      'statusDescription': statusDescription,
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
    String? contactDesignation,
    String? voltageLevel,
    String? type,
    String? operation,
    String? sasMake,
    Timestamp? commissioningDate,
    String? status,
    String? statusDescription,
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
      contactDesignation: contactDesignation ?? this.contactDesignation,
      voltageLevel: voltageLevel ?? this.voltageLevel,
      type: type ?? this.type,
      operation: operation ?? this.operation,
      sasMake: sasMake ?? this.sasMake,
      commissioningDate: commissioningDate ?? this.commissioningDate,
      status: status ?? this.status,
      statusDescription: statusDescription ?? this.statusDescription,
    );
  }
}

// Distribution Hierarchy Models
class DistributionZone extends HierarchyItem {
  final String stateName;

  DistributionZone({
    required super.id,
    required super.name,
    super.description,
    super.createdBy, // Now optional, matches superclass
    super.createdAt, // Now optional, matches superclass
    required this.stateName,
    super.landmark,
    super.contactNumber,
    super.contactPerson,
    super.contactDesignation,
  });

  factory DistributionZone.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map<String, dynamic>;
    return DistributionZone(
      id: doc.id,
      name: data['name'] ?? '',
      description: data['description'],
      createdBy:
          data['createdBy'], // No default needed here, as it's from Firestore
      createdAt:
          data['createdAt'], // No default needed here, as it's from Firestore
      stateName: data['stateName'] ?? '',
      landmark: data['landmark'],
      contactNumber: data['contactNumber'],
      contactPerson: data['contactPerson'],
      contactDesignation: data['contactDesignation'],
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
      'contactDesignation': contactDesignation,
    };
  }

  DistributionZone copyWith({
    String? id,
    String? name,
    String? description,
    String? createdBy,
    Timestamp? createdAt,
    String? stateName,
    String? landmark,
    String? contactNumber,
    String? contactPerson,
    String? contactDesignation,
  }) {
    return DistributionZone(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      stateName: stateName ?? this.stateName,
      landmark: landmark ?? this.landmark,
      contactNumber: contactNumber ?? this.contactNumber,
      contactPerson: contactPerson ?? this.contactPerson,
      contactDesignation: contactDesignation ?? this.contactDesignation,
    );
  }
}

class DistributionCircle extends HierarchyItem {
  final String distributionZoneId;

  DistributionCircle({
    required super.id,
    required super.name,
    super.description,
    super.createdBy, // Now optional, matches superclass
    super.createdAt, // Now optional, matches superclass
    required this.distributionZoneId,
    super.landmark,
    super.contactNumber,
    super.contactPerson,
    super.contactDesignation,
  });

  factory DistributionCircle.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map<String, dynamic>;
    return DistributionCircle(
      id: doc.id,
      name: data['name'] ?? '',
      description: data['description'],
      createdBy:
          data['createdBy'], // No default needed here, as it's from Firestore
      createdAt:
          data['createdAt'], // No default needed here, as it's from Firestore
      distributionZoneId: data['distributionZoneId'] ?? '',
      landmark: data['landmark'],
      contactNumber: data['contactNumber'],
      contactPerson: data['contactPerson'],
      contactDesignation: data['contactDesignation'],
    );
  }

  @override
  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'description': description,
      'createdBy': createdBy,
      'createdAt': createdAt,
      'distributionZoneId': distributionZoneId,
      'landmark': landmark,
      'contactNumber': contactNumber,
      'contactPerson': contactPerson,
      'contactDesignation': contactDesignation,
    };
  }

  DistributionCircle copyWith({
    String? id,
    String? name,
    String? description,
    String? createdBy,
    Timestamp? createdAt,
    String? distributionZoneId,
    String? landmark,
    String? contactNumber,
    String? contactPerson,
    String? contactDesignation,
  }) {
    return DistributionCircle(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      distributionZoneId: distributionZoneId ?? this.distributionZoneId,
      landmark: landmark ?? this.landmark,
      contactNumber: contactNumber ?? this.contactNumber,
      contactPerson: contactPerson ?? this.contactPerson,
      contactDesignation: contactDesignation ?? this.contactDesignation,
    );
  }
}

class DistributionDivision extends HierarchyItem {
  final String distributionCircleId;

  DistributionDivision({
    required super.id,
    required super.name,
    super.description,
    super.createdBy, // Now optional, matches superclass
    super.createdAt, // Now optional, matches superclass
    required this.distributionCircleId,
    super.landmark,
    super.contactNumber,
    super.contactPerson,
    super.contactDesignation,
  });

  factory DistributionDivision.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map<String, dynamic>;
    return DistributionDivision(
      id: doc.id,
      name: data['name'] ?? '',
      description: data['description'],
      createdBy:
          data['createdBy'], // No default needed here, as it's from Firestore
      createdAt:
          data['createdAt'], // No default needed here, as it's from Firestore
      distributionCircleId: data['distributionCircleId'] ?? '',
      landmark: data['landmark'],
      contactNumber: data['contactNumber'],
      contactPerson: data['contactPerson'],
      contactDesignation: data['contactDesignation'],
    );
  }

  @override
  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'description': description,
      'createdBy': createdBy,
      'createdAt': createdAt,
      'distributionCircleId': distributionCircleId,
      'landmark': landmark,
      'contactNumber': contactNumber,
      'contactPerson': contactPerson,
      'contactDesignation': contactDesignation,
    };
  }

  DistributionDivision copyWith({
    String? id,
    String? name,
    String? description,
    String? createdBy,
    Timestamp? createdAt,
    String? distributionCircleId,
    String? landmark,
    String? contactNumber,
    String? contactPerson,
    String? contactDesignation,
  }) {
    return DistributionDivision(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      distributionCircleId: distributionCircleId ?? this.distributionCircleId,
      landmark: landmark ?? this.landmark,
      contactNumber: contactNumber ?? this.contactNumber,
      contactPerson: contactPerson ?? this.contactPerson,
      contactDesignation: contactDesignation ?? this.contactDesignation,
    );
  }
}

// NEW: DistributionSubdivision Model
class DistributionSubdivision extends HierarchyItem {
  final String distributionDivisionId;

  DistributionSubdivision({
    required super.id,
    required super.name,
    super.description,
    super.createdBy, // Now optional, matches superclass
    super.createdAt, // Now optional, matches superclass
    required this.distributionDivisionId,
    super.landmark,
    super.contactNumber,
    super.contactPerson,
    super.contactDesignation,
  });

  factory DistributionSubdivision.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map<String, dynamic>;
    return DistributionSubdivision(
      id: doc.id,
      name: data['name'] ?? '',
      description: data['description'],
      createdBy:
          data['createdBy'], // No default needed here, as it's from Firestore
      createdAt:
          data['createdAt'], // No default needed here, as it's from Firestore
      distributionDivisionId: data['distributionDivisionId'] ?? '',
      landmark: data['landmark'],
      contactNumber: data['contactNumber'],
      contactPerson: data['contactPerson'],
      contactDesignation: data['contactDesignation'],
    );
  }

  @override
  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'description': description,
      'createdBy': createdBy,
      'createdAt': createdAt,
      'distributionDivisionId': distributionDivisionId,
      'landmark': landmark,
      'contactNumber': contactNumber,
      'contactPerson': contactPerson,
      'contactDesignation': contactDesignation,
    };
  }

  DistributionSubdivision copyWith({
    String? id,
    String? name,
    String? description,
    String? createdBy,
    Timestamp? createdAt,
    String? distributionDivisionId,
    String? landmark,
    String? contactNumber,
    String? contactPerson,
    String? contactDesignation,
  }) {
    return DistributionSubdivision(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      distributionDivisionId:
          distributionDivisionId ?? this.distributionDivisionId,
      landmark: landmark ?? this.landmark,
      contactNumber: contactNumber ?? this.contactNumber,
      contactPerson: contactPerson ?? this.contactPerson,
      contactDesignation: contactDesignation ?? this.contactDesignation,
    );
  }
}
