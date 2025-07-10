// lib/models/assessment_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class Assessment {
  final String id;
  final String substationId;
  final String bayId;
  final Timestamp assessmentTimestamp; // When the assessment was made
  final double? importAdjustment; // Positive or negative value
  final double? exportAdjustment; // Positive or negative value
  final String reason; // Mandatory note/reason for assessment
  final String createdBy; // User who made the assessment
  final Timestamp createdAt; // When the record was created

  Assessment({
    required this.id,
    required this.substationId,
    required this.bayId,
    required this.assessmentTimestamp,
    this.importAdjustment,
    this.exportAdjustment,
    required this.reason,
    required this.createdBy,
    required this.createdAt,
  });

  factory Assessment.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map<String, dynamic>;
    return Assessment(
      id: doc.id,
      substationId: data['substationId'] ?? '',
      bayId: data['bayId'] ?? '',
      assessmentTimestamp: data['assessmentTimestamp'] ?? Timestamp.now(),
      importAdjustment: (data['importAdjustment'] as num?)?.toDouble(),
      exportAdjustment: (data['exportAdjustment'] as num?)?.toDouble(),
      reason: data['reason'] ?? '',
      createdBy: data['createdBy'] ?? '',
      createdAt: data['createdAt'] ?? Timestamp.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'substationId': substationId,
      'bayId': bayId,
      'assessmentTimestamp': assessmentTimestamp,
      'importAdjustment': importAdjustment,
      'exportAdjustment': exportAdjustment,
      'reason': reason,
      'createdBy': createdBy,
      'createdAt': createdAt,
    };
  }
}
