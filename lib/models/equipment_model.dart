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
  templateRemarkText; // Stores the custom label/hint for the remarks text area in the template

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
      options:
          (map['options'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
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
  final double defaultWidth;
  final double defaultHeight;

  // NEW fields for Basic Details
  final String? make; // Make: text (optional)
  final Timestamp? dateOfManufacture; // Date of Manufacture: date (optional)
  final Timestamp?
  dateOfCommissioning; // Date of Commissioning: date (optional)

  MasterEquipmentTemplate({
    this.id,
    required this.equipmentType,
    required this.symbolKey,
    required this.equipmentCustomFields,
    required this.createdBy,
    required this.createdAt,
    this.defaultWidth = 60.0, // Default value if not provided
    this.defaultHeight = 60.0, // Default value if not provided
    // Initialize new fields
    this.make,
    this.dateOfManufacture,
    this.dateOfCommissioning,
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
      // Read new fields
      make: data['make'] as String?,
      dateOfManufacture: data['dateOfManufacture'] as Timestamp?,
      dateOfCommissioning: data['dateOfCommissioning'] as Timestamp?,
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
      // Write new fields
      'make': make,
      'dateOfManufacture': dateOfManufacture,
      'dateOfCommissioning': dateOfCommissioning,
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
    // CopyWith new fields
    String? make,
    Timestamp? dateOfManufacture,
    Timestamp? dateOfCommissioning,
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
      // Use new fields in copyWith
      make: make ?? this.make,
      dateOfManufacture: dateOfManufacture ?? this.dateOfManufacture,
      dateOfCommissioning: dateOfCommissioning ?? this.dateOfCommissioning,
    );
  }
}

// EquipmentInstance class (no changes needed here for this request)
class EquipmentInstance {
  final String id;
  final String bayId;
  final String templateId;
  final String equipmentTypeName;
  final String symbolKey;
  final String createdBy;
  final Timestamp createdAt;
  final Map<String, dynamic> customFieldValues;

  // NEW fields for Equipment History
  final String status; // e.g., 'active', 'replaced', 'decommissioned'
  final String?
  previousEquipmentInstanceId; // ID of the equipment this one replaced
  final String?
  replacementEquipmentInstanceId; // ID of the equipment that replaced this one
  final Timestamp?
  decommissionedAt; // When this equipment was replaced/decommissioned
  final String?
  reasonForChange; // Reason for changing status (e.g., 'fault', 'upgrade')

  EquipmentInstance({
    required this.id,
    required this.bayId,
    required this.templateId,
    required this.equipmentTypeName,
    required this.symbolKey,
    required this.createdBy,
    required this.createdAt,
    required this.customFieldValues,
    this.status = 'active', // Default status
    this.previousEquipmentInstanceId,
    this.replacementEquipmentInstanceId,
    this.decommissionedAt,
    this.reasonForChange,
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
      status: data['status'] ?? 'active', // Read new field
      previousEquipmentInstanceId:
          data['previousEquipmentInstanceId'], // Read new field
      replacementEquipmentInstanceId:
          data['replacementEquipmentInstanceId'], // Read new field
      decommissionedAt:
          data['decommissionedAt'] as Timestamp?, // Read new field
      reasonForChange: data['reasonForChange'], // Read new field
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
      'status': status, // Write new field
      'previousEquipmentInstanceId':
          previousEquipmentInstanceId, // Write new field
      'replacementEquipmentInstanceId':
          replacementEquipmentInstanceId, // Write new field
      'decommissionedAt': decommissionedAt, // Write new field
      'reasonForChange': reasonForChange, // Write new field
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
    String? status, // CopyWith new field
    String? previousEquipmentInstanceId, // CopyWith new field
    String? replacementEquipmentInstanceId, // CopyWith new field
    Timestamp? decommissionedAt, // CopyWith new field
    String? reasonForChange, // CopyWith new field
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
      status: status ?? this.status, // Use new field
      previousEquipmentInstanceId:
          previousEquipmentInstanceId ??
          this.previousEquipmentInstanceId, // Use new field
      replacementEquipmentInstanceId:
          replacementEquipmentInstanceId ??
          this.replacementEquipmentInstanceId, // Use new field
      decommissionedAt:
          decommissionedAt ?? this.decommissionedAt, // Use new field
      reasonForChange: reasonForChange ?? this.reasonForChange, // Use new field
    );
  }
}
