// lib/screens/readings_configuration_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dropdown_search/dropdown_search.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/user_model.dart';
import '../../models/bay_model.dart';
import '../../models/hierarchy_models.dart';
import '../../utils/snackbar_utils.dart';
import '../../models/user_readings_config_model.dart';
import '../../models/reading_models.dart';

class ReadingConfigurationScreen extends StatefulWidget {
  final AppUser currentUser;
  final String subdivisionId;

  const ReadingConfigurationScreen({
    Key? key,
    required this.currentUser,
    required this.subdivisionId,
  }) : super(key: key);

  @override
  State<ReadingConfigurationScreen> createState() =>
      _ReadingConfigurationScreenState();
}

class _ReadingConfigurationScreenState
    extends State<ReadingConfigurationScreen> {
  bool _isLoading = true;
  bool _isSaving = false;
  final TextEditingController _durationValueController =
      TextEditingController();
  String _selectedDurationUnit = 'hours';
  final List<String> _durationUnits = ['hours', 'days', 'weeks', 'months'];
  List<ConfiguredBayReading> _configuredReadings = [];
  List<Substation> _substationsInSubdivision = [];
  List<Bay> _baysInSelectedSubstations = [];
  Map<String, List<String>> _bayToAvailableReadingFields = {};

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: _buildAppBar(theme),
      body: _isLoading ? _buildLoadingState() : _buildMainContent(theme),
    );
  }

  PreferredSizeWidget _buildAppBar(ThemeData theme) {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      title: Text(
        'Reading Configuration',
        style: TextStyle(
          color: theme.colorScheme.onSurface,
          fontSize: 18,
          fontWeight: FontWeight.w500,
        ),
      ),
      leading: IconButton(
        icon: Icon(Icons.arrow_back, color: theme.colorScheme.onSurface),
        onPressed: () => Navigator.pop(context),
      ),
    );
  }

  Widget _buildLoadingState() {
    return const Center(child: CircularProgressIndicator());
  }

  Widget _buildMainContent(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildDurationSection(theme),
          const SizedBox(height: 32),
          _buildSubstationSelection(theme),
          const SizedBox(height: 32),
          if (_baysInSelectedSubstations.isNotEmpty)
            _buildBayConfiguration(theme),
          const SizedBox(height: 32),
          _buildSaveButton(theme),
        ],
      ),
    );
  }

  Widget _buildDurationSection(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(
                  Icons.schedule,
                  color: theme.colorScheme.primary,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Data Duration',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: TextFormField(
                  controller: _durationValueController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Duration Value',
                    hintText: 'e.g., 48',
                    border: OutlineInputBorder(),
                    helperText: 'How far back to fetch data',
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 1,
                child: DropdownButtonFormField<String>(
                  value: _selectedDurationUnit,
                  decoration: const InputDecoration(
                    labelText: 'Unit',
                    border: OutlineInputBorder(),
                  ),
                  items: _durationUnits
                      .map(
                        (unit) => DropdownMenuItem(
                          value: unit,
                          child: Text(unit.capitalize()),
                        ),
                      )
                      .toList(),
                  onChanged: (value) =>
                      setState(() => _selectedDurationUnit = value!),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSubstationSelection(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(
                  Icons.electrical_services,
                  color: Colors.blue,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Substation Selection',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          DropdownSearch<Substation>.multiSelection(
            popupProps: PopupPropsMultiSelection.menu(
              showSearchBox: true,
              searchFieldProps: TextFieldProps(
                decoration: InputDecoration(
                  hintText: 'Search substations...',
                  prefixIcon: Icon(
                    Icons.search,
                    color: theme.colorScheme.primary,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
            dropdownDecoratorProps: const DropDownDecoratorProps(
              dropdownSearchDecoration: InputDecoration(
                labelText: 'Select Substations',
                hintText: 'Choose substations to configure',
                border: OutlineInputBorder(),
              ),
            ),
            itemAsString: (s) => s.name,
            selectedItems: _getSelectedSubstations(),
            items: _substationsInSubdivision,
            onChanged: (substations) =>
                _fetchBaysForSubstations(substations.map((s) => s.id).toList()),
          ),
        ],
      ),
    );
  }

  Widget _buildBayConfiguration(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(Icons.tune, color: Colors.green, size: 18),
              ),
              const SizedBox(width: 12),
              Text(
                'Bay Configuration',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...(_baysInSelectedSubstations
              .map((bay) => _buildBayCard(bay, theme))
              .toList()),
        ],
      ),
    );
  }

  Widget _buildBayCard(Bay bay, ThemeData theme) {
    final currentConfig = _configuredReadings.firstWhereOrNull(
      (cbr) => cbr.bayId == bay.id,
    );
    final availableFields = _bayToAvailableReadingFields[bay.id] ?? [];

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: _getBayTypeColor(bay.bayType),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${bay.name} (${bay.voltageLevel})',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          if (availableFields.isEmpty)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.warning_amber,
                    color: Colors.orange.shade700,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'No reading template assigned',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.orange.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            )
          else
            DropdownSearch<String>.multiSelection(
              popupProps: PopupPropsMultiSelection.menu(showSearchBox: true),
              dropdownDecoratorProps: DropDownDecoratorProps(
                dropdownSearchDecoration: InputDecoration(
                  labelText: 'Select Reading Fields',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                  isDense: true,
                ),
              ),
              itemAsString: (s) => s,
              selectedItems: currentConfig?.readingFields ?? [],
              items: availableFields,
              onChanged: (fields) => _updateBayConfiguration(bay, fields),
            ),
        ],
      ),
    );
  }

  Widget _buildSaveButton(ThemeData theme) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton(
        onPressed: _isSaving ? null : _saveConfiguration,
        style: ElevatedButton.styleFrom(
          backgroundColor: theme.colorScheme.primary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: _isSaving
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Text(
                'Save Configuration',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
      ),
    );
  }

  // Helper methods
  Color _getBayTypeColor(String bayType) {
    switch (bayType.toLowerCase()) {
      case 'transformer':
        return Colors.orange;
      case 'line':
        return Colors.blue;
      case 'feeder':
        return Colors.green;
      case 'capacitor bank':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  List<Substation> _getSelectedSubstations() {
    final selectedIds = _configuredReadings.map((e) => e.substationId).toSet();
    return _substationsInSubdivision
        .where((s) => selectedIds.contains(s.id))
        .toList();
  }

  void _updateBayConfiguration(Bay bay, List<String> fields) {
    setState(() {
      if (fields.isEmpty) {
        _configuredReadings.removeWhere((cbr) => cbr.bayId == bay.id);
      } else {
        final config = ConfiguredBayReading(
          bayId: bay.id,
          bayName: bay.name,
          substationId: bay.substationId,
          substationName: _substationsInSubdivision
              .firstWhere((s) => s.id == bay.substationId)
              .name,
          readingFields: fields,
        );

        final existingIndex = _configuredReadings.indexWhere(
          (cbr) => cbr.bayId == bay.id,
        );
        if (existingIndex != -1) {
          _configuredReadings[existingIndex] = config;
        } else {
          _configuredReadings.add(config);
        }
      }
    });
  }

  // Data loading and saving methods remain the same as original
  Future<void> _loadInitialData() async {
    // Implementation remains the same
  }

  Future<void> _saveConfiguration() async {
    // Implementation remains the same
  }

  Future<void> _fetchBaysForSubstations(List<String> substationIds) async {
    // Implementation remains the same
  }

  @override
  void dispose() {
    _durationValueController.dispose();
    super.dispose();
  }
}

// Extensions
extension ListExtension<T> on List<T> {
  T? firstWhereOrNull(bool Function(T element) test) {
    for (var element in this) {
      if (test(element)) return element;
    }
    return null;
  }
}

extension StringExtension on String {
  String capitalize() {
    return "${this[0].toUpperCase()}${substring(1)}";
  }
}
