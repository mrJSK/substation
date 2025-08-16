import 'dart:io';
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:open_filex/open_filex.dart';

class ExcelDownloadService {
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
              backgroundColorHex: ExcelColor.grey400,
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
        return await _downloadOnWeb(fileBytes, title);
      } else {
        return await _saveOnMobile(fileBytes, title);
      }
    } catch (e) {
      print('Error creating Excel file: $e');
      throw Exception('Failed to create Excel file: $e');
    }
  }

  /// Save Excel file to user-friendly location: Internal Storage/Substation/PowerPulse/
  static Future<String?> _saveOnMobile(
    List<int> fileBytes,
    String title,
  ) async {
    try {
      // Request appropriate permissions
      if (Platform.isAndroid) {
        // For Android 11+ (API 30+), request MANAGE_EXTERNAL_STORAGE
        var status = await Permission.manageExternalStorage.status;
        if (!status.isGranted) {
          status = await Permission.manageExternalStorage.request();
          if (!status.isGranted) {
            // Fall back to regular storage permission
            var storageStatus = await Permission.storage.status;
            if (!storageStatus.isGranted) {
              storageStatus = await Permission.storage.request();
              if (!storageStatus.isGranted) {
                throw Exception(
                  'Storage permission is required to save Excel files',
                );
              }
            }
          }
        }
      }

      Directory? directory;
      String folderPath;

      if (Platform.isAndroid) {
        // Create path: /storage/emulated/0/Substation/PowerPulse/
        // This is the main internal storage that users can easily access
        folderPath = '/storage/emulated/0/Substation/PowerPulse';
      } else if (Platform.isIOS) {
        // For iOS, use Documents directory
        final docDir = await getApplicationDocumentsDirectory();
        folderPath = '${docDir.path}/Substation/PowerPulse';
      } else {
        // For other platforms, use Documents directory
        final docDir = await getApplicationDocumentsDirectory();
        folderPath = '${docDir.path}/Substation/PowerPulse';
      }

      // Create the directory structure if it doesn't exist
      directory = Directory(folderPath);
      if (!await directory.exists()) {
        await directory.create(recursive: true);
        print('Created directory: $folderPath');
      }

      // Generate filename with timestamp
      final fileName =
          '${_sanitizeFileName(title)}_${_getFormattedDateTime()}.xlsx';
      final filePath = '${directory.path}/$fileName';

      // Save the file
      final file = File(filePath);
      await file.writeAsBytes(fileBytes, flush: true);

      print('✅ Excel file saved successfully!');
      print('📁 Location: $filePath');
      print(
        '📱 User can find it at: Internal Storage > Substation > PowerPulse',
      );

      return filePath;
    } catch (e) {
      print('❌ Error saving Excel file: $e');
      throw Exception('Failed to save Excel file: $e');
    }
  }

  /// Alternative method: Save to Downloads folder (even more accessible)
  static Future<String?> saveToDownloads(
    List<int> fileBytes,
    String title,
  ) async {
    try {
      // Request permissions
      if (Platform.isAndroid) {
        var status = await Permission.storage.status;
        if (!status.isGranted) {
          status = await Permission.storage.request();
        }

        if (!status.isGranted) {
          // Try manage external storage for Android 11+
          status = await Permission.manageExternalStorage.status;
          if (!status.isGranted) {
            await Permission.manageExternalStorage.request();
          }
        }
      }

      Directory? directory;

      if (Platform.isAndroid) {
        // Save directly to Downloads folder: /storage/emulated/0/Download/
        directory = Directory('/storage/emulated/0/Download');
        if (!await directory.exists()) {
          // Fallback to external storage Downloads
          final externalDir = await getExternalStorageDirectory();
          directory = Directory('${externalDir?.path}/Download');
          if (!await directory.exists()) {
            await directory.create(recursive: true);
          }
        }
      } else {
        // For iOS/other platforms, use Documents
        directory = await getApplicationDocumentsDirectory();
      }

      final fileName =
          '${_sanitizeFileName(title)}_${_getFormattedDateTime()}.xlsx';
      final filePath = '${directory!.path}/$fileName';

      final file = File(filePath);
      await file.writeAsBytes(fileBytes, flush: true);

      print('✅ Excel file saved to Downloads!');
      print('📁 Location: $filePath');

      return filePath;
    } catch (e) {
      throw Exception('Failed to save to Downloads: $e');
    }
  }

  /// Get formatted date-time for filename
  static String _getFormattedDateTime() {
    final now = DateTime.now();
    return '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}';
  }

  /// Create app folder and return path
  static Future<String> createAppFolder() async {
    String folderPath;

    if (Platform.isAndroid) {
      folderPath = '/storage/emulated/0/Substation/PowerPulse';
    } else {
      final docDir = await getApplicationDocumentsDirectory();
      folderPath = '${docDir.path}/Substation/PowerPulse';
    }

    final directory = Directory(folderPath);
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }

    return folderPath;
  }

  /// Web platform download (requires separate web implementation)
  static Future<String?> _downloadOnWeb(
    List<int> fileBytes,
    String title,
  ) async {
    // This would require dart:html for web implementation
    return null;
  }

  /// Sanitize sheet name to comply with Excel requirements
  static String _sanitizeSheetName(String name) {
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

  /// Open the saved Excel file (mobile/desktop only)
  static Future<void> openExcelFile(String filePath) async {
    if (!kIsWeb && File(filePath).existsSync()) {
      try {
        await OpenFilex.open(filePath);
      } catch (e) {
        throw Exception('Failed to open Excel file: $e');
      }
    }
  }

  /// Show success message with file location
  static String getSuccessMessage(String filePath) {
    if (Platform.isAndroid) {
      return '✅ Excel file saved successfully!\n📱 Find it at: Internal Storage > Substation > PowerPulse\n📁 Or use any file manager to navigate to: $filePath';
    } else {
      return '✅ Excel file saved successfully!\n📁 Location: $filePath';
    }
  }

  /// Check if the app has storage permission
  static Future<bool> hasStoragePermission() async {
    if (!Platform.isAndroid) return true;

    // Check for manage external storage first (Android 11+)
    var manageStatus = await Permission.manageExternalStorage.status;
    if (manageStatus == PermissionStatus.granted) {
      return true;
    }

    // Fall back to regular storage permission
    var status = await Permission.storage.status;
    return status == PermissionStatus.granted;
  }

  /// Request storage permissions with user-friendly explanation
  static Future<bool> requestStoragePermission() async {
    if (!Platform.isAndroid) return true;

    // For Android 11+ (API 30+)
    var manageStatus = await Permission.manageExternalStorage.status;
    if (manageStatus != PermissionStatus.granted) {
      manageStatus = await Permission.manageExternalStorage.request();
    }

    if (manageStatus == PermissionStatus.granted) {
      return true;
    }

    // Fall back to regular storage permission
    var status = await Permission.storage.status;
    if (status != PermissionStatus.granted) {
      status = await Permission.storage.request();
    }

    return status == PermissionStatus.granted;
  }
}
