// lib/old_app/models/substation_model.dart
//
// Substation stored in Firestore collection 'substations'.
// Bays are EMBEDDED as an array — loading a substation loads all bays in ONE read.
// Hierarchy IDs are denormalized so any manager level can query with one .where().

import 'package:cloud_firestore/cloud_firestore.dart';
import 'bay_model.dart';
import 'base_hierarchy_item.dart';

// ── Busbar ───────────────────────────────────────────────────────────────────

class Busbar {
  final String id;
  final String name;
  final String voltageLevel;
  final double? xPosition;
  final double? yPosition;
  final double? busbarLength;

  const Busbar({
    required this.id,
    required this.name,
    required this.voltageLevel,
    this.xPosition,
    this.yPosition,
    this.busbarLength,
  });

  factory Busbar.fromMap(Map<String, dynamic> data) => Busbar(
    id: data['id'] ?? '',
    name: data['name'] ?? '',
    voltageLevel: data['voltageLevel'] ?? '',
    xPosition: (data['xPosition'] as num?)?.toDouble(),
    yPosition: (data['yPosition'] as num?)?.toDouble(),
    busbarLength: (data['busbarLength'] as num?)?.toDouble(),
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'voltageLevel': voltageLevel,
    if (xPosition != null) 'xPosition': xPosition,
    if (yPosition != null) 'yPosition': yPosition,
    if (busbarLength != null) 'busbarLength': busbarLength,
  };

  Busbar copyWith({
    String? id,
    String? name,
    String? voltageLevel,
    double? xPosition,
    double? yPosition,
    double? busbarLength,
  }) => Busbar(
    id: id ?? this.id,
    name: name ?? this.name,
    voltageLevel: voltageLevel ?? this.voltageLevel,
    xPosition: xPosition ?? this.xPosition,
    yPosition: yPosition ?? this.yPosition,
    busbarLength: busbarLength ?? this.busbarLength,
  );
}

// ── Substation ────────────────────────────────────────────────────────────────

class Substation extends HierarchyItem {
  /// Denormalized hierarchy IDs — any manager level can query with one .where().
  final String subdivisionId;
  final String divisionId;
  final String circleId;
  final String zoneId;

  // Details
  final String? voltageLevel;
  final String? type;
  final String? operation;
  final String? sasMake;
  final String? status;
  final String? statusDescription;
  final String? cityId;
  final Timestamp? commissioningDate;

  /// Denormalized name fields for display without extra reads.
  final String? subdivisionName;
  final String? divisionName;
  final String? circleName;

  /// Bays embedded — loading a substation loads all bays in ONE read.
  final List<Bay> bays;

  /// Busbars embedded.
  final List<Busbar> busbars;

  /// Reading template IDs assigned to this substation's bay types.
  final List<String> readingTemplateIds;

  const Substation({
    required super.id,
    required super.name,
    required this.subdivisionId,
    required this.divisionId,
    required this.circleId,
    required this.zoneId,
    this.voltageLevel,
    this.type,
    this.operation,
    this.sasMake,
    this.status,
    this.statusDescription,
    super.address,
    this.cityId,
    super.landmark,
    super.contactPerson,
    super.contactNumber,
    super.contactDesignation,
    super.description,
    this.commissioningDate,
    super.createdBy,
    super.createdAt,
    this.bays = const [],
    this.busbars = const [],
    this.readingTemplateIds = const [],
    this.subdivisionName,
    this.divisionName,
    this.circleName,
  });

  factory Substation.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Substation(
      id: doc.id,
      name: data['name'] ?? '',
      subdivisionId: data['subdivisionId'] ?? '',
      divisionId: data['divisionId'] ?? '',
      circleId: data['circleId'] ?? '',
      zoneId: data['zoneId'] ?? '',
      voltageLevel: data['voltageLevel'],
      type: data['type'],
      operation: data['operation'],
      sasMake: data['sasMake'],
      status: data['status'],
      statusDescription: data['statusDescription'],
      address: data['address'],
      landmark: data['landmark'],
      contactPerson: data['contactPerson'],
      contactNumber: data['contactNumber'],
      contactDesignation: data['contactDesignation'],
      description: data['description'],
      commissioningDate: data['commissioningDate'] as Timestamp?,
      createdBy: data['createdBy'],
      createdAt: data['createdAt'] as Timestamp?,
      bays: (data['bays'] as List<dynamic>? ?? [])
          .map((b) => Bay.fromMap(b as Map<String, dynamic>))
          .toList(),
      busbars: (data['busbars'] as List<dynamic>? ?? [])
          .map((b) => Busbar.fromMap(b as Map<String, dynamic>))
          .toList(),
      readingTemplateIds:
          (data['readingTemplateIds'] as List<dynamic>? ?? [])
              .map((e) => e.toString())
              .toList(),
      cityId: data['cityId'],
      subdivisionName: data['subdivisionName'],
      divisionName: data['divisionName'],
      circleName: data['circleName'],
    );
  }

  @override
  Map<String, dynamic> toFirestore() => {
    'name': name,
    'subdivisionId': subdivisionId,
    'divisionId': divisionId,
    'circleId': circleId,
    'zoneId': zoneId,
    'voltageLevel': voltageLevel,
    'type': type,
    'operation': operation,
    'sasMake': sasMake,
    'status': status,
    'statusDescription': statusDescription,
    'address': address,
    'landmark': landmark,
    'contactPerson': contactPerson,
    'contactNumber': contactNumber,
    'contactDesignation': contactDesignation,
    'description': description,
    'commissioningDate': commissioningDate,
    'createdBy': createdBy,
    'createdAt': createdAt ?? FieldValue.serverTimestamp(),
    'bays': bays.map((b) => b.toMap()).toList(),
    'busbars': busbars.map((b) => b.toMap()).toList(),
    'readingTemplateIds': readingTemplateIds,
    if (cityId != null) 'cityId': cityId,
    if (subdivisionName != null) 'subdivisionName': subdivisionName,
    if (divisionName != null) 'divisionName': divisionName,
    if (circleName != null) 'circleName': circleName,
  };

  Substation copyWith({
    String? id,
    String? name,
    String? subdivisionId,
    String? divisionId,
    String? circleId,
    String? zoneId,
    String? voltageLevel,
    String? type,
    String? operation,
    String? sasMake,
    String? status,
    String? statusDescription,
    String? address,
    String? landmark,
    String? contactPerson,
    String? contactNumber,
    String? contactDesignation,
    String? description,
    Timestamp? commissioningDate,
    String? createdBy,
    Timestamp? createdAt,
    List<Bay>? bays,
    List<Busbar>? busbars,
    List<String>? readingTemplateIds,
    String? cityId,
    String? subdivisionName,
    String? divisionName,
    String? circleName,
  }) => Substation(
    id: id ?? this.id,
    name: name ?? this.name,
    subdivisionId: subdivisionId ?? this.subdivisionId,
    divisionId: divisionId ?? this.divisionId,
    circleId: circleId ?? this.circleId,
    zoneId: zoneId ?? this.zoneId,
    voltageLevel: voltageLevel ?? this.voltageLevel,
    type: type ?? this.type,
    operation: operation ?? this.operation,
    sasMake: sasMake ?? this.sasMake,
    status: status ?? this.status,
    statusDescription: statusDescription ?? this.statusDescription,
    address: address ?? this.address,
    landmark: landmark ?? this.landmark,
    contactPerson: contactPerson ?? this.contactPerson,
    contactNumber: contactNumber ?? this.contactNumber,
    contactDesignation: contactDesignation ?? this.contactDesignation,
    description: description ?? this.description,
    commissioningDate: commissioningDate ?? this.commissioningDate,
    createdBy: createdBy ?? this.createdBy,
    createdAt: createdAt ?? this.createdAt,
    bays: bays ?? this.bays,
    busbars: busbars ?? this.busbars,
    readingTemplateIds: readingTemplateIds ?? this.readingTemplateIds,
    cityId: cityId ?? this.cityId,
    subdivisionName: subdivisionName ?? this.subdivisionName,
    divisionName: divisionName ?? this.divisionName,
    circleName: circleName ?? this.circleName,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is Substation && other.id == id);

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Substation($id, $name)';
}
