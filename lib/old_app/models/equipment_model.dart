// lib/models/equipment_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

/// Defines the possible data types for custom fields associated with equipment templates.
enum CustomFieldDataType {
  text,
  number,
  boolean,
  date,
  dropdown,
  group, // Represents a nested list of custom fields (e.g., for repetitive items like phases)
}

/// Represents a single custom field definition within a MasterEquipmentTemplate.
/// These fields define the additional properties that can be recorded for an equipment.
class CustomField {
  /// The display name of the custom field (e.g., 'Voltage', 'Manufacturer').
  String name;

  /// The data type of the field, defined by [CustomFieldDataType].
  CustomFieldDataType dataType;

  /// Indicates if this field is mandatory for data entry.
  bool isMandatory;

  /// Indicates if this field (typically 'number' type) has associated units.
  bool hasUnits;

  /// The unit of measurement for number fields (e.g., 'V', 'A', 'kW').
  String units;

  /// Options for 'dropdown' type fields.
  List<String> options;

  /// Indicates if a boolean field should have an associated text area for remarks/description.
  bool hasRemarksField;

  /// Stores the custom label/hint for the remarks text area associated with a boolean field.
  String templateRemarkText;

  /// For 'group' type fields, this defines the structure of items within the group.
  /// Each item in the group will conform to the structure defined by these nested CustomFields.
  List<CustomField>? nestedFields;

  /// Creates a [CustomField] instance.
  CustomField({
    required this.name,
    required this.dataType,
    this.isMandatory = false,
    this.hasUnits = false,
    this.units = '',
    this.options = const [],
    this.hasRemarksField = false,
    this.templateRemarkText = '',
    this.nestedFields,
  });

  /// Creates a [CustomField] instance from a Firestore map.
  factory CustomField.fromMap(Map<String, dynamic> map) {
    return CustomField(
      name: map['name'] ?? '',
      dataType: CustomFieldDataType.values.firstWhere(
        // Check for 'group' in map, fallback if 'list' still exists in old data
        (e) =>
            e.toString().split('.').last == map['dataType'] ||
            (map['dataType'] == 'list' && e == CustomFieldDataType.group),
        orElse: () => CustomFieldDataType
            .text, // Fallback to text if data type is unknown
      ),
      isMandatory: map['isMandatory'] ?? false,
      hasUnits: map['hasUnits'] ?? false,
      units: map['units'] ?? '',
      options:
          (map['options'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      hasRemarksField: map['hasRemarksField'] ?? false,
      templateRemarkText: map['templateRemarkText'] ?? '',
      nestedFields: (map['nestedFields'] as List<dynamic>?)
          ?.map(
            (fieldMap) => CustomField.fromMap(fieldMap as Map<String, dynamic>),
          )
          .toList(),
    );
  }

  /// Converts this [CustomField] instance to a Firestore-compatible map.
  Map<String, dynamic> toMap() {
    final Map<String, dynamic> map = {
      'name': name,
      'dataType': dataType
          .toString()
          .split('.')
          .last, // Store enum name as string
      'isMandatory': isMandatory,
      'hasUnits': hasUnits,
      'units': units,
      'options': options,
    };
    if (hasRemarksField) {
      map['hasRemarksField'] = hasRemarksField;
      if (templateRemarkText.isNotEmpty) {
        map['templateRemarkText'] = templateRemarkText;
      }
    }
    if (nestedFields != null) {
      map['nestedFields'] = nestedFields!
          .map((field) => field.toMap())
          .toList();
    }
    return map;
  }

  /// Creates a copy of this [CustomField] but with the given fields replaced with the new values.
  CustomField copyWith({
    String? name,
    CustomFieldDataType? dataType,
    bool? isMandatory,
    bool? hasUnits,
    String? units,
    List<String>? options,
    bool? hasRemarksField,
    String? templateRemarkText,
    List<CustomField>? nestedFields,
  }) {
    return CustomField(
      name: name ?? this.name,
      dataType: dataType ?? this.dataType,
      isMandatory: isMandatory ?? this.isMandatory,
      hasUnits: hasUnits ?? this.hasUnits,
      units: units ?? this.units,
      options: options ?? this.options,
      hasRemarksField: hasRemarksField ?? this.hasRemarksField,
      templateRemarkText: templateRemarkText ?? this.templateRemarkText,
      nestedFields: nestedFields ?? this.nestedFields,
    );
  }
}

/// Defines the structure for a master equipment template, used to standardize
/// equipment types and their properties across the system.
class MasterEquipmentTemplate {
  /// The unique identifier for the template (null for new templates before saving).
  final String? id;

  /// The name of the equipment type (e.g., 'Power Transformer', 'Circuit Breaker').
  final String equipmentType;

  /// A key referencing the symbolic representation for this equipment type.
  final String symbolKey;

  /// A list of custom fields that further define the properties of this equipment type.
  final List<CustomField> equipmentCustomFields;

  /// The user ID of the creator.
  final String createdBy;

  /// The timestamp when the template was created.
  final Timestamp createdAt;

  /// Default width for the equipment symbol in diagrams (optional).
  final double defaultWidth;

  /// Default height for the equipment symbol in diagrams (optional).
  final double defaultHeight;

  /// Make/manufacturer of the equipment (optional basic detail).
  final String? make;

  /// Date of manufacture of the equipment (optional basic detail).
  final Timestamp? dateOfManufacture;

  /// Date when the equipment was commissioned (optional basic detail).
  final Timestamp? dateOfCommissioning;

  /// Creates a [MasterEquipmentTemplate] instance.
  MasterEquipmentTemplate({
    this.id,
    required this.equipmentType,
    required this.symbolKey,
    required this.equipmentCustomFields,
    required this.createdBy,
    required this.createdAt,
    this.defaultWidth = 60.0,
    this.defaultHeight = 60.0,
    this.make,
    this.dateOfManufacture,
    this.dateOfCommissioning,
  });

  /// Creates a [MasterEquipmentTemplate] instance from a Firestore [DocumentSnapshot].
  factory MasterEquipmentTemplate.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return MasterEquipmentTemplate(
      id: doc.id,
      equipmentType: data['equipmentType'] ?? '',
      symbolKey: data['symbolKey'] ?? 'Other',
      equipmentCustomFields:
          (data['equipmentCustomFields'] as List<dynamic>?)
              ?.map((fieldMap) => CustomField.fromMap(fieldMap))
              .toList() ??
          [],
      createdBy: data['createdBy'] ?? '',
      createdAt: data['createdAt'] ?? Timestamp.now(),
      defaultWidth: (data['defaultWidth'] as num?)?.toDouble() ?? 60.0,
      defaultHeight: (data['defaultHeight'] as num?)?.toDouble() ?? 60.0,
      make: data['make'] as String?,
      dateOfManufacture: data['dateOfManufacture'] as Timestamp?,
      dateOfCommissioning: data['dateOfCommissioning'] as Timestamp?,
    );
  }

  /// Converts this [MasterEquipmentTemplate] instance to a Firestore-compatible map.
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
      'make': make,
      'dateOfManufacture': dateOfManufacture,
      'dateOfCommissioning': dateOfCommissioning,
    };
  }

  /// Creates a copy of this [MasterEquipmentTemplate] but with the given fields replaced with the new values.
  MasterEquipmentTemplate copyWith({
    String? id,
    String? equipmentType,
    String? symbolKey,
    List<CustomField>? equipmentCustomFields,
    String? createdBy,
    Timestamp? createdAt,
    double? defaultWidth,
    double? defaultHeight,
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
      make: make ?? this.make,
      dateOfManufacture: dateOfManufacture ?? this.dateOfManufacture,
      dateOfCommissioning: dateOfCommissioning ?? this.dateOfCommissioning,
    );
  }
}

/// Represents an actual instance of an equipment deployed in a bay,
/// referencing a [MasterEquipmentTemplate] and storing its specific values.
class EquipmentInstance {
  /// The unique identifier for this equipment instance.
  final String id;

  /// The ID of the bay where this equipment is installed.
  final String bayId;

  /// The ID of the [MasterEquipmentTemplate] this instance is based on.
  final String templateId;

  /// The type name from the associated template (e.g., 'Power Transformer').
  final String equipmentTypeName;

  /// The symbol key from the associated template (e.g., 'Transformer').
  final String symbolKey;

  /// The user ID of the creator.
  final String createdBy;

  /// The timestamp when this equipment instance record was created.
  final Timestamp createdAt;

  /// A map storing the actual values for the custom fields defined in the template.
  /// Key: CustomField.name, Value: recorded data.
  final Map<String, dynamic> customFieldValues;

  /// The operational status of this equipment instance (e.g., 'active', 'replaced', 'decommissioned').
  final String status;

  /// The ID of the equipment instance that this one replaced (for history tracking).
  final String? previousEquipmentInstanceId;

  /// The ID of the equipment instance that replaced this one (for history tracking).
  final String? replacementEquipmentInstanceId;

  /// The timestamp when this equipment instance was decommissioned or replaced.
  final Timestamp? decommissionedAt;

  /// The reason for changing the status (e.g., 'fault', 'upgrade', 'maintenance').
  final String? reasonForChange;

  /// The make or manufacturer of the specific equipment instance.
  final String make;

  /// The manufacturing date of the specific equipment instance.
  final Timestamp? dateOfManufacturing;

  /// The commissioning date of the specific equipment instance.
  final Timestamp? dateOfCommissioning;

  // NEW FIELD for ordering equipment within a bay
  final int? positionIndex;

  /// Creates an [EquipmentInstance] instance.
  EquipmentInstance({
    required this.id,
    required this.bayId,
    required this.templateId,
    required this.equipmentTypeName,
    required this.symbolKey,
    required this.createdBy,
    required this.createdAt,
    required this.customFieldValues,
    this.status = 'active', // Default status is 'active'
    this.previousEquipmentInstanceId,
    this.replacementEquipmentInstanceId,
    this.decommissionedAt,
    this.reasonForChange,
    required this.make,
    this.dateOfManufacturing,
    this.dateOfCommissioning,
    this.positionIndex, // Initialize new field
  });

  /// Creates an [EquipmentInstance] instance from a Firestore [DocumentSnapshot].
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
      status: data['status'] ?? 'active',
      previousEquipmentInstanceId:
          data['previousEquipmentInstanceId'] as String?,
      replacementEquipmentInstanceId:
          data['replacementEquipmentInstanceId'] as String?,
      decommissionedAt: data['decommissionedAt'] as Timestamp?,
      reasonForChange: data['reasonForChange'] as String?,
      make: data['make'] as String? ?? '',
      dateOfManufacturing: data['dateOfManufacturing'] as Timestamp?,
      dateOfCommissioning: data['dateOfCommissioning'] as Timestamp?,
      positionIndex: data['positionIndex'] as int?, // Read from Firestore
    );
  }

  /// Converts this [EquipmentInstance] instance to a Firestore-compatible map.
  Map<String, dynamic> toFirestore() {
    return {
      'bayId': bayId,
      'templateId': templateId,
      'equipmentTypeName': equipmentTypeName,
      'symbolKey': symbolKey,
      'createdBy': createdBy,
      'createdAt': createdAt,
      'customFieldValues': customFieldValues,
      'status': status,
      'previousEquipmentInstanceId': previousEquipmentInstanceId,
      'replacementEquipmentInstanceId': replacementEquipmentInstanceId,
      'decommissionedAt': decommissionedAt,
      'reasonForChange': reasonForChange,
      'make': make,
      'dateOfManufacturing': dateOfManufacturing,
      'dateOfCommissioning': dateOfCommissioning,
      'positionIndex': positionIndex, // Include in toFirestore
    };
  }

  /// Creates a copy of this [EquipmentInstance] but with the given fields replaced with the new values.
  EquipmentInstance copyWith({
    String? id,
    String? bayId,
    String? templateId,
    String? equipmentTypeName,
    String? symbolKey,
    String? createdBy,
    Timestamp? createdAt,
    Map<String, dynamic>? customFieldValues,
    String? status,
    String? previousEquipmentInstanceId,
    String? replacementEquipmentInstanceId,
    Timestamp? decommissionedAt,
    String? reasonForChange,
    String? make,
    Timestamp? dateOfManufacturing,
    Timestamp? dateOfCommissioning,
    int? positionIndex, // Add to copyWith
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
      status: status ?? this.status,
      previousEquipmentInstanceId:
          previousEquipmentInstanceId ?? this.previousEquipmentInstanceId,
      replacementEquipmentInstanceId:
          replacementEquipmentInstanceId ?? this.replacementEquipmentInstanceId,
      decommissionedAt: decommissionedAt ?? this.decommissionedAt,
      reasonForChange: reasonForChange ?? this.reasonForChange,
      make: make ?? this.make,
      dateOfManufacturing: dateOfManufacturing ?? this.dateOfManufacturing,
      dateOfCommissioning: dateOfCommissioning ?? this.dateOfCommissioning,
      positionIndex:
          positionIndex ??
          this.positionIndex, // Use null-aware operator for copyWith
    );
  }
}
