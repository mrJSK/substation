// lib/screens/admin/reading_template_management_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/reading_models.dart';
import '../../utils/snackbar_utils.dart';
import 'package:intl/intl.dart';

// Import your existing custom icon painters
import 'package:substation_manager/equipment_icons/battery_icon.dart';
import 'package:substation_manager/equipment_icons/busbar_icon.dart';
import 'package:substation_manager/equipment_icons/capacitor_bank_icon.dart';
import 'package:substation_manager/equipment_icons/circuit_breaker_icon.dart';
import 'package:substation_manager/equipment_icons/energy_meter_icon.dart';
import 'package:substation_manager/equipment_icons/feeder_icon.dart';
import 'package:substation_manager/equipment_icons/ground_icon.dart';
import 'package:substation_manager/equipment_icons/isolator_icon.dart';
import 'package:substation_manager/equipment_icons/line_icon.dart';
import 'package:substation_manager/equipment_icons/other_icon.dart';
import 'package:substation_manager/equipment_icons/pt_icon.dart';
import 'package:substation_manager/equipment_icons/relay_icon.dart';
import 'package:substation_manager/equipment_icons/reactor_icon.dart';
import 'package:substation_manager/equipment_icons/surge_arrester_icon.dart';
import 'package:substation_manager/equipment_icons/transformer_icon.dart';

class ReadingTemplateManagementScreen extends StatefulWidget {
  const ReadingTemplateManagementScreen({super.key});

  @override
  State<ReadingTemplateManagementScreen> createState() =>
      _ReadingTemplateManagementScreenState();
}

class _ReadingTemplateManagementScreenState
    extends State<ReadingTemplateManagementScreen> {
  bool _showForm = false;
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  ReadingTemplate? _templateToEdit;
  List<ReadingTemplate> _templates = [];
  bool _isLoading = true;
  bool _isSaving = false;
  String? _selectedBayType;
  List<Map<String, dynamic>> _readingFields = [];

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

  final List<String> _dataTypes = [
    'text',
    'number',
    'boolean',
    'date',
    'dropdown',
    'group',
  ];
  final List<String> _frequencies = ['hourly', 'daily', 'monthly'];

  // HARDCODED TEMPLATES - Your default energy fields
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
    ReadingField(
      name: 'Previous Month Reading (Import)',
      dataType: ReadingFieldDataType.number,
      isMandatory: true,
      unit: 'MWH',
      frequency: ReadingFrequency.monthly,
    ),
    ReadingField(
      name: 'Current Month Reading (Import)',
      dataType: ReadingFieldDataType.number,
      isMandatory: true,
      unit: 'MWH',
      frequency: ReadingFrequency.monthly,
    ),
    ReadingField(
      name: 'Previous Month Reading (Export)',
      dataType: ReadingFieldDataType.number,
      isMandatory: true,
      unit: 'MWH',
      frequency: ReadingFrequency.monthly,
    ),
    ReadingField(
      name: 'Current Month Reading (Export)',
      dataType: ReadingFieldDataType.number,
      isMandatory: true,
      unit: 'MWH',
      frequency: ReadingFrequency.monthly,
    ),
  ];

  // HARDCODED TEMPLATES - Your hourly fields by bay type
  final Map<String, List<ReadingField>> _defaultHourlyFields = {
    'Feeder': [
      ReadingField(
        name: 'Current',
        unit: 'A',
        dataType: ReadingFieldDataType.number,
        isMandatory: true,
        frequency: ReadingFrequency.hourly,
      ),
    ],
    'Transformer': [
      ReadingField(
        name: 'Current',
        unit: 'A',
        dataType: ReadingFieldDataType.number,
        isMandatory: true,
        frequency: ReadingFrequency.hourly,
      ),
      ReadingField(
        name: 'Power Factor',
        unit: '',
        dataType: ReadingFieldDataType.number,
        isMandatory: true,
        frequency: ReadingFrequency.hourly,
      ),
      ReadingField(
        name: 'Real Power (MW)',
        unit: 'MW',
        dataType: ReadingFieldDataType.number,
        isMandatory: true,
        frequency: ReadingFrequency.hourly,
      ),
      ReadingField(
        name: 'Voltage',
        unit: 'kV',
        dataType: ReadingFieldDataType.number,
        isMandatory: true,
        frequency: ReadingFrequency.hourly,
      ),
      ReadingField(
        name: 'Apparent Power (MVAR)',
        unit: 'MVAR',
        dataType: ReadingFieldDataType.number,
        isMandatory: true,
        frequency: ReadingFrequency.hourly,
      ),
      ReadingField(
        name: 'Gas Pressure (SF6)',
        unit: 'kg/cm2',
        dataType: ReadingFieldDataType.number,
        isMandatory: true,
        frequency: ReadingFrequency.hourly,
      ),
      ReadingField(
        name: 'Winding Temperature',
        unit: 'Celsius',
        dataType: ReadingFieldDataType.number,
        isMandatory: true,
        frequency: ReadingFrequency.hourly,
      ),
      ReadingField(
        name: 'Oil Temperature',
        unit: 'Celsius',
        dataType: ReadingFieldDataType.number,
        isMandatory: true,
        frequency: ReadingFrequency.hourly,
      ),
      ReadingField(
        name: 'Tap Position',
        unit: 'No.',
        dataType: ReadingFieldDataType.number,
        isMandatory: true,
        frequency: ReadingFrequency.hourly,
      ),
      ReadingField(
        name: 'Frequency',
        unit: 'Hz',
        dataType: ReadingFieldDataType.number,
        isMandatory: true,
        frequency: ReadingFrequency.hourly,
      ),
    ],
    'Line': [
      ReadingField(
        name: 'Current',
        unit: 'A',
        dataType: ReadingFieldDataType.number,
        isMandatory: true,
        frequency: ReadingFrequency.hourly,
      ),
      ReadingField(
        name: 'Power Factor',
        unit: '',
        dataType: ReadingFieldDataType.number,
        isMandatory: true,
        frequency: ReadingFrequency.hourly,
      ),
      ReadingField(
        name: 'Real Power (MW)',
        unit: 'MW',
        dataType: ReadingFieldDataType.number,
        isMandatory: true,
        frequency: ReadingFrequency.hourly,
      ),
      ReadingField(
        name: 'Voltage',
        unit: 'kV',
        dataType: ReadingFieldDataType.number,
        isMandatory: true,
        frequency: ReadingFrequency.hourly,
      ),
      ReadingField(
        name: 'Apparent Power (MVAR)',
        unit: 'MVAR',
        dataType: ReadingFieldDataType.number,
        isMandatory: true,
        frequency: ReadingFrequency.hourly,
      ),
      ReadingField(
        name: 'Gas Pressure (SF6)',
        unit: 'kg/cm2',
        dataType: ReadingFieldDataType.number,
        isMandatory: true,
        frequency: ReadingFrequency.hourly,
      ),
    ],
    'Capacitor Bank': [
      ReadingField(
        name: 'Current',
        unit: 'A',
        dataType: ReadingFieldDataType.number,
        isMandatory: true,
        frequency: ReadingFrequency.hourly,
      ),
      ReadingField(
        name: 'Power Factor',
        unit: '',
        dataType: ReadingFieldDataType.number,
        isMandatory: true,
        frequency: ReadingFrequency.hourly,
      ),
    ],
    'Battery': [
      ReadingField(
        name: 'Voltage',
        unit: 'V',
        dataType: ReadingFieldDataType.number,
        isMandatory: true,
        frequency: ReadingFrequency.hourly,
      ),
      ReadingField(
        name: 'Current',
        unit: 'A',
        dataType: ReadingFieldDataType.number,
        isMandatory: true,
        frequency: ReadingFrequency.hourly,
      ),
    ],
    'Busbar': [
      ReadingField(
        name: 'Voltage',
        unit: 'kV',
        dataType: ReadingFieldDataType.number,
        isMandatory: true,
        frequency: ReadingFrequency.hourly,
      ),
    ],
  };

  // HARDCODED TEMPLATES - Your daily fields by bay type
  // Updated battery default fields with grouped structure
  final Map<String, List<ReadingField>> _defaultDailyFields = {
    'Battery': [
      // Single set of overall battery readings (not grouped)
      ReadingField(
        name: 'Positive to Earth Voltage',
        unit: 'V',
        dataType: ReadingFieldDataType.number,
        isMandatory: true,
        frequency: ReadingFrequency.daily,
      ),
      ReadingField(
        name: 'Negative to Earth Voltage',
        unit: 'V',
        dataType: ReadingFieldDataType.number,
        isMandatory: true,
        frequency: ReadingFrequency.daily,
      ),
      ReadingField(
        name: 'Positive to Negative Voltage',
        unit: 'V',
        dataType: ReadingFieldDataType.number,
        isMandatory: true,
        frequency: ReadingFrequency.daily,
      ),
      // 8 Groups of cell readings (each group has 3 fields)
      ...List.generate(8, (groupIndex) {
        final cellNumber = groupIndex + 1;
        return [
          ReadingField(
            name: 'Cell Number',
            unit: '',
            dataType: ReadingFieldDataType.number,
            isMandatory: true,
            frequency: ReadingFrequency.daily,
            groupName: 'Cell $cellNumber', // This groups the fields
          ),
          ReadingField(
            name: 'Voltage',
            unit: 'V',
            dataType: ReadingFieldDataType.number,
            isMandatory: true,
            frequency: ReadingFrequency.daily,
            groupName: 'Cell $cellNumber', // Same group name
          ),
          ReadingField(
            name: 'Specific Gravity',
            unit: '',
            dataType: ReadingFieldDataType.number,
            isMandatory: true,
            frequency: ReadingFrequency.daily,
            groupName: 'Cell $cellNumber', // Same group name
          ),
        ];
      }).expand((group) => group).toList(),
    ],
  };

  @override
  void initState() {
    super.initState();
    _fetchReadingTemplates();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: _buildAppBar(theme),
      floatingActionButton: _showForm ? null : _buildFAB(theme),
      body: _showForm ? _buildFormView(theme) : _buildListView(theme),
    );
  }

  PreferredSizeWidget _buildAppBar(ThemeData theme) {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      title: Text(
        _showForm
            ? (_templateToEdit == null
                  ? 'New Reading Template'
                  : 'Edit Reading Template')
            : 'Reading Templates',
        style: TextStyle(
          color: theme.colorScheme.onSurface,
          fontSize: 18,
          fontWeight: FontWeight.w500,
        ),
      ),
      leading: IconButton(
        icon: Icon(
          Icons.arrow_back,
          color: theme.colorScheme.onSurface,
          size: 20,
        ),
        onPressed: _showForm ? _showListView : () => Navigator.pop(context),
      ),
    );
  }

  Widget _buildFAB(ThemeData theme) {
    return FloatingActionButton(
      onPressed: _showFormForNew,
      backgroundColor: theme.colorScheme.primary,
      foregroundColor: Colors.white,
      elevation: 2,
      child: const Icon(Icons.add, size: 24),
    );
  }

  Widget _buildListView(ThemeData theme) {
    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(color: theme.colorScheme.primary),
      );
    }

    if (_templates.isEmpty) {
      return _buildEmptyState(theme);
    }

    // Group templates by bay type
    final Map<String, List<ReadingTemplate>> groupedTemplates = {};
    for (final template in _templates) {
      groupedTemplates.putIfAbsent(template.bayType, () => []).add(template);
    }

    return ListView.separated(
      padding: const EdgeInsets.all(24),
      itemCount: groupedTemplates.keys.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final bayType = groupedTemplates.keys.elementAt(index);
        final templates = groupedTemplates[bayType]!;
        return _buildBayTypeGroup(bayType, templates, theme);
      },
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.rule_outlined,
              size: 40,
              color: theme.colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'No reading templates',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: theme.colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Create templates to define reading parameters for different bay types',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: theme.colorScheme.onSurface.withOpacity(0.5),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildBayTypeGroup(
    String bayType,
    List<ReadingTemplate> templates,
    ThemeData theme,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withOpacity(0.05),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: _getBayTypeColor(bayType),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: _getBayTypeIcon(
                    bayType,
                    size: 18.0,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        bayType,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${templates.length} template${templates.length == 1 ? '' : 's'}',
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.onSurface.withOpacity(0.6),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          ...templates
              .map((template) => _buildTemplateItem(template, theme))
              .toList(),
        ],
      ),
    );
  }

  Widget _buildTemplateItem(ReadingTemplate template, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: theme.colorScheme.outline.withOpacity(0.2)),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Reading Fields Configuration',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${template.readingFields.length} fields defined',
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onSurface.withOpacity(0.6),
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: _frequencies.map((freq) {
                    final count = template.readingFields
                        .where(
                          (field) =>
                              field.frequency.toString().split('.').last ==
                              freq,
                        )
                        .length;
                    if (count == 0) return const SizedBox.shrink();
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: _getFrequencyColor(freq).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: _getFrequencyColor(freq).withOpacity(0.3),
                        ),
                      ),
                      child: Text(
                        '$freq: $count',
                        style: TextStyle(
                          fontSize: 11,
                          color: _getFrequencyColor(freq),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                onPressed: () => _showFormForEdit(template),
                icon: Icon(
                  Icons.edit_outlined,
                  color: theme.colorScheme.primary,
                  size: 18,
                ),
                tooltip: 'Edit template',
              ),
              IconButton(
                onPressed: () => _deleteTemplate(template.id),
                icon: Icon(
                  Icons.delete_outline,
                  color: theme.colorScheme.error,
                  size: 18,
                ),
                tooltip: 'Delete template',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _getBayTypeIcon(
    String bayType, {
    double size = 20.0,
    Color color = Colors.white,
  }) {
    EquipmentPainter painter;

    switch (bayType.toLowerCase()) {
      case 'transformer':
        painter = TransformerIconPainter(
          color: color,
          strokeWidth: 2.0,
          equipmentSize: Size(size, size),
          symbolSize: Size(size, size),
        );
        break;
      case 'line':
        painter = LineIconPainter(
          color: color,
          strokeWidth: 2.0,
          equipmentSize: Size(size, size),
          symbolSize: Size(size, size),
        );
        break;
      case 'feeder':
        painter = FeederIconPainter(
          color: color,
          strokeWidth: 2.0,
          equipmentSize: Size(size, size),
          symbolSize: Size(size, size),
        );
        break;
      case 'capacitor bank':
        painter = CapacitorBankIconPainter(
          color: color,
          strokeWidth: 2.0,
          equipmentSize: Size(size, size),
          symbolSize: Size(size, size),
        );
        break;
      case 'reactor':
        painter = ReactorIconPainter(
          color: color,
          strokeWidth: 2.0,
          equipmentSize: Size(size, size),
          symbolSize: Size(size, size),
        );
        break;
      case 'bus coupler':
        painter = CircuitBreakerIconPainter(
          color: color,
          strokeWidth: 2.0,
          equipmentSize: Size(size, size),
          symbolSize: Size(size, size),
        );
        break;
      case 'battery':
        painter = BatteryIconPainter(
          color: color,
          strokeWidth: 2.0,
          equipmentSize: Size(size, size),
          symbolSize: Size(size, size),
        );
        break;
      case 'busbar':
        painter = BusbarIconPainter(
          color: color,
          strokeWidth: 2.0,
          equipmentSize: Size(size, size),
          symbolSize: Size(size, size),
        );
        break;
      default:
        painter = OtherIconPainter(
          color: color,
          strokeWidth: 2.0,
          equipmentSize: Size(size, size),
          symbolSize: Size(size, size),
        );
    }

    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: painter),
    );
  }

  Widget _buildFormView(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildBayTypeSelection(theme),
            const SizedBox(height: 24),
            _buildReadingFieldsSection(theme),
            const SizedBox(height: 24),
            _buildActionButtons(theme),
          ],
        ),
      ),
    );
  }

  Widget _buildBayTypeSelection(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Bay Type Configuration',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: _selectedBayType,
            decoration: InputDecoration(
              labelText: 'Select Bay Type *',
              labelStyle: TextStyle(
                color: theme.colorScheme.onSurface.withOpacity(0.6),
                fontSize: 14,
              ),
              border: UnderlineInputBorder(
                borderSide: BorderSide(
                  color: theme.colorScheme.outline.withOpacity(0.3),
                ),
              ),
              enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(
                  color: theme.colorScheme.outline.withOpacity(0.3),
                ),
              ),
              focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(
                  color: theme.colorScheme.primary,
                  width: 2,
                ),
              ),
            ),
            items: _bayTypes.map((type) {
              return DropdownMenuItem(
                value: type,
                child: Row(
                  children: [
                    Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: _getBayTypeColor(type),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: _getBayTypeIcon(
                        type,
                        size: 12.0,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      type,
                      style: TextStyle(
                        fontSize: 14,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
            onChanged: _onBayTypeSelected,
            validator: (value) =>
                value == null ? 'Please select a bay type' : null,
            style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 14),
            dropdownColor: Colors.white,
            icon: Icon(
              Icons.arrow_drop_down,
              color: theme.colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReadingFieldsSection(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
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
              Text(
                'Reading Fields',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.primary,
                ),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: _addReadingField,
                icon: Icon(
                  Icons.add,
                  size: 16,
                  color: theme.colorScheme.primary,
                ),
                label: Text(
                  'Add Field',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: theme.colorScheme.primary,
                  ),
                ),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_readingFields.isEmpty)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.list_alt,
                    color: theme.colorScheme.onSurface.withOpacity(0.4),
                    size: 40,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'No reading fields defined',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: theme.colorScheme.onSurface.withOpacity(0.5),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Select a bay type to see default fields or add custom ones',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: theme.colorScheme.onSurface.withOpacity(0.5),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
          else
            ...List.generate(_readingFields.length, (index) {
              final field = _readingFields[index];
              return _buildReadingFieldCard(field, index, theme);
            }),
        ],
      ),
    );
  }

  Widget _buildReadingFieldCard(
    Map<String, dynamic> field,
    int index,
    ThemeData theme,
  ) {
    final isDefault = field['isDefault'] ?? false;
    final groupName = field['groupName'] as String?;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDefault ? Colors.blue.shade50 : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDefault
              ? Colors.blue.shade200
              : theme.colorScheme.outline.withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (isDefault)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade100,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'DEFAULT',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: Colors.blue.shade700,
                    ),
                  ),
                ),
              if (groupName != null) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green.shade100,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    groupName,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: Colors.green.shade700,
                    ),
                  ),
                ),
              ],
              const Spacer(),
              if (!isDefault)
                IconButton(
                  onPressed: () => _removeReadingField(index),
                  icon: Icon(
                    Icons.delete_outline,
                    color: theme.colorScheme.error,
                    size: 18,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),

          // Group Name field for custom fields
          if (!isDefault) ...[
            TextFormField(
              initialValue: field['groupName'],
              decoration: InputDecoration(
                labelText: 'Group Name (optional)',
                isDense: true,
                labelStyle: TextStyle(
                  color: theme.colorScheme.onSurface.withOpacity(0.6),
                  fontSize: 14,
                ),
                border: UnderlineInputBorder(
                  borderSide: BorderSide(
                    color: theme.colorScheme.outline.withOpacity(0.3),
                  ),
                ),
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(
                    color: theme.colorScheme.outline.withOpacity(0.3),
                  ),
                ),
                focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(
                    color: theme.colorScheme.primary,
                    width: 2,
                  ),
                ),
              ),
              style: TextStyle(
                fontSize: 14,
                color: theme.colorScheme.onSurface,
              ),
              onChanged: (value) =>
                  field['groupName'] = value.isEmpty ? null : value,
            ),
            const SizedBox(height: 12),
          ],

          TextFormField(
            initialValue: field['name'],
            decoration: InputDecoration(
              labelText: 'Field Name',
              isDense: true,
              labelStyle: TextStyle(
                color: theme.colorScheme.onSurface.withOpacity(0.6),
                fontSize: 14,
              ),
              border: UnderlineInputBorder(
                borderSide: BorderSide(
                  color: theme.colorScheme.outline.withOpacity(0.3),
                ),
              ),
              enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(
                  color: theme.colorScheme.outline.withOpacity(0.3),
                ),
              ),
              focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(
                  color: theme.colorScheme.primary,
                  width: 2,
                ),
              ),
            ),
            style: TextStyle(fontSize: 14, color: theme.colorScheme.onSurface),
            onChanged: isDefault ? null : (value) => field['name'] = value,
            readOnly: isDefault,
            validator: (value) => value == null || value.trim().isEmpty
                ? 'Field name required'
                : null,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: field['dataType'],
                  decoration: InputDecoration(
                    labelText: 'Data Type',
                    isDense: true,
                    labelStyle: TextStyle(
                      color: theme.colorScheme.onSurface.withOpacity(0.6),
                      fontSize: 14,
                    ),
                    border: UnderlineInputBorder(
                      borderSide: BorderSide(
                        color: theme.colorScheme.outline.withOpacity(0.3),
                      ),
                    ),
                    enabledBorder: UnderlineInputBorder(
                      borderSide: BorderSide(
                        color: theme.colorScheme.outline.withOpacity(0.3),
                      ),
                    ),
                    focusedBorder: UnderlineInputBorder(
                      borderSide: BorderSide(
                        color: theme.colorScheme.primary,
                        width: 2,
                      ),
                    ),
                  ),
                  items: _dataTypes.map((type) {
                    return DropdownMenuItem(
                      value: type,
                      child: Text(
                        type,
                        style: TextStyle(
                          fontSize: 14,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                    );
                  }).toList(),
                  onChanged: isDefault
                      ? null
                      : (value) => setState(() {
                          field['dataType'] = value!;
                          if (value != 'dropdown') field['options'] = [];
                          if (value != 'number') field['unit'] = '';
                          if (value != 'boolean')
                            field['description_remarks'] = '';
                        }),
                  style: TextStyle(
                    color: theme.colorScheme.onSurface,
                    fontSize: 14,
                  ),
                  dropdownColor: Colors.white,
                  icon: Icon(
                    Icons.arrow_drop_down,
                    color: theme.colorScheme.onSurface.withOpacity(0.6),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: field['frequency'],
                  decoration: InputDecoration(
                    labelText: 'Frequency',
                    isDense: true,
                    labelStyle: TextStyle(
                      color: theme.colorScheme.onSurface.withOpacity(0.6),
                      fontSize: 14,
                    ),
                    border: UnderlineInputBorder(
                      borderSide: BorderSide(
                        color: theme.colorScheme.outline.withOpacity(0.3),
                      ),
                    ),
                    enabledBorder: UnderlineInputBorder(
                      borderSide: BorderSide(
                        color: theme.colorScheme.outline.withOpacity(0.3),
                      ),
                    ),
                    focusedBorder: UnderlineInputBorder(
                      borderSide: BorderSide(
                        color: theme.colorScheme.primary,
                        width: 2,
                      ),
                    ),
                  ),
                  items: _frequencies.map((freq) {
                    return DropdownMenuItem(
                      value: freq,
                      child: Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: _getFrequencyColor(freq),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            freq,
                            style: TextStyle(
                              fontSize: 14,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: isDefault
                      ? null
                      : (value) => setState(() => field['frequency'] = value!),
                  style: TextStyle(
                    color: theme.colorScheme.onSurface,
                    fontSize: 14,
                  ),
                  dropdownColor: Colors.white,
                  icon: Icon(
                    Icons.arrow_drop_down,
                    color: theme.colorScheme.onSurface.withOpacity(0.6),
                  ),
                ),
              ),
            ],
          ),

          // Conditional fields based on dataType
          if (field['dataType'] == 'dropdown') ...[
            const SizedBox(height: 12),
            TextFormField(
              initialValue: (field['options'] as List<dynamic>?)?.join(','),
              decoration: InputDecoration(
                labelText: 'Options (comma-separated)',
                hintText: 'e.g., Option1, Option2',
                isDense: true,
                labelStyle: TextStyle(
                  color: theme.colorScheme.onSurface.withOpacity(0.6),
                  fontSize: 14,
                ),
                border: UnderlineInputBorder(
                  borderSide: BorderSide(
                    color: theme.colorScheme.outline.withOpacity(0.3),
                  ),
                ),
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(
                    color: theme.colorScheme.outline.withOpacity(0.3),
                  ),
                ),
                focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(
                    color: theme.colorScheme.primary,
                    width: 2,
                  ),
                ),
              ),
              style: TextStyle(
                fontSize: 14,
                color: theme.colorScheme.onSurface,
              ),
              onChanged: isDefault
                  ? null
                  : (value) => field['options'] = value
                        .split(',')
                        .map((e) => e.trim())
                        .where((e) => e.isNotEmpty)
                        .toList(),
              readOnly: isDefault,
            ),
          ],

          if (field['dataType'] == 'number') ...[
            const SizedBox(height: 12),
            TextFormField(
              initialValue: field['unit'],
              decoration: InputDecoration(
                labelText: 'Unit (e.g., V, A, kW)',
                isDense: true,
                labelStyle: TextStyle(
                  color: theme.colorScheme.onSurface.withOpacity(0.6),
                  fontSize: 14,
                ),
                border: UnderlineInputBorder(
                  borderSide: BorderSide(
                    color: theme.colorScheme.outline.withOpacity(0.3),
                  ),
                ),
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(
                    color: theme.colorScheme.outline.withOpacity(0.3),
                  ),
                ),
                focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(
                    color: theme.colorScheme.primary,
                    width: 2,
                  ),
                ),
              ),
              style: TextStyle(
                fontSize: 14,
                color: theme.colorScheme.onSurface,
              ),
              onChanged: isDefault ? null : (value) => field['unit'] = value,
              readOnly: isDefault,
            ),
          ],

          if (field['dataType'] == 'boolean') ...[
            const SizedBox(height: 12),
            TextFormField(
              initialValue: field['description_remarks'],
              decoration: InputDecoration(
                labelText: 'Description / Remarks (Optional)',
                isDense: true,
                labelStyle: TextStyle(
                  color: theme.colorScheme.onSurface.withOpacity(0.6),
                  fontSize: 14,
                ),
                border: UnderlineInputBorder(
                  borderSide: BorderSide(
                    color: theme.colorScheme.outline.withOpacity(0.3),
                  ),
                ),
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(
                    color: theme.colorScheme.outline.withOpacity(0.3),
                  ),
                ),
                focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(
                    color: theme.colorScheme.primary,
                    width: 2,
                  ),
                ),
              ),
              style: TextStyle(
                fontSize: 14,
                color: theme.colorScheme.onSurface,
              ),
              onChanged: isDefault
                  ? null
                  : (value) => field['description_remarks'] = value,
              readOnly: isDefault,
              maxLines: 2,
            ),
          ],

          const SizedBox(height: 12),
          Row(
            children: [
              Checkbox(
                value: field['isMandatory'] ?? false,
                onChanged: isDefault
                    ? null
                    : (value) => setState(() => field['isMandatory'] = value),
                activeColor: theme.colorScheme.primary,
              ),
              const Text(
                'Required field',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(ThemeData theme) {
    return Row(
      children: [
        Expanded(
          child: TextButton(
            onPressed: _showListView,
            style: TextButton.styleFrom(
              foregroundColor: theme.colorScheme.onSurface.withOpacity(0.7),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(
                  color: theme.colorScheme.outline.withOpacity(0.3),
                ),
              ),
            ),
            child: const Text(
              'Cancel',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton(
            onPressed: _isSaving ? null : _saveTemplate,
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: theme.colorScheme.onPrimary,
              padding: const EdgeInsets.symmetric(vertical: 12),
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
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
          ),
        ),
      ],
    );
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

  void _showListView() {
    setState(() {
      _showForm = false;
      _templateToEdit = null;
      _selectedBayType = null;
      _readingFields.clear();
    });
    _fetchReadingTemplates();
  }

  void _showFormForNew() {
    setState(() {
      _showForm = true;
      _templateToEdit = null;
      _selectedBayType = null;
      _readingFields.clear();
    });
  }

  void _showFormForEdit(ReadingTemplate template) {
    setState(() {
      _showForm = true;
      _templateToEdit = template;
      _selectedBayType = template.bayType;
      _readingFields = template.readingFields
          .map(
            (field) =>
                field.toMap()..['isDefault'] = _isDefaultField(field.name),
          )
          .toList();
    });
  }

  bool _isDefaultField(String fieldName) {
    // Check if it's a default energy field (except for Battery and Busbar)
    if (_selectedBayType != 'Battery' &&
        _selectedBayType != 'Busbar' &&
        _defaultEnergyFields.any((field) => field.name == fieldName)) {
      return true;
    }

    // Check hourly fields for selected bay type
    if (_selectedBayType != null) {
      if (_defaultHourlyFields[_selectedBayType]?.any(
            (field) => field.name == fieldName,
          ) ??
          false) {
        return true;
      }

      // Check daily fields for selected bay type
      if (_defaultDailyFields[_selectedBayType]?.any(
            (field) => field.name == fieldName,
          ) ??
          false) {
        return true;
      }
    }

    return false;
  }

  void _onBayTypeSelected(String? newBayType) {
    setState(() {
      _selectedBayType = newBayType;

      // Clear only custom fields, keep default ones if applicable
      _readingFields.removeWhere((field) => !(field['isDefault'] ?? false));

      if (newBayType != null) {
        // Add default fields based on bay type
        List<ReadingField> defaultFields = [];

        // Add energy fields (except for Battery and Busbar)
        if (newBayType != 'Battery' && newBayType != 'Busbar') {
          defaultFields.addAll(_defaultEnergyFields);
        }

        // Add hourly fields for this bay type
        defaultFields.addAll(_defaultHourlyFields[newBayType] ?? []);

        // Add daily fields for this bay type
        defaultFields.addAll(_defaultDailyFields[newBayType] ?? []);

        // Convert to maps and mark as default
        final defaultFieldsAsMaps = defaultFields
            .map((field) => field.toMap()..['isDefault'] = true)
            .toList();

        // Add default fields that aren't already present
        for (var defaultField in defaultFieldsAsMaps) {
          if (!_readingFields.any(
            (existing) => existing['name'] == defaultField['name'],
          )) {
            // Insert at beginning to show defaults first
            _readingFields.insert(0, defaultField);
          }
        }
      }
    });
  }

  void _addReadingField() {
    setState(() {
      _readingFields.add({
        'name': '',
        'dataType': 'text',
        'frequency': 'daily',
        'unit': '',
        'isMandatory': false,
        'isDefault': false,
      });
    });
  }

  void _removeReadingField(int index) {
    setState(() => _readingFields.removeAt(index));
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
    } catch (e) {
      if (mounted) {
        SnackBarUtils.showSnackBar(
          context,
          'Failed to load templates: $e',
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveTemplate() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedBayType == null) {
      SnackBarUtils.showSnackBar(
        context,
        'Please select a bay type.',
        isError: true,
      );
      return;
    }

    setState(() => _isSaving = true);

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      SnackBarUtils.showSnackBar(
        context,
        'Error: User not logged in.',
        isError: true,
      );
      setState(() => _isSaving = false);
      return;
    }

    try {
      final readingFields = _readingFields.map((fieldMap) {
        return ReadingField.fromMap(fieldMap);
      }).toList();

      final template = ReadingTemplate(
        bayType: _selectedBayType!,
        readingFields: readingFields,
        createdBy: currentUser.uid,
        createdAt: Timestamp.now(),
      );

      if (_templateToEdit == null) {
        await FirebaseFirestore.instance
            .collection('readingTemplates')
            .add(template.toFirestore());
        SnackBarUtils.showSnackBar(context, 'Template created successfully!');
      } else {
        await FirebaseFirestore.instance
            .collection('readingTemplates')
            .doc(_templateToEdit!.id)
            .update(template.toFirestore());
        SnackBarUtils.showSnackBar(context, 'Template updated successfully!');
      }

      _showListView();
    } catch (e) {
      SnackBarUtils.showSnackBar(
        context,
        'Failed to save template: $e',
        isError: true,
      );
    } finally {
      setState(() => _isSaving = false);
    }
  }

  Future<void> _deleteTemplate(String? templateId) async {
    if (templateId == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text(
          'Delete Template',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        content: Text(
          'Are you sure you want to delete this reading template? This action cannot be undone.',
          style: TextStyle(
            fontSize: 14,
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(
                context,
              ).colorScheme.onSurface.withOpacity(0.7),
            ),
            child: const Text(
              'Cancel',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              'Delete',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await FirebaseFirestore.instance
            .collection('readingTemplates')
            .doc(templateId)
            .delete();
        SnackBarUtils.showSnackBar(context, 'Template deleted successfully!');
        _fetchReadingTemplates();
      } catch (e) {
        SnackBarUtils.showSnackBar(
          context,
          'Failed to delete template: $e',
          isError: true,
        );
      }
    }
  }
}
