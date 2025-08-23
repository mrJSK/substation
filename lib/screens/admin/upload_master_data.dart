import 'package:flutter/material.dart';
import 'package:excel/excel.dart' hide Border;
import 'package:file_picker/file_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:typed_data';
import 'dart:io';
import 'dart:isolate';
import 'dart:convert';
import '../../utils/snackbar_utils.dart';

class UploadMasterDataScreen extends StatefulWidget {
  const UploadMasterDataScreen({super.key});

  @override
  _UploadMasterDataScreenState createState() => _UploadMasterDataScreenState();
}

class _UploadMasterDataScreenState extends State<UploadMasterDataScreen> {
  bool _isUploading = false;
  String _uploadProgress = '';
  final ScrollController _scrollController = ScrollController();
  final List<String> _debugLogs = [];

  Isolate? _processingIsolate;
  ReceivePort? _receivePort;

  void _addDebugLog(String message) {
    final timestamp = DateTime.now().toString().substring(11, 19);
    if (mounted) {
      setState(() {
        _debugLogs.add('[$timestamp] $message');
      });
    }
    print(message);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 100),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _clearDebugLogs() {
    if (mounted) {
      setState(() {
        _debugLogs.clear();
        _uploadProgress = '';
      });
    }
  }

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
        actions: [
          if (_debugLogs.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear),
              onPressed: _clearDebugLogs,
              tooltip: 'Clear logs',
            ),
          if (_isUploading)
            IconButton(
              icon: const Icon(Icons.stop),
              onPressed: _cancelUpload,
              tooltip: 'Cancel upload',
            ),
        ],
      ),
      body: WillPopScope(
        onWillPop: () async {
          if (_isUploading) {
            _cancelUpload();
            return false;
          }
          return true;
        },
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              // Upload Section
              Expanded(
                flex: _debugLogs.isEmpty ? 1 : 2,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'High-Speed Background Upload',
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
                      'Processing in background isolate for maximum performance. UI remains responsive.',
                      style: TextStyle(
                        fontSize: 14,
                        color: isDarkMode
                            ? Colors.white70
                            : Colors.grey.shade600,
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
                              'Start Background Upload',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                    if (_uploadProgress.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: Text(
                          _uploadProgress,
                          style: TextStyle(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              // Debug Logs Section
              if (_debugLogs.isNotEmpty) ...[
                const Divider(),
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Debug Logs:',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: isDarkMode ? Colors.white : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isDarkMode
                                ? Colors.black26
                                : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isDarkMode
                                  ? Colors.white24
                                  : Colors.grey.shade300,
                            ),
                          ),
                          child: ListView.builder(
                            controller: _scrollController,
                            itemCount: _debugLogs.length,
                            itemBuilder: (context, index) {
                              final log = _debugLogs[index];
                              final isError =
                                  log.contains('ERROR') ||
                                  log.contains('Failed');
                              final isSuccess =
                                  log.contains('SUCCESS') ||
                                  log.contains('Successfully');

                              return Padding(
                                padding: const EdgeInsets.only(bottom: 2),
                                child: Text(
                                  log,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontFamily: 'Courier',
                                    color: isError
                                        ? Colors.red
                                        : isSuccess
                                        ? Colors.green
                                        : (isDarkMode
                                              ? Colors.white70
                                              : Colors.black87),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<Uint8List?> _readFileBytes(PlatformFile file) async {
    try {
      if (file.bytes != null) {
        _addDebugLog(
          'Reading file bytes directly (${file.bytes!.length} bytes)',
        );
        return file.bytes;
      }

      if (file.path != null) {
        _addDebugLog('Reading file from path: ${file.path}');
        final fileObj = File(file.path!);

        if (await fileObj.exists()) {
          final bytes = await fileObj.readAsBytes();
          _addDebugLog('Successfully read ${bytes.length} bytes from file');
          return bytes;
        }
      }

      return null;
    } catch (e) {
      _addDebugLog('ERROR: Exception while reading file bytes: $e');
      return null;
    }
  }

  void _cancelUpload() {
    _addDebugLog('Cancelling upload...');

    if (_processingIsolate != null) {
      _processingIsolate!.kill(priority: Isolate.immediate);
      _processingIsolate = null;
    }

    if (_receivePort != null) {
      _receivePort!.close();
      _receivePort = null;
    }

    setState(() {
      _isUploading = false;
      _uploadProgress = 'Upload cancelled';
    });

    SnackBarUtils.showSnackBar(context, 'Upload cancelled', isError: false);
  }

  Future<void> _pickAndUploadFile() async {
    setState(() {
      _isUploading = true;
      _uploadProgress = 'Initializing...';
    });

    _clearDebugLogs();
    _addDebugLog('Starting background upload process...');

    try {
      // Step 1: File Selection
      _addDebugLog('Opening file picker...');
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls'],
        allowMultiple: false,
        withData: true,
      );

      if (result == null || result.files.isEmpty) {
        _addDebugLog('ERROR: No file selected');
        SnackBarUtils.showSnackBar(context, 'No file selected', isError: true);
        return;
      }

      final file = result.files.single;
      _addDebugLog('Selected file: ${file.name} (${file.size} bytes)');

      setState(() => _uploadProgress = 'Reading file...');

      // Step 2: Read file bytes
      final Uint8List? fileBytes = await _readFileBytes(file);

      if (fileBytes == null) {
        _addDebugLog('ERROR: Failed to read file bytes');
        SnackBarUtils.showSnackBar(
          context,
          'Failed to read file. Please try again.',
          isError: true,
        );
        return;
      }

      _addDebugLog('Successfully read ${fileBytes.length} bytes');

      // Step 3: Process in background isolate
      await _processFileInBackground(fileBytes);
    } catch (e) {
      _addDebugLog('ERROR: Unexpected error: $e');
      SnackBarUtils.showSnackBar(context, 'Upload failed: $e', isError: true);
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
          if (_uploadProgress.isEmpty ||
              !_uploadProgress.contains('successfully')) {
            _uploadProgress = '';
          }
        });
      }
    }
  }

  Future<void> _processFileInBackground(Uint8List fileBytes) async {
    _addDebugLog('Starting background processing...');
    setState(() => _uploadProgress = 'Processing Excel file in background...');

    // Create a receive port for communication with the isolate
    _receivePort = ReceivePort();

    try {
      // Spawn the isolate
      _processingIsolate = await Isolate.spawn(
        _processFileIsolate,
        IsolateMessage(fileBytes: fileBytes, sendPort: _receivePort!.sendPort),
      );

      // Listen to messages from the isolate
      await for (final message in _receivePort!) {
        if (!mounted) break;

        if (message is Map<String, dynamic>) {
          final messageType = message['type'] as String;

          switch (messageType) {
            case 'update':
              final updateMessage = message['message'] as String;
              setState(() => _uploadProgress = updateMessage);
              _addDebugLog(updateMessage);
              break;

            case 'error':
              final errorMessage = message['error'] as String;
              _addDebugLog('ERROR: $errorMessage');
              SnackBarUtils.showSnackBar(context, errorMessage, isError: true);
              break;

            case 'result':
              // Process the result data for Firebase upload
              final processedData = message['data'] as List<dynamic>;
              await _uploadProcessedDataToFirestore(processedData);
              break;
          }
        }
      }
    } catch (e) {
      _addDebugLog('ERROR: Background processing failed: $e');
      SnackBarUtils.showSnackBar(
        context,
        'Processing failed: $e',
        isError: true,
      );
    } finally {
      _receivePort?.close();
      _receivePort = null;
      _processingIsolate = null;
    }
  }

  Future<void> _uploadProcessedDataToFirestore(
    List<dynamic> processedData,
  ) async {
    _addDebugLog(
      'Starting Firebase upload of ${processedData.length} records...',
    );
    setState(() => _uploadProgress = 'Uploading to Firebase...');

    try {
      // Upload in batches for better performance
      const int batchSize = 1000;
      final List<WriteBatch> batches = [];
      WriteBatch currentBatch = FirebaseFirestore.instance.batch();
      int operationCount = 0;
      int totalUploaded = 0;

      final now = Timestamp.now();

      for (final item in processedData) {
        final itemMap = item as Map<String, dynamic>;
        final docId = itemMap['id'] as String;
        final dataType = itemMap['dataType'] as String;
        final attributes = itemMap['attributes'] as Map<String, dynamic>;

        final docRef = FirebaseFirestore.instance
            .collection('masterData')
            .doc(docId);

        currentBatch.set(docRef, {
          'type': dataType,
          'attributes': attributes,
          'lastUpdatedOn': now,
        });

        operationCount++;

        if (operationCount >= batchSize) {
          batches.add(currentBatch);
          currentBatch = FirebaseFirestore.instance.batch();
          operationCount = 0;
        }
      }

      // Add remaining operations
      if (operationCount > 0) {
        batches.add(currentBatch);
      }

      _addDebugLog('Created ${batches.length} batches for upload');

      // Upload batches with parallel processing
      const int maxConcurrentUploads = 3;

      for (int i = 0; i < batches.length; i += maxConcurrentUploads) {
        if (!mounted || !_isUploading) break;

        final batchGroup = batches.sublist(
          i,
          (i + maxConcurrentUploads < batches.length)
              ? i + maxConcurrentUploads
              : batches.length,
        );

        // Upload this group in parallel
        final uploadFutures = batchGroup.asMap().entries.map((entry) async {
          try {
            await entry.value.commit();
            return batchSize; // Return number of operations in batch
          } catch (e) {
            _addDebugLog('ERROR: Batch ${i + entry.key + 1} failed: $e');
            return 0;
          }
        });

        final results = await Future.wait(uploadFutures);
        final uploadedCount = results.fold<int>(0, (sum, count) => sum + count);
        totalUploaded += uploadedCount;

        _addDebugLog(
          'SUCCESS: Uploaded batches ${i + 1}-${i + batchGroup.length}',
        );

        if (mounted) {
          setState(
            () => _uploadProgress = 'Uploaded ${totalUploaded} records...',
          );
        }

        // Small delay to prevent overwhelming Firebase
        if (i + maxConcurrentUploads < batches.length) {
          await Future.delayed(const Duration(milliseconds: 50));
        }
      }

      // Success
      _addDebugLog(
        'SUCCESS: All batches uploaded successfully! Total: ${processedData.length} records',
      );

      if (mounted) {
        SnackBarUtils.showSnackBar(
          context,
          'Successfully uploaded ${processedData.length} records!',
        );
        setState(() => _uploadProgress = 'Upload completed successfully!');
      }
    } catch (e) {
      _addDebugLog('ERROR: Firebase upload failed: $e');

      String errorMessage = 'Upload failed';
      if (e.toString().contains('permission-denied')) {
        errorMessage = 'Permission denied. Check Firestore security rules.';
      } else if (e.toString().contains('quota-exceeded')) {
        errorMessage = 'Firebase quota exceeded. Try uploading fewer records.';
      }

      if (mounted) {
        SnackBarUtils.showSnackBar(context, errorMessage, isError: true);
      }
    }
  }

  @override
  void dispose() {
    _cancelUpload();
    _scrollController.dispose();
    super.dispose();
  }
}

// Message class for isolate communication
class IsolateMessage {
  final Uint8List fileBytes;
  final SendPort sendPort;

  IsolateMessage({required this.fileBytes, required this.sendPort});
}

// Isolate entry point - must be top-level function
void _processFileIsolate(IsolateMessage message) async {
  final sendPort = message.sendPort;

  try {
    sendPort.send({'type': 'update', 'message': 'Decoding Excel file...'});

    // Decode Excel in isolate
    final excel = Excel.decodeBytes(message.fileBytes);

    if (excel.tables.isEmpty) {
      sendPort.send({
        'type': 'error',
        'error': 'No sheets found in Excel file',
      });
      return;
    }

    final sheetName = excel.tables.keys.first;
    final sheet = excel.tables[sheetName];

    if (sheet == null || sheet.rows.isEmpty) {
      sendPort.send({'type': 'error', 'error': 'Empty or invalid Excel sheet'});
      return;
    }

    sendPort.send({
      'type': 'update',
      'message': 'Processing ${sheet.rows.length} rows...',
    });

    // Process headers
    final firstRow = sheet.rows.first;
    final headers = firstRow
        .map((cell) => cell?.value?.toString()?.trim() ?? '')
        .where((header) => header.isNotEmpty)
        .toList();

    String? dataType;
    String? keyColumn;

    if (headers.contains('Vendor')) {
      dataType = 'vendor';
      keyColumn = 'Vendor';
    } else if (headers.contains('Material')) {
      dataType = 'material';
      keyColumn = 'Material';
    } else if (headers.contains('Activity number')) {
      dataType = 'service';
      keyColumn = 'Activity number';
    } else {
      sendPort.send({
        'type': 'error',
        'error':
            'Unknown data type. Expected headers: Vendor, Material, or Activity number',
      });
      return;
    }

    final keyColumnIndex = headers.indexOf(keyColumn!);
    if (keyColumnIndex == -1) {
      sendPort.send({
        'type': 'error',
        'error': 'Key column not found: $keyColumn',
      });
      return;
    }

    sendPort.send({'type': 'update', 'message': 'Data type: $dataType'});

    // Process data rows
    final List<Map<String, dynamic>> processedData = [];
    int totalProcessed = 0;
    int totalSkipped = 0;

    for (int rowIndex = 1; rowIndex < sheet.rows.length; rowIndex++) {
      final row = sheet.rows[rowIndex];

      // Skip empty rows
      if (row.isEmpty || row.every((cell) => cell?.value == null)) {
        totalSkipped++;
        continue;
      }

      // Extract document ID
      final docIdCell = row.length > keyColumnIndex
          ? row[keyColumnIndex]
          : null;
      final docId = docIdCell?.value?.toString()?.trim();

      if (docId == null || docId.isEmpty) {
        totalSkipped++;
        continue;
      }

      // Build attributes map
      final Map<String, dynamic> attributes = {};
      for (int i = 0; i < headers.length && i < row.length; i++) {
        final cellValue = row[i]?.value?.toString()?.trim();
        attributes[headers[i]] = (cellValue?.isNotEmpty == true)
            ? cellValue
            : null;
      }

      // Skip deleted services (if applicable)
      if (dataType == 'service' && attributes['Deletion Indicator'] != null) {
        totalSkipped++;
        continue;
      }

      // Clean document ID for Firestore
      final cleanDocId = docId.replaceAll(RegExp(r'[/\\]'), '_');

      processedData.add({
        'id': cleanDocId,
        'dataType': dataType,
        'attributes': attributes,
      });

      totalProcessed++;

      // Send progress updates
      if (totalProcessed % 1000 == 0) {
        sendPort.send({
          'type': 'update',
          'message': 'Processed $totalProcessed records...',
        });
      }
    }

    sendPort.send({
      'type': 'update',
      'message':
          'Processing complete. $totalProcessed records ready for upload.',
    });

    // Send the processed data back to main isolate
    sendPort.send({'type': 'result', 'data': processedData});
  } catch (e) {
    sendPort.send({'type': 'error', 'error': 'Processing failed: $e'});
  }
}
