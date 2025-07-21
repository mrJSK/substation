import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart'; // For @required if not using null safety checks

enum ReadingFieldDataType { text, number, boolean, date, dropdown, group }

enum ReadingFrequency {
  hourly,
  daily,
  monthly,
  quarterly,
  semiannually,
  annually,
  onDemand, // For readings not tied to a strict schedule
}

class ReadingField {
  final String name;
  final ReadingFieldDataType dataType;
  final String? unit; // Optional for number types
  final List<String>? options; // For dropdown types
  final bool isMandatory;
  final ReadingFrequency? frequency; // Made optional for nested fields
  final String? descriptionRemarks; // For boolean fields
  final List<ReadingField>? nestedFields; // For group type fields

  ReadingField({
    required this.name,
    required this.dataType,
    this.unit,
    this.options,
    this.isMandatory = false,
    this.frequency, // No longer required
    this.descriptionRemarks,
    this.nestedFields,
  });

  // Convert from a Map (e.g., from Firestore)
  factory ReadingField.fromMap(Map<String, dynamic> map) {
    return ReadingField(
      name: map['name'] as String,
      dataType: ReadingFieldDataType.values.firstWhere(
        (e) => e.toString().split('.').last == map['dataType'],
        orElse: () => ReadingFieldDataType.text, // Default to text if not found
      ),
      unit: map['unit'] as String?,
      options: (map['options'] as List<dynamic>?)
          ?.map((e) => e.toString())
          .toList(),
      isMandatory: map['isMandatory'] as bool? ?? false,
      frequency: map['frequency'] != null
          ? ReadingFrequency.values.firstWhere(
              (e) => e.toString().split('.').last == map['frequency'],
              orElse: () => ReadingFrequency.onDemand, // Default
            )
          : null,
      descriptionRemarks: map['description_remarks'] as String?,
      nestedFields: (map['nestedFields'] as List<dynamic>?)
          ?.map(
            (fieldMap) =>
                ReadingField.fromMap(fieldMap as Map<String, dynamic>),
          )
          .toList(),
    );
  }

  // Convert to a Map (e.g., for Firestore)
  Map<String, dynamic> toMap() {
    final map = {
      'name': name,
      'dataType': dataType.toString().split('.').last,
      'unit': unit,
      'options': options,
      'isMandatory': isMandatory,
      'description_remarks': descriptionRemarks,
    };
    if (frequency != null) {
      map['frequency'] = frequency!.toString().split('.').last;
    }
    if (nestedFields != null) {
      map['nestedFields'] = nestedFields!
          .map((field) => field.toMap())
          .toList();
    }
    return map;
  }
}

class ReadingTemplate {
  final String? id; // Null for new templates before they are saved
  final String bayType;
  final List<ReadingField> readingFields;
  final String createdBy;
  final Timestamp createdAt;

  ReadingTemplate({
    this.id,
    required this.bayType,
    required this.readingFields,
    required this.createdBy,
    required this.createdAt,
  });

  // Create a ReadingTemplate from a Firestore DocumentSnapshot
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
    );
  }

  // Convert a ReadingTemplate to a Map for Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'bayType': bayType,
      'readingFields': readingFields.map((field) => field.toMap()).toList(),
      'createdBy': createdBy,
      'createdAt': createdAt,
    };
  }

  // For updating only specific fields
  ReadingTemplate copyWith({
    String? id,
    String? bayType,
    List<ReadingField>? readingFields,
    String? createdBy,
    Timestamp? createdAt,
  }) {
    return ReadingTemplate(
      id: id ?? this.id,
      bayType: bayType ?? this.bayType,
      readingFields: readingFields ?? this.readingFields,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
