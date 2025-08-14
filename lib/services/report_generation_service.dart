// lib/services/report_generation_service.dart

import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:excel/excel.dart';
import '../models/report_template_models.dart';
import 'field_discovery_service.dart';

class ReportGenerationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FieldDiscoveryService _fieldDiscoveryService = FieldDiscoveryService();

  Future<List<int>> generateReport({
    required ReportTemplate template,
    required DateTime startDate,
    required DateTime endDate,
    Map<String, dynamic>? additionalFilters,
  }) async {
    try {
      final excel = Excel.createExcel();
      final sheet = excel['Report'];

      await _generateReportTitle(sheet, template, startDate, endDate);
      await _generateNestedHeaders(sheet, template);
      await _populateData(
        sheet,
        template,
        startDate,
        endDate,
        additionalFilters,
      );
      await _applyFormatting(sheet, template);
      await _generateComputedColumns(sheet, template);

      excel.delete('Sheet1');
      return excel.save()!;
    } catch (e) {
      throw Exception('Failed to generate report: $e');
    }
  }

  Future<void> _generateReportTitle(
    Sheet sheet,
    ReportTemplate template,
    DateTime startDate,
    DateTime endDate,
  ) async {
    var titleCell = sheet.cell(CellIndex.indexByString("A1"));
    titleCell.value = TextCellValue(template.name);
    titleCell.cellStyle = CellStyle(
      bold: true,
      fontSize: 16,
      horizontalAlign: HorizontalAlign.Center,
    );

    if (template.description.isNotEmpty) {
      var subtitleCell = sheet.cell(CellIndex.indexByString("A2"));
      subtitleCell.value = TextCellValue(template.description);
      subtitleCell.cellStyle = CellStyle(
        fontSize: 12,
        horizontalAlign: HorizontalAlign.Center,
      );
    }

    var periodCell = sheet.cell(CellIndex.indexByString("A3"));
    periodCell.value = TextCellValue(
      'Period: ${_formatDate(startDate)} to ${_formatDate(endDate)}',
    );
    periodCell.cellStyle = CellStyle(
      fontSize: 10,
      horizontalAlign: HorizontalAlign.Center,
    );
  }

  Future<void> _generateNestedHeaders(
    Sheet sheet,
    ReportTemplate template,
  ) async {
    const int headerStartRow = 4;

    for (final headerLevel in template.headerLevels) {
      for (final cell in headerLevel.cells) {
        final excelCell = sheet.cell(
          CellIndex.indexByColumnRow(
            columnIndex: cell.columnIndex,
            rowIndex: headerStartRow + cell.rowIndex,
          ),
        );

        excelCell.value = TextCellValue(cell.text);
        excelCell.cellStyle = _createHeaderCellStyle(cell.style);

        if (cell.colspan > 1 || cell.rowspan > 1) {
          sheet.merge(
            CellIndex.indexByColumnRow(
              columnIndex: cell.columnIndex,
              rowIndex: headerStartRow + cell.rowIndex,
            ),
            CellIndex.indexByColumnRow(
              columnIndex: cell.columnIndex + cell.colspan - 1,
              rowIndex: headerStartRow + cell.rowIndex + cell.rowspan - 1,
            ),
          );
        }
      }
    }
  }

  Future<void> _populateData(
    Sheet sheet,
    ReportTemplate template,
    DateTime startDate,
    DateTime endDate,
    Map<String, dynamic>? additionalFilters,
  ) async {
    final dataMap = await _fetchAllData(
      template,
      startDate,
      endDate,
      additionalFilters,
    );
    final dataStartRow = _getDataStartRow(template);

    final primaryDataSource = _getPrimaryDataSource(template);
    final primaryData = dataMap[primaryDataSource] ?? [];

    for (int i = 0; i < primaryData.length; i++) {
      final record = primaryData[i];
      final rowIndex = dataStartRow + i;

      template.fieldMappings.forEach((cellId, fieldMapping) {
        if (fieldMapping.isVisible) {
          final columnIndex = fieldMapping.columnIndex;
          final value = _extractFieldValue(record, fieldMapping, dataMap);
          final formattedValue = _formatValue(value, fieldMapping.format);

          final excelCell = sheet.cell(
            CellIndex.indexByColumnRow(
              columnIndex: columnIndex,
              rowIndex: rowIndex,
            ),
          );

          if (value is num) {
            excelCell.value = DoubleCellValue(value.toDouble());
          } else if (value is bool) {
            excelCell.value = BoolCellValue(value);
          } else {
            excelCell.value = TextCellValue(formattedValue.toString());
          }

          excelCell.cellStyle = _createDataCellStyle(fieldMapping);
        }
      });
    }
  }

  Future<Map<String, List<Map<String, dynamic>>>> _fetchAllData(
    ReportTemplate template,
    DateTime startDate,
    DateTime endDate,
    Map<String, dynamic>? additionalFilters,
  ) async {
    final Map<String, List<Map<String, dynamic>>> dataMap = {};

    for (final dataSource in template.dataSources) {
      switch (dataSource.type) {
        case DataSourceType.substations:
          dataMap['substations'] = await _fetchSubstations(
            dataSource.filters,
            additionalFilters,
          );
          break;
        case DataSourceType.bays:
          dataMap['bays'] = await _fetchBays(
            dataSource.filters,
            additionalFilters,
          );
          break;
        case DataSourceType.equipments:
          dataMap['equipments'] = await _fetchEquipments(
            dataSource.filters,
            additionalFilters,
          );
          break;
        case DataSourceType.logsheetEntries:
          dataMap['logsheetEntries'] = await _fetchLogsheetEntries(
            startDate,
            endDate,
            dataSource.filters,
            additionalFilters,
          );
          break;
        case DataSourceType.assessments:
          dataMap['assessments'] = await _fetchAssessments(
            startDate,
            endDate,
            dataSource.filters,
            additionalFilters,
          );
          break;
        case DataSourceType.customCollections:
          dataMap[dataSource.id] = await _fetchCustomCollectionData(
            dataSource.id,
            dataSource.filters,
            additionalFilters,
          );
          break;
      }
    }

    return dataMap;
  }

  Future<List<Map<String, dynamic>>> _fetchSubstations(
    Map<String, dynamic> sourceFilters,
    Map<String, dynamic>? additionalFilters,
  ) async {
    Query query = _firestore.collection('substations');

    final allFilters = {...sourceFilters, ...?additionalFilters};
    allFilters.forEach((key, value) {
      if (value != null) {
        query = query.where(key, isEqualTo: value);
      }
    });

    final snapshot = await query.get();
    return snapshot.docs
        .map((doc) => {'id': doc.id, ...doc.data() as Map<String, dynamic>})
        .toList();
  }

  Future<List<Map<String, dynamic>>> _fetchBays(
    Map<String, dynamic> sourceFilters,
    Map<String, dynamic>? additionalFilters,
  ) async {
    Query query = _firestore.collection('bays');

    final allFilters = {...sourceFilters, ...?additionalFilters};
    allFilters.forEach((key, value) {
      if (value != null) {
        query = query.where(key, isEqualTo: value);
      }
    });

    final snapshot = await query.get();
    return snapshot.docs
        .map((doc) => {'id': doc.id, ...doc.data() as Map<String, dynamic>})
        .toList();
  }

  Future<List<Map<String, dynamic>>> _fetchEquipments(
    Map<String, dynamic> sourceFilters,
    Map<String, dynamic>? additionalFilters,
  ) async {
    Query query = _firestore.collection('equipments');

    final allFilters = {...sourceFilters, ...?additionalFilters};
    allFilters.forEach((key, value) {
      if (value != null) {
        query = query.where(key, isEqualTo: value);
      }
    });

    final snapshot = await query.get();
    return snapshot.docs
        .map((doc) => {'id': doc.id, ...doc.data() as Map<String, dynamic>})
        .toList();
  }

  Future<List<Map<String, dynamic>>> _fetchLogsheetEntries(
    DateTime startDate,
    DateTime endDate,
    Map<String, dynamic> sourceFilters,
    Map<String, dynamic>? additionalFilters,
  ) async {
    Query query = _firestore.collection('logsheetEntries');

    query = query
        .where(
          'readingTimestamp',
          isGreaterThanOrEqualTo: Timestamp.fromDate(startDate),
        )
        .where(
          'readingTimestamp',
          isLessThanOrEqualTo: Timestamp.fromDate(endDate),
        )
        .orderBy('readingTimestamp');

    final allFilters = {...sourceFilters, ...?additionalFilters};
    allFilters.forEach((key, value) {
      if (value != null && key != 'readingTimestamp') {
        query = query.where(key, isEqualTo: value);
      }
    });

    final snapshot = await query.get();
    return snapshot.docs
        .map((doc) => {'id': doc.id, ...doc.data() as Map<String, dynamic>})
        .toList();
  }

  Future<List<Map<String, dynamic>>> _fetchAssessments(
    DateTime startDate,
    DateTime endDate,
    Map<String, dynamic> sourceFilters,
    Map<String, dynamic>? additionalFilters,
  ) async {
    Query query = _firestore.collection('assessments');

    query = query
        .where(
          'assessmentTimestamp',
          isGreaterThanOrEqualTo: Timestamp.fromDate(startDate),
        )
        .where(
          'assessmentTimestamp',
          isLessThanOrEqualTo: Timestamp.fromDate(endDate),
        )
        .orderBy('assessmentTimestamp');

    final allFilters = {...sourceFilters, ...?additionalFilters};
    allFilters.forEach((key, value) {
      if (value != null && key != 'assessmentTimestamp') {
        query = query.where(key, isEqualTo: value);
      }
    });

    final snapshot = await query.get();
    return snapshot.docs
        .map((doc) => {'id': doc.id, ...doc.data() as Map<String, dynamic>})
        .toList();
  }

  Future<List<Map<String, dynamic>>> _fetchCustomCollectionData(
    String collectionName,
    Map<String, dynamic> sourceFilters,
    Map<String, dynamic>? additionalFilters,
  ) async {
    Query query = _firestore.collection(collectionName);

    final allFilters = {...sourceFilters, ...?additionalFilters};
    allFilters.forEach((key, value) {
      if (value != null) {
        query = query.where(key, isEqualTo: value);
      }
    });

    final snapshot = await query.get();
    return snapshot.docs
        .map((doc) => {'id': doc.id, ...doc.data() as Map<String, dynamic>})
        .toList();
  }

  dynamic _extractFieldValue(
    Map<String, dynamic> record,
    DynamicFieldMapping fieldMapping,
    Map<String, List<Map<String, dynamic>>> dataMap,
  ) {
    if (fieldMapping.origin == FieldOrigin.computed) {
      return _evaluateFormula(fieldMapping.formula!, record, dataMap);
    }

    return _getNestedValue(record, fieldMapping.sourcePath);
  }

  dynamic _getNestedValue(Map<String, dynamic> data, String path) {
    final parts = path.split('.');
    dynamic value = data;

    for (final part in parts) {
      if (value is Map<String, dynamic>) {
        value = value[part];
      } else {
        return null;
      }
    }

    return value;
  }

  dynamic _evaluateFormula(
    String formula,
    Map<String, dynamic> record,
    Map<String, List<Map<String, dynamic>>> dataMap,
  ) {
    try {
      if (formula.toUpperCase().contains('SUM(')) {
        final field = _extractFormulaField(formula);
        final values = _getAllValuesForField(field, dataMap);
        return values.fold<double>(
          0.0,
          (sum, val) => sum + ((val as num?)?.toDouble() ?? 0.0),
        );
      }

      if (formula.toUpperCase().contains('COUNT(')) {
        final field = _extractFormulaField(formula);
        return _countNonNullValues(field, dataMap);
      }

      if (formula.toUpperCase().contains('AVG(')) {
        final field = _extractFormulaField(formula);
        final values = _getAllValuesForField(
          field,
          dataMap,
        ).where((v) => v is num).toList();
        if (values.isEmpty) return 0.0;
        final sum = values.fold<double>(
          0.0,
          (s, val) => s + (val as num).toDouble(),
        );
        return sum / values.length;
      }

      if (formula.toUpperCase().contains('MAX(')) {
        final field = _extractFormulaField(formula);
        final values = _getAllValuesForField(
          field,
          dataMap,
        ).where((v) => v is num).toList();
        if (values.isEmpty) return 0.0;
        return values
            .map((v) => (v as num).toDouble())
            .reduce((a, b) => a > b ? a : b);
      }

      if (formula.toUpperCase().contains('MIN(')) {
        final field = _extractFormulaField(formula);
        final values = _getAllValuesForField(
          field,
          dataMap,
        ).where((v) => v is num).toList();
        if (values.isEmpty) return 0.0;
        return values
            .map((v) => (v as num).toDouble())
            .reduce((a, b) => a < b ? a : b);
      }

      return formula;
    } catch (e) {
      return 'ERROR: $e';
    }
  }

  String _extractFormulaField(String formula) {
    final match = RegExp(r'\(([^)]+)\)').firstMatch(formula);
    return match?.group(1) ?? '';
  }

  List<dynamic> _getAllValuesForField(
    String field,
    Map<String, List<Map<String, dynamic>>> dataMap,
  ) {
    final List<dynamic> values = [];

    dataMap.forEach((sourceId, records) {
      for (final record in records) {
        final value = _getNestedValue(record, field);
        if (value != null) values.add(value);
      }
    });

    return values;
  }

  int _countNonNullValues(
    String field,
    Map<String, List<Map<String, dynamic>>> dataMap,
  ) {
    return _getAllValuesForField(
      field,
      dataMap,
    ).where((value) => value != null).length;
  }

  Future<void> _applyFormatting(Sheet sheet, ReportTemplate template) async {
    // Apply global formatting based on template settings
  }

  Future<void> _generateComputedColumns(
    Sheet sheet,
    ReportTemplate template,
  ) async {
    // Generate computed columns with Excel formulas
  }

  CellStyle _createHeaderCellStyle(HeaderCellStyle style) {
    return CellStyle(
      bold: style.bold,
      italic: style.italic,
      fontSize: style.fontSize.toInt(),
      fontFamily: getFontFamily(style.fontFamily as FontFamily),
      horizontalAlign: _getHorizontalAlignment(style.alignment),
      backgroundColorHex: ExcelColor.fromHexString(style.backgroundColor),
      fontColorHex: ExcelColor.fromHexString(style.textColor),
    );
  }

  CellStyle _createDataCellStyle(DynamicFieldMapping fieldMapping) {
    return CellStyle(
      fontSize: 10,
      fontFamily: getFontFamily('Arial' as FontFamily),
      horizontalAlign: HorizontalAlign.Left,
    );
  }

  HorizontalAlign _getHorizontalAlignment(String alignment) {
    switch (alignment.toLowerCase()) {
      case 'left':
        return HorizontalAlign.Left;
      case 'center':
        return HorizontalAlign.Center;
      case 'right':
        return HorizontalAlign.Right;
      default:
        return HorizontalAlign.Left;
    }
  }

  String _formatValue(dynamic value, String format) {
    if (value == null) return '';

    if (value is num) {
      if (format.contains('%')) {
        return '${(value * 100).toStringAsFixed(1)}%';
      } else if (format.contains(',')) {
        return value.toString().replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]},',
        );
      } else if (format.contains('.')) {
        final decimals = format.split('.')[1].length;
        return value.toStringAsFixed(decimals);
      }
      return value.toString();
    }

    if (value is DateTime) {
      if (format.contains('yyyy')) {
        return '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';
      }
      return value.toString();
    }

    return value.toString();
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  int _getDataStartRow(ReportTemplate template) {
    return 4 + template.headerLevels.length;
  }

  String _getPrimaryDataSource(ReportTemplate template) {
    return template.dataSources.isNotEmpty ? template.dataSources.first.id : '';
  }
}
