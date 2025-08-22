import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import '../../models/power_pulse/sap_master_data_model.dart';
import '../../utils/snackbar_utils.dart';

class MasterDataScreen extends StatefulWidget {
  const MasterDataScreen({super.key});

  @override
  _MasterDataScreenState createState() => _MasterDataScreenState();
}

class _MasterDataScreenState extends State<MasterDataScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  MasterDataType? _filterType;
  bool _isUploading = false;
  bool _isLoadingMore = false;
  DocumentSnapshot? _lastDocument;
  final int _pageSize = 20;
  List<MasterData> _data = [];
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadInitialData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _loadInitialData() async {
    final query = FirebaseFirestore.instance
        .collection('masterData')
        .orderBy('lastUpdatedOn', descending: true)
        .limit(_pageSize);
    final snapshot = await query.get();
    setState(() {
      _data = snapshot.docs
          .map((doc) => MasterData.fromFirestore(doc))
          .toList();
      _lastDocument = snapshot.docs.isNotEmpty ? snapshot.docs.last : null;
      _hasMore = snapshot.docs.length == _pageSize;
    });
  }

  void _loadMoreData() async {
    if (_isLoadingMore || !_hasMore) return;
    setState(() => _isLoadingMore = true);

    Query query = FirebaseFirestore.instance
        .collection('masterData')
        .orderBy('lastUpdatedOn', descending: true)
        .limit(_pageSize);

    if (_lastDocument != null) {
      query = query.startAfterDocument(_lastDocument!);
    }

    if (_filterType != null) {
      query = query.where(
        'type',
        isEqualTo: _filterType!.toString().split('.').last,
      );
    }

    final snapshot = await query.get();
    setState(() {
      _data.addAll(snapshot.docs.map((doc) => MasterData.fromFirestore(doc)));
      _lastDocument = snapshot.docs.isNotEmpty ? snapshot.docs.last : null;
      _hasMore = snapshot.docs.length == _pageSize;
      _isLoadingMore = false;
    });
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
          'Master Data Management',
          style: TextStyle(
            color: isDarkMode ? Colors.white : theme.colorScheme.onSurface,
            fontSize: 18,
            fontWeight: FontWeight.w500,
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: isDarkMode ? Colors.white : theme.colorScheme.primary,
          unselectedLabelColor: isDarkMode
              ? Colors.white70
              : Colors.grey.shade600,
          indicatorColor: theme.colorScheme.primary,
          tabs: const [
            Tab(text: 'Search'),
            Tab(text: 'Upload'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildSearchTab(theme), _buildUploadTab(theme)],
      ),
    );
  }

  Widget _buildSearchTab(ThemeData theme) {
    final isDarkMode = theme.brightness == Brightness.dark;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search by name or description...',
                  prefixIcon: Icon(
                    Icons.search,
                    color: theme.colorScheme.primary,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: isDarkMode
                          ? Colors.white.withOpacity(0.3)
                          : Colors.grey.shade300,
                    ),
                  ),
                  filled: true,
                  fillColor: isDarkMode
                      ? const Color(0xFF2C2C2E)
                      : Colors.white,
                ),
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value.trim().toLowerCase();
                    _lastDocument = null;
                    _data.clear();
                    _hasMore = true;
                    _loadInitialData();
                  });
                },
              ),
              const SizedBox(height: 8),
              DropdownButton<MasterDataType?>(
                value: _filterType,
                hint: Text(
                  'Filter by type',
                  style: TextStyle(
                    color: isDarkMode ? Colors.white70 : Colors.grey.shade600,
                  ),
                ),
                isExpanded: true,
                items: [
                  const DropdownMenuItem<MasterDataType?>(
                    value: null,
                    child: Text('All Types'),
                  ),
                  ...MasterDataType.values.map(
                    (type) => DropdownMenuItem<MasterDataType>(
                      value: type,
                      child: Text(type.toString().split('.').last.capitalize()),
                    ),
                  ),
                ],
                onChanged: (value) {
                  setState(() {
                    _filterType = value;
                    _lastDocument = null;
                    _data.clear();
                    _hasMore = true;
                    _loadInitialData();
                  });
                },
              ),
            ],
          ),
        ),
        Expanded(
          child: _data.isEmpty && !_hasMore
              ? Center(
                  child: Text(
                    'No data found',
                    style: TextStyle(
                      fontSize: 16,
                      color: isDarkMode ? Colors.white70 : Colors.grey.shade600,
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _data.length + (_hasMore ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == _data.length) {
                      return Padding(
                        padding: const EdgeInsets.all(16),
                        child: ElevatedButton(
                          onPressed: _isLoadingMore ? null : _loadMoreData,
                          child: _isLoadingMore
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text('Load More'),
                        ),
                      );
                    }

                    final item = _data[index];
                    if (!_searchQuery.isEmpty &&
                        !item.getDisplayName().toLowerCase().contains(
                          _searchQuery,
                        )) {
                      return const SizedBox.shrink();
                    }

                    return Card(
                      color: isDarkMode
                          ? const Color(0xFF2C2C2E)
                          : Colors.white,
                      elevation: 2,
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        title: Text(
                          item.getDisplayName(),
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            color: isDarkMode ? Colors.white : Colors.black87,
                          ),
                        ),
                        subtitle: Text(
                          '${item.type.toString().split('.').last.capitalize()} • ${item.getSecondaryInfo()} • Last Updated: ${DateTime.fromMillisecondsSinceEpoch(item.lastUpdatedOn.millisecondsSinceEpoch).toString().substring(0, 16)}',
                          style: TextStyle(
                            color: isDarkMode
                                ? Colors.white70
                                : Colors.grey.shade600,
                          ),
                        ),
                        onTap: () => _showDetailsDialog(item, theme),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildUploadTab(ThemeData theme) {
    final isDarkMode = theme.brightness == Brightness.dark;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Upload Master Data',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: isDarkMode ? Colors.white : theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Select an Excel file (Vendor, Material, or Service) to upload to Firestore.',
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
    );
  }

  void _showDetailsDialog(MasterData item, ThemeData theme) {
    final isDarkMode = theme.brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDarkMode ? const Color(0xFF2C2C2E) : Colors.white,
        title: Text(
          item.getDisplayName(),
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: isDarkMode ? Colors.white : theme.colorScheme.onSurface,
          ),
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Type: ${item.type.toString().split('.').last.capitalize()}',
                style: TextStyle(
                  color: isDarkMode ? Colors.white70 : Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Last Updated: ${DateTime.fromMillisecondsSinceEpoch(item.lastUpdatedOn.millisecondsSinceEpoch).toString().substring(0, 16)}',
                style: TextStyle(
                  color: isDarkMode ? Colors.white70 : Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 16),
              ...item.attributes.entries.map(
                (entry) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    '${entry.key}: ${entry.value ?? 'N/A'}',
                    style: TextStyle(
                      color: isDarkMode
                          ? Colors.white
                          : theme.colorScheme.onSurface,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Close',
              style: TextStyle(color: theme.colorScheme.primary),
            ),
          ),
        ],
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

// Extension to capitalize strings
extension StringExtension on String {
  String capitalize() {
    return "${this[0].toUpperCase()}${substring(1).toLowerCase()}";
  }
}
