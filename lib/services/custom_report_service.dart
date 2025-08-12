// lib/services/custom_report_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:excel/excel.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:csv/csv.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class CustomReportService {
  static const Map<String, String> collectionMap = {
    'energy': 'bayEnergyData',
    'bays': 'bays',
    'tripping': 'trippingShutdownEntries',
    'operations': 'logsheetEntries',
    'equipment': 'equipmentInstances',
    'assessments': 'assessments',
  };

  // Generate field catalog from your models
  static Map<String, List<ReportField>> getFieldCatalog() {
    return {
      'bays': [
        ReportField(
          name: 'name',
          displayName: 'Bay Name',
          type: 'string',
          path: 'name',
        ),
        ReportField(
          name: 'substationId',
          displayName: 'Substation ID',
          type: 'string',
          path: 'substationId',
        ),
        ReportField(
          name: 'voltageLevel',
          displayName: 'Voltage Level',
          type: 'string',
          path: 'voltageLevel',
        ),
        ReportField(
          name: 'capacity',
          displayName: 'Capacity (MVA)',
          type: 'number',
          path: 'capacity',
        ),
        ReportField(
          name: 'bayType',
          displayName: 'Bay Type',
          type: 'string',
          path: 'bayType',
        ),
        ReportField(
          name: 'commissioningDate',
          displayName: 'Commissioning Date',
          type: 'date',
          path: 'commissioningDate',
        ),
        ReportField(
          name: 'multiplyingFactor',
          displayName: 'Multiplying Factor',
          type: 'number',
          path: 'multiplyingFactor',
        ),
      ],
      'energy': [
        ReportField(
          name: 'importConsumed',
          displayName: 'Import Energy (kWh)',
          type: 'number',
          path: 'importConsumed',
        ),
        ReportField(
          name: 'exportConsumed',
          displayName: 'Export Energy (kWh)',
          type: 'number',
          path: 'exportConsumed',
        ),
        ReportField(
          name: 'importReading',
          displayName: 'Import Reading',
          type: 'number',
          path: 'importReading',
        ),
        ReportField(
          name: 'exportReading',
          displayName: 'Export Reading',
          type: 'number',
          path: 'exportReading',
        ),
        ReportField(
          name: 'readingTimestamp',
          displayName: 'Reading Time',
          type: 'datetime',
          path: 'readingTimestamp',
        ),
        ReportField(
          name: 'multiplierFactor',
          displayName: 'Multiplier Factor',
          type: 'number',
          path: 'multiplierFactor',
        ),
        ReportField(
          name: 'adjustedImportConsumed',
          displayName: 'Adjusted Import',
          type: 'number',
          path: 'adjustedImportConsumed',
        ),
        ReportField(
          name: 'adjustedExportConsumed',
          displayName: 'Adjusted Export',
          type: 'number',
          path: 'adjustedExportConsumed',
        ),
      ],
      'tripping': [
        ReportField(
          name: 'startTime',
          displayName: 'Trip Start',
          type: 'datetime',
          path: 'startTime',
        ),
        ReportField(
          name: 'endTime',
          displayName: 'Trip End',
          type: 'datetime',
          path: 'endTime',
        ),
        ReportField(
          name: 'eventType',
          displayName: 'Event Type',
          type: 'string',
          path: 'eventType',
        ),
        ReportField(
          name: 'flagsCause',
          displayName: 'Cause',
          type: 'string',
          path: 'flagsCause',
        ),
        ReportField(
          name: 'shutdownType',
          displayName: 'Shutdown Type',
          type: 'string',
          path: 'shutdownType',
        ),
        ReportField(
          name: 'status',
          displayName: 'Status',
          type: 'string',
          path: 'status',
        ),
        ReportField(
          name: 'distance',
          displayName: 'Distance (km)',
          type: 'number',
          path: 'distance',
        ),
      ],
      'operations': [
        ReportField(
          name: 'readingTimestamp',
          displayName: 'Operation Time',
          type: 'datetime',
          path: 'readingTimestamp',
        ),
        ReportField(
          name: 'recordedBy',
          displayName: 'Recorded By',
          type: 'string',
          path: 'recordedBy',
        ),
        ReportField(
          name: 'frequency',
          displayName: 'Frequency',
          type: 'string',
          path: 'frequency',
        ),
        ReportField(
          name: 'readingHour',
          displayName: 'Reading Hour',
          type: 'number',
          path: 'readingHour',
        ),
      ],
      'equipment': [
        ReportField(
          name: 'type',
          displayName: 'Equipment Type',
          type: 'string',
          path: 'type',
        ),
        ReportField(
          name: 'manufacturer',
          displayName: 'Manufacturer',
          type: 'string',
          path: 'manufacturer',
        ),
        ReportField(
          name: 'serialNumber',
          displayName: 'Serial Number',
          type: 'string',
          path: 'serialNumber',
        ),
        ReportField(
          name: 'rating',
          displayName: 'Rating',
          type: 'string',
          path: 'rating',
        ),
        ReportField(
          name: 'installationDate',
          displayName: 'Installation Date',
          type: 'date',
          path: 'installationDate',
        ),
      ],
      'assessments': [
        ReportField(
          name: 'assessmentTimestamp',
          displayName: 'Assessment Date',
          type: 'datetime',
          path: 'assessmentTimestamp',
        ),
        ReportField(
          name: 'importAdjustment',
          displayName: 'Import Adjustment',
          type: 'number',
          path: 'importAdjustment',
        ),
        ReportField(
          name: 'exportAdjustment',
          displayName: 'Export Adjustment',
          type: 'number',
          path: 'exportAdjustment',
        ),
        ReportField(
          name: 'reason',
          displayName: 'Adjustment Reason',
          type: 'string',
          path: 'reason',
        ),
        ReportField(
          name: 'createdBy',
          displayName: 'Created By',
          type: 'string',
          path: 'createdBy',
        ),
      ],
    };
  }

  // Execute custom query with nested columns
  static Future<List<Map<String, dynamic>>> executeCustomQuery({
    required List<CustomColumn> columns,
    required List<String> dataSources,
    required Map<String, dynamic> filters,
    required DateTime startDate,
    required DateTime endDate,
    String? substationId,
  }) async {
    try {
      // 1. Build base queries per data source
      Map<String, List<DocumentSnapshot>> rawData = {};

      for (String source in dataSources) {
        final query = _buildBaseQuery(
          source,
          startDate,
          endDate,
          filters,
          substationId,
        );
        final querySnapshot = await query.get();
        rawData[source] = querySnapshot.docs;
      }

      // 2. Process and join data based on column configuration
      return _processAndJoinData(rawData, columns, filters);
    } catch (e) {
      print('Error executing custom query: $e');
      return [];
    }
  }

  static Query _buildBaseQuery(
    String source,
    DateTime startDate,
    DateTime endDate,
    Map<String, dynamic> filters,
    String? substationId,
  ) {
    Query query = FirebaseFirestore.instance.collection(collectionMap[source]!);

    // Apply substation filter if provided
    if (substationId != null) {
      switch (source) {
        case 'bays':
          query = query.where('substationId', isEqualTo: substationId);
          break;
        case 'energy':
        case 'operations':
          // These might need to be joined with bays first
          break;
      }
    }

    // Apply date filters based on source
    switch (source) {
      case 'energy':
      case 'operations':
        query = query
            .where(
              'readingTimestamp',
              isGreaterThanOrEqualTo: Timestamp.fromDate(startDate),
            )
            .where(
              'readingTimestamp',
              isLessThanOrEqualTo: Timestamp.fromDate(endDate),
            )
            .orderBy('readingTimestamp', descending: false);
        break;
      case 'tripping':
        query = query
            .where(
              'startTime',
              isGreaterThanOrEqualTo: Timestamp.fromDate(startDate),
            )
            .where(
              'startTime',
              isLessThanOrEqualTo: Timestamp.fromDate(endDate),
            )
            .orderBy('startTime', descending: false);
        break;
      case 'assessments':
        query = query
            .where(
              'assessmentTimestamp',
              isGreaterThanOrEqualTo: Timestamp.fromDate(startDate),
            )
            .where(
              'assessmentTimestamp',
              isLessThanOrEqualTo: Timestamp.fromDate(endDate),
            )
            .orderBy('assessmentTimestamp', descending: false);
        break;
    }

    // Apply custom filters
    filters.forEach((key, value) {
      if (key.startsWith('$source.') &&
          value != null &&
          value.toString().isNotEmpty) {
        String field = key.replaceFirst('$source.', '');
        if (value is List) {
          query = query.where(field, whereIn: value);
        } else {
          query = query.where(field, isEqualTo: value);
        }
      }
    });

    return query;
  }

  static List<Map<String, dynamic>> _processAndJoinData(
    Map<String, List<DocumentSnapshot>> rawData,
    List<CustomColumn> columns,
    Map<String, dynamic> filters,
  ) {
    List<Map<String, dynamic>> results = [];

    // Determine primary data source (first non-group column's source)
    String? primarySource = _findPrimaryDataSource(columns);
    if (primarySource == null || !rawData.containsKey(primarySource)) {
      return results;
    }

    // Process each document from primary source
    for (DocumentSnapshot primaryDoc in rawData[primarySource]!) {
      Map<String, dynamic> row = {};

      // Process each column (including nested)
      for (CustomColumn column in columns) {
        _processColumnRecursive(column, row, primaryDoc, rawData);
      }

      results.add(row);
    }

    return results;
  }

  static void _processColumnRecursive(
    CustomColumn column,
    Map<String, dynamic> row,
    DocumentSnapshot primaryDoc,
    Map<String, List<DocumentSnapshot>> allData,
  ) {
    if (column.isGroupHeader && column.subColumns != null) {
      // Process sub-columns
      for (CustomColumn subColumn in column.subColumns!) {
        _processColumnRecursive(subColumn, row, primaryDoc, allData);
      }
    } else {
      // Process data column
      dynamic value = _extractColumnValue(column, primaryDoc, allData);
      row[_getColumnKey(column)] = value;
    }
  }

  static String _getColumnKey(CustomColumn column) {
    if (column.parentColumn != null) {
      return '${column.parentColumn!.header}_${column.header}';
    }
    return column.header;
  }

  static String? _findPrimaryDataSource(List<CustomColumn> columns) {
    for (CustomColumn column in columns) {
      if (column.isGroupHeader && column.subColumns != null) {
        String? source = _findPrimaryDataSource(column.subColumns!);
        if (source != null) return source;
      } else if (!column.isGroupHeader && column.dataSource.isNotEmpty) {
        return column.dataSource;
      }
    }
    return null;
  }

  static dynamic _extractColumnValue(
    CustomColumn column,
    DocumentSnapshot primaryDoc,
    Map<String, List<DocumentSnapshot>> allData,
  ) {
    switch (column.dataType) {
      case 'computed':
        return _executeFormula(column.formula ?? '', primaryDoc, allData);
      case 'aggregated':
        return _executeAggregation(column, allData);
      default:
        return _extractDirectField(column, primaryDoc, allData);
    }
  }

  // FIXED: Add the missing _executeAggregation method
  static dynamic _executeAggregation(
    CustomColumn column,
    Map<String, List<DocumentSnapshot>> allData,
  ) {
    try {
      // Handle aggregation based on column configuration
      if (column.formula != null && column.formula!.isNotEmpty) {
        // Use formula if provided
        return _executeFormula(column.formula!, null, allData);
      }

      // Default aggregation based on fieldPath
      if (column.fieldPath != null && column.fieldPath!.contains('.')) {
        List<String> parts = column.fieldPath!.split('.');
        if (parts.length >= 2) {
          String source = parts[0];
          String field = parts[1];

          // Default to SUM for numeric fields, COUNT for others
          List<DocumentSnapshot> docs = allData[source] ?? [];
          if (docs.isEmpty) return 0;

          // Check if field is numeric
          final firstDoc = docs.first.data() as Map<String, dynamic>?;
          if (firstDoc != null && firstDoc[field] is num) {
            // Sum numeric values
            num sum = 0;
            for (DocumentSnapshot doc in docs) {
              final data = doc.data() as Map<String, dynamic>?;
              if (data != null && data[field] is num) {
                sum += data[field];
              }
            }
            return sum;
          } else {
            // Count non-numeric values
            return docs.length;
          }
        }
      }

      return 0;
    } catch (e) {
      print('Error in _executeAggregation: $e');
      return 'Error';
    }
  }

  static dynamic _executeFormula(
    String formula,
    DocumentSnapshot? primaryDoc, // FIXED: Made nullable
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

      // Handle duration calculation for tripping (only if primaryDoc is not null)
      if (primaryDoc != null &&
          (formula.contains('duration') ||
              formula.contains('endTime - startTime'))) {
        final data = primaryDoc.data() as Map<String, dynamic>?;
        if (data != null &&
            data['startTime'] != null &&
            data['endTime'] != null) {
          Timestamp startTime = data['startTime'];
          Timestamp endTime = data['endTime'];
          return endTime.millisecondsSinceEpoch -
              startTime.millisecondsSinceEpoch;
        }
      }

      return formula; // Return formula as-is if not recognized
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
    for (DocumentSnapshot doc in allData[source] ?? []) {
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

  static dynamic _extractDirectField(
    CustomColumn column,
    DocumentSnapshot primaryDoc,
    Map<String, List<DocumentSnapshot>> allData,
  ) {
    final data = primaryDoc.data() as Map<String, dynamic>?;
    if (data == null) return '';

    // Handle different field paths
    if (column.fieldPath != null && column.fieldPath!.isNotEmpty) {
      return _getNestedValue(data, column.fieldPath!);
    }

    return data[column.header] ?? '';
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

  // Export to Excel with nested headers
  static Future<void> exportToExcel({
    required List<Map<String, dynamic>> data,
    required List<CustomColumn> columns,
    required String reportTitle,
    String? reportSubtitle,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      var excel = Excel.createExcel();
      Sheet sheet = excel['Report'];

      int currentRow = 0;

      // Add report title
      if (reportTitle.isNotEmpty) {
        sheet
            .cell(
              CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: currentRow),
            )
            .value = TextCellValue(
          reportTitle,
        );
        sheet.merge(
          CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: currentRow),
          CellIndex.indexByColumnRow(
            columnIndex: _getFlatColumnCount(columns) - 1,
            rowIndex: currentRow,
          ),
        );
        currentRow += 1;
      }

      // Add subtitle
      if (reportSubtitle != null && reportSubtitle.isNotEmpty) {
        sheet
            .cell(
              CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: currentRow),
            )
            .value = TextCellValue(
          reportSubtitle,
        );
        currentRow += 1;
      }

      // Add metadata
      if (metadata != null) {
        metadata.forEach((key, value) {
          sheet
              .cell(
                CellIndex.indexByColumnRow(
                  columnIndex: 0,
                  rowIndex: currentRow,
                ),
              )
              .value = TextCellValue(
            '$key: $value',
          );
          currentRow += 1;
        });
        currentRow += 1; // Extra space
      }

      // Add nested headers
      int headerStartRow = currentRow;
      int maxDepth = _calculateMaxDepth(columns);

      for (int level = 0; level < maxDepth; level++) {
        int colIndex = 0;
        for (CustomColumn column in columns) {
          colIndex = _writeHeaderLevel(
            sheet,
            column,
            level,
            headerStartRow + level,
            colIndex,
          );
        }
      }

      currentRow = headerStartRow + maxDepth;

      // Add data rows
      for (int i = 0; i < data.length; i++) {
        Map<String, dynamic> row = data[i];
        int colIndex = 0;

        for (CustomColumn column in columns) {
          colIndex = _writeDataCells(sheet, column, row, currentRow, colIndex);
        }
        currentRow++;
      }

      // Save and share file
      final directory = await getApplicationDocumentsDirectory();
      final file = File(
        '${directory.path}/custom_report_${DateTime.now().millisecondsSinceEpoch}.xlsx',
      );
      final bytes = excel.save();
      if (bytes != null) {
        await file.writeAsBytes(bytes);
        await Share.shareXFiles([XFile(file.path)], text: 'Custom Report');
      }
    } catch (e) {
      print('Error exporting to Excel: $e');
      throw Exception('Failed to export Excel: $e');
    }
  }

  static int _writeHeaderLevel(
    Sheet sheet,
    CustomColumn column,
    int targetLevel,
    int row,
    int startCol,
  ) {
    if (column.isGroupHeader && column.subColumns != null) {
      if (column.level == targetLevel) {
        int colspan = _countDataColumnsInGroup(column);
        sheet
            .cell(
              CellIndex.indexByColumnRow(columnIndex: startCol, rowIndex: row),
            )
            .value = TextCellValue(
          column.header,
        );
        if (colspan > 1) {
          sheet.merge(
            CellIndex.indexByColumnRow(columnIndex: startCol, rowIndex: row),
            CellIndex.indexByColumnRow(
              columnIndex: startCol + colspan - 1,
              rowIndex: row,
            ),
          );
        }
      }

      int colIndex = startCol;
      for (CustomColumn subColumn in column.subColumns!) {
        colIndex = _writeHeaderLevel(
          sheet,
          subColumn,
          targetLevel,
          row,
          colIndex,
        );
      }
      return colIndex;
    } else {
      if (column.level == targetLevel) {
        sheet
            .cell(
              CellIndex.indexByColumnRow(columnIndex: startCol, rowIndex: row),
            )
            .value = TextCellValue(
          column.header,
        );
      }
      return startCol + 1;
    }
  }

  static int _writeDataCells(
    Sheet sheet,
    CustomColumn column,
    Map<String, dynamic> data,
    int row,
    int startCol,
  ) {
    if (column.isGroupHeader && column.subColumns != null) {
      int colIndex = startCol;
      for (CustomColumn subColumn in column.subColumns!) {
        colIndex = _writeDataCells(sheet, subColumn, data, row, colIndex);
      }
      return colIndex;
    } else {
      String key = _getColumnKey(column);
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

  static int _getFlatColumnCount(List<CustomColumn> columns) {
    int count = 0;
    for (CustomColumn column in columns) {
      if (column.isGroupHeader && column.subColumns != null) {
        count += _countDataColumnsInGroup(column);
      } else {
        count += 1;
      }
    }
    return count;
  }

  static int _countDataColumnsInGroup(CustomColumn groupColumn) {
    if (groupColumn.subColumns == null || groupColumn.subColumns!.isEmpty) {
      return 1;
    }

    int count = 0;
    for (CustomColumn subColumn in groupColumn.subColumns!) {
      if (subColumn.isGroupHeader) {
        count += _countDataColumnsInGroup(subColumn);
      } else {
        count += 1;
      }
    }
    return count;
  }

  static int _calculateMaxDepth(List<CustomColumn> columns) {
    int maxDepth = 1;
    for (CustomColumn column in columns) {
      int depth = _calculateColumnDepth(column);
      if (depth > maxDepth) maxDepth = depth;
    }
    return maxDepth;
  }

  static int _calculateColumnDepth(CustomColumn column) {
    if (column.subColumns == null || column.subColumns!.isEmpty) {
      return 1;
    }

    int maxSubDepth = 0;
    for (CustomColumn subColumn in column.subColumns!) {
      int subDepth = _calculateColumnDepth(subColumn);
      if (subDepth > maxSubDepth) maxSubDepth = subDepth;
    }

    return 1 + maxSubDepth;
  }

  // Export to PDF with nested headers
  static Future<void> exportToPDF({
    required List<Map<String, dynamic>> data,
    required List<CustomColumn> columns,
    required String reportTitle,
    String? reportSubtitle,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final pdf = pw.Document();

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4.landscape,
          build: (pw.Context context) {
            List<pw.Widget> widgets = [];

            // Title
            if (reportTitle.isNotEmpty) {
              widgets.add(
                pw.Center(
                  child: pw.Text(
                    reportTitle,
                    style: pw.TextStyle(
                      fontSize: 18,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),
              );
              widgets.add(pw.SizedBox(height: 10));
            }

            // Subtitle
            if (reportSubtitle != null && reportSubtitle.isNotEmpty) {
              widgets.add(
                pw.Center(
                  child: pw.Text(
                    reportSubtitle,
                    style: pw.TextStyle(fontSize: 14),
                  ),
                ),
              );
              widgets.add(pw.SizedBox(height: 10));
            }

            // Table with nested headers
            widgets.add(_buildPDFTable(data, columns));

            return widgets;
          },
        ),
      );

      final directory = await getApplicationDocumentsDirectory();
      final file = File(
        '${directory.path}/custom_report_${DateTime.now().millisecondsSinceEpoch}.pdf',
      );
      await file.writeAsBytes(await pdf.save());
      await Share.shareXFiles([XFile(file.path)], text: 'Custom Report PDF');
    } catch (e) {
      print('Error exporting to PDF: $e');
      throw Exception('Failed to export PDF: $e');
    }
  }

  static pw.Widget _buildPDFTable(
    List<Map<String, dynamic>> data,
    List<CustomColumn> columns,
  ) {
    // Simplified PDF table - you can enhance this for nested headers
    List<String> headers = _getFlatHeaders(columns);

    return pw.Table(
      border: pw.TableBorder.all(),
      children: [
        // Header row
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey200),
          children: headers
              .map(
                (header) => pw.Padding(
                  padding: const pw.EdgeInsets.all(4),
                  child: pw.Text(
                    header,
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  ),
                ),
              )
              .toList(),
        ),
        // Data rows
        ...data
            .take(100)
            .map(
              (row) => // Limit for PDF performance
              pw.TableRow(
                children: headers
                    .map(
                      (header) => pw.Padding(
                        padding: const pw.EdgeInsets.all(4),
                        child: pw.Text(row[header]?.toString() ?? ''),
                      ),
                    )
                    .toList(),
              ),
            )
            .toList(),
      ],
    );
  }

  static List<String> _getFlatHeaders(List<CustomColumn> columns) {
    List<String> headers = [];
    for (CustomColumn column in columns) {
      headers.addAll(_getFlatHeadersRecursive(column));
    }
    return headers;
  }

  static List<String> _getFlatHeadersRecursive(CustomColumn column) {
    List<String> headers = [];
    if (column.isGroupHeader && column.subColumns != null) {
      for (CustomColumn subColumn in column.subColumns!) {
        headers.addAll(_getFlatHeadersRecursive(subColumn));
      }
    } else {
      headers.add(_getColumnKey(column));
    }
    return headers;
  }
}

// Supporting models
class ReportField {
  final String name;
  final String displayName;
  final String type;
  final String path;

  ReportField({
    required this.name,
    required this.displayName,
    required this.type,
    required this.path,
  });
}

class CustomColumn {
  String id;
  String header;
  String dataType;
  String dataSource;
  String? fieldPath;
  int? width;
  String? formula;

  // Nested header support
  List<CustomColumn>? subColumns;
  CustomColumn? parentColumn;
  int level;
  bool isGroupHeader;

  CustomColumn({
    required this.id,
    required this.header,
    required this.dataType,
    required this.dataSource,
    this.fieldPath,
    this.width,
    this.formula,
    this.subColumns,
    this.parentColumn,
    this.level = 0,
    this.isGroupHeader = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'header': header,
      'dataType': dataType,
      'dataSource': dataSource,
      'fieldPath': fieldPath,
      'width': width,
      'formula': formula,
      'level': level,
      'isGroupHeader': isGroupHeader,
      'subColumns': subColumns?.map((col) => col.toJson()).toList(),
    };
  }

  factory CustomColumn.fromJson(Map<String, dynamic> json) {
    final column = CustomColumn(
      id: json['id'] ?? '',
      header: json['header'] ?? '',
      dataType: json['dataType'] ?? 'text',
      dataSource: json['dataSource'] ?? '',
      fieldPath: json['fieldPath'],
      width: json['width'],
      formula: json['formula'],
      level: json['level'] ?? 0,
      isGroupHeader: json['isGroupHeader'] ?? false,
    );

    if (json['subColumns'] != null) {
      column.subColumns = (json['subColumns'] as List)
          .map((subJson) => CustomColumn.fromJson(subJson))
          .toList();

      // Set parent references
      for (var subColumn in column.subColumns!) {
        subColumn.parentColumn = column;
      }
    }

    return column;
  }
}
