// lib/models/bay_relationships_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class BayRelationship {
  final String? id;
  final String substationId;
  final String transformerBayId;
  final String incomingBayId;
  final List<String> outgoingBayIds;
  final String createdBy;
  final Timestamp createdAt;

  BayRelationship({
    this.id,
    required this.substationId,
    required this.transformerBayId,
    required this.incomingBayId,
    required this.outgoingBayIds,
    required this.createdBy,
    required this.createdAt,
  });

  factory BayRelationship.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return BayRelationship(
      id: doc.id,
      substationId: data['substationId'] ?? '',
      transformerBayId: data['transformerBayId'] ?? '',
      incomingBayId: data['incomingBayId'] ?? '',
      outgoingBayIds: List<String>.from(data['outgoingBayIds'] ?? []),
      createdBy: data['createdBy'] ?? '',
      createdAt: data['createdAt'] ?? Timestamp.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'substationId': substationId,
      'transformerBayId': transformerBayId,
      'incomingBayId': incomingBayId,
      'outgoingBayIds': outgoingBayIds,
      'createdBy': createdBy,
      'createdAt': createdAt,
    };
  }
}
