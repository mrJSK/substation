// lib/old_app/models/base_hierarchy_item.dart
//
// Minimal base class shared by all Firestore-backed hierarchy types,
// including Substation. Extracted to avoid circular imports.

import 'package:cloud_firestore/cloud_firestore.dart';

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

  const HierarchyItem({
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
      other is HierarchyItem && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
