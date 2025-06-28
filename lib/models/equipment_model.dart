import 'package:cloud_firestore/cloud_firestore.dart';

enum CustomFieldDataType { text, number, boolean, date, dropdown }

class CustomField {
  String name;
  CustomFieldDataType dataType;
  bool isMandatory;
  bool hasUnits;
  String units;
  List<String> options; // Used for dropdown type
  bool
  hasRemarksField; // Indicates if this boolean field should have an associated remarks text area
  String
  templateRemarkText; // NEW: Stores the custom label/hint for the remarks text area in the template

  CustomField({
    required this.name,
    required this.dataType,
    this.isMandatory = false,
    this.hasUnits = false,
    this.units = '',
    this.options = const [],
    this.hasRemarksField = false, // Default to false
    this.templateRemarkText = '', // Default to empty string
  });

  factory CustomField.fromMap(Map<String, dynamic> map) {
    return CustomField(
      name: map['name'] ?? '',
      dataType: CustomFieldDataType.values.firstWhere(
        (e) => e.toString().split('.').last == map['dataType'],
        orElse: () => CustomFieldDataType.text, // Provide a fallback
      ),
      isMandatory: map['isMandatory'] ?? false,
      hasUnits: map['hasUnits'] ?? false,
      units: map['units'] ?? '',
      options: List<String>.from(map['options'] ?? []),
      hasRemarksField: map['hasRemarksField'] ?? false, // Read from map
      templateRemarkText: map['templateRemarkText'] ?? '', // Read from map
    );
  }

  Map<String, dynamic> toMap() {
    final Map<String, dynamic> map = {
      'name': name,
      'dataType': dataType.toString().split('.').last, // Store as string
      'isMandatory': isMandatory,
      'hasUnits': hasUnits,
      'units': units,
      'options': options,
    };
    if (hasRemarksField) {
      map['hasRemarksField'] = hasRemarksField;
      if (templateRemarkText.isNotEmpty) {
        // Only save remark text if it's not empty
        map['templateRemarkText'] = templateRemarkText;
      }
    }
    return map;
  }
}

class MasterEquipmentTemplate {
  final String? id; // Null for new templates before they are saved
  final String equipmentType;
  final String symbolKey; // e.g., "Transformer", "Breaker"
  final List<CustomField> equipmentCustomFields;
  final String createdBy;
  final Timestamp createdAt;
  final double defaultWidth; // Assuming these are part of your template
  final double defaultHeight; // Assuming these are part of your template

  MasterEquipmentTemplate({
    this.id,
    required this.equipmentType,
    required this.symbolKey,
    required this.equipmentCustomFields,
    required this.createdBy,
    required this.createdAt,
    this.defaultWidth = 60.0, // Default value if not provided
    this.defaultHeight = 60.0, // Default value if not provided
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
      defaultWidth: (data['defaultWidth'] as num?)?.toDouble() ?? 60.0,
      defaultHeight: (data['defaultHeight'] as num?)?.toDouble() ?? 60.0,
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
      'defaultWidth': defaultWidth,
      'defaultHeight': defaultHeight,
    };
  }

  MasterEquipmentTemplate copyWith({
    String? id,
    String? equipmentType,
    String? symbolKey,
    List<CustomField>? equipmentCustomFields,
    String? createdBy,
    Timestamp? createdAt,
    double? defaultWidth,
    double? defaultHeight,
  }) {
    return MasterEquipmentTemplate(
      id: id ?? this.id,
      equipmentType: equipmentType ?? this.equipmentType,
      symbolKey: symbolKey ?? this.symbolKey,
      equipmentCustomFields:
          equipmentCustomFields ?? this.equipmentCustomFields,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      defaultWidth: defaultWidth ?? this.defaultWidth,
      defaultHeight: defaultHeight ?? this.defaultHeight,
    );
  }
}

// Ensure you have this in equipment_instance_model.dart or within this file
// if it's a single file structure. I'll include it here for completeness,
// assuming it's usually in equipment_instance_model.dart.
class EquipmentInstance {
  final String id;
  final String bayId;
  final String templateId;
  final String equipmentTypeName;
  final String symbolKey;
  final String createdBy;
  final Timestamp createdAt;
  final Map<String, dynamic> customFieldValues;

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
      bayId: data['bayId'] as String,
      templateId: data['templateId'] as String,
      equipmentTypeName: data['equipmentTypeName'] as String,
      symbolKey: data['symbolKey'] as String,
      createdBy: data['createdBy'] as String,
      createdAt: data['createdAt'] as Timestamp,
      customFieldValues:
          data['customFieldValues'] as Map<String, dynamic>? ?? {},
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
}
