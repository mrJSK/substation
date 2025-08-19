// lib/screens/export_master_data_screen.dart

import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:csv/csv.dart';
import 'package:dropdown_search/dropdown_search.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/bay_model.dart';
import '../models/equipment_model.dart';
import '../models/hierarchy_models.dart';
import '../models/user_model.dart';
import '../utils/snackbar_utils.dart';

enum ExportDataType { equipment, bays, substations }

class ExportMasterDataScreen extends StatefulWidget {
  final AppUser currentUser;
  final String? subdivisionId;

  const ExportMasterDataScreen({
    super.key,
    required this.currentUser,
    this.subdivisionId,
  });

  static const routeName = '/export-master-data';

  @override
  State<ExportMasterDataScreen> createState() => _ExportMasterDataScreenState();
}

class _ExportMasterDataScreenState extends State<ExportMasterDataScreen> {
  bool _isLoading = true;
  bool _isGeneratingReport = false;
  ExportDataType _selectedDataType = ExportDataType.equipment;

  AppScreenState? _selectedState;
  Company? _selectedCompany;
  Zone? _selectedZone;
  Circle? _selectedCircle;
  Division? _selectedDivision;
  Subdivision? _selectedSubdivision;
  Substation? _selectedSubstation;

  List<MasterEquipmentTemplate> _selectedEquipmentTypes = [];
  List<String> _selectedVoltageLevels = [];
  DateTime? _startDate;
  DateTime? _endDate;

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

  String _getStartingHierarchyLevel() {
    switch (widget.currentUser.role) {
      case UserRole.admin:
      case UserRole.superAdmin:
        return 'state';
      case UserRole.stateManager:
        return 'company';
      case UserRole.companyManager:
        return 'zone';
      case UserRole.zoneManager:
        return 'circle';
      case UserRole.circleManager:
        return 'division';
      case UserRole.divisionManager:
        return 'subdivision';
      case UserRole.subdivisionManager:
        return 'substation';
      case UserRole.substationUser:
        return 'substation';
      case UserRole.pending:
        throw UnimplementedError();
    }
  }

  String? _getUserAssignedId() {
    final assignedLevels = widget.currentUser.assignedLevels;
    if (assignedLevels == null) return null;

    switch (widget.currentUser.role) {
      case UserRole.stateManager:
        return assignedLevels['stateId'];
      case UserRole.companyManager:
        return assignedLevels['companyId'];
      case UserRole.zoneManager:
        return assignedLevels['zoneId'];
      case UserRole.circleManager:
        return assignedLevels['circleId'];
      case UserRole.divisionManager:
        return assignedLevels['divisionId'];
      case UserRole.subdivisionManager:
        return assignedLevels['subdivisionId'] ?? widget.subdivisionId;
      case UserRole.substationUser:
        return assignedLevels['substationId'];
      case UserRole.admin:
      case UserRole.superAdmin:
        return null;
      case UserRole.pending:
        throw UnimplementedError();
    }
  }

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

      await _autoSelectUserLevel();
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

  Future<void> _autoSelectUserLevel() async {
    final assignedId = _getUserAssignedId();
    if (assignedId == null) return;

    try {
      switch (widget.currentUser.role) {
        case UserRole.stateManager:
          final doc = await FirebaseFirestore.instance
              .collection('appScreenStates')
              .doc(assignedId)
              .get();
          if (doc.exists) {
            _selectedState = AppScreenState.fromFirestore(doc);
          }
          break;
        case UserRole.companyManager:
          final doc = await FirebaseFirestore.instance
              .collection('companies')
              .doc(assignedId)
              .get();
          if (doc.exists) {
            _selectedCompany = Company.fromFirestore(doc);
          }
          break;
        case UserRole.zoneManager:
          final doc = await FirebaseFirestore.instance
              .collection('zones')
              .doc(assignedId)
              .get();
          if (doc.exists) {
            _selectedZone = Zone.fromFirestore(doc);
          }
          break;
        case UserRole.circleManager:
          final doc = await FirebaseFirestore.instance
              .collection('circles')
              .doc(assignedId)
              .get();
          if (doc.exists) {
            _selectedCircle = Circle.fromFirestore(doc);
          }
          break;
        case UserRole.divisionManager:
          final doc = await FirebaseFirestore.instance
              .collection('divisions')
              .doc(assignedId)
              .get();
          if (doc.exists) {
            _selectedDivision = Division.fromFirestore(doc);
          }
          break;
        case UserRole.subdivisionManager:
          final doc = await FirebaseFirestore.instance
              .collection('subdivisions')
              .doc(assignedId)
              .get();
          if (doc.exists) {
            _selectedSubdivision = Subdivision.fromFirestore(doc);
          }
          break;
        case UserRole.substationUser:
          final doc = await FirebaseFirestore.instance
              .collection('substations')
              .doc(assignedId)
              .get();
          if (doc.exists) {
            _selectedSubstation = Substation.fromFirestore(doc);
          }
          break;
        case UserRole.admin:
        case UserRole.superAdmin:
          break;
        case UserRole.pending:
          throw UnimplementedError();
      }
    } catch (e) {
      print("Error auto-selecting user level: $e");
    }
  }

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
    List<List<dynamic>> rows = [];

    rows.add([
      'Equipment ID',
      'Name',
      'Type',
      'Bay Name',
      'Bay Type',
      'Voltage Level',
      'Substation',
      'Subdivision',
      'Division',
      'Circle',
      'Zone',
      'Status',
      'Created At',
    ]);

    List<String> substationIds = await _getSubstationIds();
    if (substationIds.isEmpty) {
      SnackBarUtils.showSnackBar(
        context,
        'No substations found for the selected criteria.',
        isError: true,
      );
      return;
    }

    for (int i = 0; i < substationIds.length; i += 10) {
      final chunk = substationIds.sublist(
        i,
        i + 10 > substationIds.length ? substationIds.length : i + 10,
      );

      final baysSnapshot = await FirebaseFirestore.instance
          .collection('bays')
          .where('substationId', whereIn: chunk)
          .get();

      final bays = baysSnapshot.docs
          .map((doc) => Bay.fromFirestore(doc))
          .toList();

      if (_selectedVoltageLevels.isNotEmpty) {
        bays.retainWhere(
          (bay) => _selectedVoltageLevels.contains(bay.voltageLevel),
        );
      }

      if (bays.isNotEmpty) {
        final bayIds = bays.map((bay) => bay.id).toList();

        for (int j = 0; j < bayIds.length; j += 10) {
          final bayChunk = bayIds.sublist(
            j,
            j + 10 > bayIds.length ? bayIds.length : j + 10,
          );

          Query equipmentQuery = FirebaseFirestore.instance
              .collection('equipmentInstances')
              .where('bayId', whereIn: bayChunk);

          if (_selectedEquipmentTypes.isNotEmpty) {
            final equipmentTypeNames = _selectedEquipmentTypes
                .map((template) => template.equipmentType)
                .toList();
            equipmentQuery = equipmentQuery.where(
              'equipmentTypeName',
              whereIn: equipmentTypeNames,
            );
          }

          if (_startDate != null) {
            equipmentQuery = equipmentQuery.where(
              'createdAt',
              isGreaterThanOrEqualTo: Timestamp.fromDate(_startDate!),
            );
          }

          if (_endDate != null) {
            equipmentQuery = equipmentQuery.where(
              'createdAt',
              isLessThanOrEqualTo: Timestamp.fromDate(_endDate!),
            );
          }

          final equipmentSnapshot = await equipmentQuery.get();
          final equipment = equipmentSnapshot.docs
              .map((doc) => EquipmentInstance.fromFirestore(doc))
              .toList();

          for (final eq in equipment) {
            final bay = bays.firstWhere((b) => b.id == eq.bayId);
            final substationInfo = await _getSubstationHierarchyInfo(
              bay.substationId,
            );

            rows.add([
              eq.id,
              eq.equipmentTypeName,
              bay.name,
              bay.bayType,
              bay.voltageLevel,
              substationInfo['substationName'],
              substationInfo['subdivisionName'],
              substationInfo['divisionName'],
              substationInfo['circleName'],
              substationInfo['zoneName'],
              eq.status,
              eq.createdAt.toDate().toString(),
            ]);
          }
        }
      }
    }

    await _saveAndShareCsv(rows, 'equipment_report');
  }

  Future<void> _generateBaysReport() async {
    List<List<dynamic>> rows = [];

    rows.add([
      'Bay ID',
      'Bay Name',
      'Bay Type',
      'Voltage Level',
      'Substation',
      'Subdivision',
      'Division',
      'Circle',
      'Zone',
      'Equipment Count',
      'Multiplying Factor',
      'Created At',
    ]);

    List<String> substationIds = await _getSubstationIds();
    if (substationIds.isEmpty) {
      SnackBarUtils.showSnackBar(
        context,
        'No substations found for the selected criteria.',
        isError: true,
      );
      return;
    }

    for (int i = 0; i < substationIds.length; i += 10) {
      final chunk = substationIds.sublist(
        i,
        i + 10 > substationIds.length ? substationIds.length : i + 10,
      );

      Query baysQuery = FirebaseFirestore.instance
          .collection('bays')
          .where('substationId', whereIn: chunk);

      final baysSnapshot = await baysQuery.get();
      final bays = baysSnapshot.docs
          .map((doc) => Bay.fromFirestore(doc))
          .toList();

      if (_selectedVoltageLevels.isNotEmpty) {
        bays.retainWhere(
          (bay) => _selectedVoltageLevels.contains(bay.voltageLevel),
        );
      }

      for (final bay in bays) {
        final equipmentSnapshot = await FirebaseFirestore.instance
            .collection('equipmentInstances')
            .where('bayId', isEqualTo: bay.id)
            .get();

        final substationInfo = await _getSubstationHierarchyInfo(
          bay.substationId,
        );

        rows.add([
          bay.id,
          bay.name,
          bay.bayType,
          bay.voltageLevel,
          substationInfo['substationName'],
          substationInfo['subdivisionName'],
          substationInfo['divisionName'],
          substationInfo['circleName'],
          substationInfo['zoneName'],
          equipmentSnapshot.docs.length,
          bay.multiplyingFactor?.toString() ?? 'N/A',
          bay.createdAt.toDate().toString(),
        ]);
      }
    }

    await _saveAndShareCsv(rows, 'bays_report');
  }

  Future<void> _generateSubstationsReport() async {
    List<List<dynamic>> rows = [];

    rows.add([
      'Substation ID',
      'Substation Name',
      'Voltage Level',
      'Subdivision',
      'Division',
      'Circle',
      'Zone',
      'Bay Count',
      'Equipment Count',
      'Created At',
    ]);

    List<String> substationIds = await _getSubstationIds();
    if (substationIds.isEmpty) {
      SnackBarUtils.showSnackBar(
        context,
        'No substations found for the selected criteria.',
        isError: true,
      );
      return;
    }

    for (final substationId in substationIds) {
      final substationDoc = await FirebaseFirestore.instance
          .collection('substations')
          .doc(substationId)
          .get();

      if (substationDoc.exists) {
        final substation = Substation.fromFirestore(substationDoc);

        final baysSnapshot = await FirebaseFirestore.instance
            .collection('bays')
            .where('substationId', isEqualTo: substationId)
            .get();

        final equipmentSnapshot = await FirebaseFirestore.instance
            .collection('equipmentInstances')
            .where(
              'bayId',
              whereIn: baysSnapshot.docs.map((doc) => doc.id).toList(),
            )
            .get();

        final substationInfo = await _getSubstationHierarchyInfo(substationId);

        rows.add([
          substation.id,
          substation.name,
          substation.voltageLevel,
          substationInfo['subdivisionName'],
          substationInfo['divisionName'],
          substationInfo['circleName'],
          substationInfo['zoneName'],
          baysSnapshot.docs.length,
          equipmentSnapshot.docs.length,
          substation.createdAt?.toDate().toString() ?? 'N/A',
        ]);
      }
    }

    await _saveAndShareCsv(rows, 'substations_report');
  }

  Future<List<String>> _getSubstationIds() async {
    if (_selectedSubstation != null) {
      return [_selectedSubstation!.id];
    }

    String? parentId;
    String? parentField;

    if (_selectedSubdivision != null) {
      parentId = _selectedSubdivision!.id;
      parentField = 'subdivisionId';
    } else if (_selectedDivision != null) {
      final subdivisionsSnapshot = await FirebaseFirestore.instance
          .collection('subdivisions')
          .where('divisionId', isEqualTo: _selectedDivision!.id)
          .get();

      if (subdivisionsSnapshot.docs.isEmpty) return [];

      final subdivisionIds = subdivisionsSnapshot.docs
          .map((doc) => doc.id)
          .toList();

      final substationsSnapshot = await FirebaseFirestore.instance
          .collection('substations')
          .where('subdivisionId', whereIn: subdivisionIds)
          .get();

      return substationsSnapshot.docs.map((doc) => doc.id).toList();
    } else if (_selectedCircle != null) {
      final divisionsSnapshot = await FirebaseFirestore.instance
          .collection('divisions')
          .where('circleId', isEqualTo: _selectedCircle!.id)
          .get();

      if (divisionsSnapshot.docs.isEmpty) return [];

      final divisionIds = divisionsSnapshot.docs.map((doc) => doc.id).toList();

      List<String> subdivisionIds = [];
      for (int i = 0; i < divisionIds.length; i += 10) {
        final chunk = divisionIds.sublist(
          i,
          i + 10 > divisionIds.length ? divisionIds.length : i + 10,
        );

        final subdivisionsSnapshot = await FirebaseFirestore.instance
            .collection('subdivisions')
            .where('divisionId', whereIn: chunk)
            .get();

        subdivisionIds.addAll(subdivisionsSnapshot.docs.map((doc) => doc.id));
      }

      if (subdivisionIds.isEmpty) return [];

      List<String> substationIds = [];
      for (int i = 0; i < subdivisionIds.length; i += 10) {
        final chunk = subdivisionIds.sublist(
          i,
          i + 10 > subdivisionIds.length ? subdivisionIds.length : i + 10,
        );

        final substationsSnapshot = await FirebaseFirestore.instance
            .collection('substations')
            .where('subdivisionId', whereIn: chunk)
            .get();

        substationIds.addAll(substationsSnapshot.docs.map((doc) => doc.id));
      }

      return substationIds;
    }

    if (parentId != null && parentField != null) {
      final substationsSnapshot = await FirebaseFirestore.instance
          .collection('substations')
          .where(parentField, isEqualTo: parentId)
          .get();

      return substationsSnapshot.docs.map((doc) => doc.id).toList();
    }

    return [];
  }

  Future<Map<String, String>> _getSubstationHierarchyInfo(
    String substationId,
  ) async {
    try {
      final substationDoc = await FirebaseFirestore.instance
          .collection('substations')
          .doc(substationId)
          .get();

      if (!substationDoc.exists) {
        return {
          'substationName': 'Unknown',
          'subdivisionName': 'Unknown',
          'divisionName': 'Unknown',
          'circleName': 'Unknown',
          'zoneName': 'Unknown',
        };
      }

      final substation = Substation.fromFirestore(substationDoc);
      Map<String, String> info = {
        'substationName': substation.name,
        'subdivisionName': 'Unknown',
        'divisionName': 'Unknown',
        'circleName': 'Unknown',
        'zoneName': 'Unknown',
      };

      final subdivisionDoc = await FirebaseFirestore.instance
          .collection('subdivisions')
          .doc(substation.subdivisionId)
          .get();

      if (subdivisionDoc.exists) {
        final subdivision = Subdivision.fromFirestore(subdivisionDoc);
        info['subdivisionName'] = subdivision.name;

        final divisionDoc = await FirebaseFirestore.instance
            .collection('divisions')
            .doc(subdivision.divisionId)
            .get();

        if (divisionDoc.exists) {
          final division = Division.fromFirestore(divisionDoc);
          info['divisionName'] = division.name;

          final circleDoc = await FirebaseFirestore.instance
              .collection('circles')
              .doc(division.circleId)
              .get();

          if (circleDoc.exists) {
            final circle = Circle.fromFirestore(circleDoc);
            info['circleName'] = circle.name;

            final zoneDoc = await FirebaseFirestore.instance
                .collection('zones')
                .doc(circle.zoneId)
                .get();

            if (zoneDoc.exists) {
              final zone = Zone.fromFirestore(zoneDoc);
              info['zoneName'] = zone.name;
            }
          }
        }
      }

      return info;
    } catch (e) {
      print("Error getting substation hierarchy info: $e");
      return {
        'substationName': 'Error',
        'subdivisionName': 'Error',
        'divisionName': 'Error',
        'circleName': 'Error',
        'zoneName': 'Error',
      };
    }
  }

  Future<void> _saveAndShareCsv(
    List<List<dynamic>> rows,
    String fileName,
  ) async {
    if (rows.length <= 1) {
      SnackBarUtils.showSnackBar(
        context,
        'No data available to export.',
        isError: true,
      );
      return;
    }

    try {
      String csv = const ListToCsvConverter().convert(rows);

      final directory = await getApplicationDocumentsDirectory();
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final file = File('${directory.path}/${fileName}_$timestamp.csv');

      await file.writeAsString(csv);

      await Share.shareXFiles([XFile(file.path)], text: 'Master Data Export');

      if (mounted) {
        SnackBarUtils.showSnackBar(
          context,
          'Report generated successfully! ${rows.length - 1} records exported.',
          isError: false,
        );
      }
    } catch (e) {
      print("Error saving CSV: $e");
      if (mounted) {
        SnackBarUtils.showSnackBar(
          context,
          'Failed to generate CSV file: $e',
          isError: true,
        );
      }
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
      appBar: _buildAppBar(theme),
      body: _isLoading
          ? _buildLoadingState(theme)
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeaderSection(theme),
                  const SizedBox(height: 20),
                  _buildDataTypeSelector(theme),
                  const SizedBox(height: 20),
                  _buildHierarchySelectors(theme),
                  const SizedBox(height: 20),
                  if (_selectedDataType == ExportDataType.equipment) ...[
                    _buildFilterSelectors(theme),
                    const SizedBox(height: 20),
                  ],
                  _buildGenerateButton(theme),
                ],
              ),
            ),
    );
  }

  PreferredSizeWidget _buildAppBar(ThemeData theme) {
    final isDarkMode = theme.brightness == Brightness.dark;

    return AppBar(
      backgroundColor: isDarkMode ? const Color(0xFF2C2C2E) : Colors.white,
      elevation: 0,
      title: Text(
        'Export Master Data',
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: isDarkMode ? Colors.white : theme.colorScheme.onSurface,
        ),
      ),
      leading: IconButton(
        icon: Icon(
          Icons.arrow_back,
          color: isDarkMode ? Colors.white : theme.colorScheme.onSurface,
        ),
        onPressed: () => Navigator.of(context).pop(),
      ),
    );
  }

  Widget _buildLoadingState(ThemeData theme) {
    final isDarkMode = theme.brightness == Brightness.dark;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 60,
            height: 60,
            child: CircularProgressIndicator(
              strokeWidth: 4,
              valueColor: AlwaysStoppedAnimation(theme.colorScheme.primary),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Loading Export Options',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: isDarkMode
                  ? Colors.white.withOpacity(0.7)
                  : theme.colorScheme.onSurface.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderSection(ThemeData theme) {
    final isDarkMode = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF2C2C2E) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: isDarkMode
                ? Colors.black.withOpacity(0.3)
                : Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.green, Colors.green.withOpacity(0.7)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.download, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Export Master Data',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Generate comprehensive CSV reports of your assets',
                  style: TextStyle(
                    fontSize: 13,
                    color: isDarkMode
                        ? Colors.white.withOpacity(0.6)
                        : Colors.grey.shade600,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDataTypeSelector(ThemeData theme) {
    final isDarkMode = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF2C2C2E) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: isDarkMode
                ? Colors.black.withOpacity(0.3)
                : Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Select Data to Export',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: isDarkMode ? Colors.white : theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<ExportDataType>(
            value: _selectedDataType,
            decoration: InputDecoration(
              labelText: 'Data Type',
              labelStyle: TextStyle(
                color: isDarkMode
                    ? Colors.white.withOpacity(0.6)
                    : Colors.grey.shade700,
              ),
              prefixIcon: Icon(
                Icons.source,
                color: isDarkMode
                    ? Colors.white.withOpacity(0.6)
                    : Colors.grey.shade600,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(
                  color: isDarkMode
                      ? Colors.white.withOpacity(0.3)
                      : Colors.grey.shade300,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(
                  color: isDarkMode
                      ? Colors.white.withOpacity(0.3)
                      : Colors.grey.shade300,
                ),
              ),
              filled: true,
              fillColor: isDarkMode
                  ? const Color(0xFF3C3C3E)
                  : Colors.grey.shade50,
            ),
            dropdownColor: isDarkMode ? const Color(0xFF2C2C2E) : null,
            style: TextStyle(color: isDarkMode ? Colors.white : Colors.black87),
            items: ExportDataType.values.map((type) {
              String displayName =
                  type.name[0].toUpperCase() + type.name.substring(1);
              return DropdownMenuItem(
                value: type,
                child: Text(
                  displayName,
                  style: TextStyle(
                    fontSize: 14,
                    color: isDarkMode ? Colors.white : Colors.black87,
                  ),
                ),
              );
            }).toList(),
            onChanged: (ExportDataType? newValue) {
              if (newValue != null) {
                setState(() => _selectedDataType = newValue);
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildHierarchySelectors(ThemeData theme) {
    final isDarkMode = theme.brightness == Brightness.dark;
    final startingLevel = _getStartingHierarchyLevel();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF2C2C2E) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: isDarkMode
                ? Colors.black.withOpacity(0.3)
                : Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Select Export Scope',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: isDarkMode ? Colors.white : theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 16),

          if (['state'].contains(startingLevel)) ...[
            _buildHierarchyDropdown<AppScreenState>(
              collection: 'appScreenStates',
              label: 'State',
              icon: Icons.flag,
              selectedItem: _selectedState,
              itemAsString: (state) => state.name,
              onChanged: (state) => setState(() {
                _selectedState = state;
                _selectedCompany = null;
                _selectedZone = null;
                _selectedCircle = null;
                _selectedDivision = null;
                _selectedSubdivision = null;
                _selectedSubstation = null;
              }),
              fromFirestore: (doc) => AppScreenState.fromFirestore(doc),
            ),
            const SizedBox(height: 16),
          ],

          if (['state', 'company'].contains(startingLevel) ||
              _selectedState != null) ...[
            _buildHierarchyDropdown<Company>(
              collection: 'companies',
              label: 'Company',
              icon: Icons.business,
              selectedItem: _selectedCompany,
              itemAsString: (company) => company.name,
              parentId: startingLevel == 'company'
                  ? _getUserAssignedId()
                  : _selectedState?.id,
              parentField: 'stateId',
              onChanged: (company) => setState(() {
                _selectedCompany = company;
                _selectedZone = null;
                _selectedCircle = null;
                _selectedDivision = null;
                _selectedSubdivision = null;
                _selectedSubstation = null;
              }),
              fromFirestore: (doc) => Company.fromFirestore(doc),
              enabled: startingLevel == 'company' || _selectedState != null,
            ),
            const SizedBox(height: 16),
          ],

          if (['state', 'company', 'zone'].contains(startingLevel) ||
              _selectedCompany != null) ...[
            _buildHierarchyDropdown<Zone>(
              collection: 'zones',
              label: 'Zone',
              icon: Icons.public,
              selectedItem: _selectedZone,
              itemAsString: (zone) => zone.name,
              parentId: startingLevel == 'zone'
                  ? _getUserAssignedId()
                  : _selectedCompany?.id,
              parentField: 'companyId',
              onChanged: (zone) => setState(() {
                _selectedZone = zone;
                _selectedCircle = null;
                _selectedDivision = null;
                _selectedSubdivision = null;
                _selectedSubstation = null;
              }),
              fromFirestore: (doc) => Zone.fromFirestore(doc),
              enabled: startingLevel == 'zone' || _selectedCompany != null,
            ),
            const SizedBox(height: 16),
          ],

          if (['zone', 'circle'].contains(startingLevel) ||
              _selectedZone != null) ...[
            _buildHierarchyDropdown<Circle>(
              collection: 'circles',
              label: 'Circle',
              icon: Icons.circle_outlined,
              selectedItem: _selectedCircle,
              itemAsString: (circle) => circle.name,
              parentId: startingLevel == 'circle'
                  ? _getUserAssignedId()
                  : _selectedZone?.id,
              parentField: 'zoneId',
              onChanged: (circle) => setState(() {
                _selectedCircle = circle;
                _selectedDivision = null;
                _selectedSubdivision = null;
                _selectedSubstation = null;
              }),
              fromFirestore: (doc) => Circle.fromFirestore(doc),
              enabled: startingLevel == 'circle' || _selectedZone != null,
            ),
            const SizedBox(height: 16),
          ],

          if (['circle', 'division'].contains(startingLevel) ||
              _selectedCircle != null) ...[
            _buildHierarchyDropdown<Division>(
              collection: 'divisions',
              label: 'Division',
              icon: Icons.business,
              selectedItem: _selectedDivision,
              itemAsString: (division) => division.name,
              parentId: startingLevel == 'division'
                  ? _getUserAssignedId()
                  : _selectedCircle?.id,
              parentField: 'circleId',
              onChanged: (division) => setState(() {
                _selectedDivision = division;
                _selectedSubdivision = null;
                _selectedSubstation = null;
              }),
              fromFirestore: (doc) => Division.fromFirestore(doc),
              enabled: startingLevel == 'division' || _selectedCircle != null,
            ),
            const SizedBox(height: 16),
          ],

          if (['division', 'subdivision'].contains(startingLevel) ||
              _selectedDivision != null) ...[
            _buildHierarchyDropdown<Subdivision>(
              collection: 'subdivisions',
              label: 'Subdivision',
              icon: Icons.apartment,
              selectedItem: _selectedSubdivision,
              itemAsString: (subdivision) => subdivision.name,
              parentId: startingLevel == 'subdivision'
                  ? _getUserAssignedId()
                  : _selectedDivision?.id,
              parentField: 'divisionId',
              onChanged: (subdivision) => setState(() {
                _selectedSubdivision = subdivision;
                _selectedSubstation = null;
              }),
              fromFirestore: (doc) => Subdivision.fromFirestore(doc),
              enabled:
                  startingLevel == 'subdivision' || _selectedDivision != null,
            ),
            const SizedBox(height: 16),
          ],

          if (['subdivision', 'substation'].contains(startingLevel) ||
              _selectedSubdivision != null) ...[
            _buildHierarchyDropdown<Substation>(
              collection: 'substations',
              label: 'Substation',
              icon: Icons.electrical_services,
              selectedItem: _selectedSubstation,
              itemAsString: (substation) => substation.name,
              parentId: startingLevel == 'substation'
                  ? _getUserAssignedId()
                  : _selectedSubdivision?.id,
              parentField: 'subdivisionId',
              onChanged: (substation) => setState(() {
                _selectedSubstation = substation;
              }),
              fromFirestore: (doc) => Substation.fromFirestore(doc),
              enabled:
                  startingLevel == 'substation' || _selectedSubdivision != null,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildHierarchyDropdown<T extends HierarchyItem>({
    required String collection,
    required String label,
    required IconData icon,
    required T? selectedItem,
    required String Function(T) itemAsString,
    required void Function(T?) onChanged,
    required T Function(DocumentSnapshot) fromFirestore,
    String? parentId,
    String? parentField,
    bool enabled = true,
  }) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return DropdownSearch<T>(
      popupProps: PopupProps.menu(
        showSearchBox: true,
        menuProps: MenuProps(
          backgroundColor: isDarkMode ? const Color(0xFF2C2C2E) : null,
          borderRadius: BorderRadius.circular(10),
        ),
        searchFieldProps: TextFieldProps(
          style: TextStyle(color: isDarkMode ? Colors.white : Colors.black87),
          decoration: InputDecoration(
            labelText: 'Search $label',
            labelStyle: TextStyle(
              color: isDarkMode
                  ? Colors.white.withOpacity(0.6)
                  : Colors.grey.shade700,
            ),
            prefixIcon: Icon(
              Icons.search,
              color: isDarkMode
                  ? Colors.white.withOpacity(0.6)
                  : Colors.grey.shade600,
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            filled: true,
            fillColor: isDarkMode
                ? const Color(0xFF3C3C3E)
                : Colors.grey.shade50,
          ),
        ),
      ),
      dropdownDecoratorProps: DropDownDecoratorProps(
        dropdownSearchDecoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(
            color: isDarkMode
                ? Colors.white.withOpacity(0.6)
                : Colors.grey.shade700,
          ),
          prefixIcon: Icon(
            icon,
            color: isDarkMode
                ? Colors.white.withOpacity(0.6)
                : Colors.grey.shade600,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(
              color: isDarkMode
                  ? Colors.white.withOpacity(0.3)
                  : Colors.grey.shade300,
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(
              color: isDarkMode
                  ? Colors.white.withOpacity(0.3)
                  : Colors.grey.shade300,
            ),
          ),
          filled: true,
          fillColor: enabled
              ? (isDarkMode ? const Color(0xFF3C3C3E) : Colors.grey.shade50)
              : (isDarkMode ? Colors.grey.shade800 : Colors.grey.shade100),
        ),
      ),
      asyncItems: (filter) => _fetchHierarchyItems<T>(
        collection,
        fromFirestore,
        filter: filter,
        parentId: parentId,
        parentField: parentField,
      ),
      itemAsString: itemAsString,
      onChanged: enabled ? onChanged : null,
      selectedItem: selectedItem,
      enabled: enabled,
    );
  }

  Future<List<T>> _fetchHierarchyItems<T extends HierarchyItem>(
    String collection,
    T Function(DocumentSnapshot) fromFirestore, {
    required String filter,
    String? parentId,
    String? parentField,
  }) async {
    try {
      Query query = FirebaseFirestore.instance.collection(collection);

      if (parentId != null && parentField != null) {
        query = query.where(parentField, isEqualTo: parentId);
      }

      final snapshot = await query.orderBy('name').get();
      return snapshot.docs
          .map((doc) => fromFirestore(doc))
          .where(
            (item) => item.name.toLowerCase().contains(filter.toLowerCase()),
          )
          .toList();
    } catch (e) {
      print("Error fetching $collection: $e");
      return [];
    }
  }

  Widget _buildFilterSelectors(ThemeData theme) {
    final isDarkMode = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF2C2C2E) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: isDarkMode
                ? Colors.black.withOpacity(0.3)
                : Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Apply Filters (Optional)',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: isDarkMode ? Colors.white : theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 16),

          DropdownSearch<MasterEquipmentTemplate>.multiSelection(
            items: _allEquipmentTemplates,
            popupProps: PopupPropsMultiSelection.menu(
              showSearchBox: true,
              menuProps: MenuProps(
                backgroundColor: isDarkMode ? const Color(0xFF2C2C2E) : null,
                borderRadius: BorderRadius.circular(10),
              ),
              searchFieldProps: TextFieldProps(
                style: TextStyle(
                  color: isDarkMode ? Colors.white : Colors.black87,
                ),
                decoration: InputDecoration(
                  labelText: 'Search Equipment Types',
                  labelStyle: TextStyle(
                    color: isDarkMode
                        ? Colors.white.withOpacity(0.6)
                        : Colors.grey.shade700,
                  ),
                  prefixIcon: Icon(
                    Icons.search,
                    color: isDarkMode
                        ? Colors.white.withOpacity(0.6)
                        : Colors.grey.shade600,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  filled: true,
                  fillColor: isDarkMode
                      ? const Color(0xFF3C3C3E)
                      : Colors.grey.shade50,
                ),
              ),
            ),
            dropdownDecoratorProps: DropDownDecoratorProps(
              dropdownSearchDecoration: InputDecoration(
                labelText: 'Equipment Types',
                labelStyle: TextStyle(
                  color: isDarkMode
                      ? Colors.white.withOpacity(0.6)
                      : Colors.grey.shade700,
                ),
                prefixIcon: Icon(
                  Icons.construction,
                  color: isDarkMode
                      ? Colors.white.withOpacity(0.6)
                      : Colors.grey.shade600,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                    color: isDarkMode
                        ? Colors.white.withOpacity(0.3)
                        : Colors.grey.shade300,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                    color: isDarkMode
                        ? Colors.white.withOpacity(0.3)
                        : Colors.grey.shade300,
                  ),
                ),
                filled: true,
                fillColor: isDarkMode
                    ? const Color(0xFF3C3C3E)
                    : Colors.grey.shade50,
              ),
            ),
            itemAsString: (template) => template.equipmentType,
            onChanged: (data) => setState(() => _selectedEquipmentTypes = data),
            selectedItems: _selectedEquipmentTypes,
          ),
          const SizedBox(height: 16),

          DropdownSearch<String>.multiSelection(
            items: _allVoltageLevels,
            popupProps: PopupPropsMultiSelection.menu(
              showSearchBox: true,
              menuProps: MenuProps(
                backgroundColor: isDarkMode ? const Color(0xFF2C2C2E) : null,
                borderRadius: BorderRadius.circular(10),
              ),
              searchFieldProps: TextFieldProps(
                style: TextStyle(
                  color: isDarkMode ? Colors.white : Colors.black87,
                ),
                decoration: InputDecoration(
                  labelText: 'Search Voltage Levels',
                  labelStyle: TextStyle(
                    color: isDarkMode
                        ? Colors.white.withOpacity(0.6)
                        : Colors.grey.shade700,
                  ),
                  prefixIcon: Icon(
                    Icons.search,
                    color: isDarkMode
                        ? Colors.white.withOpacity(0.6)
                        : Colors.grey.shade600,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  filled: true,
                  fillColor: isDarkMode
                      ? const Color(0xFF3C3C3E)
                      : Colors.grey.shade50,
                ),
              ),
            ),
            dropdownDecoratorProps: DropDownDecoratorProps(
              dropdownSearchDecoration: InputDecoration(
                labelText: 'Bay Voltage Levels',
                labelStyle: TextStyle(
                  color: isDarkMode
                      ? Colors.white.withOpacity(0.6)
                      : Colors.grey.shade700,
                ),
                prefixIcon: Icon(
                  Icons.flash_on,
                  color: isDarkMode
                      ? Colors.white.withOpacity(0.6)
                      : Colors.grey.shade600,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                    color: isDarkMode
                        ? Colors.white.withOpacity(0.3)
                        : Colors.grey.shade300,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                    color: isDarkMode
                        ? Colors.white.withOpacity(0.3)
                        : Colors.grey.shade300,
                  ),
                ),
                filled: true,
                fillColor: isDarkMode
                    ? const Color(0xFF3C3C3E)
                    : Colors.grey.shade50,
              ),
            ),
            onChanged: (data) => setState(() => _selectedVoltageLevels = data),
            selectedItems: _selectedVoltageLevels,
          ),
          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () => _selectDate(context, true),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: isDarkMode
                            ? Colors.white.withOpacity(0.3)
                            : Colors.grey.shade400,
                      ),
                      borderRadius: BorderRadius.circular(8),
                      color: isDarkMode
                          ? const Color(0xFF3C3C3E)
                          : Colors.grey.shade50,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.calendar_today,
                          size: 20,
                          color: isDarkMode
                              ? Colors.white.withOpacity(0.6)
                              : Colors.grey.shade600,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _startDate == null
                                ? 'Start Date'
                                : 'Start: ${_formatDate(_startDate)}',
                            style: TextStyle(
                              fontSize: 14,
                              color: _startDate == null
                                  ? (isDarkMode
                                        ? Colors.white.withOpacity(0.6)
                                        : Colors.grey.shade600)
                                  : (isDarkMode
                                        ? Colors.white
                                        : Colors.black87),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: InkWell(
                  onTap: () => _selectDate(context, false),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: isDarkMode
                            ? Colors.white.withOpacity(0.3)
                            : Colors.grey.shade400,
                      ),
                      borderRadius: BorderRadius.circular(8),
                      color: isDarkMode
                          ? const Color(0xFF3C3C3E)
                          : Colors.grey.shade50,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.calendar_today,
                          size: 20,
                          color: isDarkMode
                              ? Colors.white.withOpacity(0.6)
                              : Colors.grey.shade600,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _endDate == null
                                ? 'End Date'
                                : 'End: ${_formatDate(_endDate)}',
                            style: TextStyle(
                              fontSize: 14,
                              color: _endDate == null
                                  ? (isDarkMode
                                        ? Colors.white.withOpacity(0.6)
                                        : Colors.grey.shade600)
                                  : (isDarkMode
                                        ? Colors.white
                                        : Colors.black87),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGenerateButton(ThemeData theme) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton.icon(
        onPressed: _isGeneratingReport ? null : _generateAndShareReport,
        style: ElevatedButton.styleFrom(
          backgroundColor: theme.colorScheme.primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
        ),
        icon: _isGeneratingReport
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.download, size: 20),
        label: Text(
          _isGeneratingReport ? 'Generating...' : 'Generate & Share CSV',
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
        ),
      ),
    );
  }

  Future<void> _selectDate(BuildContext context, bool isStart) async {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: (isStart ? _startDate : _endDate) ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: theme.copyWith(
            colorScheme: theme.colorScheme.copyWith(
              primary: theme.colorScheme.primary,
              onPrimary: theme.colorScheme.onPrimary,
              surface: isDarkMode
                  ? const Color(0xFF2C2C2E)
                  : theme.colorScheme.surface,
              onSurface: isDarkMode
                  ? Colors.white
                  : theme.colorScheme.onSurface,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startDate = picked;
        } else {
          _endDate = picked;
        }
      });
    }
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'N/A';
    return DateFormat('yyyy-MM-dd').format(date);
  }
}
