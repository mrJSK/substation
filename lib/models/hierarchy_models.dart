// lib/models/hierarchy_models.dart
import 'package:cloud_firestore/cloud_firestore.dart';

/// ---------------------------------------------------------------------------
///                               Core abstract
/// ---------------------------------------------------------------------------
abstract class HierarchyItem {
  final String id;
  final String name;
  final String? description;
  final String? createdBy;
  final Timestamp? createdAt;

  final String? address;
  final String? landmark;
  final String? contactNumber;
  final String? contactPerson;
  final String? contactDesignation;

  HierarchyItem({
    required this.id,
    required this.name,
    this.description,
    this.createdBy,
    this.createdAt,
    this.address,
    this.landmark,
    this.contactNumber,
    this.contactPerson,
    this.contactDesignation,
  });

  Map<String, dynamic> toFirestore();

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HierarchyItem &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}

/// ---------------------------------------------------------------------------
///                               Application State
/// ---------------------------------------------------------------------------
class AppScreenState extends HierarchyItem {
  AppScreenState({
    required super.id,
    required super.name,
    super.description,
    super.createdBy,
    super.createdAt,
    super.address,
    super.landmark,
    super.contactNumber,
    super.contactPerson,
    super.contactDesignation,
  });

  factory AppScreenState.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return AppScreenState(
      id: doc.id,
      name: data['name'] ?? '',
      description: data['description'],
      createdBy: data['createdBy'],
      createdAt: data['createdAt'],
      address: data['address'],
      landmark: data['landmark'],
      contactNumber: data['contactNumber'],
      contactPerson: data['contactPerson'],
      contactDesignation: data['contactDesignation'],
    );
  }

  @override
  Map<String, dynamic> toFirestore() => {
    'name': name,
    'description': description,
    'createdBy': createdBy,
    'createdAt': createdAt,
    'address': address,
    'landmark': landmark,
    'contactNumber': contactNumber,
    'contactPerson': contactPerson,
    'contactDesignation': contactDesignation,
  };

  AppScreenState copyWith({
    String? id,
    String? name,
    String? description,
    String? createdBy,
    Timestamp? createdAt,
    String? address,
    String? landmark,
    String? contactNumber,
    String? contactPerson,
    String? contactDesignation,
  }) => AppScreenState(
    id: id ?? this.id,
    name: name ?? this.name,
    description: description ?? this.description,
    createdBy: createdBy ?? this.createdBy,
    createdAt: createdAt ?? this.createdAt,
    address: address ?? this.address,
    landmark: landmark ?? this.landmark,
    contactNumber: contactNumber ?? this.contactNumber,
    contactPerson: contactPerson ?? this.contactPerson,
    contactDesignation: contactDesignation ?? this.contactDesignation,
  );
}

/// ---------------------------------------------------------------------------
///                               Transmission side
/// ---------------------------------------------------------------------------
class Company extends HierarchyItem {
  final String stateId;

  Company({
    required super.id,
    required super.name,
    super.description,
    super.createdBy,
    super.createdAt,
    required this.stateId,
    super.address,
    super.landmark,
    super.contactNumber,
    super.contactPerson,
    super.contactDesignation,
  });

  factory Company.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Company(
      id: doc.id,
      name: data['name'] ?? '',
      description: data['description'],
      createdBy: data['createdBy'],
      createdAt: data['createdAt'],
      stateId: data['stateId'] ?? '',
      address: data['address'],
      landmark: data['landmark'],
      contactNumber: data['contactNumber'],
      contactPerson: data['contactPerson'],
      contactDesignation: data['contactDesignation'],
    );
  }

  @override
  Map<String, dynamic> toFirestore() => {
    'name': name,
    'description': description,
    'createdBy': createdBy,
    'createdAt': createdAt,
    'stateId': stateId,
    'address': address,
    'landmark': landmark,
    'contactNumber': contactNumber,
    'contactPerson': contactPerson,
    'contactDesignation': contactDesignation,
  };

  Company copyWith({
    String? id,
    String? name,
    String? description,
    String? createdBy,
    Timestamp? createdAt,
    String? stateId,
    String? address,
    String? landmark,
    String? contactNumber,
    String? contactPerson,
    String? contactDesignation,
  }) => Company(
    id: id ?? this.id,
    name: name ?? this.name,
    description: description ?? this.description,
    createdBy: createdBy ?? this.createdBy,
    createdAt: createdAt ?? this.createdAt,
    stateId: stateId ?? this.stateId,
    address: address ?? this.address,
    landmark: landmark ?? this.landmark,
    contactNumber: contactNumber ?? this.contactNumber,
    contactPerson: contactPerson ?? this.contactPerson,
    contactDesignation: contactDesignation ?? this.contactDesignation,
  );
}

class Zone extends HierarchyItem {
  final String companyId;

  Zone({
    required super.id,
    required super.name,
    super.description,
    super.createdBy,
    super.createdAt,
    required this.companyId,
    super.address,
    super.landmark,
    super.contactNumber,
    super.contactPerson,
    super.contactDesignation,
  });

  factory Zone.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Zone(
      id: doc.id,
      name: data['name'] ?? '',
      description: data['description'],
      createdBy: data['createdBy'],
      createdAt: data['createdAt'],
      companyId: data['companyId'] ?? '',
      address: data['address'],
      landmark: data['landmark'],
      contactNumber: data['contactNumber'],
      contactPerson: data['contactPerson'],
      contactDesignation: data['contactDesignation'],
    );
  }

  @override
  Map<String, dynamic> toFirestore() => {
    'name': name,
    'description': description,
    'createdBy': createdBy,
    'createdAt': createdAt,
    'companyId': companyId,
    'address': address,
    'landmark': landmark,
    'contactNumber': contactNumber,
    'contactPerson': contactPerson,
    'contactDesignation': contactDesignation,
  };

  Zone copyWith({
    String? id,
    String? name,
    String? description,
    String? createdBy,
    Timestamp? createdAt,
    String? companyId,
    String? address,
    String? landmark,
    String? contactNumber,
    String? contactPerson,
    String? contactDesignation,
  }) => Zone(
    id: id ?? this.id,
    name: name ?? this.name,
    description: description ?? this.description,
    createdBy: createdBy ?? this.createdBy,
    createdAt: createdAt ?? this.createdAt,
    companyId: companyId ?? this.companyId,
    address: address ?? this.address,
    landmark: landmark ?? this.landmark,
    contactNumber: contactNumber ?? this.contactNumber,
    contactPerson: contactPerson ?? this.contactPerson,
    contactDesignation: contactDesignation ?? this.contactDesignation,
  );
}

class Circle extends HierarchyItem {
  final String zoneId;

  Circle({
    required super.id,
    required super.name,
    super.description,
    super.createdBy,
    super.createdAt,
    required this.zoneId,
    super.address,
    super.landmark,
    super.contactNumber,
    super.contactPerson,
    super.contactDesignation,
  });

  factory Circle.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Circle(
      id: doc.id,
      name: data['name'] ?? '',
      description: data['description'],
      createdBy: data['createdBy'],
      createdAt: data['createdAt'],
      zoneId: data['zoneId'] ?? '',
      address: data['address'],
      landmark: data['landmark'],
      contactNumber: data['contactNumber'],
      contactPerson: data['contactPerson'],
      contactDesignation: data['contactDesignation'],
    );
  }

  @override
  Map<String, dynamic> toFirestore() => {
    'name': name,
    'description': description,
    'createdBy': createdBy,
    'createdAt': createdAt,
    'zoneId': zoneId,
    'address': address,
    'landmark': landmark,
    'contactNumber': contactNumber,
    'contactPerson': contactPerson,
    'contactDesignation': contactDesignation,
  };

  Circle copyWith({
    String? id,
    String? name,
    String? description,
    String? createdBy,
    Timestamp? createdAt,
    String? zoneId,
    String? address,
    String? landmark,
    String? contactNumber,
    String? contactPerson,
    String? contactDesignation,
  }) => Circle(
    id: id ?? this.id,
    name: name ?? this.name,
    description: description ?? this.description,
    createdBy: createdBy ?? this.createdBy,
    createdAt: createdAt ?? this.createdAt,
    zoneId: zoneId ?? this.zoneId,
    address: address ?? this.address,
    landmark: landmark ?? this.landmark,
    contactNumber: contactNumber ?? this.contactNumber,
    contactPerson: contactPerson ?? this.contactPerson,
    contactDesignation: contactDesignation ?? this.contactDesignation,
  );
}

class Division extends HierarchyItem {
  final String circleId;

  Division({
    required super.id,
    required super.name,
    super.description,
    super.createdBy,
    super.createdAt,
    required this.circleId,
    super.address,
    super.landmark,
    super.contactNumber,
    super.contactPerson,
    super.contactDesignation,
  });

  factory Division.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Division(
      id: doc.id,
      name: data['name'] ?? '',
      description: data['description'],
      createdBy: data['createdBy'],
      createdAt: data['createdAt'],
      circleId: data['circleId'] ?? '',
      address: data['address'],
      landmark: data['landmark'],
      contactNumber: data['contactNumber'],
      contactPerson: data['contactPerson'],
      contactDesignation: data['contactDesignation'],
    );
  }

  @override
  Map<String, dynamic> toFirestore() => {
    'name': name,
    'description': description,
    'createdBy': createdBy,
    'createdAt': createdAt,
    'circleId': circleId,
    'address': address,
    'landmark': landmark,
    'contactNumber': contactNumber,
    'contactPerson': contactPerson,
    'contactDesignation': contactDesignation,
  };

  Division copyWith({
    String? id,
    String? name,
    String? description,
    String? createdBy,
    Timestamp? createdAt,
    String? circleId,
    String? address,
    String? landmark,
    String? contactNumber,
    String? contactPerson,
    String? contactDesignation,
  }) => Division(
    id: id ?? this.id,
    name: name ?? this.name,
    description: description ?? this.description,
    createdBy: createdBy ?? this.createdBy,
    createdAt: createdAt ?? this.createdAt,
    circleId: circleId ?? this.circleId,
    address: address ?? this.address,
    landmark: landmark ?? this.landmark,
    contactNumber: contactNumber ?? this.contactNumber,
    contactPerson: contactPerson ?? this.contactPerson,
    contactDesignation: contactDesignation ?? this.contactDesignation,
  );
}

class Subdivision extends HierarchyItem {
  final String divisionId;

  Subdivision({
    required super.id,
    required super.name,
    super.description,
    super.createdBy,
    super.createdAt,
    required this.divisionId,
    super.address,
    super.landmark,
    super.contactNumber,
    super.contactPerson,
    super.contactDesignation,
  });

  factory Subdivision.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Subdivision(
      id: doc.id,
      name: data['name'] ?? '',
      description: data['description'],
      createdBy: data['createdBy'],
      createdAt: data['createdAt'],
      divisionId: data['divisionId'] ?? '',
      address: data['address'],
      landmark: data['landmark'],
      contactNumber: data['contactNumber'],
      contactPerson: data['contactPerson'],
      contactDesignation: data['contactDesignation'],
    );
  }

  @override
  Map<String, dynamic> toFirestore() => {
    'name': name,
    'description': description,
    'createdBy': createdBy,
    'createdAt': createdAt,
    'divisionId': divisionId,
    'address': address,
    'landmark': landmark,
    'contactNumber': contactNumber,
    'contactPerson': contactPerson,
    'contactDesignation': contactDesignation,
  };

  Subdivision copyWith({
    String? id,
    String? name,
    String? description,
    String? createdBy,
    Timestamp? createdAt,
    String? divisionId,
    String? address,
    String? landmark,
    String? contactNumber,
    String? contactPerson,
    String? contactDesignation,
  }) => Subdivision(
    id: id ?? this.id,
    name: name ?? this.name,
    description: description ?? this.description,
    createdBy: createdBy ?? this.createdBy,
    createdAt: createdAt ?? this.createdAt,
    divisionId: divisionId ?? this.divisionId,
    address: address ?? this.address,
    landmark: landmark ?? this.landmark,
    contactNumber: contactNumber ?? this.contactNumber,
    contactPerson: contactPerson ?? this.contactPerson,
    contactDesignation: contactDesignation ?? this.contactDesignation,
  );
}

class Substation extends HierarchyItem {
  final String subdivisionId;
  final String? cityId;
  final String? voltageLevel;
  final String? type;
  final String? operation;
  final String? sasMake;
  final Timestamp? commissioningDate;
  final String? status;
  final String? statusDescription;

  // Add these fields to store the hierarchy names
  final String? subdivisionName;
  final String? divisionName;
  final String? circleName;

  Substation({
    required super.id,
    required super.name,
    super.description,
    super.createdBy,
    super.createdAt,
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
    // Add these parameters
    this.subdivisionName,
    this.divisionName,
    this.circleName,
  });

  @override
  final String? address;

  factory Substation.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Substation(
      id: doc.id,
      name: data['name'] ?? '',
      description: data['description'],
      createdBy: data['createdBy'],
      createdAt: data['createdAt'],
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
      // Add these fields
      subdivisionName: data['subdivisionName'],
      divisionName: data['divisionName'],
      circleName: data['circleName'],
    );
  }

  @override
  Map<String, dynamic> toFirestore() => {
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
    // Add these fields
    'subdivisionName': subdivisionName,
    'divisionName': divisionName,
    'circleName': circleName,
  };

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
    // Add these parameters
    String? subdivisionName,
    String? divisionName,
    String? circleName,
  }) => Substation(
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
    // Add these fields
    subdivisionName: subdivisionName ?? this.subdivisionName,
    divisionName: divisionName ?? this.divisionName,
    circleName: circleName ?? this.circleName,
  );
}

/// ---------------------------------------------------------------------------
///                               Distribution side
/// ---------------------------------------------------------------------------
class DistributionZone extends HierarchyItem {
  final String stateName;

  DistributionZone({
    required super.id,
    required super.name,
    super.description,
    super.address,
    super.createdBy,
    super.createdAt,
    required this.stateName,
    super.landmark,
    super.contactNumber,
    super.contactPerson,
    super.contactDesignation,
  });

  factory DistributionZone.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return DistributionZone(
      id: doc.id,
      name: data['name'] ?? '',
      description: data['description'],
      address: data['address'],
      createdBy: data['createdBy'],
      createdAt: data['createdAt'],
      stateName: data['stateName'] ?? '',
      landmark: data['landmark'],
      contactNumber: data['contactNumber'],
      contactPerson: data['contactPerson'],
      contactDesignation: data['contactDesignation'],
    );
  }

  @override
  Map<String, dynamic> toFirestore() => {
    'name': name,
    'description': description,
    'address': address,
    'createdBy': createdBy,
    'createdAt': createdAt,
    'stateName': stateName,
    'landmark': landmark,
    'contactNumber': contactNumber,
    'contactPerson': contactPerson,
    'contactDesignation': contactDesignation,
  };

  DistributionZone copyWith({
    String? id,
    String? name,
    String? description,
    String? address,
    String? createdBy,
    Timestamp? createdAt,
    String? stateName,
    String? landmark,
    String? contactNumber,
    String? contactPerson,
    String? contactDesignation,
  }) => DistributionZone(
    id: id ?? this.id,
    name: name ?? this.name,
    description: description ?? this.description,
    address: address ?? this.address,
    createdBy: createdBy ?? this.createdBy,
    createdAt: createdAt ?? this.createdAt,
    stateName: stateName ?? this.stateName,
    landmark: landmark ?? this.landmark,
    contactNumber: contactNumber ?? this.contactNumber,
    contactPerson: contactPerson ?? this.contactPerson,
    contactDesignation: contactDesignation ?? this.contactDesignation,
  );
}

class DistributionCircle extends HierarchyItem {
  final String distributionZoneId;

  DistributionCircle({
    required super.id,
    required super.name,
    super.description,
    super.address,
    super.createdBy,
    super.createdAt,
    required this.distributionZoneId,
    super.landmark,
    super.contactNumber,
    super.contactPerson,
    super.contactDesignation,
  });

  factory DistributionCircle.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return DistributionCircle(
      id: doc.id,
      name: data['name'] ?? '',
      description: data['description'],
      address: data['address'],
      createdBy: data['createdBy'],
      createdAt: data['createdAt'],
      distributionZoneId: data['distributionZoneId'] ?? '',
      landmark: data['landmark'],
      contactNumber: data['contactNumber'],
      contactPerson: data['contactPerson'],
      contactDesignation: data['contactDesignation'],
    );
  }

  @override
  Map<String, dynamic> toFirestore() => {
    'name': name,
    'description': description,
    'address': address,
    'createdBy': createdBy,
    'createdAt': createdAt,
    'distributionZoneId': distributionZoneId,
    'landmark': landmark,
    'contactNumber': contactNumber,
    'contactPerson': contactPerson,
    'contactDesignation': contactDesignation,
  };

  DistributionCircle copyWith({
    String? id,
    String? name,
    String? description,
    String? address,
    String? createdBy,
    Timestamp? createdAt,
    String? distributionZoneId,
    String? landmark,
    String? contactNumber,
    String? contactPerson,
    String? contactDesignation,
  }) => DistributionCircle(
    id: id ?? this.id,
    name: name ?? this.name,
    description: description ?? this.description,
    address: address ?? this.address,
    createdBy: createdBy ?? this.createdBy,
    createdAt: createdAt ?? this.createdAt,
    distributionZoneId: distributionZoneId ?? this.distributionZoneId,
    landmark: landmark ?? this.landmark,
    contactNumber: contactNumber ?? this.contactNumber,
    contactPerson: contactPerson ?? this.contactPerson,
    contactDesignation: contactDesignation ?? this.contactDesignation,
  );
}

class DistributionDivision extends HierarchyItem {
  final String distributionCircleId;

  DistributionDivision({
    required super.id,
    required super.name,
    super.description,
    super.address,
    super.createdBy,
    super.createdAt,
    required this.distributionCircleId,
    super.landmark,
    super.contactNumber,
    super.contactPerson,
    super.contactDesignation,
  });

  factory DistributionDivision.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return DistributionDivision(
      id: doc.id,
      name: data['name'] ?? '',
      description: data['description'],
      address: data['address'],
      createdBy: data['createdBy'],
      createdAt: data['createdAt'],
      distributionCircleId: data['distributionCircleId'] ?? '',
      landmark: data['landmark'],
      contactNumber: data['contactNumber'],
      contactPerson: data['contactPerson'],
      contactDesignation: data['contactDesignation'],
    );
  }

  @override
  Map<String, dynamic> toFirestore() => {
    'name': name,
    'description': description,
    'address': address,
    'createdBy': createdBy,
    'createdAt': createdAt,
    'distributionCircleId': distributionCircleId,
    'landmark': landmark,
    'contactNumber': contactNumber,
    'contactPerson': contactPerson,
    'contactDesignation': contactDesignation,
  };

  DistributionDivision copyWith({
    String? id,
    String? name,
    String? description,
    String? address,
    String? createdBy,
    Timestamp? createdAt,
    String? distributionCircleId,
    String? landmark,
    String? contactNumber,
    String? contactPerson,
    String? contactDesignation,
  }) => DistributionDivision(
    id: id ?? this.id,
    name: name ?? this.name,
    description: description ?? this.description,
    address: address ?? this.address,
    createdBy: createdBy ?? this.createdBy,
    createdAt: createdAt ?? this.createdAt,
    distributionCircleId: distributionCircleId ?? this.distributionCircleId,
    landmark: landmark ?? this.landmark,
    contactNumber: contactNumber ?? this.contactNumber,
    contactPerson: contactPerson ?? this.contactPerson,
    contactDesignation: contactDesignation ?? this.contactDesignation,
  );
}

class DistributionSubdivision extends HierarchyItem {
  final String distributionDivisionId;
  final List<String> substationIds;

  DistributionSubdivision({
    required super.id,
    required super.name,
    super.description,
    super.address,
    super.createdBy,
    super.createdAt,
    required this.distributionDivisionId,
    this.substationIds = const [],
    super.landmark,
    super.contactNumber,
    super.contactPerson,
    super.contactDesignation,
  });

  factory DistributionSubdivision.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return DistributionSubdivision(
      id: doc.id,
      name: data['name'] ?? '',
      description: data['description'],
      address: data['address'],
      createdBy: data['createdBy'],
      createdAt: data['createdAt'],
      distributionDivisionId: data['distributionDivisionId'] ?? '',
      substationIds: List<String>.from(data['substationIds'] ?? []),
      landmark: data['landmark'],
      contactNumber: data['contactNumber'],
      contactPerson: data['contactPerson'],
      contactDesignation: data['contactDesignation'],
    );
  }

  @override
  Map<String, dynamic> toFirestore() => {
    'name': name,
    'description': description,
    'address': address,
    'createdBy': createdBy,
    'createdAt': createdAt,
    'distributionDivisionId': distributionDivisionId,
    'substationIds': substationIds,
    'landmark': landmark,
    'contactNumber': contactNumber,
    'contactPerson': contactPerson,
    'contactDesignation': contactDesignation,
  };

  DistributionSubdivision copyWith({
    String? id,
    String? name,
    String? description,
    String? address,
    String? createdBy,
    Timestamp? createdAt,
    String? distributionDivisionId,
    List<String>? substationIds,
    String? landmark,
    String? contactNumber,
    String? contactPerson,
    String? contactDesignation,
  }) => DistributionSubdivision(
    id: id ?? this.id,
    name: name ?? this.name,
    description: description ?? this.description,
    address: address ?? this.address,
    createdBy: createdBy ?? this.createdBy,
    createdAt: createdAt ?? this.createdAt,
    distributionDivisionId:
        distributionDivisionId ?? this.distributionDivisionId,
    substationIds: substationIds ?? this.substationIds,
    landmark: landmark ?? this.landmark,
    contactNumber: contactNumber ?? this.contactNumber,
    contactPerson: contactPerson ?? this.contactPerson,
    contactDesignation: contactDesignation ?? this.contactDesignation,
  );
}
