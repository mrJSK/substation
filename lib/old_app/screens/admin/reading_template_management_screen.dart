// lib/screens/admin/reading_template_management_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import 'package:intl/intl.dart';
import '../../models/reading_models.dart';
import '../../utils/snackbar_utils.dart';
import '../../widgets/reading_field_widgets.dart';

enum ReadingTemplateViewMode { list, form }

class ReadingTemplateManagementScreen extends StatefulWidget {
  const ReadingTemplateManagementScreen({super.key});

  @override
  State<ReadingTemplateManagementScreen> createState() =>
      _ReadingTemplateManagementScreenState();
}

class _ReadingTemplateManagementScreenState
    extends State<ReadingTemplateManagementScreen>
    with SingleTickerProviderStateMixin {
  ReadingTemplateViewMode _viewMode = ReadingTemplateViewMode.list;
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  ReadingTemplate? _templateToEdit;
  List<ReadingTemplate> _templates = [];
  bool _isLoading = true;
  bool _isSaving = false;
  String? _selectedBayType;
  String? _templateDescription;
  List<Map<String, dynamic>> _templateReadingFields = [];

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  final List<String> _dataTypes = ReadingFieldDataType.values
      .map((e) => e.toString().split('.').last)
      .toList();

  // Updated to include monthly
  final List<String> _frequencies = ReadingFrequency.values
      .map((e) => e.toString().split('.').last)
      .toList();

  final List<String> _bayTypes = [
    'Transformer',
    'Line',
    'Feeder',
    'Capacitor Bank',
    'Reactor',
    'Bus Coupler',
    'Battery',
    'Busbar',
  ];

  final List<ReadingField> _defaultEnergyFields = [
    ReadingField(
      name: 'Previous Day Reading (Import)',
      dataType: ReadingFieldDataType.number,
      isMandatory: true,
      unit: 'MWH',
      frequency: ReadingFrequency.daily,
    ),
    ReadingField(
      name: 'Current Day Reading (Import)',
      dataType: ReadingFieldDataType.number,
      isMandatory: true,
      unit: 'MWH',
      frequency: ReadingFrequency.daily,
    ),
    ReadingField(
      name: 'Previous Day Reading (Export)',
      dataType: ReadingFieldDataType.number,
      isMandatory: true,
      unit: 'MWH',
      frequency: ReadingFrequency.daily,
    ),
    ReadingField(
      name: 'Current Day Reading (Export)',
      dataType: ReadingFieldDataType.number,
      isMandatory: true,
      unit: 'MWH',
      frequency: ReadingFrequency.daily,
    ),
  ];

  // Updated Battery hourly fields with Charging Mode dropdown
  final Map<String, List<ReadingField>> _defaultHourlyFields = {
    'Feeder': [
      ReadingField(
        name: 'Current',
        unit: 'A',
        dataType: ReadingFieldDataType.number,
        isMandatory: true,
        frequency: ReadingFrequency.hourly,
        minRange: 0.00,
        maxRange: 5000.000,
      ),
    ],
    'Transformer': [
      ReadingField(
        name: 'Current',
        unit: 'A',
        dataType: ReadingFieldDataType.number,
        isMandatory: true,
        frequency: ReadingFrequency.hourly,
        minRange: 0.00,
        maxRange: 5000.00,
      ),
      ReadingField(
        name: 'Power Factor',
        unit: '',
        dataType: ReadingFieldDataType.number,
        isMandatory: true,
        frequency: ReadingFrequency.hourly,
        minRange: -1.00,
        maxRange: 1.00,
      ),
      ReadingField(
        name: 'Real Power (MW)',
        unit: 'MW',
        dataType: ReadingFieldDataType.number,
        isMandatory: true,
        frequency: ReadingFrequency.hourly,
        minRange: 0.00,
        maxRange: 1000.00,
      ),
      ReadingField(
        name: 'Voltage',
        unit: 'kV',
        dataType: ReadingFieldDataType.number,
        isMandatory: true,
        frequency: ReadingFrequency.hourly,
        minRange: 10.00,
        maxRange: 1000.00,
      ),
      ReadingField(
        name: 'Apparent Power (MVAR)',
        unit: 'MVAR',
        dataType: ReadingFieldDataType.number,
        isMandatory: true,
        frequency: ReadingFrequency.hourly,
        minRange: 0.00,
        maxRange: 1000.00,
      ),
      ReadingField(
        name: 'Gas Pressure (SF6)',
        unit: 'kg/cm2',
        dataType: ReadingFieldDataType.number,
        isMandatory: false,
        frequency: ReadingFrequency.hourly,
        minRange: 4.0,
        maxRange: 10.0,
      ),
      ReadingField(
        name: 'Winding Temperature',
        unit: 'Celsius',
        dataType: ReadingFieldDataType.number,
        isMandatory: true,
        frequency: ReadingFrequency.hourly,
        minRange: -40.00,
        maxRange: 120.00,
      ),
      ReadingField(
        name: 'Oil Temperature',
        unit: 'Celsius',
        dataType: ReadingFieldDataType.number,
        isMandatory: true,
        frequency: ReadingFrequency.hourly,
        minRange: -40.00,
        maxRange: 120.00,
      ),
      ReadingField(
        name: 'Tap Position',
        unit: 'No.',
        dataType: ReadingFieldDataType.number,
        isMandatory: true,
        frequency: ReadingFrequency.hourly,
        minRange: 1.0,
        maxRange: 33.0,
        isInteger: true,
      ),
      ReadingField(
        name: 'Frequency',
        unit: 'Hz',
        dataType: ReadingFieldDataType.number,
        isMandatory: true,
        frequency: ReadingFrequency.hourly,
        minRange: 48.0,
        maxRange: 52.0,
      ),
    ],
    'Line': [
      ReadingField(
        name: 'Current',
        unit: 'A',
        dataType: ReadingFieldDataType.number,
        isMandatory: true,
        frequency: ReadingFrequency.hourly,
        minRange: 0.00,
        maxRange: 5000.00,
      ),
      ReadingField(
        name: 'Power Factor',
        unit: '',
        dataType: ReadingFieldDataType.number,
        isMandatory: true,
        frequency: ReadingFrequency.hourly,
        minRange: -1.00,
        maxRange: 1.00,
      ),
      ReadingField(
        name: 'Real Power (MW)',
        unit: 'MW',
        dataType: ReadingFieldDataType.number,
        isMandatory: true,
        frequency: ReadingFrequency.hourly,
        minRange: 0.00,
        maxRange: 1000.00,
      ),
      ReadingField(
        name: 'Voltage',
        unit: 'kV',
        dataType: ReadingFieldDataType.number,
        isMandatory: true,
        frequency: ReadingFrequency.hourly,
        minRange: 10.00,
        maxRange: 1000.00,
      ),
      ReadingField(
        name: 'Apparent Power (MVAR)',
        unit: 'MVAR',
        dataType: ReadingFieldDataType.number,
        isMandatory: true,
        frequency: ReadingFrequency.hourly,
        minRange: 0.00,
        maxRange: 1000.00,
      ),
      ReadingField(
        name: 'Gas Pressure (SF6)',
        unit: 'kg/cm2',
        dataType: ReadingFieldDataType.number,
        isMandatory: false,
        frequency: ReadingFrequency.hourly,
        minRange: 4.0,
        maxRange: 10.0,
      ),
    ],
    'Capacitor Bank': [
      ReadingField(
        name: 'Current',
        unit: 'A',
        dataType: ReadingFieldDataType.number,
        isMandatory: true,
        frequency: ReadingFrequency.hourly,
        minRange: 0.00,
        maxRange: 2000.00,
      ),
      ReadingField(
        name: 'Power Factor',
        unit: '',
        dataType: ReadingFieldDataType.number,
        isMandatory: true,
        frequency: ReadingFrequency.hourly,
        minRange: -1.00,
        maxRange: 1.0,
      ),
    ],
    // Updated Battery hourly fields
    'Battery': [
      ReadingField(
        name: 'Battery Voltage',
        unit: 'V',
        dataType: ReadingFieldDataType.number,
        isMandatory: true,
        frequency: ReadingFrequency.hourly,
        minRange: 80.00,
        maxRange: 150.00,
      ),
      ReadingField(
        name: 'Charging Mode',
        dataType: ReadingFieldDataType.dropdown,
        isMandatory: true,
        frequency: ReadingFrequency.hourly,
        options: ['Float', 'Boost'],
      ),
    ],
    'Busbar': [
      ReadingField(
        name: 'Voltage',
        unit: 'kV',
        dataType: ReadingFieldDataType.number,
        isMandatory: true,
        frequency: ReadingFrequency.hourly,
        minRange: 10.00,
        maxRange: 1000.00,
      ),
    ],
  };

  // Updated Battery daily fields with string voltages + 8 cells
  final Map<String, List<ReadingField>> _defaultDailyFields = {
    'Battery': [
      // String-level voltage measurements
      ReadingField(
        name: 'Positive to Earth Voltage',
        unit: 'V',
        dataType: ReadingFieldDataType.number,
        isMandatory: true,
        frequency: ReadingFrequency.daily,
        minRange: -300.00,
        maxRange: 300.00,
      ),
      ReadingField(
        name: 'Negative to Earth Voltage',
        unit: 'V',
        dataType: ReadingFieldDataType.number,
        isMandatory: true,
        frequency: ReadingFrequency.daily,
        minRange: -300.00,
        maxRange: 300.00,
      ),
      ReadingField(
        name: 'Positive to Negative Voltage',
        unit: 'V',
        dataType: ReadingFieldDataType.number,
        isMandatory: true,
        frequency: ReadingFrequency.daily,
        minRange: -300.00,
        maxRange: 300.00,
      ),
      // 8 cell groups for daily reading
      ...List.generate(
        8,
        (i) => ReadingField(
          name: 'Cell ${i + 1}',
          dataType: ReadingFieldDataType.group,
          isMandatory: true,
          frequency: ReadingFrequency.daily,
          nestedFields: [
            ReadingField(
              name: 'Cell Number',
              dataType: ReadingFieldDataType.number,
              isMandatory: true,
              minRange: 1.0,
              maxRange: 8.0,
              isInteger: true,
            ),
            ReadingField(
              name: 'Cell Voltage',
              unit: 'V',
              dataType: ReadingFieldDataType.number,
              isMandatory: true,
              minRange: 1.8,
              maxRange: 2.4,
            ),
            ReadingField(
              name: 'Specific Gravity',
              unit: '',
              dataType: ReadingFieldDataType.number,
              isMandatory: true,
              minRange: 1000,
              maxRange: 1300,
            ),
          ],
        ),
      ),
    ],
  };

  // NEW: Battery monthly fields with 55 cells
  final Map<String, List<ReadingField>> _defaultMonthlyFields = {
    'Battery': [
      // 55 cell groups for monthly reading
      ...List.generate(
        55,
        (i) => ReadingField(
          name: 'Cell ${i + 1}',
          dataType: ReadingFieldDataType.group,
          isMandatory: true,
          frequency: ReadingFrequency.monthly,
          nestedFields: [
            ReadingField(
              name: 'Cell Number',
              dataType: ReadingFieldDataType.number,
              isMandatory: true,
              minRange: 1.0,
              maxRange: 55.0,
              isInteger: true,
            ),
            ReadingField(
              name: 'Cell Voltage',
              unit: 'V',
              dataType: ReadingFieldDataType.number,
              isMandatory: true,
              minRange: 1.8,
              maxRange: 2.4,
            ),
            ReadingField(
              name: 'Specific Gravity',
              unit: '',
              dataType: ReadingFieldDataType.number,
              isMandatory: true,
              minRange: 1000,
              maxRange: 1300,
            ),
          ],
        ),
      ),
    ],
  };

  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );
    _fetchReadingTemplates();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _fetchReadingTemplates() async {
    setState(() => _isLoading = true);
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('readingTemplates')
          .orderBy('bayType')
          .get();
      _templates = snapshot.docs
          .map((doc) => ReadingTemplate.fromFirestore(doc))
          .toList();
      _animationController.forward();
    } catch (e) {
      if (mounted) {
        SnackBarUtils.showSnackBar(
          context,
          'Failed to load reading templates: $e',
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showListView() {
    setState(() {
      _viewMode = ReadingTemplateViewMode.list;
      _templateToEdit = null;
      _selectedBayType = null;
      _templateDescription = null;
      _templateReadingFields = [];
    });
    _fetchReadingTemplates();
  }

  void _showFormForNew() {
    setState(() {
      _viewMode = ReadingTemplateViewMode.form;
      _templateToEdit = null;
      _selectedBayType = null;
      _templateDescription = null;
      _templateReadingFields = [];
    });
  }

  void _showFormForEdit(ReadingTemplate template) {
    setState(() {
      _viewMode = ReadingTemplateViewMode.form;
      _templateToEdit = template;
      _selectedBayType = template.bayType;
      _templateDescription = template.description;
      _templateReadingFields = template.readingFields
          .map(
            (field) =>
                field.toMap()..['isDefault'] = _isDefaultField(field.name),
          )
          .map((m) => Map<String, dynamic>.from(m))
          .toList();
    });
  }

  bool _isDefaultField(String fieldName) {
    final List<String> energyFieldsToKeepReadOnly = [
      'Previous Day Reading (Import)',
      'Current Day Reading (Import)',
      'Previous Day Reading (Export)',
      'Current Day Reading (Export)',
      'Previous Month Reading (Import)',
      'Current Month Reading (Import)',
      'Previous Month Reading (Export)',
      'Current Month Reading (Export)',
    ];
    if (energyFieldsToKeepReadOnly.contains(fieldName)) return true;
    return false;
  }

  void _onBayTypeSelected(String? newBayType) {
    setState(() {
      _selectedBayType = newBayType;
      _templateReadingFields.clear();
      if (newBayType != null) {
        final List<ReadingField> defaults = [
          // Add energy fields for non-Battery and non-Busbar types
          if (newBayType != 'Battery' && newBayType != 'Busbar')
            ..._defaultEnergyFields,
          // Add hourly fields
          ...(_defaultHourlyFields[newBayType] ?? []),
          // Add daily fields
          ...(_defaultDailyFields[newBayType] ?? []),
          // Add monthly fields
          ...(_defaultMonthlyFields[newBayType] ?? []),
        ];

        for (final field in defaults) {
          final fieldMap = field.toMap();
          fieldMap['isDefault'] = _isDefaultField(field.name);
          _templateReadingFields.add(fieldMap);
        }

        // Debug
        print(
          'DEBUG: Added ${_templateReadingFields.length} fields for $newBayType',
        );
      }
    });
  }

  void _addReadingField() {
    setState(() {
      _templateReadingFields.add({
        'name': '',
        'dataType': ReadingFieldDataType.text.toString().split('.').last,
        'unit': '',
        'options': <String>[],
        'isMandatory': false,
        'frequency': ReadingFrequency.daily.toString().split('.').last,
        'description_remarks': '',
        'isDefault': false,
        'nestedFields': null,
        'minRange': null,
        'maxRange': null,
        'isInteger': false,
      });
    });
  }

  void _addGroupReadingField() {
    setState(() {
      _templateReadingFields.add({
        'name': '',
        'dataType': ReadingFieldDataType.group.toString().split('.').last,
        'unit': '',
        'options': <String>[],
        'isMandatory': false,
        'frequency': ReadingFrequency.daily.toString().split('.').last,
        'description_remarks': '',
        'isDefault': false,
        'nestedFields': <Map<String, dynamic>>[],
        'minRange': null,
        'maxRange': null,
        'isInteger': false,
      });
    });
  }

  void _removeReadingField(int index) {
    setState(() => _templateReadingFields.removeAt(index));
  }

  Future<void> _saveTemplate() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedBayType == null) {
      SnackBarUtils.showSnackBar(
        context,
        'Please select a Bay Type.',
        isError: true,
      );
      return;
    }

    setState(() => _isSaving = true);
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      if (mounted) {
        SnackBarUtils.showSnackBar(
          context,
          'Error: User not logged in.',
          isError: true,
        );
      }
      setState(() => _isSaving = false);
      return;
    }

    try {
      final List<ReadingField> readingFields = _templateReadingFields
          .map((fieldMap) => ReadingField.fromMap(fieldMap))
          .toList();

      final newTemplate = ReadingTemplate(
        id: _templateToEdit?.id,
        bayType: _selectedBayType!,
        readingFields: readingFields,
        createdBy: currentUser.uid,
        createdAt: _templateToEdit?.createdAt ?? Timestamp.now(),
        description: _templateDescription,
        isActive: true,
      );

      if (_templateToEdit == null) {
        await FirebaseFirestore.instance
            .collection('readingTemplates')
            .add(newTemplate.toFirestore());
        if (mounted) {
          SnackBarUtils.showSnackBar(
            context,
            'Reading template created successfully!',
          );
        }
      } else {
        final updatedTemplate = newTemplate.withUpdatedTimestamp();
        await FirebaseFirestore.instance
            .collection('readingTemplates')
            .doc(_templateToEdit!.id)
            .update(updatedTemplate.toFirestore());
        if (mounted) {
          SnackBarUtils.showSnackBar(
            context,
            'Reading template updated successfully!',
          );
        }
      }
      _showListView();
    } catch (e) {
      if (mounted) {
        SnackBarUtils.showSnackBar(
          context,
          'Failed to save template: $e',
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _deleteTemplate(String? templateId) async {
    if (templateId == null) return;

    final bool confirm =
        await showDialog<bool>(
          context: context,
          builder: (BuildContext context) {
            final theme = Theme.of(context);
            final isDarkMode = theme.brightness == Brightness.dark;
            return AlertDialog(
              backgroundColor: isDarkMode
                  ? const Color(0xFF1C1C1E)
                  : Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              title: Row(
                children: [
                  Icon(Icons.warning_amber, color: theme.colorScheme.error),
                  const SizedBox(width: 8),
                  Text(
                    'Confirm Deletion',
                    style: TextStyle(color: isDarkMode ? Colors.white : null),
                  ),
                ],
              ),
              content: Text(
                'Are you sure you want to delete this reading template? This action cannot be undone and may affect existing bay assignments.',
                style: TextStyle(color: isDarkMode ? Colors.white : null),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: Text(
                    'Cancel',
                    style: TextStyle(color: isDarkMode ? Colors.white70 : null),
                  ),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.error,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('Delete'),
                ),
              ],
            );
          },
        ) ??
        false;

    if (confirm) {
      try {
        await FirebaseFirestore.instance
            .collection('readingTemplates')
            .doc(templateId)
            .delete();
        if (mounted) {
          SnackBarUtils.showSnackBar(
            context,
            'Reading template deleted successfully!',
          );
        }
        _fetchReadingTemplates();
      } catch (e) {
        if (mounted) {
          SnackBarUtils.showSnackBar(
            context,
            'Failed to delete template: $e',
            isError: true,
          );
        }
      }
    }
  }

  void _debouncedUpdate(VoidCallback callback) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) setState(callback);
    });
  }

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
      case 'reactor':
        return Colors.red;
      case 'bus coupler':
        return Colors.teal;
      case 'battery':
        return Colors.amber;
      case 'busbar':
        return Colors.indigo;
      default:
        return Colors.grey;
    }
  }

  IconData _getBayTypeIcon(String bayType) {
    switch (bayType.toLowerCase()) {
      case 'transformer':
        return Icons.electrical_services;
      case 'line':
        return Icons.power_input;
      case 'feeder':
        return Icons.power;
      case 'capacitor bank':
        return Icons.battery_charging_full;
      case 'reactor':
        return Icons.device_hub;
      case 'bus coupler':
        return Icons.power_settings_new;
      case 'battery':
        return Icons.battery_std;
      case 'busbar':
        return Icons.horizontal_rule;
      default:
        return Icons.electrical_services;
    }
  }

  Color _getFrequencyColor(String frequency) {
    switch (frequency.toLowerCase()) {
      case 'hourly':
        return Colors.red;
      case 'daily':
        return Colors.blue;
      case 'monthly':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    if (_isLoading) {
      return Scaffold(
        backgroundColor: isDarkMode
            ? const Color(0xFF1C1C1E)
            : const Color(0xFFF8F9FA),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 60,
                height: 60,
                child: CircularProgressIndicator(
                  strokeWidth: 4,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    theme.colorScheme.primary,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Loading templates...',
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
        ),
      );
    }

    return Scaffold(
      backgroundColor: isDarkMode
          ? const Color(0xFF1C1C1E)
          : const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: isDarkMode ? const Color(0xFF1C1C1E) : Colors.white,
        elevation: 0,
        toolbarHeight: 60,
        title: Text(
          _viewMode == ReadingTemplateViewMode.list
              ? 'Reading Templates'
              : (_templateToEdit == null
                    ? 'Create New Template'
                    : 'Edit Template'),
          style: TextStyle(
            color: isDarkMode ? Colors.white : theme.colorScheme.onSurface,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        leading: _viewMode == ReadingTemplateViewMode.form
            ? IconButton(
                icon: Icon(
                  Icons.arrow_back_ios,
                  color: isDarkMode
                      ? Colors.white
                      : theme.colorScheme.onSurface,
                ),
                onPressed: _showListView,
              )
            : IconButton(
                icon: Icon(
                  Icons.arrow_back_ios,
                  color: isDarkMode
                      ? Colors.white
                      : theme.colorScheme.onSurface,
                ),
                onPressed: () => Navigator.pop(context),
              ),
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: _viewMode == ReadingTemplateViewMode.list
            ? _buildListView(theme, isDarkMode)
            : _buildFormView(theme, isDarkMode),
      ),
      floatingActionButton: _viewMode == ReadingTemplateViewMode.list
          ? FloatingActionButton.extended(
              onPressed: _showFormForNew,
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: Colors.white,
              elevation: 2,
              icon: const Icon(Icons.add),
              label: const Text(
                'New Template',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            )
          : null,
    );
  }

  Widget _buildListView(ThemeData theme, bool isDarkMode) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: _templates.isEmpty
          ? Center(
              child: Container(
                margin: const EdgeInsets.all(32),
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: isDarkMode ? const Color(0xFF2C2C2E) : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: isDarkMode
                          ? Colors.black.withOpacity(0.3)
                          : Colors.black.withOpacity(0.05),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.rule_outlined,
                      size: 80,
                      color: isDarkMode
                          ? Colors.white.withOpacity(0.4)
                          : Colors.grey.shade400,
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'No Reading Templates',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: isDarkMode
                            ? Colors.white
                            : theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Create templates to define reading parameters\nfor different bay types',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: isDarkMode
                            ? Colors.white.withOpacity(0.6)
                            : Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 32),
                    ElevatedButton.icon(
                      onPressed: _showFormForNew,
                      icon: const Icon(Icons.add),
                      label: const Text('Create First Template'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.colorScheme.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: _templates.map((template) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: isDarkMode
                          ? const Color(0xFF2C2C2E)
                          : Colors.white,
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
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(16),
                      leading: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: _getBayTypeColor(
                            template.bayType,
                          ).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          _getBayTypeIcon(template.bayType),
                          color: _getBayTypeColor(template.bayType),
                          size: 24,
                        ),
                      ),
                      title: Text(
                        template.bayType,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: isDarkMode
                              ? Colors.white
                              : theme.colorScheme.onSurface,
                        ),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          Text(
                            '${template.totalFieldCount} fields • Created ${DateFormat('MMM dd, yyyy').format(template.createdAt.toDate())}',
                            style: TextStyle(
                              fontSize: 13,
                              color: isDarkMode
                                  ? Colors.white.withOpacity(0.6)
                                  : Colors.grey.shade600,
                            ),
                          ),
                          if ((template.description ?? '').isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              template.description!,
                              style: TextStyle(
                                fontSize: 12,
                                color: isDarkMode
                                    ? Colors.white.withOpacity(0.5)
                                    : Colors.grey.shade500,
                                fontStyle: FontStyle.italic,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: _frequencies.map((freq) {
                              final count = template.readingFields
                                  .where(
                                    (field) =>
                                        field.frequency
                                            .toString()
                                            .split('.')
                                            .last ==
                                        freq,
                                  )
                                  .length;
                              if (count == 0) return const SizedBox.shrink();
                              return Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: _getFrequencyColor(
                                    freq,
                                  ).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                    color: _getFrequencyColor(
                                      freq,
                                    ).withOpacity(0.3),
                                  ),
                                ),
                                child: Text(
                                  '$freq: $count',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: _getFrequencyColor(freq),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                      trailing: PopupMenuButton<String>(
                        icon: Icon(
                          Icons.more_vert,
                          color: isDarkMode
                              ? Colors.white.withOpacity(0.7)
                              : Colors.grey.shade600,
                        ),
                        color: isDarkMode
                            ? const Color(0xFF2C2C2E)
                            : Colors.white,
                        onSelected: (String result) {
                          if (result == 'edit') {
                            _showFormForEdit(template);
                          } else if (result == 'delete') {
                            _deleteTemplate(template.id);
                          }
                        },
                        itemBuilder: (BuildContext context) => [
                          PopupMenuItem<String>(
                            value: 'edit',
                            child: ListTile(
                              leading: Icon(
                                Icons.edit_outlined,
                                size: 16,
                                color: theme.colorScheme.primary,
                              ),
                              title: Text(
                                'Edit',
                                style: TextStyle(
                                  color: isDarkMode ? Colors.white : null,
                                ),
                              ),
                              dense: true,
                            ),
                          ),
                          PopupMenuItem<String>(
                            value: 'delete',
                            child: ListTile(
                              leading: Icon(
                                Icons.delete_outline,
                                size: 16,
                                color: theme.colorScheme.error,
                              ),
                              title: Text(
                                'Delete',
                                style: TextStyle(
                                  color: theme.colorScheme.error,
                                ),
                              ),
                              dense: true,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
    );
  }

  Widget _buildFormView(ThemeData theme, bool isDarkMode) {
    return SingleChildScrollView(
      child: Column(
        children: [
          _buildBasicInfoSection(theme, isDarkMode),
          const SizedBox(height: 16),
          _buildBayTypeSection(theme, isDarkMode),
          const SizedBox(height: 16),
          _buildReadingFieldsSection(theme, isDarkMode),
          const SizedBox(height: 16),
          _buildActionButtons(theme, isDarkMode),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildBasicInfoSection(ThemeData theme, bool isDarkMode) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
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
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.info_outline,
                  color: Colors.blue,
                  size: 16,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Template Information',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: isDarkMode
                      ? Colors.white
                      : theme.colorScheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextFormField(
            initialValue: _templateDescription,
            decoration: InputDecoration(
              labelText: 'Description (Optional)',
              hintText: 'Describe the purpose of this template',
              prefixIcon: Icon(
                Icons.description,
                color: theme.colorScheme.primary,
                size: 20,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              filled: true,
              fillColor: isDarkMode
                  ? const Color(0xFF3C3C3E)
                  : Colors.grey.shade50,
            ),
            style: TextStyle(
              color: isDarkMode ? Colors.white : theme.colorScheme.onSurface,
            ),
            maxLines: 2,
            onChanged: (value) =>
                _templateDescription = value.isEmpty ? null : value,
          ),
        ],
      ),
    );
  }

  Widget _buildBayTypeSection(ThemeData theme, bool isDarkMode) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
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
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.category,
                  color: Colors.green,
                  size: 16,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Bay Type Configuration',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: isDarkMode
                      ? Colors.white
                      : theme.colorScheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: _selectedBayType,
            decoration: InputDecoration(
              labelText: 'Select Bay Type *',
              prefixIcon: Icon(
                Icons.electrical_services,
                color: theme.colorScheme.primary,
                size: 20,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              filled: true,
              fillColor: isDarkMode
                  ? const Color(0xFF3C3C3E)
                  : Colors.grey.shade50,
            ),
            dropdownColor: isDarkMode ? const Color(0xFF2C2C2E) : Colors.white,
            items: _bayTypes
                .map(
                  (type) => DropdownMenuItem<String>(
                    value: type,
                    child: Row(
                      children: [
                        Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: _getBayTypeColor(type).withOpacity(0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Icon(
                            _getBayTypeIcon(type),
                            color: _getBayTypeColor(type),
                            size: 14,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          type,
                          style: TextStyle(
                            color: isDarkMode
                                ? Colors.white
                                : theme.colorScheme.onSurface,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
                .toList(),
            onChanged: _onBayTypeSelected,
            validator: (value) =>
                value == null ? 'Please select a bay type' : null,
            style: TextStyle(
              color: isDarkMode ? Colors.white : theme.colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReadingFieldsSection(ThemeData theme, bool isDarkMode) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
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
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: Colors.purple.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.list_alt,
                    color: Colors.purple,
                    size: 16,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Reading Fields',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: isDarkMode
                          ? Colors.white
                          : theme.colorScheme.onSurface,
                    ),
                  ),
                ),
                if (_templateReadingFields.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${_templateReadingFields.length}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            // Use shared field list widget
            FieldListWidget(
              fields: _templateReadingFields,
              isEditable: true,
              dataTypes: _dataTypes,
              frequencies: _frequencies,
              onFieldsChanged: (updated) {
                setState(() {
                  _templateReadingFields
                    ..clear()
                    ..addAll(updated.map((e) => Map<String, dynamic>.from(e)));
                });
              },
              onAddField: _addReadingField,
              onAddGroupField: _addGroupReadingField,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons(ThemeData theme, bool isDarkMode) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: _showListView,
              style: OutlinedButton.styleFrom(
                foregroundColor: isDarkMode
                    ? Colors.white.withOpacity(0.7)
                    : Colors.grey.shade700,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                side: BorderSide(
                  color: isDarkMode
                      ? Colors.white.withOpacity(0.6)
                      : Colors.grey.shade300,
                ),
              ),
              child: const Text(
                'Cancel',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: ElevatedButton(
              onPressed: _isSaving ? null : _saveTemplate,
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                elevation: 2,
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
                  : Text(
                      _templateToEdit == null
                          ? 'Create Template'
                          : 'Update Template',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
