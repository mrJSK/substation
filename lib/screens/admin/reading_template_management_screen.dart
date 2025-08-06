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
              errorBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: theme.colorScheme.error),
              ),
              focusedErrorBorder: UnderlineInputBorder(
                borderSide: BorderSide(
                  color: theme.colorScheme.error,
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

  // Updated function to use your existing icon painters
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
              // ADD FIELD BUTTON
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
              const SizedBox(width: 8),
              // ADD GROUP BUTTON
              TextButton.icon(
                onPressed: _addGroupReadingField,
                icon: Icon(
                  Icons.group_add,
                  size: 16,
                  color: theme.colorScheme.primary,
                ),
                label: Text(
                  'Add Group',
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
              if (field['dataType'] == 'group') {
                return _buildGroupFieldInput(field, index, theme);
              } else {
                return _buildReadingFieldCard(field, index, theme);
              }
            }),
        ],
      ),
    );
  }

  // Keep all your existing methods for the rest of the UI
  Widget _buildReadingFieldCard(
    Map<String, dynamic> field,
    int index,
    ThemeData theme, {
    bool isSubField = false,
    int? subFieldIndex,
    int? groupIndex,
  }) {
    // Your existing implementation from the attachment
    final isDefault = field['isDefault'] ?? false;
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
              const Spacer(),
              if (!isDefault)
                IconButton(
                  onPressed: () => isSubField
                      ? _removeSubField(groupIndex!, subFieldIndex!)
                      : _removeReadingField(index),
                  icon: Icon(
                    Icons.delete_outline,
                    color: theme.colorScheme.error,
                    size: 18,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
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
              errorBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: theme.colorScheme.error),
              ),
              focusedErrorBorder: UnderlineInputBorder(
                borderSide: BorderSide(
                  color: theme.colorScheme.error,
                  width: 2,
                ),
              ),
            ),
            style: TextStyle(fontSize: 14, color: theme.colorScheme.onSurface),
            onChanged: isDefault ? null : (value) => field['name'] = value,
            readOnly: isDefault,
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
                    errorBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: theme.colorScheme.error),
                    ),
                    focusedErrorBorder: UnderlineInputBorder(
                      borderSide: BorderSide(
                        color: theme.colorScheme.error,
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
                      : (value) => setState(() => field['dataType'] = value),
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
                    errorBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: theme.colorScheme.error),
                    ),
                    focusedErrorBorder: UnderlineInputBorder(
                      borderSide: BorderSide(
                        color: theme.colorScheme.error,
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
                      : (value) => setState(() => field['frequency'] = value),
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
                errorBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: theme.colorScheme.error),
                ),
                focusedErrorBorder: UnderlineInputBorder(
                  borderSide: BorderSide(
                    color: theme.colorScheme.error,
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

  Widget _buildGroupFieldInput(
    Map<String, dynamic> group,
    int index,
    ThemeData theme,
  ) {
    // Your existing implementation from the attachment
    final isDefault = group['isDefault'] ?? false;

    return ExpansionTile(
      title: Text(
        group['name'].isEmpty ? 'Unnamed Group' : group['name'],
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: theme.colorScheme.onSurface,
        ),
      ),
      leading: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: theme.colorScheme.primary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Icon(Icons.group, size: 16, color: theme.colorScheme.primary),
      ),
      trailing: isDefault
          ? null
          : IconButton(
              icon: Icon(
                Icons.delete_outline,
                size: 18,
                color: theme.colorScheme.error,
              ),
              onPressed: () => _removeReadingField(index),
            ),
      childrenPadding: const EdgeInsets.only(left: 16, right: 16, bottom: 12),
      backgroundColor: isDefault ? Colors.blue.shade50 : Colors.grey.shade50,
      collapsedBackgroundColor: isDefault
          ? Colors.blue.shade50
          : Colors.grey.shade50,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      collapsedShape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      children: [
        Row(
          children: [
            if (isDefault)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                margin: const EdgeInsets.only(bottom: 12),
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
            if (isDefault) const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.purple.shade100,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'GROUP',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: Colors.purple.shade700,
                ),
              ),
            ),
          ],
        ),
        TextFormField(
          initialValue: group['name'],
          decoration: InputDecoration(
            labelText: 'Group Name',
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
          onChanged: isDefault ? null : (value) => group['name'] = value,
          readOnly: isDefault,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: Text(
                'Subfields',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: theme.colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
            ),
            if (!isDefault)
              TextButton.icon(
                onPressed: () => _addSubFieldToGroup(index),
                icon: Icon(
                  Icons.add,
                  size: 16,
                  color: theme.colorScheme.primary,
                ),
                label: Text(
                  'Add Subfield',
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
        const SizedBox(height: 8),
        ...(group['nestedFields'] as List<Map<String, dynamic>>)
            .asMap()
            .entries
            .map(
              (entry) => _buildReadingFieldCard(
                entry.value,
                index,
                theme,
                isSubField: true,
                subFieldIndex: entry.key,
                groupIndex: index,
              ),
            ),
      ],
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

  void _onBayTypeSelected(String? newBayType) {
    setState(() {
      _selectedBayType = newBayType;
      _readingFields.clear();
      if (newBayType != null) {
        _addDefaultFieldsForBayType(newBayType);
      }
    });
  }

  void _addDefaultFieldsForBayType(String bayType) {
    final defaultFields = _getDefaultFieldsForBayType(bayType);
    for (final field in defaultFields) {
      _readingFields.add(field.toMap()..['isDefault'] = true);
    }
  }

  List<ReadingField> _getDefaultFieldsForBayType(String bayType) {
    switch (bayType.toLowerCase()) {
      case 'transformer':
        return [
          ReadingField(
            name: 'Current',
            dataType: ReadingFieldDataType.number,
            unit: 'A',
            isMandatory: true,
            frequency: ReadingFrequency.hourly,
            nestedFields: null,
          ),
          ReadingField(
            name: 'Voltage',
            dataType: ReadingFieldDataType.number,
            unit: 'kV',
            isMandatory: true,
            frequency: ReadingFrequency.hourly,
            nestedFields: null,
          ),
        ];
      default:
        return [];
    }
  }

  bool _isDefaultField(String fieldName) {
    return false;
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
        'nestedFields': null,
      });
    });
  }

  void _addGroupReadingField() {
    setState(() {
      _readingFields.add({
        'name': '',
        'dataType': 'group',
        'frequency': 'daily',
        'unit': '',
        'isMandatory': false,
        'isDefault': false,
        'nestedFields': <Map<String, dynamic>>[],
      });
    });
  }

  void _addSubFieldToGroup(int groupIndex) {
    setState(() {
      final group = _readingFields[groupIndex];
      (group['nestedFields'] as List<Map<String, dynamic>>).add({
        'name': '',
        'dataType': 'text',
        'frequency': 'daily',
        'unit': '',
        'isMandatory': false,
        'isDefault': false,
        'nestedFields': null,
      });
    });
  }

  void _removeReadingField(int index) {
    setState(() => _readingFields.removeAt(index));
  }

  void _removeSubField(int groupIndex, int subFieldIndex) {
    setState(() {
      final group = _readingFields[groupIndex];
      (group['nestedFields'] as List<Map<String, dynamic>>).removeAt(
        subFieldIndex,
      );
    });
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
      SnackBarUtils.showSnackBar(
        context,
        'Failed to load templates: $e',
        isError: true,
      );
    } finally {
      setState(() => _isLoading = false);
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
        if (fieldMap['dataType'] == 'group') {
          return ReadingField.fromMap({
            ...fieldMap,
            'nestedFields':
                (fieldMap['nestedFields'] as List<Map<String, dynamic>>)
                    .map((subField) => ReadingField.fromMap(subField).toMap())
                    .toList(),
          });
        }
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
