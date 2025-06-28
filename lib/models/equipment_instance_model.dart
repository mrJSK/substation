// lib/models/equipment_instance_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class EquipmentInstance {
  final String id;
  final String bayId;
  final String templateId; // Link to MasterEquipmentTemplate
  final String
  equipmentTypeName; // To easily display type without fetching template
  final String symbolKey; // To easily display symbol without fetching template
  final String createdBy;
  final Timestamp createdAt;
  final Map<String, dynamic>
  customFieldValues; // Stores all custom field values (template + instance-specific)

  EquipmentInstance({
    required this.id,
    required this.bayId,
    required this.templateId,
    required this.equipmentTypeName,
    required this.symbolKey,
    required this.createdBy,
    required this.createdAt,
    required this.customFieldValues,
  });

  factory EquipmentInstance.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return EquipmentInstance(
      id: doc.id,
      bayId: data['bayId'] ?? '',
      templateId: data['templateId'] ?? '',
      equipmentTypeName: data['equipmentTypeName'] ?? '',
      symbolKey: data['symbolKey'] ?? '',
      createdBy: data['createdBy'] ?? '',
      createdAt: data['createdAt'] ?? Timestamp.now(),
      customFieldValues: Map<String, dynamic>.from(
        data['customFieldValues'] ?? {},
      ),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'bayId': bayId,
      'templateId': templateId,
      'equipmentTypeName': equipmentTypeName,
      'symbolKey': symbolKey,
      'createdBy': createdBy,
      'createdAt': createdAt,
      'customFieldValues': customFieldValues,
    };
  }

  EquipmentInstance copyWith({
    String? id,
    String? bayId,
    String? templateId,
    String? equipmentTypeName,
    String? symbolKey,
    String? createdBy,
    Timestamp? createdAt,
    Map<String, dynamic>? customFieldValues,
  }) {
    return EquipmentInstance(
      id: id ?? this.id,
      bayId: bayId ?? this.bayId,
      templateId: templateId ?? this.templateId,
      equipmentTypeName: equipmentTypeName ?? this.equipmentTypeName,
      symbolKey: symbolKey ?? this.symbolKey,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      customFieldValues: customFieldValues ?? this.customFieldValues,
    );
  }
}
