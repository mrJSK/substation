// lib/models/report_template_model.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'bay_model.dart';
import 'reading_models.dart';
import 'hierarchy_models.dart';

enum ReportFrequency { hourly, daily, custom, onDemand, monthly }

enum MathOperation {
  none,
  max,
  min,
  sum,
  average,
  add,
  subtract,
  multiply,
  divide,
}

extension ReportFrequencyExtension on ReportFrequency {
  String toShortString() {
    return toString().split('.').last;
  }
}

extension MathOperationExtension on MathOperation {
  String toShortString() {
    return toString().split('.').last;
  }
}

class CustomReportColumn {
  final String columnName;
  final String baseReadingFieldId;
  final String? secondaryReadingFieldId;
  final MathOperation operation;
  final String? operandValue;

  CustomReportColumn({
    required this.columnName,
    required this.baseReadingFieldId,
    this.secondaryReadingFieldId,
    this.operation = MathOperation.none,
    this.operandValue,
  });

  Map<String, dynamic> toMap() {
    return {
      'columnName': columnName,
      'baseReadingFieldId': baseReadingFieldId,
      'secondaryReadingFieldId': secondaryReadingFieldId,
      'operation': operation.toShortString(),
      'operandValue': operandValue,
    };
  }

  static CustomReportColumn fromMap(Map<String, dynamic> map) {
    return CustomReportColumn(
      columnName: map['columnName'],
      baseReadingFieldId: map['baseReadingFieldId'],
      secondaryReadingFieldId: map['secondaryReadingFieldId'],
      operation: MathOperation.values.firstWhere(
        (e) => e.toShortString() == map['operation'],
        orElse: () => MathOperation.none,
      ),
      operandValue: map['operandValue'],
    );
  }
}

class ReportTemplate {
  final String? id;
  final String templateName;
  final String createdByUid;
  final String substationId;
  final List<String> selectedBayIds;
  final List<String> selectedBayTypeIds;
  final List<String> selectedReadingFieldIds;
  final ReportFrequency frequency;
  final List<CustomReportColumn> customColumns;

  ReportTemplate({
    this.id,
    required this.templateName,
    required this.createdByUid,
    required this.substationId,
    this.selectedBayIds = const [],
    this.selectedBayTypeIds = const [],
    required this.selectedReadingFieldIds,
    required this.frequency,
    this.customColumns = const [],
  });

  // Convert to a Map (e.g., for Firestore)
  Map<String, dynamic> toMap() {
    return {
      'templateName': templateName,
      'createdByUid': createdByUid,
      'substationId': substationId,
      'selectedBayIds': selectedBayIds,
      'selectedBayTypeIds': selectedBayTypeIds,
      'selectedReadingFieldIds': selectedReadingFieldIds,
      'frequency': frequency.toShortString(),
      'customColumns': customColumns.map((col) => col.toMap()).toList(),
      'createdAt': FieldValue.serverTimestamp(),
    };
  }

  // FIX: Add fromFirestore factory constructor
  factory ReportTemplate.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return ReportTemplate(
      id: doc.id,
      templateName: data['templateName'] as String,
      createdByUid: data['createdByUid'] as String,
      substationId: data['substationId'] as String,
      selectedBayIds: List<String>.from(data['selectedBayIds'] ?? []),
      selectedBayTypeIds: List<String>.from(data['selectedBayTypeIds'] ?? []),
      selectedReadingFieldIds: List<String>.from(
        data['selectedReadingFieldIds'] ?? [],
      ),
      frequency: ReportFrequency.values.firstWhere(
        (e) => e.toShortString() == data['frequency'],
        orElse: () => ReportFrequency.daily,
      ),
      customColumns:
          (data['customColumns'] as List<dynamic>?)
              ?.map(
                (e) => CustomReportColumn.fromMap(e as Map<String, dynamic>),
              )
              .toList() ??
          [],
    );
  }
}
