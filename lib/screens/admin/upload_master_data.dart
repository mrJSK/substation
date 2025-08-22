import 'package:flutter/material.dart';
import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../utils/snackbar_utils.dart';

class UploadMasterDataScreen extends StatefulWidget {
  const UploadMasterDataScreen({super.key});

  @override
  _UploadMasterDataScreenState createState() => _UploadMasterDataScreenState();
}

class _UploadMasterDataScreenState extends State<UploadMasterDataScreen> {
  bool _isUploading = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDarkMode
          ? const Color(0xFF1C1C1E)
          : const Color(0xFFFAFAFA),
      appBar: AppBar(
        backgroundColor: isDarkMode ? const Color(0xFF2C2C2E) : Colors.white,
        elevation: 0,
        title: Text(
          'Upload Master Data',
          style: TextStyle(
            color: isDarkMode ? Colors.white : theme.colorScheme.onSurface,
            fontSize: 18,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Upload Excel File',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: isDarkMode
                      ? Colors.white
                      : theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Select a Vendor, Material, or Service master data Excel file to upload to Firestore.',
                style: TextStyle(
                  fontSize: 14,
                  color: isDarkMode ? Colors.white70 : Colors.grey.shade600,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isUploading ? null : _pickAndUploadFile,
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: _isUploading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Pick and Upload File',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickAndUploadFile() async {
    setState(() => _isUploading = true);

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
      );

      if (result == null || result.files.isEmpty) {
        SnackBarUtils.showSnackBar(context, 'No file selected', isError: true);
        return;
      }

      final file = result.files.single;
      if (file.bytes == null) {
        SnackBarUtils.showSnackBar(
          context,
          'Failed to read file',
          isError: true,
        );
        return;
      }

      final excel = Excel.decodeBytes(file.bytes!);
      final sheet = excel.tables[excel.tables.keys.first];
      if (sheet == null) {
        SnackBarUtils.showSnackBar(
          context,
          'Invalid Excel file',
          isError: true,
        );
        return;
      }

      final batch = FirebaseFirestore.instance.batch();
      final now = Timestamp.now();
      String? dataType;

      // Determine data type based on headers
      final headers = sheet.rows.first
          .map((cell) => cell?.value?.toString() ?? '')
          .toList();
      if (headers.contains('Vendor')) {
        dataType = 'vendor';
      } else if (headers.contains('Material')) {
        dataType = 'material';
      } else if (headers.contains('Activity number')) {
        dataType = 'service';
      } else {
        SnackBarUtils.showSnackBar(
          context,
          'Unknown data type in Excel file',
          isError: true,
        );
        return;
      }

      // Skip header row and process data rows
      for (var row in sheet.rows.skip(1)) {
        final rowData = row
            .map((cell) => cell?.value?.toString() ?? '')
            .toList();
        if (rowData.isEmpty || rowData.every((cell) => cell.isEmpty)) continue;

        String? docId;
        Map<String, dynamic> attributes = {};

        if (dataType == 'vendor') {
          docId = rowData[headers.indexOf('Vendor')];
          attributes = {
            for (var i = 0; i < headers.length; i++)
              headers[i]: rowData[i].isNotEmpty ? rowData[i] : null,
          };
        } else if (dataType == 'material') {
          docId = rowData[headers.indexOf('Material')];
          attributes = {
            for (var i = 0; i < headers.length; i++)
              headers[i]: rowData[i].isNotEmpty ? rowData[i] : null,
          };
        } else if (dataType == 'service') {
          docId = rowData[headers.indexOf('Activity number')];
          attributes = {
            for (var i = 0; i < headers.length; i++)
              headers[i]: rowData[i].isNotEmpty ? rowData[i] : null,
          };
          // Skip deleted services
          if (attributes['Deletion Indicator']?.toString().isNotEmpty ??
              false) {
            continue;
          }
        }

        if (docId == null || docId.isEmpty) continue;

        final docRef = FirebaseFirestore.instance
            .collection('masterData')
            .doc(docId);
        batch.set(docRef, {
          'type': dataType,
          'attributes': attributes,
          'lastUpdatedOn': now,
        });
      }

      await batch.commit();
      SnackBarUtils.showSnackBar(context, 'Data uploaded successfully!');
    } catch (e) {
      SnackBarUtils.showSnackBar(
        context,
        'Failed to upload data: $e',
        isError: true,
      );
    } finally {
      setState(() => _isUploading = false);
    }
  }
}
