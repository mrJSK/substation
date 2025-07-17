// lib/screens/export_master_data_screen.dart
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:csv/csv.dart';
import 'package:dropdown_search/dropdown_search.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../models/bay_model.dart';
import '../../models/equipment_model.dart';
import '../../models/hierarchy_models.dart';
import '../../models/user_model.dart';
import '../../utils/snackbar_utils.dart';

enum ExportDataType { equipment, bays, substations }

class ExportMasterDataScreen extends StatefulWidget {
  final AppUser currentUser;

  const ExportMasterDataScreen({
    super.key,
    required this.currentUser,
    required String subdivisionId,
  });

  @override
  State<ExportMasterDataScreen> createState() => _ExportMasterDataScreenState();
}

class _ExportMasterDataScreenState extends State<ExportMasterDataScreen> {
  // --- State variables for UI and Filtering ---
  bool _isLoading = true;
  bool _isGeneratingReport = false;
  ExportDataType _selectedDataType = ExportDataType.equipment;

  // Hierarchy Selection
  Zone? _selectedZone;
  Circle? _selectedCircle;
  Division? _selectedDivision;
  Subdivision? _selectedSubdivision;
  Substation? _selectedSubstation;

  // Filter Selections
  List<MasterEquipmentTemplate> _selectedEquipmentTypes = [];
  List<String> _selectedVoltageLevels = [];
  DateTime? _startDate;
  DateTime? _endDate;

  // Data for Dropdowns
  List<MasterEquipmentTemplate> _allEquipmentTemplates = [];
  final List<String> _allVoltageLevels = [
    '765kV',
    '400kV',
    '220kV',
    '132kV',
    '33kV',
    '11kV',
  ];

  @override
  void initState() {
    super.initState();
    _fetchInitialData();
  }

  /// Fetches data required for the filter dropdowns, like all equipment templates.
  Future<void> _fetchInitialData() async {
    setState(() => _isLoading = true);
    try {
      final templatesSnapshot = await FirebaseFirestore.instance
          .collection('masterEquipmentTemplates')
          .orderBy('equipmentType')
          .get();
      _allEquipmentTemplates = templatesSnapshot.docs
          .map((doc) => MasterEquipmentTemplate.fromFirestore(doc))
          .toList();
    } catch (e) {
      print("Error fetching initial data: $e");
      if (mounted) {
        SnackBarUtils.showSnackBar(
          context,
          'Failed to load filter options: $e',
          isError: true,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// Main function to trigger the report generation process based on the selected data type.
  Future<void> _generateAndShareReport() async {
    if (_isGeneratingReport) return;
    setState(() => _isGeneratingReport = true);

    try {
      switch (_selectedDataType) {
        case ExportDataType.equipment:
          await _generateEquipmentReport();
          break;
        case ExportDataType.bays:
          await _generateBaysReport();
          break;
        case ExportDataType.substations:
          await _generateSubstationsReport();
          break;
      }
    } catch (e) {
      print("Error generating report: $e");
      if (mounted) {
        SnackBarUtils.showSnackBar(
          context,
          'Failed to generate report: $e',
          isError: true,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isGeneratingReport = false);
      }
    }
  }

  Future<void> _generateEquipmentReport() async {
    // 1. Determine the set of Bay IDs to query based on hierarchy and voltage filters.
    final Map<String, Bay> filteredBays = await _getFilteredBays();
    if (filteredBays.isEmpty) {
      SnackBarUtils.showSnackBar(
        context,
        'No bays found matching the selected criteria.',
        isError: true,
      );
      return;
    }

    // 2. Fetch equipment instances based on the filtered Bay IDs and other filters.
    final List<EquipmentInstance> equipmentInstances =
        await _fetchEquipmentInstances(filteredBays.keys.toList());
    if (equipmentInstances.isEmpty) {
      SnackBarUtils.showSnackBar(
        context,
        'No equipment found matching the selected criteria.',
        isError: true,
      );
      return;
    }

    // 3. Fetch hierarchy details for CSV enrichment.
    final hierarchyData = await _fetchHierarchyData(
      filteredBays.values.toList(),
    );

    // 4. Generate and share the CSV file.
    await _createAndShareCsv(equipmentInstances, filteredBays, hierarchyData);
  }

  Future<void> _generateBaysReport() async {
    final Map<String, Bay> filteredBays = await _getFilteredBays();
    if (filteredBays.isEmpty) {
      SnackBarUtils.showSnackBar(
        context,
        'No bays found for the selected scope.',
        isError: true,
      );
      return;
    }
    final hierarchyData = await _fetchHierarchyData(
      filteredBays.values.toList(),
    );

    List<String> headers = [
      'Bay ID',
      'Bay Name',
      'Voltage Level',
      'Bay Type',
      'Substation',
      'Subdivision',
      'Division',
      'Circle',
      'Zone',
      'Created At',
    ];
    List<List<dynamic>> rows = [headers];

    for (var bay in filteredBays.values) {
      final substation = hierarchyData['substations']?[bay.substationId];
      final subdivision =
          hierarchyData['subdivisions']?[substation?.subdivisionId];
      final division = hierarchyData['divisions']?[subdivision?.divisionId];
      final circle = hierarchyData['circles']?[division?.circleId];
      final zone = hierarchyData['zones']?[circle?.zoneId];

      rows.add([
        bay.id,
        bay.name,
        bay.voltageLevel,
        bay.bayType,
        substation?.name ?? 'N/A',
        subdivision?.name ?? 'N/A',
        division?.name ?? 'N/A',
        circle?.name ?? 'N/A',
        zone?.name ?? 'N/A',
        _formatDate(bay.createdAt.toDate()),
      ]);
    }

    await _exportCsv(rows, 'bays_report');
  }

  Future<void> _generateSubstationsReport() async {
    final substationIds = await _getFilteredSubstationIds();
    if (substationIds.isEmpty) {
      SnackBarUtils.showSnackBar(
        context,
        'No substations found for the selected scope.',
        isError: true,
      );
      return;
    }

    final hierarchyData = await _fetchHierarchyDataForSubstations(
      substationIds,
    );
    final substations = hierarchyData['substations']?.values.toList() ?? [];

    List<String> headers = [
      'Substation ID',
      'Substation Name',
      'Voltage Level',
      'Type',
      'Operation',
      'Subdivision',
      'Division',
      'Circle',
      'Zone',
      'Created At',
    ];
    List<List<dynamic>> rows = [headers];

    for (var substation in substations) {
      final subdivision =
          hierarchyData['subdivisions']?[substation.subdivisionId];
      final division = hierarchyData['divisions']?[subdivision?.divisionId];
      final circle = hierarchyData['circles']?[division?.circleId];
      final zone = hierarchyData['zones']?[circle?.zoneId];

      rows.add([
        substation.id,
        '${substation.voltageLevel} Substation ${substation.name}', // Apply new naming convention
        substation.voltageLevel,
        substation.type,
        substation.operation,
        subdivision?.name ?? 'N/A',
        division?.name ?? 'N/A',
        circle?.name ?? 'N/A',
        zone?.name ?? 'N/A',
        _formatDate(substation.createdAt.toDate()),
      ]);
    }

    await _exportCsv(rows, 'substations_report');
  }

  /// Recursively fetches all substation IDs under a given hierarchy node.
  Future<List<String>> _getAllSubstationIds(
    String parentCollection,
    List<String> parentIds,
  ) async {
    if (parentIds.isEmpty) return [];

    const hierarchy = {
      'zones': {'child': 'circles', 'key': 'zoneId'},
      'circles': {'child': 'divisions', 'key': 'circleId'},
      'divisions': {'child': 'subdivisions', 'key': 'divisionId'},
      'subdivisions': {'child': 'substations', 'key': 'subdivisionId'},
    };

    if (!hierarchy.containsKey(parentCollection)) {
      return parentCollection == 'substations' ? parentIds : [];
    }

    final childInfo = hierarchy[parentCollection]!;
    final snapshot = await FirebaseFirestore.instance
        .collection(childInfo['child']!)
        .where(childInfo['key']!, whereIn: parentIds)
        .get();

    final childIds = snapshot.docs.map((doc) => doc.id).toList();
    if (childIds.isEmpty) return [];

    return _getAllSubstationIds(childInfo['child']!, childIds);
  }

  /// Fetches all Bay documents that match the hierarchy and voltage level filters.
  Future<Map<String, Bay>> _getFilteredBays() async {
    List<String> substationIds = await _getFilteredSubstationIds();
    if (substationIds.isEmpty) return {};

    // Fetch bays belonging to the determined substations
    Query baysQuery = FirebaseFirestore.instance
        .collection('bays')
        .where('substationId', whereIn: substationIds);

    // Apply voltage level filter if selected
    if (_selectedVoltageLevels.isNotEmpty) {
      baysQuery = baysQuery.where(
        'voltageLevel',
        whereIn: _selectedVoltageLevels,
      );
    }

    final baysSnapshot = await baysQuery.get();
    final Map<String, Bay> bayMap = {
      for (var doc in baysSnapshot.docs) doc.id: Bay.fromFirestore(doc),
    };
    return bayMap;
  }

  /// Fetches equipment instances based on bay IDs and equipment type/date filters.
  Future<List<EquipmentInstance>> _fetchEquipmentInstances(
    List<String> bayIds,
  ) async {
    List<EquipmentInstance> instances = [];
    List<String> templateIds = _selectedEquipmentTypes
        .map((t) => t.id!)
        .toList();

    // Firestore `whereIn` queries are limited to 30 elements. Chunk the bayIds.
    for (int i = 0; i < bayIds.length; i += 30) {
      final chunk = bayIds.sublist(
        i,
        i + 30 > bayIds.length ? bayIds.length : i + 30,
      );
      if (chunk.isEmpty) continue;

      Query query = FirebaseFirestore.instance
          .collection('equipmentInstances')
          .where('bayId', whereIn: chunk);

      // Apply equipment type filter
      if (templateIds.isNotEmpty) {
        query = query.where('templateId', whereIn: templateIds);
      }
      // Apply date range filter
      if (_startDate != null) {
        query = query.where(
          'createdAt',
          isGreaterThanOrEqualTo: Timestamp.fromDate(_startDate!),
        );
      }
      if (_endDate != null) {
        final endOfDay = DateTime(
          _endDate!.year,
          _endDate!.month,
          _endDate!.day,
          23,
          59,
          59,
        );
        query = query.where(
          'createdAt',
          isLessThanOrEqualTo: Timestamp.fromDate(endOfDay),
        );
      }

      final snapshot = await query.get();
      instances.addAll(
        snapshot.docs.map((doc) => EquipmentInstance.fromFirestore(doc)),
      );
    }
    return instances;
  }

  /// Fetches all necessary Zone, Circle, Division, and Substation documents for CSV enrichment.
  Future<Map<String, dynamic>> _fetchHierarchyData(List<Bay> bays) async {
    final substationIds = bays.map((b) => b.substationId).toSet().toList();
    return _fetchHierarchyDataForSubstations(substationIds);
  }

  /// Fetches hierarchy data starting from a list of substation IDs.
  Future<Map<String, dynamic>> _fetchHierarchyDataForSubstations(
    List<String> substationIds,
  ) async {
    if (substationIds.isEmpty) return {};

    final substations = await FirebaseFirestore.instance
        .collection('substations')
        .where(FieldPath.documentId, whereIn: substationIds)
        .get();
    final Map<String, Substation> substationMap = {
      for (var doc in substations.docs) doc.id: Substation.fromFirestore(doc),
    };

    final subdivisionIds = substationMap.values
        .map((s) => s.subdivisionId)
        .toSet()
        .toList();
    if (subdivisionIds.isEmpty) return {'substations': substationMap};

    final subdivisions = await FirebaseFirestore.instance
        .collection('subdivisions')
        .where(FieldPath.documentId, whereIn: subdivisionIds)
        .get();
    final Map<String, Subdivision> subdivisionMap = {
      for (var doc in subdivisions.docs) doc.id: Subdivision.fromFirestore(doc),
    };

    final divisionIds = subdivisionMap.values
        .map((s) => s.divisionId)
        .toSet()
        .toList();
    if (divisionIds.isEmpty)
      return {'substations': substationMap, 'subdivisions': subdivisionMap};

    final divisions = await FirebaseFirestore.instance
        .collection('divisions')
        .where(FieldPath.documentId, whereIn: divisionIds)
        .get();
    final Map<String, Division> divisionMap = {
      for (var doc in divisions.docs) doc.id: Division.fromFirestore(doc),
    };

    final circleIds = divisionMap.values
        .map((d) => d.circleId)
        .toSet()
        .toList();
    if (circleIds.isEmpty)
      return {
        'substations': substationMap,
        'subdivisions': subdivisionMap,
        'divisions': divisionMap,
      };

    final circles = await FirebaseFirestore.instance
        .collection('circles')
        .where(FieldPath.documentId, whereIn: circleIds)
        .get();
    final Map<String, Circle> circleMap = {
      for (var doc in circles.docs) doc.id: Circle.fromFirestore(doc),
    };

    final zoneIds = circleMap.values.map((c) => c.zoneId).toSet().toList();
    if (zoneIds.isEmpty)
      return {
        'substations': substationMap,
        'subdivisions': subdivisionMap,
        'divisions': divisionMap,
        'circles': circleMap,
      };

    final zones = await FirebaseFirestore.instance
        .collection('zones')
        .where(FieldPath.documentId, whereIn: zoneIds)
        .get();
    final Map<String, Zone> zoneMap = {
      for (var doc in zones.docs) doc.id: Zone.fromFirestore(doc),
    };

    return {
      'zones': zoneMap,
      'circles': circleMap,
      'divisions': divisionMap,
      'subdivisions': subdivisionMap,
      'substations': substationMap,
    };
  }

  /// Takes the final equipment data and converts it into a shareable CSV file.
  Future<void> _createAndShareCsv(
    List<EquipmentInstance> instances,
    Map<String, Bay> bayMap,
    Map<String, dynamic> hierarchyData,
  ) async {
    // Dynamically generate headers
    Set<String> customFieldHeaders = {};
    for (var eq in instances) {
      final flattened = <String, dynamic>{};
      _flattenCustomFields(eq.customFieldValues, '', flattened);
      customFieldHeaders.addAll(flattened.keys);
    }
    final sortedCustomHeaders = customFieldHeaders.toList()..sort();

    List<String> headers = [
      'Equipment ID',
      'Equipment Type',
      'Status',
      'Zone',
      'Circle',
      'Division',
      'Subdivision',
      'Substation',
      'Bay Name',
      'Bay Voltage',
      'Created At',
      ...sortedCustomHeaders,
    ];

    List<List<dynamic>> rows = [headers];

    // Populate rows
    for (var eq in instances) {
      final bay = bayMap[eq.bayId];
      if (bay == null) continue;

      final substation = hierarchyData['substations']?[bay.substationId];
      final subdivision =
          hierarchyData['subdivisions']?[substation?.subdivisionId];
      final division = hierarchyData['divisions']?[subdivision?.divisionId];
      final circle = hierarchyData['circles']?[division?.circleId];
      final zone = hierarchyData['zones']?[circle?.zoneId];

      final flattened = <String, dynamic>{};
      _flattenCustomFields(eq.customFieldValues, '', flattened);

      List<dynamic> row = [
        eq.id, eq.equipmentTypeName, eq.status,
        zone?.name ?? 'N/A',
        circle?.name ?? 'N/A',
        division?.name ?? 'N/A',
        subdivision?.name ?? 'N/A',
        substation != null
            ? '${substation.voltageLevel} Substation ${substation.name}'
            : 'N/A', // Apply new naming convention
        bay.name,
        bay.voltageLevel,
        _formatDate(eq.createdAt.toDate()),
      ];

      for (var header in sortedCustomHeaders) {
        row.add(flattened[header] ?? '');
      }
      rows.add(row);
    }

    await _exportCsv(rows, 'equipment_report');
  }

  Future<void> _exportCsv(List<List<dynamic>> rows, String reportName) async {
    String csv = const ListToCsvConverter().convert(rows);
    final directory = await getTemporaryDirectory();
    final path =
        '${directory.path}/${reportName}_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.csv';
    final file = File(path);
    await file.writeAsString(csv);

    if (mounted) {
      Share.shareXFiles([XFile(path)], text: 'Exported Master Data');
    }
  }

  Future<List<String>> _getFilteredSubstationIds() async {
    if (_selectedSubstation != null) {
      return [_selectedSubstation!.id];
    } else if (_selectedSubdivision != null) {
      return await _getAllSubstationIds('subdivisions', [
        _selectedSubdivision!.id,
      ]);
    } else if (_selectedDivision != null) {
      return await _getAllSubstationIds('divisions', [_selectedDivision!.id]);
    } else if (_selectedCircle != null) {
      return await _getAllSubstationIds('circles', [_selectedCircle!.id]);
    } else if (_selectedZone != null) {
      return await _getAllSubstationIds('zones', [_selectedZone!.id]);
    } else {
      final allSubstations = await FirebaseFirestore.instance
          .collection('substations')
          .get();
      return allSubstations.docs.map((doc) => doc.id).toList();
    }
  }

  /// Flattens nested maps from custom fields into a single-level map for CSV.
  void _flattenCustomFields(
    Map<String, dynamic> customFields,
    String prefix,
    Map<String, dynamic> flattened,
  ) {
    customFields.forEach((key, value) {
      final newKey = prefix.isEmpty ? key : '${prefix}_$key';
      if (value is Map<String, dynamic>) {
        if (value.containsKey('value') &&
            value.containsKey('description_remarks')) {
          flattened['${newKey}_value'] = value['value'];
          flattened['${newKey}_remarks'] = value['description_remarks'];
        } else {
          _flattenCustomFields(value, newKey, flattened);
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

  String _formatDate(DateTime? date) {
    if (date == null) return 'N/A';
    return DateFormat('yyyy-MM-dd').format(date);
  }

  // --- UI WIDGETS ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Export Master Data')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Select Data to Export',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  _buildDataTypeSelector(),
                  const SizedBox(height: 24),
                  Text(
                    'Select Export Scope',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  _buildHierarchySelectors(),
                  const SizedBox(height: 24),
                  if (_selectedDataType == ExportDataType.equipment) ...[
                    Text(
                      'Apply Filters (Optional)',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 16),
                    _buildFilterSelectors(),
                  ],
                  const SizedBox(height: 32),
                  _buildGenerateButton(),
                ],
              ),
            ),
    );
  }

  Widget _buildDataTypeSelector() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: DropdownButtonFormField<ExportDataType>(
          value: _selectedDataType,
          decoration: _decoratorProps(
            "Data Type",
            Icons.source,
          ).dropdownSearchDecoration,
          items: ExportDataType.values.map((type) {
            return DropdownMenuItem(
              value: type,
              child: Text(type.name[0].toUpperCase() + type.name.substring(1)),
            );
          }).toList(),
          onChanged: (ExportDataType? newValue) {
            if (newValue != null) {
              setState(() => _selectedDataType = newValue);
            }
          },
        ),
      ),
    );
  }

  Widget _buildHierarchySelectors() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Zone
            DropdownSearch<Zone>(
              popupProps: _popupProps("Search Zone"),
              dropdownDecoratorProps: _decoratorProps("Zone", Icons.public),
              asyncItems: (filter) =>
                  _fetchHierarchyItems<Zone>('zones', filter: filter),
              itemAsString: (Zone z) => z.name,
              onChanged: (Zone? data) => setState(() {
                _selectedZone = data;
                _selectedCircle = null;
                _selectedDivision = null;
                _selectedSubdivision = null;
                _selectedSubstation = null;
              }),
              selectedItem: _selectedZone,
            ),
            const SizedBox(height: 16),
            // Circle
            DropdownSearch<Circle>(
              popupProps: _popupProps("Search Circle"),
              dropdownDecoratorProps: _decoratorProps(
                "Circle",
                Icons.circle_outlined,
              ),
              asyncItems: (filter) => _fetchHierarchyItems<Circle>(
                'circles',
                parentId: _selectedZone?.id,
                parentField: 'zoneId',
                filter: filter,
              ),
              itemAsString: (Circle c) => c.name,
              onChanged: (Circle? data) => setState(() {
                _selectedCircle = data;
                _selectedDivision = null;
                _selectedSubdivision = null;
                _selectedSubstation = null;
              }),
              selectedItem: _selectedCircle,
              enabled: _selectedZone != null,
            ),
            const SizedBox(height: 16),
            // Division
            DropdownSearch<Division>(
              popupProps: _popupProps("Search Division"),
              dropdownDecoratorProps: _decoratorProps(
                "Division",
                Icons.business,
              ),
              asyncItems: (filter) => _fetchHierarchyItems<Division>(
                'divisions',
                parentId: _selectedCircle?.id,
                parentField: 'circleId',
                filter: filter,
              ),
              itemAsString: (Division d) => d.name,
              onChanged: (Division? data) => setState(() {
                _selectedDivision = data;
                _selectedSubdivision = null;
                _selectedSubstation = null;
              }),
              selectedItem: _selectedDivision,
              enabled: _selectedCircle != null,
            ),
            const SizedBox(height: 16),
            // Subdivision
            DropdownSearch<Subdivision>(
              popupProps: _popupProps("Search Subdivision"),
              dropdownDecoratorProps: _decoratorProps(
                "Subdivision",
                Icons.apartment,
              ),
              asyncItems: (filter) => _fetchHierarchyItems<Subdivision>(
                'subdivisions',
                parentId: _selectedDivision?.id,
                parentField: 'divisionId',
                filter: filter,
              ),
              itemAsString: (Subdivision s) => s.name,
              onChanged: (Subdivision? data) => setState(() {
                _selectedSubdivision = data;
                _selectedSubstation = null;
              }),
              selectedItem: _selectedSubdivision,
              enabled: _selectedDivision != null,
            ),
            const SizedBox(height: 16),
            // Substation
            DropdownSearch<Substation>(
              popupProps: _popupProps("Search Substation"),
              dropdownDecoratorProps: _decoratorProps(
                "Substation",
                Icons.electrical_services,
              ),
              asyncItems: (filter) => _fetchHierarchyItems<Substation>(
                'substations',
                parentId: _selectedSubdivision?.id,
                parentField: 'subdivisionId',
                filter: filter,
              ),
              itemAsString: (Substation s) => s.name,
              onChanged: (Substation? data) =>
                  setState(() => _selectedSubstation = data),
              selectedItem: _selectedSubstation,
              enabled: _selectedSubdivision != null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterSelectors() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            DropdownSearch<MasterEquipmentTemplate>.multiSelection(
              items: _allEquipmentTemplates,
              popupProps: _popupPropsMulti("Search Equipment Types"),
              dropdownDecoratorProps: _decoratorProps(
                "Equipment Types",
                Icons.construction,
              ),
              itemAsString: (MasterEquipmentTemplate t) => t.equipmentType,
              onChanged: (List<MasterEquipmentTemplate> data) =>
                  setState(() => _selectedEquipmentTypes = data),
              selectedItems: _selectedEquipmentTypes,
            ),
            const SizedBox(height: 16),
            DropdownSearch<String>.multiSelection(
              items: _allVoltageLevels,
              popupProps: _popupPropsMulti("Search Voltage Levels"),
              dropdownDecoratorProps: _decoratorProps(
                "Bay Voltage Levels",
                Icons.flash_on,
              ),
              onChanged: (List<String> data) =>
                  setState(() => _selectedVoltageLevels = data),
              selectedItems: _selectedVoltageLevels,
            ),
            const SizedBox(height: 16),
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
          ],
        ),
      ),
    );
  }

  Widget _buildGenerateButton() {
    return Center(
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
    );
  }

  /// Generic method to fetch items for hierarchy dropdowns.
  Future<List<T>> _fetchHierarchyItems<T extends HierarchyItem>(
    String collection, {
    String? parentId,
    String? parentField,
    required String filter,
  }) async {
    Query query = FirebaseFirestore.instance.collection(collection);
    if (parentId != null && parentField != null) {
      query = query.where(parentField, isEqualTo: parentId);
    }
    final snapshot = await query.orderBy('name').get();

    return snapshot.docs
        .map((doc) {
          switch (T) {
            case Zone:
              return Zone.fromFirestore(doc) as T;
            case Circle:
              return Circle.fromFirestore(doc) as T;
            case Division:
              return Division.fromFirestore(doc) as T;
            case Subdivision:
              return Subdivision.fromFirestore(doc) as T;
            case Substation:
              return Substation.fromFirestore(doc) as T;
            default:
              throw Exception("Unknown hierarchy type");
          }
        })
        .where((item) => item.name.toLowerCase().contains(filter.toLowerCase()))
        .toList();
  }

  PopupProps<T> _popupProps<T>(String hintText) {
    return PopupProps.menu(
      showSearchBox: true,
      menuProps: MenuProps(borderRadius: BorderRadius.circular(10)),
      searchFieldProps: TextFieldProps(
        decoration: InputDecoration(
          labelText: hintText,
          prefixIcon: const Icon(Icons.search),
        ),
      ),
    );
  }

  PopupPropsMultiSelection<T> _popupPropsMulti<T>(String hintText) {
    return PopupPropsMultiSelection.menu(
      showSearchBox: true,
      menuProps: MenuProps(borderRadius: BorderRadius.circular(10)),
      searchFieldProps: TextFieldProps(
        decoration: InputDecoration(
          labelText: hintText,
          prefixIcon: const Icon(Icons.search),
        ),
      ),
    );
  }

  DropDownDecoratorProps _decoratorProps(String label, IconData icon) {
    return DropDownDecoratorProps(
      dropdownSearchDecoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
      ),
    );
  }

  Future<void> _selectDate(BuildContext context, bool isStart) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: (isStart ? _startDate : _endDate) ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        if (isStart)
          _startDate = picked;
        else
          _endDate = picked;
      });
    }
  }
}
