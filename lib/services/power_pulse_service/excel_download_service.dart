import 'dart:io';
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:open_filex/open_filex.dart'; // Changed from open_file to open_filex

class ExcelDownloadService {
  /// Creates and saves an Excel file from the given data map using `excel` package.
  ///
  /// The input map should contain:
  /// - 'rows': int, number of rows
  /// - 'columns': int, number of columns
  /// - 'title': String, title to use for the sheet and file
  /// - 'data': List<List<dynamic>>, nested List of cell content per row
  /// - 'merged': List<Map<String,dynamic>>, each map with keys 'row1','col1','row2','col2' for merged cells
  ///
  /// Returns the file path if saved successfully (on mobile/desktop), or null on web.
  static Future<String?> createAndDownloadExcel(
    Map<String, dynamic> excelData,
  ) async {
    try {
      final int rows = excelData['rows'] ?? 0;
      final int columns = excelData['columns'] ?? 0;
      final String title = excelData['title'] ?? 'ExcelTable';
      final List<dynamic> data = excelData['data'] ?? [];
      final List<dynamic> mergedRanges = excelData['merged'] ?? [];

      if (rows == 0 || columns == 0) {
        throw Exception('Invalid table dimensions: ${rows}x${columns}');
      }

      // Create a new Excel document
      final excel = Excel.createExcel();

      // Clean sheet name (Excel has naming restrictions)
      String sheetName = _sanitizeSheetName(title);

      // Rename the default sheet
      excel.rename('Sheet1', sheetName);
      final Sheet sheet = excel[sheetName];

      // Write data to cells
      for (int r = 0; r < rows; r++) {
        for (int c = 0; c < columns; c++) {
          String cellValue = '';

          // Get cell value if it exists in data
          if (r < data.length && c < (data[r] as List).length) {
            cellValue = (data[r] as List)[c]?.toString() ?? '';
          }

          // Set cell value
          final cell = sheet.cell(
            CellIndex.indexByColumnRow(columnIndex: c, rowIndex: r),
          );
          cell.value = TextCellValue(cellValue);

          // Apply basic styling
          if (r == 0) {
            // Header row styling
            cell.cellStyle = CellStyle(
              bold: true,
              backgroundColorHex:
                  ExcelColor.grey400, // Use predefined Excel colors
            );
          }
        }
      }

      // Apply merged cell ranges
      for (final rangeMap in mergedRanges) {
        if (rangeMap is Map<String, dynamic>) {
          try {
            int row1 = rangeMap['row1'] ?? 0;
            int col1 = rangeMap['col1'] ?? 0;
            int row2 = rangeMap['row2'] ?? 0;
            int col2 = rangeMap['col2'] ?? 0;

            // Validate merge range
            if (row1 >= 0 &&
                col1 >= 0 &&
                row2 >= row1 &&
                col2 >= col1 &&
                row2 < rows &&
                col2 < columns) {
              // Create merge using CellIndex
              final startCell = CellIndex.indexByColumnRow(
                columnIndex: col1,
                rowIndex: row1,
              );
              final endCell = CellIndex.indexByColumnRow(
                columnIndex: col2,
                rowIndex: row2,
              );

              sheet.merge(startCell, endCell);
            }
          } catch (e) {
            print('Error merging cells: $e');
          }
        }
      }

      // Encode the Excel file to bytes
      var fileBytes = excel.encode();
      if (fileBytes == null) {
        throw Exception('Failed to encode Excel file');
      }

      if (kIsWeb) {
        // Web download requires separate implementation with dart:html
        return await _downloadOnWeb(fileBytes, title);
      } else {
        // Mobile/Desktop save
        return await _saveOnMobile(fileBytes, title);
      }
    } catch (e) {
      print('Error creating Excel file: $e');
      throw Exception('Failed to create Excel file: $e');
    }
  }

  /// Save Excel file on mobile/desktop platforms
  static Future<String?> _saveOnMobile(
    List<int> fileBytes,
    String title,
  ) async {
    try {
      // Request storage permission on Android
      if (Platform.isAndroid) {
        var status = await Permission.storage.status;
        if (!status.isGranted) {
          status = await Permission.storage.request();
          if (!status.isGranted) {
            // Try with manage external storage for Android 11+
            if (await Permission.manageExternalStorage.isGranted == false) {
              await Permission.manageExternalStorage.request();
            }
          }
        }
      }

      // Get appropriate directory
      Directory? directory;
      if (Platform.isAndroid) {
        directory = await getExternalStorageDirectory();
        if (directory != null) {
          // Create Downloads subfolder
          directory = Directory('${directory.path}/Download');
          if (!await directory.exists()) {
            await directory.create(recursive: true);
          }
        }
      } else {
        directory = await getApplicationDocumentsDirectory();
      }

      directory ??= await getApplicationDocumentsDirectory();

      final fileName =
          '${_sanitizeFileName(title)}_${DateTime.now().millisecondsSinceEpoch}.xlsx';
      final filePath = '${directory.path}/$fileName';

      final file = File(filePath);
      await file.writeAsBytes(fileBytes, flush: true);

      print('Excel file saved at: $filePath');
      return filePath;
    } catch (e) {
      throw Exception('Failed to save Excel file: $e');
    }
  }

  /// Web platform download (requires separate web implementation)
  static Future<String?> _downloadOnWeb(
    List<int> fileBytes,
    String title,
  ) async {
    // This would require dart:html which should be imported conditionally for web
    // For now, return null - implement web download separately if needed
    return null;
  }

  /// Sanitize sheet name to comply with Excel requirements
  static String _sanitizeSheetName(String name) {
    // Excel sheet names can't contain certain characters and max 31 chars
    // Fixed regex pattern - removed excessive escaping
    String sanitized = name.replaceAll(RegExp(r'[<>:"/\\|?*]'), '').trim();

    if (sanitized.isEmpty) {
      sanitized = 'Sheet';
    }

    return sanitized.length > 31 ? sanitized.substring(0, 31) : sanitized;
  }

  /// Sanitize file name for cross-platform compatibility
  static String _sanitizeFileName(String name) {
    return name
        .replaceAll(RegExp(r'[<>:"/\\|?*]'), '_')
        .replaceAll(' ', '_')
        .trim();
  }

  /// Convert column and row indices to Excel cell name (A1, B2, etc.)
  static String _cellName(int col, int row) {
    String columnLetter = '';
    int tempCol = col + 1; // Convert to 1-based

    while (tempCol > 0) {
      int remainder = (tempCol - 1) % 26;
      columnLetter = String.fromCharCode(65 + remainder) + columnLetter;
      tempCol = (tempCol - remainder - 1) ~/ 26;
    }

    return '$columnLetter${row + 1}'; // Convert to 1-based
  }

  /// Open the saved Excel file (mobile/desktop only)
  static Future<void> openExcelFile(String filePath) async {
    if (!kIsWeb && File(filePath).existsSync()) {
      try {
        // Changed from OpenFile.open to OpenFilex.open
        await OpenFilex.open(filePath);
      } catch (e) {
        throw Exception('Failed to open Excel file: $e');
      }
    }
  }

  /// Check if the app has storage permission (Android)
  static Future<bool> hasStoragePermission() async {
    if (!Platform.isAndroid) return true;

    var status = await Permission.storage.status;
    if (status != PermissionStatus.granted) {
      status = await Permission.storage.request();
    }

    return status == PermissionStatus.granted;
  }
}
