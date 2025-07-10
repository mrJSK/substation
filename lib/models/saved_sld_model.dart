// lib/models/saved_sld_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class SavedSld {
  final String? id;
  final String name;
  final String substationId;
  final String substationName;
  final Timestamp startDate;
  final Timestamp endDate;
  final String createdBy;
  final Timestamp createdAt;
  final Map<String, dynamic> sldParameters; // Stores serializable SLD data
  final List<Map<String, dynamic>>
  assessmentsSummary; // For assessment table display

  SavedSld({
    this.id,
    required this.name,
    required this.substationId,
    required this.substationName,
    required this.startDate,
    required this.endDate,
    required this.createdBy,
    required this.createdAt,
    required this.sldParameters,
    required this.assessmentsSummary,
  });

  factory SavedSld.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return SavedSld(
      id: doc.id,
      name: data['name'] ?? '',
      substationId: data['substationId'] ?? '',
      substationName: data['substationName'] ?? '',
      startDate: data['startDate'] ?? Timestamp.now(),
      endDate: data['endDate'] ?? Timestamp.now(),
      createdBy: data['createdBy'] ?? '',
      createdAt: data['createdAt'] ?? Timestamp.now(),
      sldParameters: data['sldParameters'] as Map<String, dynamic>? ?? {},
      assessmentsSummary:
          (data['assessmentsSummary'] as List<dynamic>?)
              ?.map((e) => e as Map<String, dynamic>)
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'substationId': substationId,
      'substationName': substationName,
      'startDate': startDate,
      'endDate': endDate,
      'createdBy': createdBy,
      'createdAt': createdAt,
      'sldParameters': sldParameters,
      'assessmentsSummary': assessmentsSummary,
    };
  }

  // Helper for creating a modified copy
  SavedSld copyWith({
    String? id,
    String? name,
    String? substationId,
    String? substationName,
    Timestamp? startDate,
    Timestamp? endDate,
    String? createdBy,
    Timestamp? createdAt,
    Map<String, dynamic>? sldParameters,
    List<Map<String, dynamic>>? assessmentsSummary,
  }) {
    return SavedSld(
      id: id ?? this.id,
      name: name ?? this.name,
      substationId: substationId ?? this.substationId,
      substationName: substationName ?? this.substationName,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      sldParameters: sldParameters ?? this.sldParameters,
      assessmentsSummary: assessmentsSummary ?? this.assessmentsSummary,
    );
  }
}
