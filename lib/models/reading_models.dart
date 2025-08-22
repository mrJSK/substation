import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

enum ReadingFieldDataType { text, number, boolean, date, dropdown, group }

enum ReadingFrequency {
  hourly,
  daily,
  monthly,
  quarterly,
  semiannually,
  annually,
}

class ReadingField {
  final String name;
  final ReadingFieldDataType dataType;
  final String? unit;
  final List<String>? options;
  final bool isMandatory;
  final ReadingFrequency? frequency;
  final String? descriptionRemarks;
  final List<ReadingField>? nestedFields;
  final String? groupName;
  final double? minRange;
  final double? maxRange;
  final bool isInteger; // 🔥 Added for integer-only validation

  ReadingField({
    required this.name,
    required this.dataType,
    this.unit,
    this.options,
    this.isMandatory = false,
    this.frequency,
    this.descriptionRemarks,
    this.nestedFields,
    this.groupName,
    this.minRange,
    this.maxRange,
    this.isInteger = false, // 🔥 Default to false (allows decimals)
  });

  factory ReadingField.fromMap(Map<String, dynamic> map) {
    return ReadingField(
      name: map['name'] ?? '',
      dataType: ReadingFieldDataType.values.firstWhere(
        (e) => e.toString().split('.').last == (map['dataType'] ?? 'text'),
        orElse: () => ReadingFieldDataType.text,
      ),
      unit: map['unit'],
      options: map['options'] != null
          ? List<String>.from(map['options'])
          : null,
      isMandatory: map['isMandatory'] ?? false,
      frequency: map['frequency'] != null
          ? ReadingFrequency.values.firstWhere(
              (e) => e.toString().split('.').last == map['frequency'],
              orElse: () => ReadingFrequency.daily,
            )
          : null,
      descriptionRemarks: map['description_remarks'],
      nestedFields: map['nestedFields'] != null
          ? (map['nestedFields'] as List<dynamic>)
                .map(
                  (fieldMap) =>
                      ReadingField.fromMap(fieldMap as Map<String, dynamic>),
                )
                .toList()
          : null,
      groupName: map['groupName'],
      minRange: map['minRange']?.toDouble(),
      maxRange: map['maxRange']?.toDouble(),
      isInteger: map['isInteger'] ?? false, // 🔥 Added with default false
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'dataType': dataType.toString().split('.').last,
      'unit': unit,
      'options': options,
      'isMandatory': isMandatory,
      'frequency': frequency?.toString().split('.').last,
      'description_remarks': descriptionRemarks,
      'nestedFields': nestedFields?.map((field) => field.toMap()).toList(),
      'groupName': groupName,
      'minRange': minRange,
      'maxRange': maxRange,
      'isInteger': isInteger, // 🔥 Added to map serialization
    };
  }

  ReadingField copyWith({
    String? name,
    ReadingFieldDataType? dataType,
    String? unit,
    List<String>? options,
    bool? isMandatory,
    ReadingFrequency? frequency,
    String? descriptionRemarks,
    List<ReadingField>? nestedFields,
    String? groupName,
    double? minRange,
    double? maxRange,
    bool? isInteger, // 🔥 Added to copyWith method
  }) {
    return ReadingField(
      name: name ?? this.name,
      dataType: dataType ?? this.dataType,
      unit: unit ?? this.unit,
      options: options ?? this.options,
      isMandatory: isMandatory ?? this.isMandatory,
      frequency: frequency ?? this.frequency,
      descriptionRemarks: descriptionRemarks ?? this.descriptionRemarks,
      nestedFields: nestedFields ?? this.nestedFields,
      groupName: groupName ?? this.groupName,
      minRange: minRange ?? this.minRange,
      maxRange: maxRange ?? this.maxRange,
      isInteger: isInteger ?? this.isInteger, // 🔥 Added to copyWith
    );
  }

  bool get isGroupType => dataType == ReadingFieldDataType.group;
  bool get hasNestedFields => nestedFields != null && nestedFields!.isNotEmpty;

  // Enhanced validation with range checking and integer validation
  bool validate(dynamic value) {
    if (isMandatory && (value == null || value.toString().isEmpty)) {
      return false;
    }

    if (value == null) return true;

    switch (dataType) {
      case ReadingFieldDataType.number:
        // 🔥 Enhanced number validation with integer checking
        if (isInteger) {
          // For integer fields, check if it's a valid integer
          final intValue = int.tryParse(value.toString());
          if (intValue == null) return false;

          final doubleValue = intValue.toDouble();
          // Check range validation for integers
          if (minRange != null && doubleValue < minRange!) return false;
          if (maxRange != null && doubleValue > maxRange!) return false;
        } else {
          // For decimal fields, use double parsing
          final numValue = double.tryParse(value.toString());
          if (numValue == null) return false;

          // Check range validation for decimals
          if (minRange != null && numValue < minRange!) return false;
          if (maxRange != null && numValue > maxRange!) return false;
        }
        return true;

      case ReadingFieldDataType.boolean:
        return value is bool ||
            value.toString().toLowerCase() == 'true' ||
            value.toString().toLowerCase() == 'false';

      case ReadingFieldDataType.dropdown:
        return options?.contains(value.toString()) ?? false;

      case ReadingFieldDataType.date:
        return DateTime.tryParse(value.toString()) != null;

      case ReadingFieldDataType.text:
      case ReadingFieldDataType.group:
      default:
        return true;
    }
  }

  // 🔥 Helper method to get validation error message
  String? getValidationError(dynamic value) {
    if (isMandatory && (value == null || value.toString().isEmpty)) {
      return 'This field is required';
    }

    if (value == null || value.toString().isEmpty) return null;

    if (dataType == ReadingFieldDataType.number) {
      if (isInteger) {
        final intValue = int.tryParse(value.toString());
        if (intValue == null) {
          return 'Please enter a valid integer';
        }

        final doubleValue = intValue.toDouble();
        if (minRange != null && doubleValue < minRange!) {
          return 'Value must be at least ${minRange!.toInt()}';
        }
        if (maxRange != null && doubleValue > maxRange!) {
          return 'Value must be at most ${maxRange!.toInt()}';
        }
      } else {
        final numValue = double.tryParse(value.toString());
        if (numValue == null) {
          return 'Please enter a valid number';
        }

        if (minRange != null && numValue < minRange!) {
          return 'Value must be at least $minRange';
        }
        if (maxRange != null && numValue > maxRange!) {
          return 'Value must be at most $maxRange';
        }
      }
    }

    return null;
  }

  @override
  String toString() {
    return 'ReadingField(name: $name, dataType: $dataType, isMandatory: $isMandatory, range: $minRange-$maxRange, isInteger: $isInteger)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ReadingField &&
        other.name == name &&
        other.dataType == dataType &&
        other.unit == unit &&
        listEquals(other.options, options) &&
        other.isMandatory == isMandatory &&
        other.frequency == frequency &&
        other.descriptionRemarks == descriptionRemarks &&
        listEquals(other.nestedFields, nestedFields) &&
        other.groupName == groupName &&
        other.minRange == minRange &&
        other.maxRange == maxRange &&
        other.isInteger == isInteger; // 🔥 Added to equality check
  }

  @override
  int get hashCode {
    return Object.hash(
      name,
      dataType,
      unit,
      options,
      isMandatory,
      frequency,
      descriptionRemarks,
      nestedFields,
      groupName,
      minRange,
      maxRange,
      isInteger, // 🔥 Added to hash code
    );
  }
}

// ReadingTemplate class remains the same as your implementation
class ReadingTemplate {
  final String? id;
  final String bayType;
  final List<ReadingField> readingFields;
  final String createdBy;
  final Timestamp createdAt;
  final Timestamp? updatedAt;
  final String? description;
  final bool isActive;

  ReadingTemplate({
    this.id,
    required this.bayType,
    required this.readingFields,
    required this.createdBy,
    required this.createdAt,
    this.updatedAt,
    this.description,
    this.isActive = true,
  });

  factory ReadingTemplate.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return ReadingTemplate(
      id: doc.id,
      bayType: data['bayType'] as String,
      readingFields: (data['readingFields'] as List<dynamic>)
          .map(
            (fieldMap) =>
                ReadingField.fromMap(fieldMap as Map<String, dynamic>),
          )
          .toList(),
      createdBy: data['createdBy'] as String,
      createdAt: data['createdAt'] as Timestamp,
      updatedAt: data['updatedAt'] as Timestamp?,
      description: data['description'] as String?,
      isActive: data['isActive'] ?? true,
    );
  }

  factory ReadingTemplate.fromMap(Map<String, dynamic> map) {
    return ReadingTemplate(
      id: map['id'],
      bayType: map['bayType'] ?? '',
      readingFields: map['readingFields'] != null
          ? (map['readingFields'] as List<dynamic>)
                .map(
                  (fieldMap) =>
                      ReadingField.fromMap(fieldMap as Map<String, dynamic>),
                )
                .toList()
          : <ReadingField>[],
      createdBy: map['createdBy'] ?? '',
      createdAt: map['createdAt'] ?? Timestamp.now(),
      updatedAt: map['updatedAt'],
      description: map['description'],
      isActive: map['isActive'] ?? true,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'bayType': bayType,
      'readingFields': readingFields.map((field) => field.toMap()).toList(),
      'createdBy': createdBy,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'description': description,
      'isActive': isActive,
    };
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'bayType': bayType,
      'readingFields': readingFields.map((field) => field.toMap()).toList(),
      'createdBy': createdBy,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'description': description,
      'isActive': isActive,
    };
  }

  ReadingTemplate copyWith({
    String? id,
    String? bayType,
    List<ReadingField>? readingFields,
    String? createdBy,
    Timestamp? createdAt,
    Timestamp? updatedAt,
    String? description,
    bool? isActive,
  }) {
    return ReadingTemplate(
      id: id ?? this.id,
      bayType: bayType ?? this.bayType,
      readingFields: readingFields ?? this.readingFields,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      description: description ?? this.description,
      isActive: isActive ?? this.isActive,
    );
  }

  List<ReadingField> get mandatoryFields {
    return readingFields.where((field) => field.isMandatory).toList();
  }

  List<ReadingField> getFieldsByType(ReadingFieldDataType type) {
    return readingFields.where((field) => field.dataType == type).toList();
  }

  List<ReadingField> getFieldsByFrequency(ReadingFrequency frequency) {
    return readingFields
        .where((field) => field.frequency == frequency)
        .toList();
  }

  // 🔥 New helper method to get integer-only fields
  List<ReadingField> get integerOnlyFields {
    return readingFields
        .where(
          (field) =>
              field.dataType == ReadingFieldDataType.number && field.isInteger,
        )
        .toList();
  }

  bool validateTemplate() {
    if (bayType.isEmpty || readingFields.isEmpty || createdBy.isEmpty) {
      return false;
    }

    for (ReadingField field in readingFields) {
      if (field.dataType == ReadingFieldDataType.group &&
          (field.nestedFields == null || field.nestedFields!.isEmpty)) {
        return false;
      }

      if (field.dataType == ReadingFieldDataType.dropdown &&
          (field.options == null || field.options!.isEmpty)) {
        return false;
      }

      // 🔥 Validate integer fields have appropriate ranges
      if (field.dataType == ReadingFieldDataType.number && field.isInteger) {
        if (field.minRange != null &&
            field.minRange! != field.minRange!.floor()) {
          return false; // minRange should be a whole number for integer fields
        }
        if (field.maxRange != null &&
            field.maxRange! != field.maxRange!.floor()) {
          return false; // maxRange should be a whole number for integer fields
        }
      }
    }

    return true;
  }

  int get totalFieldCount {
    int count = 0;
    for (ReadingField field in readingFields) {
      count++;
      if (field.nestedFields != null) {
        count += field.nestedFields!.length;
      }
    }
    return count;
  }

  ReadingTemplate withUpdatedTimestamp() {
    return copyWith(updatedAt: Timestamp.now());
  }

  @override
  String toString() {
    return 'ReadingTemplate(id: $id, bayType: $bayType, fieldCount: ${readingFields.length})';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ReadingTemplate &&
        other.id == id &&
        other.bayType == bayType &&
        listEquals(other.readingFields, readingFields) &&
        other.createdBy == createdBy &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt &&
        other.description == description &&
        other.isActive == isActive;
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      bayType,
      readingFields,
      createdBy,
      createdAt,
      updatedAt,
      description,
      isActive,
    );
  }
}
