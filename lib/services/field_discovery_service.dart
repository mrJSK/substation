// lib/services/field_discovery_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/report_template_models.dart';

class FieldDiscoveryService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<Map<String, List<AvailableField>>> loadAllAvailableFields(
    String userId,
  ) async {
    try {
      final Map<String, List<AvailableField>> allFields = {};

      allFields['substations'] = await _loadStandardFields('substations');
      allFields['bays'] = await _loadStandardFields('bays');
      allFields['equipments'] = await _loadStandardFields('equipments');
      allFields['logsheetEntries'] = await _loadStandardFields(
        'logsheetEntries',
      );
      allFields['assessments'] = await _loadStandardFields('assessments');

      final customFields = await _loadAllCustomFields(userId);
      customFields.forEach((dataSourceId, fields) {
        if (allFields.containsKey(dataSourceId)) {
          allFields[dataSourceId]!.addAll(fields);
        } else {
          allFields[dataSourceId] = fields;
        }
      });

      return allFields;
    } catch (e) {
      throw Exception('Failed to load available fields: $e');
    }
  }

  Future<List<AvailableField>> _loadStandardFields(String collection) async {
    final standardFieldsMap = {
      'substations': [
        AvailableField(
          id: 'substation_id',
          name: 'Substation ID',
          path: 'id',
          type: DataType.string,
          origin: FieldOrigin.standard,
          description: 'Unique identifier for substation',
        ),
        AvailableField(
          id: 'substation_name',
          name: 'Substation Name',
          path: 'name',
          type: DataType.string,
          origin: FieldOrigin.standard,
          description: 'Name of the substation',
        ),
        AvailableField(
          id: 'voltage_level',
          name: 'Voltage Level',
          path: 'voltageLevel',
          type: DataType.string,
          origin: FieldOrigin.standard,
          description: 'Operating voltage level',
        ),
        AvailableField(
          id: 'location',
          name: 'Location',
          path: 'location',
          type: DataType.string,
          origin: FieldOrigin.standard,
          description: 'Geographic location',
        ),
      ],
      'bays': [
        AvailableField(
          id: 'bay_id',
          name: 'Bay ID',
          path: 'id',
          type: DataType.string,
          origin: FieldOrigin.standard,
          description: 'Unique identifier for bay',
        ),
        AvailableField(
          id: 'bay_name',
          name: 'Bay Name',
          path: 'name',
          type: DataType.string,
          origin: FieldOrigin.standard,
          description: 'Name of the bay',
        ),
        AvailableField(
          id: 'bay_type',
          name: 'Bay Type',
          path: 'bayType',
          type: DataType.string,
          origin: FieldOrigin.standard,
          description: 'Type of bay (e.g., Feeder, Transformer)',
        ),
        AvailableField(
          id: 'bay_voltage_level',
          name: 'Bay Voltage Level',
          path: 'voltageLevel',
          type: DataType.string,
          origin: FieldOrigin.standard,
          description: 'Operating voltage level of bay',
        ),
      ],
      'equipments': [
        AvailableField(
          id: 'equipment_id',
          name: 'Equipment ID',
          path: 'id',
          type: DataType.string,
          origin: FieldOrigin.standard,
          description: 'Unique identifier for equipment',
        ),
        AvailableField(
          id: 'equipment_name',
          name: 'Equipment Name',
          path: 'name',
          type: DataType.string,
          origin: FieldOrigin.standard,
          description: 'Name of the equipment',
        ),
        AvailableField(
          id: 'equipment_type',
          name: 'Equipment Type',
          path: 'type',
          type: DataType.string,
          origin: FieldOrigin.standard,
          description: 'Type of equipment',
        ),
        AvailableField(
          id: 'manufacturer',
          name: 'Manufacturer',
          path: 'manufacturer',
          type: DataType.string,
          origin: FieldOrigin.standard,
          description: 'Equipment manufacturer',
        ),
      ],
      'logsheetEntries': [
        AvailableField(
          id: 'entry_id',
          name: 'Entry ID',
          path: 'id',
          type: DataType.string,
          origin: FieldOrigin.standard,
          description: 'Unique identifier for logsheet entry',
        ),
        AvailableField(
          id: 'reading_timestamp',
          name: 'Reading Timestamp',
          path: 'readingTimestamp',
          type: DataType.date,
          origin: FieldOrigin.standard,
          description: 'Timestamp when reading was taken',
        ),
        AvailableField(
          id: 'frequency',
          name: 'Frequency',
          path: 'frequency',
          type: DataType.string,
          origin: FieldOrigin.standard,
          description: 'Reading frequency (hourly/daily)',
        ),
        AvailableField(
          id: 'import_energy',
          name: 'Import Energy',
          path: 'values.importEnergy',
          type: DataType.number,
          origin: FieldOrigin.standard,
          description: 'Energy imported (kWh)',
        ),
        AvailableField(
          id: 'export_energy',
          name: 'Export Energy',
          path: 'values.exportEnergy',
          type: DataType.number,
          origin: FieldOrigin.standard,
          description: 'Energy exported (kWh)',
        ),
      ],
      'assessments': [
        AvailableField(
          id: 'assessment_id',
          name: 'Assessment ID',
          path: 'id',
          type: DataType.string,
          origin: FieldOrigin.standard,
          description: 'Unique identifier for assessment',
        ),
        AvailableField(
          id: 'assessment_timestamp',
          name: 'Assessment Timestamp',
          path: 'assessmentTimestamp',
          type: DataType.date,
          origin: FieldOrigin.standard,
          description: 'When assessment was performed',
        ),
        AvailableField(
          id: 'reason',
          name: 'Assessment Reason',
          path: 'reason',
          type: DataType.string,
          origin: FieldOrigin.standard,
          description: 'Reason for assessment',
        ),
        AvailableField(
          id: 'import_adjustment',
          name: 'Import Adjustment',
          path: 'importAdjustment',
          type: DataType.number,
          origin: FieldOrigin.standard,
          description: 'Adjustment to import energy',
        ),
        AvailableField(
          id: 'export_adjustment',
          name: 'Export Adjustment',
          path: 'exportAdjustment',
          type: DataType.number,
          origin: FieldOrigin.standard,
          description: 'Adjustment to export energy',
        ),
      ],
    };

    return standardFieldsMap[collection] ?? [];
  }

  Future<Map<String, List<AvailableField>>> _loadAllCustomFields(
    String userId,
  ) async {
    final Map<String, List<AvailableField>> customFields = {};

    try {
      final collections = ['bays', 'equipments', 'substations'];

      for (final collectionName in collections) {
        final fields = await _loadCollectionCustomFields(
          collectionName,
          userId,
        );
        if (fields.isNotEmpty) {
          customFields[collectionName] = fields;
        }
      }

      final userCollections = await _firestore
          .collection('customCollections')
          .where('createdBy', isEqualTo: userId)
          .get();

      for (var doc in userCollections.docs) {
        final collectionName = doc.id;
        final fields = await _loadCollectionCustomFields(
          collectionName,
          userId,
        );
        if (fields.isNotEmpty) {
          customFields[collectionName] = fields;
        }
      }
    } catch (e) {
      print('Error loading custom fields: $e');
    }

    return customFields;
  }

  Future<List<AvailableField>> _loadCollectionCustomFields(
    String collectionName,
    String userId,
  ) async {
    final List<AvailableField> customFields = [];

    try {
      Query query = _firestore.collection(collectionName);

      if (collectionName != 'substations') {
        query = query.limit(10);
      }

      final sampleDocs = await query.get();

      if (sampleDocs.docs.isNotEmpty) {
        final seenFields = <String>{};

        for (final doc in sampleDocs.docs) {
          final data = doc.data() as Map<String, dynamic>;

          if (data.containsKey('customFields')) {
            final customFieldsData =
                data['customFields'] as Map<String, dynamic>?;

            customFieldsData?.forEach((fieldKey, fieldValue) {
              if (!seenFields.contains(fieldKey)) {
                seenFields.add(fieldKey);
                customFields.add(
                  AvailableField(
                    id: 'custom_${fieldKey}',
                    name: _formatFieldName(fieldKey),
                    path: 'customFields.$fieldKey',
                    type: _inferDataType(fieldValue),
                    origin: FieldOrigin.custom,
                    description: 'Custom field created by user',
                  ),
                );
              }
            });
          }

          data.forEach((key, value) {
            if (!_isStandardField(key, collectionName) &&
                !seenFields.contains(key) &&
                key != 'customFields') {
              seenFields.add(key);
              customFields.add(
                AvailableField(
                  id: 'dynamic_${key}',
                  name: _formatFieldName(key),
                  path: key,
                  type: _inferDataType(value),
                  origin: FieldOrigin.custom,
                  description: 'User-defined field',
                ),
              );
            }
          });
        }
      }
    } catch (e) {
      print('Error loading custom fields for $collectionName: $e');
    }

    return customFields;
  }

  String _formatFieldName(String fieldKey) {
    return fieldKey
        .split(RegExp(r'[_\s]+'))
        .map(
          (word) => word.isNotEmpty
              ? word[0].toUpperCase() + word.substring(1).toLowerCase()
              : word,
        )
        .join(' ');
  }

  DataType _inferDataType(dynamic value) {
    if (value == null) return DataType.string;

    if (value is String) {
      if (DateTime.tryParse(value) != null) {
        return DataType.date;
      }
      if (double.tryParse(value) != null) {
        return DataType.number;
      }
      if (value.toLowerCase() == 'true' || value.toLowerCase() == 'false') {
        return DataType.boolean;
      }
      return DataType.string;
    }

    if (value is num) return DataType.number;
    if (value is bool) return DataType.boolean;
    if (value is DateTime) return DataType.date;
    if (value is Timestamp) return DataType.date;
    if (value is Map) return DataType.object;
    if (value is List) {
      return value.isNotEmpty ? _inferDataType(value.first) : DataType.string;
    }

    return DataType.string;
  }

  bool _isStandardField(String fieldName, String collectionName) {
    final standardFields = {
      'bays': [
        'id',
        'name',
        'bayType',
        'voltageLevel',
        'substationId',
        'createdAt',
        'updatedAt',
        'createdBy',
        'updatedBy',
      ],
      'equipments': [
        'id',
        'name',
        'type',
        'bayId',
        'substationId',
        'manufacturer',
        'createdAt',
        'updatedAt',
        'createdBy',
        'updatedBy',
      ],
      'substations': [
        'id',
        'name',
        'voltageLevel',
        'location',
        'circleId',
        'divisionId',
        'createdAt',
        'updatedAt',
        'createdBy',
        'updatedBy',
      ],
      'logsheetEntries': [
        'id',
        'bayId',
        'substationId',
        'readingTimestamp',
        'frequency',
        'values',
        'createdAt',
        'updatedAt',
        'createdBy',
        'updatedBy',
      ],
      'assessments': [
        'id',
        'bayId',
        'substationId',
        'assessmentTimestamp',
        'reason',
        'importAdjustment',
        'exportAdjustment',
        'createdAt',
        'updatedAt',
      ],
    };

    return standardFields[collectionName]?.contains(fieldName) ?? false;
  }
}
