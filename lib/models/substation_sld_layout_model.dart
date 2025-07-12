// lib/models/substation_sld_layout_model.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:ui'; // For Offset - even though we store dx/dy as doubles, the Offset class is useful for conceptual clarity.

class SubstationSldLayout {
  final String id; // Document ID (often same as substationId)
  final String substationId;
  final Timestamp createdAt;
  final Timestamp lastModifiedAt;
  final String createdBy;
  final String lastModifiedBy;

  // Map to store layout parameters for each bay.
  // Key: bayId
  // Value: Map containing 'x', 'y', 'textOffsetDx', 'textOffsetDy', 'busbarLength', 'energyTextOffsetDx', 'energyTextOffsetDy'
  final Map<String, Map<String, double>> bayLayoutParameters;

  SubstationSldLayout({
    required this.id,
    required this.substationId,
    required this.createdAt,
    required this.lastModifiedAt,
    required this.createdBy,
    required this.lastModifiedBy,
    this.bayLayoutParameters = const {},
  });

  factory SubstationSldLayout.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return SubstationSldLayout(
      id: doc.id,
      substationId: data['substationId'] ?? '',
      createdAt: data['createdAt'] ?? Timestamp.now(),
      lastModifiedAt: data['lastModifiedAt'] ?? Timestamp.now(),
      createdBy: data['createdBy'] ?? '',
      lastModifiedBy: data['lastModifiedBy'] ?? '',
      bayLayoutParameters:
          (data['bayLayoutParameters'] as Map<String, dynamic>?)?.map(
            (key, value) => MapEntry(key, Map<String, double>.from(value)),
          ) ??
          {},
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'substationId': substationId,
      'createdAt': createdAt,
      'lastModifiedAt': lastModifiedAt,
      'createdBy': createdBy,
      'lastModifiedBy': lastModifiedBy,
      'bayLayoutParameters': bayLayoutParameters,
    };
  }

  SubstationSldLayout copyWith({
    String? id,
    String? substationId,
    Timestamp? createdAt,
    Timestamp? lastModifiedAt,
    String? createdBy,
    String? lastModifiedBy,
    Map<String, Map<String, double>>? bayLayoutParameters,
  }) {
    return SubstationSldLayout(
      id: id ?? this.id,
      substationId: substationId ?? this.substationId,
      createdAt: createdAt ?? this.createdAt,
      lastModifiedAt: lastModifiedAt ?? this.lastModifiedAt,
      createdBy: createdBy ?? this.createdBy,
      lastModifiedBy: lastModifiedBy ?? this.lastModifiedBy,
      bayLayoutParameters: bayLayoutParameters ?? this.bayLayoutParameters,
    );
  }
}
