// models/substation_sld_layout_model.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:ui'; // For Offset

class SubstationSldLayout {
  final String
  id; // Document ID for this layout, could be same as substationId for 1:1 mapping
  final String substationId;
  final Timestamp createdAt;
  final Timestamp lastModifiedAt;
  final String createdBy;
  final String lastModifiedBy;

  // Map to store positions, text offsets, and busbar lengths per bay
  // Key: bayId
  // Value: Map containing 'x', 'y', 'textOffsetDx', 'textOffsetDy', 'busbarLength'
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
      substationId: data['substationId'],
      createdAt: data['createdAt'],
      lastModifiedAt: data['lastModifiedAt'],
      createdBy: data['createdBy'],
      lastModifiedBy: data['lastModifiedBy'],
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

  // Helper method to update specific layout parameters
  SubstationSldLayout copyWith({
    Map<String, Map<String, double>>? bayLayoutParameters,
    Timestamp? lastModifiedAt,
    String? lastModifiedBy,
  }) {
    return SubstationSldLayout(
      id: id,
      substationId: substationId,
      createdAt: createdAt,
      createdBy: createdBy,
      bayLayoutParameters: bayLayoutParameters ?? this.bayLayoutParameters,
      lastModifiedAt: lastModifiedAt ?? this.lastModifiedAt,
      lastModifiedBy: lastModifiedBy ?? this.lastModifiedBy,
    );
  }
}
