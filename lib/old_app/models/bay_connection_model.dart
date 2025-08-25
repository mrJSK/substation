// lib/models/bay_connection_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class BayConnection {
  final String? id;
  final String substationId;
  final String sourceBayId;
  final String targetBayId;
  final String createdBy;
  final Timestamp createdAt;

  BayConnection({
    this.id,
    required this.substationId,
    required this.sourceBayId,
    required this.targetBayId,
    required this.createdBy,
    required this.createdAt,
  });

  factory BayConnection.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return BayConnection(
      id: doc.id,
      substationId: data['substationId'] ?? '',
      sourceBayId: data['sourceBayId'] ?? '',
      targetBayId: data['targetBayId'] ?? '',
      createdBy: data['createdBy'] ?? '',
      createdAt: data['createdAt'] ?? Timestamp.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'substationId': substationId,
      'sourceBayId': sourceBayId,
      'targetBayId': targetBayId,
      'createdBy': createdBy,
      'createdAt': createdAt,
    };
  }
}
