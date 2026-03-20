// lib/old_app/models/hierarchy_models.dart
//
// Two distinct hierarchy representations:
//   1. HierarchyCache — the entire org tree as ONE Firestore document (read-optimized,
//      cached in SharedPreferences). Used at runtime for zero-cost name lookups.
//   2. Firestore-backed admin classes (Zone, Circle, Division, Subdivision, Company, etc.)
//      — individual Firestore documents that admins create/edit. Used by admin screens.

export 'substation_model.dart' show Substation, Busbar;
export 'base_hierarchy_item.dart' show HierarchyItem;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'base_hierarchy_item.dart';

// ════════════════════════════════════════════════════════════════════════════
// ADMIN CLASSES — individual Firestore documents for creating/editing hierarchy
// ════════════════════════════════════════════════════════════════════════════

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

  factory Company.fromMap(Map<String, dynamic> map) => Company(
    id: map['id'] ?? '',
    name: map['name'] ?? '',
    description: map['description'],
    createdBy: map['createdBy'],
    createdAt: map['createdAt'],
    stateId: map['stateId'] ?? '',
    address: map['address'],
    landmark: map['landmark'],
    contactNumber: map['contactNumber'],
    contactPerson: map['contactPerson'],
    contactDesignation: map['contactDesignation'],
  );

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

  factory Zone.fromMap(Map<String, dynamic> map) => Zone(
    id: map['id'] ?? '',
    name: map['name'] ?? '',
    description: map['description'],
    createdBy: map['createdBy'],
    createdAt: map['createdAt'],
    companyId: map['companyId'] ?? '',
    address: map['address'],
    landmark: map['landmark'],
    contactNumber: map['contactNumber'],
    contactPerson: map['contactPerson'],
    contactDesignation: map['contactDesignation'],
  );

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

  factory Circle.fromMap(Map<String, dynamic> map) => Circle(
    id: map['id'] ?? '',
    name: map['name'] ?? '',
    description: map['description'],
    createdBy: map['createdBy'],
    createdAt: map['createdAt'],
    zoneId: map['zoneId'] ?? '',
    address: map['address'],
    landmark: map['landmark'],
    contactNumber: map['contactNumber'],
    contactPerson: map['contactPerson'],
    contactDesignation: map['contactDesignation'],
  );

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

  factory Division.fromMap(Map<String, dynamic> map) => Division(
    id: map['id'] ?? '',
    name: map['name'] ?? '',
    description: map['description'],
    createdBy: map['createdBy'],
    createdAt: map['createdAt'],
    circleId: map['circleId'] ?? '',
    address: map['address'],
    landmark: map['landmark'],
    contactNumber: map['contactNumber'],
    contactPerson: map['contactPerson'],
    contactDesignation: map['contactDesignation'],
  );

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

  factory Subdivision.fromMap(Map<String, dynamic> map) => Subdivision(
    id: map['id'] ?? '',
    name: map['name'] ?? '',
    description: map['description'],
    createdBy: map['createdBy'],
    createdAt: map['createdAt'],
    divisionId: map['divisionId'] ?? '',
    address: map['address'],
    landmark: map['landmark'],
    contactNumber: map['contactNumber'],
    contactPerson: map['contactPerson'],
    contactDesignation: map['contactDesignation'],
  );

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

// ── Distribution side ────────────────────────────────────────────────────────

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

  factory DistributionZone.fromMap(Map<String, dynamic> map) => DistributionZone(
    id: map['id'] ?? '',
    name: map['name'] ?? '',
    description: map['description'],
    address: map['address'],
    createdBy: map['createdBy'],
    createdAt: map['createdAt'],
    stateName: map['stateName'] ?? '',
    landmark: map['landmark'],
    contactNumber: map['contactNumber'],
    contactPerson: map['contactPerson'],
    contactDesignation: map['contactDesignation'],
  );

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

  factory DistributionCircle.fromMap(Map<String, dynamic> map) => DistributionCircle(
    id: map['id'] ?? '',
    name: map['name'] ?? '',
    description: map['description'],
    address: map['address'],
    createdBy: map['createdBy'],
    createdAt: map['createdAt'],
    distributionZoneId: map['distributionZoneId'] ?? '',
    landmark: map['landmark'],
    contactNumber: map['contactNumber'],
    contactPerson: map['contactPerson'],
    contactDesignation: map['contactDesignation'],
  );

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

  factory DistributionDivision.fromMap(Map<String, dynamic> map) => DistributionDivision(
    id: map['id'] ?? '',
    name: map['name'] ?? '',
    description: map['description'],
    address: map['address'],
    createdBy: map['createdBy'],
    createdAt: map['createdAt'],
    distributionCircleId: map['distributionCircleId'] ?? '',
    landmark: map['landmark'],
    contactNumber: map['contactNumber'],
    contactPerson: map['contactPerson'],
    contactDesignation: map['contactDesignation'],
  );

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

  factory DistributionSubdivision.fromMap(Map<String, dynamic> map) => DistributionSubdivision(
    id: map['id'] ?? '',
    name: map['name'] ?? '',
    description: map['description'],
    address: map['address'],
    createdBy: map['createdBy'],
    createdAt: map['createdAt'],
    distributionDivisionId: map['distributionDivisionId'] ?? '',
    substationIds: List<String>.from(map['substationIds'] ?? []),
    landmark: map['landmark'],
    contactNumber: map['contactNumber'],
    contactPerson: map['contactPerson'],
    contactDesignation: map['contactDesignation'],
  );

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
    distributionDivisionId: distributionDivisionId ?? this.distributionDivisionId,
    substationIds: substationIds ?? this.substationIds,
    landmark: landmark ?? this.landmark,
    contactNumber: contactNumber ?? this.contactNumber,
    contactPerson: contactPerson ?? this.contactPerson,
    contactDesignation: contactDesignation ?? this.contactDesignation,
  );
}

// ════════════════════════════════════════════════════════════════════════════
// CACHE CLASSES — entire hierarchy as one JSON document (read-optimized)
// ════════════════════════════════════════════════════════════════════════════

class HierarchyCache {
  final Map<String, HierarchyZone> zones;
  final int version;

  const HierarchyCache({required this.zones, this.version = 0});

  factory HierarchyCache.empty() =>
      const HierarchyCache(zones: {}, version: 0);

  factory HierarchyCache.fromMap(Map<String, dynamic> data) {
    final zonesData = data['zones'] as Map<String, dynamic>? ?? {};
    return HierarchyCache(
      version: (data['version'] as num?)?.toInt() ?? 0,
      zones: zonesData.map(
        (id, z) => MapEntry(
          id,
          HierarchyZone.fromMap(id, z as Map<String, dynamic>),
        ),
      ),
    );
  }

  Map<String, dynamic> toMap() => {
    'version': version,
    'zones': zones.map((id, z) => MapEntry(id, z.toMap())),
  };

  bool get isEmpty => zones.isEmpty;

  // ── Name lookups (all in-memory, zero Firestore reads) ──────────────────

  String zoneName(String id) => zones[id]?.name ?? id;

  String circleName(String zoneId, String circleId) =>
      zones[zoneId]?.circles[circleId]?.name ?? circleId;

  String divisionName(String zoneId, String circleId, String divisionId) =>
      zones[zoneId]?.circles[circleId]?.divisions[divisionId]?.name ??
      divisionId;

  String subdivisionName(
    String zoneId,
    String circleId,
    String divisionId,
    String subdivisionId,
  ) =>
      zones[zoneId]
          ?.circles[circleId]
          ?.divisions[divisionId]
          ?.subdivisions[subdivisionId]
          ?.name ??
      subdivisionId;

  /// Full "Zone > Circle > Division > Subdivision" breadcrumb string.
  String breadcrumb({
    String? zoneId,
    String? circleId,
    String? divisionId,
    String? subdivisionId,
  }) {
    final parts = <String>[];
    if (zoneId != null) { parts.add(zoneName(zoneId)); }
    if (zoneId != null && circleId != null) {
      parts.add(circleName(zoneId, circleId));
    }
    if (zoneId != null && circleId != null && divisionId != null) {
      parts.add(divisionName(zoneId, circleId, divisionId));
    }
    if (zoneId != null && circleId != null && divisionId != null && subdivisionId != null) {
      parts.add(subdivisionName(zoneId, circleId, divisionId, subdivisionId));
    }
    return parts.join(' > ');
  }

  // ── List helpers for dropdowns / admin screens ────────────────────────────

  List<HierarchyZone> get allZones => zones.values.toList();

  List<HierarchyCircle> circlesForZone(String zoneId) =>
      zones[zoneId]?.circles.values.toList() ?? [];

  List<HierarchyDivision> divisionsForCircle(String zoneId, String circleId) =>
      zones[zoneId]?.circles[circleId]?.divisions.values.toList() ?? [];

  List<HierarchySubdivision> subdivisionsForDivision(
    String zoneId,
    String circleId,
    String divisionId,
  ) =>
      zones[zoneId]
          ?.circles[circleId]
          ?.divisions[divisionId]
          ?.subdivisions
          .values
          .toList() ??
      [];

  List<HierarchySubdivision> subdivisionsForZone(String zoneId) {
    final result = <HierarchySubdivision>[];
    final zone = zones[zoneId];
    if (zone == null) return result;
    for (final c in zone.circles.values) {
      for (final d in c.divisions.values) {
        result.addAll(d.subdivisions.values);
      }
    }
    return result;
  }

  List<HierarchySubdivision> subdivisionsForCircle(
    String zoneId,
    String circleId,
  ) {
    final result = <HierarchySubdivision>[];
    final circle = zones[zoneId]?.circles[circleId];
    if (circle == null) return result;
    for (final d in circle.divisions.values) {
      result.addAll(d.subdivisions.values);
    }
    return result;
  }

  List<HierarchySubdivision> get allSubdivisions {
    final result = <HierarchySubdivision>[];
    for (final z in zones.values) {
      for (final c in z.circles.values) {
        for (final d in c.divisions.values) {
          result.addAll(d.subdivisions.values);
        }
      }
    }
    return result;
  }
}

// ── Node classes ─────────────────────────────────────────────────────────────

class HierarchyZone {
  final String id;
  final String name;
  final String? contactPerson;
  final String? contactNumber;
  final Map<String, HierarchyCircle> circles;

  const HierarchyZone({
    required this.id,
    required this.name,
    this.contactPerson,
    this.contactNumber,
    required this.circles,
  });

  factory HierarchyZone.fromMap(String id, Map<String, dynamic> data) {
    final circlesData = data['circles'] as Map<String, dynamic>? ?? {};
    return HierarchyZone(
      id: id,
      name: data['name'] ?? '',
      contactPerson: data['contactPerson'],
      contactNumber: data['contactNumber'],
      circles: circlesData.map(
        (cId, cData) => MapEntry(
          cId,
          HierarchyCircle.fromMap(cId, cData as Map<String, dynamic>),
        ),
      ),
    );
  }

  Map<String, dynamic> toMap() => {
    'name': name,
    if (contactPerson != null) 'contactPerson': contactPerson,
    if (contactNumber != null) 'contactNumber': contactNumber,
    'circles': circles.map((id, c) => MapEntry(id, c.toMap())),
  };
}

class HierarchyCircle {
  final String id;
  final String name;
  final String? contactPerson;
  final String? contactNumber;
  final Map<String, HierarchyDivision> divisions;

  const HierarchyCircle({
    required this.id,
    required this.name,
    this.contactPerson,
    this.contactNumber,
    required this.divisions,
  });

  factory HierarchyCircle.fromMap(String id, Map<String, dynamic> data) {
    final divisionsData = data['divisions'] as Map<String, dynamic>? ?? {};
    return HierarchyCircle(
      id: id,
      name: data['name'] ?? '',
      contactPerson: data['contactPerson'],
      contactNumber: data['contactNumber'],
      divisions: divisionsData.map(
        (dId, dData) => MapEntry(
          dId,
          HierarchyDivision.fromMap(dId, dData as Map<String, dynamic>),
        ),
      ),
    );
  }

  Map<String, dynamic> toMap() => {
    'name': name,
    if (contactPerson != null) 'contactPerson': contactPerson,
    if (contactNumber != null) 'contactNumber': contactNumber,
    'divisions': divisions.map((id, d) => MapEntry(id, d.toMap())),
  };
}

class HierarchyDivision {
  final String id;
  final String name;
  final String? contactPerson;
  final String? contactNumber;
  final Map<String, HierarchySubdivision> subdivisions;

  const HierarchyDivision({
    required this.id,
    required this.name,
    this.contactPerson,
    this.contactNumber,
    required this.subdivisions,
  });

  factory HierarchyDivision.fromMap(String id, Map<String, dynamic> data) {
    final subData = data['subdivisions'] as Map<String, dynamic>? ?? {};
    return HierarchyDivision(
      id: id,
      name: data['name'] ?? '',
      contactPerson: data['contactPerson'],
      contactNumber: data['contactNumber'],
      subdivisions: subData.map(
        (sId, sData) => MapEntry(
          sId,
          HierarchySubdivision.fromMap(sId, sData as Map<String, dynamic>),
        ),
      ),
    );
  }

  Map<String, dynamic> toMap() => {
    'name': name,
    if (contactPerson != null) 'contactPerson': contactPerson,
    if (contactNumber != null) 'contactNumber': contactNumber,
    'subdivisions': subdivisions.map((id, s) => MapEntry(id, s.toMap())),
  };
}

class HierarchySubdivision {
  final String id;
  final String name;
  final String? contactPerson;
  final String? contactNumber;

  const HierarchySubdivision({
    required this.id,
    required this.name,
    this.contactPerson,
    this.contactNumber,
  });

  factory HierarchySubdivision.fromMap(String id, Map<String, dynamic> data) =>
      HierarchySubdivision(
        id: id,
        name: data['name'] ?? '',
        contactPerson: data['contactPerson'],
        contactNumber: data['contactNumber'],
      );

  Map<String, dynamic> toMap() => {
    'name': name,
    if (contactPerson != null) 'contactPerson': contactPerson,
    if (contactNumber != null) 'contactNumber': contactNumber,
  };

  HierarchySubdivision copyWith({
    String? id,
    String? name,
    String? contactPerson,
    String? contactNumber,
  }) => HierarchySubdivision(
    id: id ?? this.id,
    name: name ?? this.name,
    contactPerson: contactPerson ?? this.contactPerson,
    contactNumber: contactNumber ?? this.contactNumber,
  );
}
