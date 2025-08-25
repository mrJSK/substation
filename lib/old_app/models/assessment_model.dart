// lib/models/assessment_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class Assessment {
  final String id;
  final String substationId;
  final String bayId;
  final Timestamp assessmentTimestamp; // When the assessment was made
  final Timestamp?
  effectiveEndDate; // New field for the assessment's effective end date
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
    this.effectiveEndDate, // Include new field in constructor
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
      effectiveEndDate:
          data['effectiveEndDate'] as Timestamp?, // Parse new field
      importAdjustment: (data['importAdjustment'] as num?)?.toDouble(),
      exportAdjustment: (data['exportAdjustment'] as num?)?.toDouble(),
      reason: data['reason'] ?? '',
      createdBy: data['createdBy'] ?? '',
      createdAt: data['createdAt'] ?? Timestamp.now(),
    );
  }

  /// Factory constructor to create an Assessment from a Map<String, dynamic>.
  /// Useful for deserializing data that isn't directly from a Firestore DocumentSnapshot.
  factory Assessment.fromMap(Map<String, dynamic> map, {String? id}) {
    return Assessment(
      id:
          id ??
          map['id'] ??
          '', // Use provided id, or from map, or empty string
      substationId: map['substationId'] ?? '',
      bayId: map['bayId'] ?? '',
      assessmentTimestamp: map['assessmentTimestamp'] is Timestamp
          ? map['assessmentTimestamp']
          : Timestamp.now(), // Handle different timestamp types if necessary
      effectiveEndDate: map['effectiveEndDate'] is Timestamp
          ? map['effectiveEndDate']
          : null, // Parse new field from map
      importAdjustment: (map['importAdjustment'] as num?)?.toDouble(),
      exportAdjustment: (map['exportAdjustment'] as num?)?.toDouble(),
      reason: map['reason'] ?? '',
      createdBy: map['createdBy'] ?? '',
      createdAt: map['createdAt'] is Timestamp
          ? map['createdAt']
          : Timestamp.now(), // Handle different timestamp types if necessary
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'substationId': substationId,
      'bayId': bayId,
      'assessmentTimestamp': assessmentTimestamp,
      'effectiveEndDate':
          effectiveEndDate, // Include new field in Firestore map
      'importAdjustment': importAdjustment,
      'exportAdjustment': exportAdjustment,
      'reason': reason,
      'createdBy': createdBy,
      'createdAt': createdAt,
    };
  }
}
