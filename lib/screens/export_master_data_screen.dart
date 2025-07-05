// lib/screens/export_master_data_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dropdown_search/dropdown_search.dart';
import 'package:intl/intl.dart';
import 'package:csv/csv.dart'; // For CSV generation
import 'package:share_plus/share_plus.dart'; // For sharing files
import 'package:path_provider/path_provider.dart'; // To get temporary directory
import 'dart:io'; // For File operations
import '../../models/bay_model.dart';

import '../../models/user_model.dart';
import '../../models/hierarchy_models.dart';
import '../../models/equipment_model.dart'; // For EquipmentInstance, MasterEquipmentTemplate
import '../../utils/snackbar_utils.dart';

class ExportMasterDataScreen extends StatefulWidget {
  final String subdivisionId;
  final AppUser currentUser;

  const ExportMasterDataScreen({
    super.key,
    required this.subdivisionId,
    required this.currentUser,
  });

  @override
  State<ExportMasterDataScreen> createState() => _ExportMasterDataScreenState();
}

enum ExportScope { subdivision, substation, bay }

enum DataTypeToExport { substations, bays, equipmentInstances }

class _ExportMasterDataScreenState extends State<ExportMasterDataScreen> {
  ExportScope _selectedScope = ExportScope.subdivision;
  DataTypeToExport _selectedDataType = DataTypeToExport.equipmentInstances;

  Substation? _selectedSubstation;
  Bay? _selectedBay;

  List<Substation> _substationsInSubdivision = [];
  List<Bay> _baysInSelectedSubstation = [];

  bool _isLoadingData = true;
  bool _isGeneratingReport = false;

  DateTime? _startDate;
  DateTime? _endDate;

  // For dynamic custom field filtering (complex - placeholder for now)
  MasterEquipmentTemplate? _selectedEquipmentTemplateForFilter;
  List<MasterEquipmentTemplate> _equipmentTemplates = [];
  Map<String, dynamic> _customFieldFilterValues =
      {}; // Stores values for custom field filters

  @override
  void initState() {
    super.initState();
    _fetchInitialData();
  }

  Future<void> _fetchInitialData() async {
    setState(() {
      _isLoadingData = true;
    });
    try {
      // Fetch all substations in the user's subdivision
      final substationsSnapshot = await FirebaseFirestore.instance
          .collection('substations')
          .where('subdivisionId', isEqualTo: widget.subdivisionId)
          .orderBy('name')
          .get();
      _substationsInSubdivision = substationsSnapshot.docs
          .map((doc) => Substation.fromFirestore(doc))
          .toList();

      // Fetch all equipment templates for filtering options
      final templatesSnapshot = await FirebaseFirestore.instance
          .collection('masterEquipmentTemplates')
          .orderBy('equipmentType')
          .get();
      _equipmentTemplates = templatesSnapshot.docs
          .map((doc) => MasterEquipmentTemplate.fromFirestore(doc))
          .toList();
    } catch (e) {
      print("Error fetching initial export data: $e");
      if (mounted) {
        SnackBarUtils.showSnackBar(
          context,
          'Failed to load data for export: $e',
          isError: true,
        );
      }
    } finally {
      setState(() {
        _isLoadingData = false;
      });
    }
  }

  Future<void> _fetchBaysForSelectedSubstation(String substationId) async {
    setState(() {
      _baysInSelectedSubstation.clear();
      _selectedBay = null;
    });
    try {
      final baysSnapshot = await FirebaseFirestore.instance
          .collection('bays')
          .where('substationId', isEqualTo: substationId)
          .orderBy('name')
          .get();
      setState(() {
        _baysInSelectedSubstation = baysSnapshot.docs
            .map((doc) => Bay.fromFirestore(doc))
            .toList();
      });
    } catch (e) {
      print("Error fetching bays for selected substation: $e");
      if (mounted) {
        SnackBarUtils.showSnackBar(
          context,
          'Failed to load bays: $e',
          isError: true,
        );
      }
    }
  }

  Future<void> _selectDate(BuildContext context, bool isStartDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: (isStartDate ? _startDate : _endDate) ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        if (isStartDate) {
          _startDate = picked;
        } else {
          _endDate = picked;
        }
      });
    }
  }

  // Helper to format date for display or filename
  String _formatDate(DateTime? date) {
    if (date == null) return 'N/A';
    return DateFormat('yyyy-MM-dd').format(date);
  }

  // Helper to flatten custom field values for CSV
  void _flattenCustomFields(
    Map<String, dynamic> customFields,
    String prefix,
    Map<String, dynamic> flattened,
  ) {
    customFields.forEach((key, value) {
      final newKey = prefix.isEmpty ? key : '${prefix}_$key';
      if (value is Map<String, dynamic>) {
        // Handle boolean with remarks
        if (value.containsKey('value') &&
            value.containsKey('description_remarks')) {
          flattened['${newKey}_value'] = value['value'];
          flattened['${newKey}_remarks'] = value['description_remarks'];
        } else {
          // Nested group
          _flattenCustomFields(value, newKey, flattened);
        }
      } else if (value is List<dynamic>) {
        // Handle list of group items
        for (int i = 0; i < value.length; i++) {
          if (value[i] is Map<String, dynamic>) {
            _flattenCustomFields(
              value[i] as Map<String, dynamic>,
              '${newKey}_item${i + 1}',
              flattened,
            );
          } else {
            flattened['${newKey}_item${i + 1}'] = value[i];
          }
        }
      } else if (value is Timestamp) {
        flattened[newKey] = DateFormat(
          'yyyy-MM-dd HH:mm',
        ).format(value.toDate());
      } else {
        flattened[newKey] = value;
      }
    });
  }

  Future<void> _generateAndShareReport() async {
    if (_isGeneratingReport) return;

    if (_selectedScope != ExportScope.subdivision) {
      if (_selectedSubstation == null) {
        SnackBarUtils.showSnackBar(
          context,
          'Please select a Substation.',
          isError: true,
        );
        return;
      }
      if (_selectedScope == ExportScope.bay && _selectedBay == null) {
        SnackBarUtils.showSnackBar(
          context,
          'Please select a Bay.',
          isError: true,
        );
        return;
      }
    }

    setState(() {
      _isGeneratingReport = true;
    });

    try {
      List<List<dynamic>> csvData = [];
      List<String> headers = [];
      String reportFileName = "master_data_report.csv";

      Query query;

      if (_selectedDataType == DataTypeToExport.substations) {
        headers = [
          'ID',
          'Name',
          'Subdivision ID',
          'Address',
          'City ID',
          'Voltage Level',
          'Type',
          'Operation',
          'SAS Make',
          'Commissioning Date',
          'Status',
          'Status Description',
          'Contact Designation',
          'Landmark',
          'Contact Number',
          'Contact Person',
          'Created By',
          'Created At',
        ];
        csvData.add(headers);

        query = FirebaseFirestore.instance.collection('substations');
        if (_selectedScope == ExportScope.substation) {
          query = query.where(
            FieldPath.documentId,
            isEqualTo: _selectedSubstation!.id,
          );
        } else {
          // ExportScope.subdivision
          query = query.where('subdivisionId', isEqualTo: widget.subdivisionId);
        }

        final snapshot = await query.get();
        for (var doc in snapshot.docs) {
          final substation = Substation.fromFirestore(doc);
          csvData.add([
            substation.id,
            substation.name,
            substation.subdivisionId,
            substation.address,
            substation.cityId,
            substation.voltageLevel,
            substation.type,
            substation.operation,
            substation.sasMake,
            _formatDate(substation.commissioningDate?.toDate()),
            substation.status,
            substation.statusDescription,
            substation.contactDesignation,
            substation.landmark,
            substation.contactNumber,
            substation.contactPerson,
            substation.createdBy,
            _formatDate(substation.createdAt.toDate()),
          ]);
        }
        reportFileName =
            "substations_report_${_formatDate(DateTime.now())}.csv";
      } else if (_selectedDataType == DataTypeToExport.bays) {
        headers = [
          'ID',
          'Name',
          'Substation ID',
          'Voltage Level',
          'Bay Type',
          'Is Government Feeder',
          'Feeder Type',
          'Description',
          'Landmark',
          'Contact Number',
          'Contact Person',
          'Created By',
          'Created At',
        ];
        csvData.add(headers);

        query = FirebaseFirestore.instance.collection('bays');
        if (_selectedScope == ExportScope.subdivision) {
          final substationIds = _substationsInSubdivision
              .map((s) => s.id)
              .toList();
          if (substationIds.isEmpty) {
            SnackBarUtils.showSnackBar(
              context,
              'No substations found in subdivision.',
              isError: true,
            );
            return;
          }
          query = query.where('substationId', whereIn: substationIds);
        } else if (_selectedScope == ExportScope.substation) {
          query = query.where(
            'substationId',
            isEqualTo: _selectedSubstation!.id,
          );
        } else {
          // ExportScope.bay
          query = query.where(
            FieldPath.documentId,
            isEqualTo: _selectedBay!.id,
          );
        }

        final snapshot = await query.get();
        for (var doc in snapshot.docs) {
          final bay = Bay.fromFirestore(doc);
          csvData.add([
            bay.id,
            bay.name,
            bay.substationId,
            bay.voltageLevel,
            bay.bayType,
            bay.isGovernmentFeeder,
            bay.feederType,
            bay.description,
            bay.landmark,
            bay.contactNumber,
            bay.contactPerson,
            bay.createdBy,
            _formatDate(bay.createdAt.toDate()),
          ]);
        }
        reportFileName = "bays_report_${_formatDate(DateTime.now())}.csv";
      } else if (_selectedDataType == DataTypeToExport.equipmentInstances) {
        reportFileName =
            "equipment_instances_report_${_formatDate(DateTime.now())}.csv";

        // Fetch equipment instances
        Query currentEquipmentQuery = FirebaseFirestore.instance.collection(
          'equipmentInstances',
        );
        List<String> bayIdsToQuery = [];

        if (_selectedScope == ExportScope.subdivision) {
          for (var sub in _substationsInSubdivision) {
            final baysSnapshot = await FirebaseFirestore.instance
                .collection('bays')
                .where('substationId', isEqualTo: sub.id)
                .get();
            for (var bayDoc in baysSnapshot.docs) {
              bayIdsToQuery.add(bayDoc.id);
            }
          }
        } else if (_selectedScope == ExportScope.substation) {
          final baysSnapshot = await FirebaseFirestore.instance
              .collection('bays')
              .where('substationId', isEqualTo: _selectedSubstation!.id)
              .get();
          for (var bayDoc in baysSnapshot.docs) {
            bayIdsToQuery.add(bayDoc.id);
          }
        } else if (_selectedScope == ExportScope.bay) {
          bayIdsToQuery.add(_selectedBay!.id);
        }

        if (bayIdsToQuery.isEmpty) {
          SnackBarUtils.showSnackBar(
            context,
            'No bays found for selected scope.',
            isError: true,
          );
          return;
        }

        // Firestore `whereIn` has a limit of 10. If bayIdsToQuery is larger,
        // you'd need to chunk the queries or rethink the data model/rules.
        // For simplicity, assuming bayIdsToQuery is within limits.
        currentEquipmentQuery = currentEquipmentQuery.where(
          'bayId',
          whereIn: bayIdsToQuery,
        );

        // Date Filtering (applies to all data types)
        if (_startDate != null) {
          currentEquipmentQuery = currentEquipmentQuery.where(
            'createdAt',
            isGreaterThanOrEqualTo: Timestamp.fromDate(_startDate!),
          );
        }
        if (_endDate != null) {
          currentEquipmentQuery = currentEquipmentQuery.where(
            'createdAt',
            isLessThanOrEqualTo: Timestamp.fromDate(_endDate!),
          );
        }

        final snapshot = await currentEquipmentQuery.get();
        List<EquipmentInstance> fetchedEquipment = snapshot.docs
            .map((doc) => EquipmentInstance.fromFirestore(doc))
            .toList();

        // Apply Equipment Type filter if selected
        if (_selectedEquipmentTemplateForFilter != null) {
          fetchedEquipment = fetchedEquipment
              .where(
                (eq) =>
                    eq.templateId == _selectedEquipmentTemplateForFilter!.id,
              )
              .toList();
        }

        // Dynamic Custom Field Filtering (Complex - Placeholder)
        // This would require iterating fetchedEquipment and applying filters based on _customFieldFilterValues
        // This is complex due to nested nature of customFieldValues and dynamic field names.
        // Example: if _customFieldFilterValues has {'Voltage_value': '110'}
        // fetchedEquipment = fetchedEquipment.where((eq) => eq.customFieldValues['Voltage']?['value'] == '110').toList();
        // This requires dynamically building paths and types.

        if (fetchedEquipment.isEmpty) {
          SnackBarUtils.showSnackBar(
            context,
            'No equipment found matching criteria.',
            isError: true,
          );
          return;
        }

        // Collect all possible headers first for Equipment Instances
        Set<String> dynamicHeaders = Set<String>();
        for (var eq in fetchedEquipment) {
          final Map<String, dynamic> flattenedCustomFields = {};
          _flattenCustomFields(eq.customFieldValues, '', flattenedCustomFields);
          dynamicHeaders.addAll(flattenedCustomFields.keys);
        }

        headers = [
          'ID',
          'Bay ID',
          'Template ID',
          'Equipment Type Name',
          'Symbol Key',
          'Status',
          'Previous ID',
          'Replacement ID',
          'Decommissioned At',
          'Reason For Change',
          'Created By',
          'Created At',
        ];
        headers.addAll(
          dynamicHeaders.toList()..sort(),
        ); // Add sorted dynamic custom field headers
        csvData.add(headers);

        for (var eq in fetchedEquipment) {
          final Map<String, dynamic> flattenedCustomFields = {};
          _flattenCustomFields(eq.customFieldValues, '', flattenedCustomFields);

          List<dynamic> row = [
            eq.id,
            eq.bayId,
            eq.templateId,
            eq.equipmentTypeName,
            eq.symbolKey,
            eq.status,
            eq.previousEquipmentInstanceId,
            eq.replacementEquipmentInstanceId,
            _formatDate(eq.decommissionedAt?.toDate()),
            eq.reasonForChange,
            eq.createdBy,
            _formatDate(eq.createdAt.toDate()),
          ];

          // Add values for dynamic custom fields
          for (var header in dynamicHeaders.toList()..sort()) {
            row.add(flattenedCustomFields[header] ?? '');
          }
          csvData.add(row);
        }
      }

      String csv = const ListToCsvConverter().convert(csvData);

      final directory = await getTemporaryDirectory();
      final path = '${directory.path}/$reportFileName';
      final file = File(path);
      await file.writeAsString(csv);

      if (mounted) {
        Share.shareXFiles([
          XFile(path),
        ], text: 'Here is your exported master data report.');
        SnackBarUtils.showSnackBar(
          context,
          'Report generated and ready to share!',
        );
      }
    } catch (e) {
      print("Error generating or sharing report: $e");
      if (mounted) {
        SnackBarUtils.showSnackBar(
          context,
          'Failed to generate report: $e',
          isError: true,
        );
      }
    } finally {
      setState(() {
        _isGeneratingReport = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingData) {
      return const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      // Added Scaffold
      appBar: AppBar(title: const Text('Export Master Data')), // Added AppBar
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Export Master Data Records',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 20),

            // Export Scope Selection
            Text(
              'Select Export Scope:',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Column(
              children: ExportScope.values.map((scope) {
                return ListTile(
                  title: Text(
                    scope
                        .toString()
                        .split('.')
                        .last
                        .replaceAllMapped(
                          RegExp(r'(?<=[a-z])[A-Z]'),
                          (match) => ' ${match.group(0)}',
                        ),
                  ),
                  leading: Radio<ExportScope>(
                    value: scope,
                    groupValue: _selectedScope,
                    onChanged: (ExportScope? value) {
                      setState(() {
                        _selectedScope = value!;
                        _selectedSubstation = null;
                        _selectedBay = null;
                        _baysInSelectedSubstation.clear();
                      });
                    },
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            // Substation Selection (if scope is not subdivision)
            if (_selectedScope == ExportScope.substation ||
                _selectedScope == ExportScope.bay)
              DropdownSearch<Substation>(
                popupProps: PopupProps.menu(showSearchBox: true),
                dropdownDecoratorProps: DropDownDecoratorProps(
                  dropdownSearchDecoration: InputDecoration(
                    labelText: 'Select Substation',
                  ),
                ),
                itemAsString: (s) => s.name,
                selectedItem: _selectedSubstation,
                items: _substationsInSubdivision,
                onChanged: (value) {
                  setState(() {
                    _selectedSubstation = value;
                    _selectedBay = null;
                    if (value != null) {
                      _fetchBaysForSelectedSubstation(value.id);
                    }
                  });
                },
                validator: (value) =>
                    value == null ? 'Substation is mandatory' : null,
              ),
            const SizedBox(height: 16),

            // Bay Selection (if scope is bay)
            if (_selectedScope == ExportScope.bay)
              DropdownSearch<Bay>(
                popupProps: PopupProps.menu(showSearchBox: true),
                dropdownDecoratorProps: DropDownDecoratorProps(
                  dropdownSearchDecoration: InputDecoration(
                    labelText: 'Select Bay',
                  ),
                ),
                itemAsString: (b) => b.name,
                selectedItem: _selectedBay,
                items: _baysInSelectedSubstation,
                onChanged: (value) {
                  setState(() {
                    _selectedBay = value;
                  });
                },
                validator: (value) => value == null ? 'Bay is mandatory' : null,
              ),
            const SizedBox(height: 24),

            // Data Type to Export
            Text(
              'Select Data Type to Export:',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Column(
              children: DataTypeToExport.values.map((type) {
                return ListTile(
                  title: Text(
                    type
                        .toString()
                        .split('.')
                        .last
                        .replaceAllMapped(
                          RegExp(r'(?<=[a-z])[A-Z]'),
                          (match) => ' ${match.group(0)}',
                        ),
                  ),
                  leading: Radio<DataTypeToExport>(
                    value: type,
                    groupValue: _selectedDataType,
                    onChanged: (DataTypeToExport? value) {
                      setState(() {
                        _selectedDataType = value!;
                        _selectedEquipmentTemplateForFilter =
                            null; // Clear equipment template filter
                        _customFieldFilterValues
                            .clear(); // Clear custom field filters
                      });
                    },
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),

            // Equipment Type Filter (only for Equipment Instances)
            if (_selectedDataType == DataTypeToExport.equipmentInstances) ...[
              Text(
                'Filter Equipment Instances (Optional):',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 10),
              DropdownSearch<MasterEquipmentTemplate>(
                popupProps: PopupProps.menu(showSearchBox: true),
                dropdownDecoratorProps: DropDownDecoratorProps(
                  dropdownSearchDecoration: InputDecoration(
                    labelText: 'Filter by Equipment Type',
                  ),
                ),
                itemAsString: (t) => t.equipmentType,
                selectedItem: _selectedEquipmentTemplateForFilter,
                items: _equipmentTemplates,
                onChanged: (value) {
                  setState(() {
                    _selectedEquipmentTemplateForFilter = value;
                    _customFieldFilterValues
                        .clear(); // Clear custom field values when template changes
                  });
                },
              ),
              const SizedBox(height: 16),
              // Placeholder for Dynamic Custom Field Filtering UI (Complex)
              if (_selectedEquipmentTemplateForFilter != null &&
                  _selectedEquipmentTemplateForFilter!
                      .equipmentCustomFields
                      .isNotEmpty)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Filter by Custom Field Values:',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 8),
                    Card(
                      elevation: 1,
                      color: Theme.of(
                        context,
                      ).colorScheme.surfaceVariant.withOpacity(0.5),
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Text(
                          'Dynamic custom field filtering UI goes here. (Complex to implement dynamically).',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 16),
            ],

            // Date Range Filter (applies to Equipment Instances export by default, can be extended)
            Text(
              'Filter by Creation Date (Optional):',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: ListTile(
                    title: Text(
                      _startDate == null
                          ? 'Start Date'
                          : 'Start: ${_formatDate(_startDate)}',
                    ),
                    trailing: const Icon(Icons.calendar_today),
                    onTap: () => _selectDate(context, true),
                  ),
                ),
                Expanded(
                  child: ListTile(
                    title: Text(
                      _endDate == null
                          ? 'End Date'
                          : 'End: ${_formatDate(_endDate)}',
                    ),
                    trailing: const Icon(Icons.calendar_today),
                    onTap: () => _selectDate(context, false),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),

            Center(
              child: _isGeneratingReport
                  ? const CircularProgressIndicator()
                  : ElevatedButton.icon(
                      onPressed: _generateAndShareReport,
                      icon: const Icon(Icons.download),
                      label: const Text('Generate & Share CSV'),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 50),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
