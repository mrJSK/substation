// lib/models/equipment_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

enum CustomFieldDataType { text, number, boolean, date, dropdown }

class CustomField {
  String name;
  CustomFieldDataType dataType;
  bool isMandatory;
  bool hasUnits;
  String units;
  List<String> options; // Used for dropdown type

  CustomField({
    required this.name,
    required this.dataType,
    this.isMandatory = false,
    this.hasUnits = false,
    this.units = '',
    this.options = const [],
  });

  factory CustomField.fromMap(Map<String, dynamic> map) {
    return CustomField(
      name: map['name'] ?? '',
      dataType: CustomFieldDataType.values.firstWhere(
        (e) => e.toString().split('.').last == map['dataType'],
        orElse: () => CustomFieldDataType.text,
      ),
      isMandatory: map['isMandatory'] ?? false,
      hasUnits: map['hasUnits'] ?? false,
      units: map['units'] ?? '',
      options: List<String>.from(map['options'] ?? []),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'dataType': dataType.toString().split('.').last,
      'isMandatory': isMandatory,
      'hasUnits': hasUnits,
      'units': units,
      'options': options,
    };
  }
}

class MasterEquipmentTemplate {
  final String? id; // Null for new templates before they are saved
  final String equipmentType;
  final String symbolKey; // e.g., "Transformer", "Breaker"
  final List<CustomField> equipmentCustomFields;
  final String createdBy;
  final Timestamp createdAt;

  MasterEquipmentTemplate({
    this.id,
    required this.equipmentType,
    required this.symbolKey,
    required this.equipmentCustomFields,
    required this.createdBy,
    required this.createdAt,
  });

  factory MasterEquipmentTemplate.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return MasterEquipmentTemplate(
      id: doc.id,
      equipmentType: data['equipmentType'] ?? '',
      symbolKey: data['symbolKey'] ?? 'Other', // Provide a default symbol
      equipmentCustomFields:
          (data['equipmentCustomFields'] as List<dynamic>?)
              ?.map((fieldMap) => CustomField.fromMap(fieldMap))
              .toList() ??
          [],
      createdBy: data['createdBy'] ?? '',
      createdAt: data['createdAt'] ?? Timestamp.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'equipmentType': equipmentType,
      'symbolKey': symbolKey,
      'equipmentCustomFields': equipmentCustomFields
          .map((field) => field.toMap())
          .toList(),
      'createdBy': createdBy,
      'createdAt': createdAt,
    };
  }

  MasterEquipmentTemplate copyWith({
    String? id,
    String? equipmentType,
    String? symbolKey,
    List<CustomField>? equipmentCustomFields,
    String? createdBy,
    Timestamp? createdAt,
  }) {
    return MasterEquipmentTemplate(
      id: id ?? this.id,
      equipmentType: equipmentType ?? this.equipmentType,
      symbolKey: symbolKey ?? this.symbolKey,
      equipmentCustomFields:
          equipmentCustomFields ?? this.equipmentCustomFields,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
