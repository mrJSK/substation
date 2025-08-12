// lib/services/report_builder_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:excel/excel.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/report_builder_models.dart';

class ReportBuilderService {
  static const Map<String, String> collectionMap = {
    'energy': 'bayEnergyData',
    'bays': 'bays',
    'tripping': 'trippingShutdownEntries',
    'operations': 'logsheetEntries',
    'equipment': 'equipmentInstances',
    'assessments': 'assessments',
  };

  // Step 3: Get available data sources with dynamic field discovery
  static Future<List<DataSourceConfig>> getAvailableDataSources({
    required List<String> substationIds,
  }) async {
    List<DataSourceConfig> dataSources = [];

    // Core system data sources
    final coreSourcesData = {
      'energy': {
        'name': 'Energy Readings',
        'fields': [
          AvailableField(
            name: 'importConsumed',
            displayName: 'Import Energy (kWh)',
            type: 'number',
            path: 'importConsumed',
            dataSourceId: 'energy',
          ),
          AvailableField(
            name: 'exportConsumed',
            displayName: 'Export Energy (kWh)',
            type: 'number',
            path: 'exportConsumed',
            dataSourceId: 'energy',
          ),
          AvailableField(
            name: 'readingTimestamp',
            displayName: 'Reading Time',
            type: 'datetime',
            path: 'readingTimestamp',
            dataSourceId: 'energy',
          ),
          AvailableField(
            name: 'multiplierFactor',
            displayName: 'Multiplier Factor',
            type: 'number',
            path: 'multiplierFactor',
            dataSourceId: 'energy',
          ),
          AvailableField(
            name: 'adjustedImportConsumed',
            displayName: 'Adjusted Import',
            type: 'number',
            path: 'adjustedImportConsumed',
            dataSourceId: 'energy',
          ),
        ],
      },
      'bays': {
        'name': 'Bay Information',
        'fields': [
          AvailableField(
            name: 'name',
            displayName: 'Bay Name',
            type: 'string',
            path: 'name',
            dataSourceId: 'bays',
          ),
          AvailableField(
            name: 'voltageLevel',
            displayName: 'Voltage Level',
            type: 'string',
            path: 'voltageLevel',
            dataSourceId: 'bays',
          ),
          AvailableField(
            name: 'capacity',
            displayName: 'Capacity (MVA)',
            type: 'number',
            path: 'capacity',
            dataSourceId: 'bays',
          ),
          AvailableField(
            name: 'bayType',
            displayName: 'Bay Type',
            type: 'string',
            path: 'bayType',
            dataSourceId: 'bays',
          ),
          AvailableField(
            name: 'substationId',
            displayName: 'Substation ID',
            type: 'string',
            path: 'substationId',
            dataSourceId: 'bays',
          ),
        ],
      },
      'tripping': {
        'name': 'Tripping Events',
        'fields': [
          AvailableField(
            name: 'startTime',
            displayName: 'Trip Start',
            type: 'datetime',
            path: 'startTime',
            dataSourceId: 'tripping',
          ),
          AvailableField(
            name: 'endTime',
            displayName: 'Trip End',
            type: 'datetime',
            path: 'endTime',
            dataSourceId: 'tripping',
          ),
          AvailableField(
            name: 'eventType',
            displayName: 'Event Type',
            type: 'string',
            path: 'eventType',
            dataSourceId: 'tripping',
          ),
          AvailableField(
            name: 'flagsCause',
            displayName: 'Cause',
            type: 'string',
            path: 'flagsCause',
            dataSourceId: 'tripping',
          ),
          AvailableField(
            name: 'status',
            displayName: 'Status',
            type: 'string',
            path: 'status',
            dataSourceId: 'tripping',
          ),
        ],
      },
      'operations': {
        'name': 'Operations Log',
        'fields': [
          AvailableField(
            name: 'readingTimestamp',
            displayName: 'Operation Time',
            type: 'datetime',
            path: 'readingTimestamp',
            dataSourceId: 'operations',
          ),
          AvailableField(
            name: 'recordedBy',
            displayName: 'Recorded By',
            type: 'string',
            path: 'recordedBy',
            dataSourceId: 'operations',
          ),
          AvailableField(
            name: 'frequency',
            displayName: 'Frequency',
            type: 'string',
            path: 'frequency',
            dataSourceId: 'operations',
          ),
          AvailableField(
            name: 'readingHour',
            displayName: 'Reading Hour',
            type: 'number',
            path: 'readingHour',
            dataSourceId: 'operations',
          ),
        ],
      },
    };

    // Add core data sources
    for (var entry in coreSourcesData.entries) {
      dataSources.add(
        DataSourceConfig(
          sourceId: entry.key,
          sourceName: entry.value['name'] as String,
          type: DataSourceType.core,
          fields: entry.value['fields'] as List<AvailableField>,
        ),
      );
    }

    // Add custom fields from user models
    final customFields = await _getCustomFields(substationIds);
    if (customFields.isNotEmpty) {
      dataSources.add(
        DataSourceConfig(
          sourceId: 'customFields',
          sourceName: 'Custom Fields',
          type: DataSourceType.customField,
          fields: customFields,
        ),
      );
    }

    // Add custom grouped fields
    final customGroupedFields = await _getCustomGroupedFields(substationIds);
    if (customGroupedFields.isNotEmpty) {
      dataSources.add(
        DataSourceConfig(
          sourceId: 'customGroups',
          sourceName: 'Custom Grouped Fields',
          type: DataSourceType.customGroup,
          fields: customGroupedFields,
        ),
      );
    }

    return dataSources;
  }

  // Get custom fields from reading field templates
  static Future<List<AvailableField>> _getCustomFields(
    List<String> substationIds,
  ) async {
    List<AvailableField> customFields = [];

    try {
      if (substationIds.isNotEmpty) {
        final snapshot = await FirebaseFirestore.instance
            .collection('readingFieldTemplates')
            .where('substationId', whereIn: substationIds)
            .get();

        for (var doc in snapshot.docs) {
          final data = doc.data();
          final fields = data['fields'] as List<dynamic>? ?? [];

          for (var field in fields) {
            if (field is Map<String, dynamic>) {
              customFields.add(
                AvailableField(
                  name: field['name'] ?? '',
                  displayName: field['displayName'] ?? field['name'] ?? '',
                  type: field['type'] ?? 'string',
                  path: 'customFields.${field['name']}',
                  dataSourceId: 'customFields',
                ),
              );
            }
          }
        }
      }
    } catch (e) {
      print('Error loading custom fields: $e');
    }

    return customFields;
  }

  // Get custom grouped fields
  static Future<List<AvailableField>> _getCustomGroupedFields(
    List<String> substationIds,
  ) async {
    List<AvailableField> groupedFields = [];

    try {
      if (substationIds.isNotEmpty) {
        final snapshot = await FirebaseFirestore.instance
            .collection('customFieldGroups')
            .where('substationId', whereIn: substationIds)
            .get();

        for (var doc in snapshot.docs) {
          final data = doc.data();
          groupedFields.add(
            AvailableField(
              name: data['groupName'] ?? '',
              displayName: data['displayName'] ?? data['groupName'] ?? '',
              type: 'group',
              path: 'customGroups.${data['groupName']}',
              dataSourceId: 'customGroups',
            ),
          );
        }
      }
    } catch (e) {
      print('Error loading custom grouped fields: $e');
    }

    return groupedFields;
  }

  // Step 6: Generate preview data
  static Future<PreviewData> generatePreview(ReportConfiguration config) async {
    try {
      final rawData = await _executeQuery(config);
      final processedData = _processRawData(rawData, config);

      return PreviewData(
        sampleRows: processedData.take(50).toList(),
        totalEstimatedRows: processedData.length,
        generatedAt: DateTime.now(),
      );
    } catch (e) {
      print('Error generating preview: $e');
      return PreviewData(
        sampleRows: [],
        totalEstimatedRows: 0,
        generatedAt: DateTime.now(),
      );
    }
  }

  // Execute query based on configuration
  static Future<Map<String, List<DocumentSnapshot>>> _executeQuery(
    ReportConfiguration config,
  ) async {
    Map<String, List<DocumentSnapshot>> rawData = {};

    for (var dataSource in config.dataSources.where((ds) => ds.isEnabled)) {
      if (dataSource.type == DataSourceType.core) {
        final query = _buildQuery(dataSource.sourceId, config);
        final snapshot = await query.get();
        rawData[dataSource.sourceId] = snapshot.docs;
      }
    }

    return rawData;
  }

  // Build Firestore query
  static Query _buildQuery(String sourceId, ReportConfiguration config) {
    Query query = FirebaseFirestore.instance.collection(
      collectionMap[sourceId]!,
    );

    // Apply substation filter
    if (config.substationIds.isNotEmpty) {
      switch (sourceId) {
        case 'bays':
          query = query.where('substationId', whereIn: config.substationIds);
          break;
        case 'energy':
        case 'operations':
          // These collections might need bay-based filtering
          break;
      }
    }

    // Apply date filters
    switch (sourceId) {
      case 'energy':
      case 'operations':
        query = query
            .where(
              'readingTimestamp',
              isGreaterThanOrEqualTo: Timestamp.fromDate(config.startDate),
            )
            .where(
              'readingTimestamp',
              isLessThanOrEqualTo: Timestamp.fromDate(config.endDate),
            )
            .orderBy('readingTimestamp');
        break;
      case 'tripping':
        query = query
            .where(
              'startTime',
              isGreaterThanOrEqualTo: Timestamp.fromDate(config.startDate),
            )
            .where(
              'startTime',
              isLessThanOrEqualTo: Timestamp.fromDate(config.endDate),
            )
            .orderBy('startTime');
        break;
    }

    // Apply custom filters
    config.filters.forEach((key, value) {
      if (key.startsWith('$sourceId.') && value != null) {
        String field = key.replaceFirst('$sourceId.', '');
        query = query.where(field, isEqualTo: value);
      }
    });

    return query;
  }

  // Process raw data according to row and column configuration
  static List<Map<String, dynamic>> _processRawData(
    Map<String, List<DocumentSnapshot>> rawData,
    ReportConfiguration config,
  ) {
    List<Map<String, dynamic>> processedRows = [];

    // Determine primary data source
    String primarySource = config.rowConfig.primaryDataSource.isNotEmpty
        ? config.rowConfig.primaryDataSource
        : config.dataSources.firstWhere((ds) => ds.isEnabled).sourceId;

    if (!rawData.containsKey(primarySource)) return processedRows;

    // Process each document from primary source
    for (var doc in rawData[primarySource]!) {
      Map<String, dynamic> row = {};

      // Process each column
      for (var column in config.columns) {
        _processColumnData(column, row, doc, rawData, config);
      }

      // Apply row filters
      if (_passesRowFilters(row, config.rowConfig.filterRules)) {
        processedRows.add(row);
      }
    }

    // Apply sorting
    _applySorting(processedRows, config.rowConfig.sortRules);

    return processedRows;
  }

  static void _processColumnData(
    ColumnConfig column,
    Map<String, dynamic> row,
    DocumentSnapshot doc,
    Map<String, List<DocumentSnapshot>> allData,
    ReportConfiguration config,
  ) {
    if (column.isGroupHeader && column.subColumns != null) {
      for (var subColumn in column.subColumns!) {
        _processColumnData(subColumn, row, doc, allData, config);
      }
    } else {
      dynamic value = _extractFieldValue(column, doc, allData);
      row[column.getColumnKey()] = value;
    }
  }

  static dynamic _extractFieldValue(
    ColumnConfig column,
    DocumentSnapshot doc,
    Map<String, List<DocumentSnapshot>> allData,
  ) {
    if (column.dataType == ColumnDataType.computed && column.formula != null) {
      return _executeFormula(column.formula!, doc, allData);
    }

    final data = doc.data() as Map<String, dynamic>?;
    if (data == null) return '';

    return _getNestedValue(data, column.fieldPath) ?? '';
  }

  static dynamic _executeFormula(
    String formula,
    DocumentSnapshot doc,
    Map<String, List<DocumentSnapshot>> allData,
  ) {
    try {
      if (formula.startsWith('MAX(')) {
        String field = formula.replaceAll(RegExp(r'MAX\(|\)'), '');
        return _calculateAggregation('MAX', field, allData);
      } else if (formula.startsWith('MIN(')) {
        String field = formula.replaceAll(RegExp(r'MIN\(|\)'), '');
        return _calculateAggregation('MIN', field, allData);
      } else if (formula.startsWith('AVG(')) {
        String field = formula.replaceAll(RegExp(r'AVG\(|\)'), '');
        return _calculateAggregation('AVG', field, allData);
      } else if (formula.startsWith('SUM(')) {
        String field = formula.replaceAll(RegExp(r'SUM\(|\)'), '');
        return _calculateAggregation('SUM', field, allData);
      } else if (formula.startsWith('COUNT(')) {
        String source = formula.replaceAll(RegExp(r'COUNT\(|\)'), '');
        return allData[source]?.length ?? 0;
      }

      return formula;
    } catch (e) {
      return 'Error';
    }
  }

  static dynamic _calculateAggregation(
    String operation,
    String fieldPath,
    Map<String, List<DocumentSnapshot>> allData,
  ) {
    List<String> parts = fieldPath.split('.');
    if (parts.length < 2) return 0;

    String source = parts[0];
    String field = parts[1];

    List<num> values = [];
    for (var doc in allData[source] ?? []) {
      final data = doc.data() as Map<String, dynamic>?;
      if (data != null && data[field] is num) {
        values.add(data[field]);
      }
    }

    if (values.isEmpty) return 0;

    switch (operation) {
      case 'MAX':
        return values.reduce((a, b) => a > b ? a : b);
      case 'MIN':
        return values.reduce((a, b) => a < b ? a : b);
      case 'SUM':
        return values.reduce((a, b) => a + b);
      case 'AVG':
        return values.reduce((a, b) => a + b) / values.length;
      default:
        return 0;
    }
  }

  static dynamic _getNestedValue(Map<String, dynamic> data, String path) {
    List<String> parts = path.split('.');
    dynamic value = data;

    for (String part in parts) {
      if (value is Map<String, dynamic> && value.containsKey(part)) {
        value = value[part];
      } else {
        return null;
      }
    }

    return value;
  }

  static bool _passesRowFilters(
    Map<String, dynamic> row,
    List<FilterRule> filters,
  ) {
    for (var filter in filters) {
      dynamic rowValue = row[filter.fieldPath];
      if (!_evaluateFilter(rowValue, filter.operator, filter.value)) {
        return false;
      }
    }
    return true;
  }

  static bool _evaluateFilter(
    dynamic rowValue,
    String operator,
    dynamic filterValue,
  ) {
    switch (operator) {
      case '==':
        return rowValue == filterValue;
      case '!=':
        return rowValue != filterValue;
      case '>':
        return (rowValue is num && filterValue is num)
            ? rowValue > filterValue
            : false;
      case '<':
        return (rowValue is num && filterValue is num)
            ? rowValue < filterValue
            : false;
      case 'contains':
        return rowValue.toString().toLowerCase().contains(
          filterValue.toString().toLowerCase(),
        );
      default:
        return true;
    }
  }

  static void _applySorting(
    List<Map<String, dynamic>> rows,
    List<SortRule> sortRules,
  ) {
    if (sortRules.isEmpty) return;

    rows.sort((a, b) {
      for (var rule in sortRules) {
        dynamic aValue = a[rule.fieldPath];
        dynamic bValue = b[rule.fieldPath];

        int comparison = _compareValues(aValue, bValue);
        if (comparison != 0) {
          return rule.ascending ? comparison : -comparison;
        }
      }
      return 0;
    });
  }

  static int _compareValues(dynamic a, dynamic b) {
    if (a == null && b == null) return 0;
    if (a == null) return -1;
    if (b == null) return 1;

    if (a is num && b is num) {
      return a.compareTo(b);
    } else if (a is String && b is String) {
      return a.compareTo(b);
    } else if (a is DateTime && b is DateTime) {
      return a.compareTo(b);
    } else {
      return a.toString().compareTo(b.toString());
    }
  }

  // Export to Excel
  static Future<void> exportToExcel(
    ReportConfiguration config,
    List<Map<String, dynamic>> data,
  ) async {
    try {
      var excel = Excel.createExcel();
      Sheet sheet = excel['Report'];

      int currentRow = 0;

      // Add title
      if (config.title.isNotEmpty) {
        sheet
            .cell(
              CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: currentRow),
            )
            .value = TextCellValue(
          config.title,
        );
        currentRow += 1;
      }

      // Add subtitle
      if (config.subtitle != null && config.subtitle!.isNotEmpty) {
        sheet
            .cell(
              CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: currentRow),
            )
            .value = TextCellValue(
          config.subtitle!,
        );
        currentRow += 1;
      }

      currentRow += 1; // Empty row

      // Add headers
      int colIndex = 0;
      for (var column in config.columns) {
        colIndex = _writeColumnHeaders(sheet, column, currentRow, colIndex);
      }
      currentRow += 1;

      // Add data rows
      for (var row in data) {
        colIndex = 0;
        for (var column in config.columns) {
          colIndex = _writeColumnData(sheet, column, row, currentRow, colIndex);
        }
        currentRow += 1;
      }

      // Save and share
      final directory = await getApplicationDocumentsDirectory();
      final file = File(
        '${directory.path}/report_${DateTime.now().millisecondsSinceEpoch}.xlsx',
      );
      final bytes = excel.save();
      if (bytes != null) {
        await file.writeAsBytes(bytes);
        await Share.shareXFiles([XFile(file.path)], text: 'Custom Report');
      }
    } catch (e) {
      throw Exception('Failed to export Excel: $e');
    }
  }

  static int _writeColumnHeaders(
    Sheet sheet,
    ColumnConfig column,
    int row,
    int startCol,
  ) {
    if (column.isGroupHeader && column.subColumns != null) {
      // Write group header
      sheet
          .cell(
            CellIndex.indexByColumnRow(columnIndex: startCol, rowIndex: row),
          )
          .value = TextCellValue(
        column.header,
      );

      int colIndex = startCol;
      for (var subColumn in column.subColumns!) {
        colIndex = _writeColumnHeaders(sheet, subColumn, row + 1, colIndex);
      }
      return colIndex;
    } else {
      sheet
          .cell(
            CellIndex.indexByColumnRow(columnIndex: startCol, rowIndex: row),
          )
          .value = TextCellValue(
        column.header,
      );
      return startCol + 1;
    }
  }

  static int _writeColumnData(
    Sheet sheet,
    ColumnConfig column,
    Map<String, dynamic> data,
    int row,
    int startCol,
  ) {
    if (column.isGroupHeader && column.subColumns != null) {
      int colIndex = startCol;
      for (var subColumn in column.subColumns!) {
        colIndex = _writeColumnData(sheet, subColumn, data, row, colIndex);
      }
      return colIndex;
    } else {
      String key = column.getColumnKey();
      dynamic value = data[key] ?? '';
      sheet
          .cell(
            CellIndex.indexByColumnRow(columnIndex: startCol, rowIndex: row),
          )
          .value = TextCellValue(
        value.toString(),
      );
      return startCol + 1;
    }
  }

  // Step 7: Save template
  static Future<void> saveTemplate(
    ReportConfiguration config,
    String userId,
  ) async {
    try {
      await FirebaseFirestore.instance.collection('reportTemplates').add({
        ...config.toJson(),
        'createdBy': userId,
        'createdAt': FieldValue.serverTimestamp(),
        'lastUsed': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Failed to save template: $e');
    }
  }
}

// Validation service
class ReportValidationService {
  static ValidationResult validateStep(int step, ReportConfiguration config) {
    switch (step) {
      case 0:
        return _validateMetadata(config);
      case 1:
        return _validateSubstationSelection(config);
      case 2:
        return _validateDataSources(config);
      case 3:
        return _validateColumnMapping(config);
      case 4:
        return _validateRowMapping(config);
      case 5:
        return _validatePreview(config);
      default:
        return ValidationResult.success();
    }
  }

  static ValidationResult _validateMetadata(ReportConfiguration config) {
    if (config.title.trim().isEmpty) {
      return ValidationResult.error("Report title is required");
    }
    return ValidationResult.success();
  }

  static ValidationResult _validateSubstationSelection(
    ReportConfiguration config,
  ) {
    if (config.substationIds.isEmpty) {
      return ValidationResult.error("At least one substation must be selected");
    }
    return ValidationResult.success();
  }

  static ValidationResult _validateDataSources(ReportConfiguration config) {
    if (!config.dataSources.any((ds) => ds.isEnabled)) {
      return ValidationResult.error(
        "At least one data source must be selected",
      );
    }
    return ValidationResult.success();
  }

  static ValidationResult _validateColumnMapping(ReportConfiguration config) {
    if (config.columns.isEmpty) {
      return ValidationResult.error("At least one column must be configured");
    }

    for (var column in config.columns) {
      if (column.header.trim().isEmpty) {
        return ValidationResult.error("All columns must have headers");
      }
    }

    return ValidationResult.success();
  }

  static ValidationResult _validateRowMapping(ReportConfiguration config) {
    if (config.rowConfig.primaryDataSource.isEmpty) {
      return ValidationResult.warning(
        "Primary data source not set - using first enabled source",
      );
    }
    return ValidationResult.success();
  }

  static ValidationResult _validatePreview(ReportConfiguration config) {
    if (config.preview == null || config.preview!.sampleRows.isEmpty) {
      return ValidationResult.error("Preview must be generated before saving");
    }
    return ValidationResult.success();
  }
}
