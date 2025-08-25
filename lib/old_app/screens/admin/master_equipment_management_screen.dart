import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/equipment_model.dart';
import '../../utils/snackbar_utils.dart';
import 'package:intl/intl.dart';

// Import all the icon painters
import '../../equipment_icons/transformer_icon.dart';
import '../../equipment_icons/circuit_breaker_icon.dart';
import '../../equipment_icons/ct_icon.dart';
import '../../equipment_icons/pt_icon.dart';
import '../../equipment_icons/relay_icon.dart';
import '../../equipment_icons/capacitor_bank_icon.dart';
import '../../equipment_icons/reactor_icon.dart';
import '../../equipment_icons/surge_arrester_icon.dart';
import '../../equipment_icons/energy_meter_icon.dart';
import '../../equipment_icons/ground_icon.dart';
import '../../equipment_icons/busbar_icon.dart';
import '../../equipment_icons/isolator_icon.dart';
import '../../equipment_icons/other_icon.dart';

class MasterEquipmentScreen extends StatefulWidget {
  const MasterEquipmentScreen({super.key});

  @override
  State<MasterEquipmentScreen> createState() => _MasterEquipmentScreenState();
}

class _MasterEquipmentScreenState extends State<MasterEquipmentScreen> {
  bool _showForm = false;
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _equipmentTypeController =
      TextEditingController();

  // ✅ KEEP these fields for data model but don't show in UI
  final TextEditingController _makeController = TextEditingController();
  DateTime? _dateOfManufacture;
  DateTime? _dateOfCommissioning;

  String? _selectedSymbolKey;
  MasterEquipmentTemplate? _templateToEdit;
  List<MasterEquipmentTemplate> _templates = [];
  List<Map<String, dynamic>> _customFields = [];
  bool _isLoading = true;
  bool _isSaving = false;

  final List<Map<String, dynamic>> _availableSymbols = [
    {'key': 'Transformer', 'name': 'Transformer'},
    {'key': 'Circuit Breaker', 'name': 'Circuit Breaker'},
    {'key': 'Current Transformer', 'name': 'Current Transformer'},
    {'key': 'Voltage Transformer', 'name': 'Voltage Transformer'},
    {'key': 'Relay', 'name': 'Relay'},
    {'key': 'Capacitor Bank', 'name': 'Capacitor Bank'},
    {'key': 'Reactor', 'name': 'Reactor'},
    {'key': 'Surge Arrester', 'name': 'Surge Arrester'},
    {'key': 'Energy Meter', 'name': 'Energy Meter'},
    {'key': 'Ground', 'name': 'Ground'},
    {'key': 'Busbar', 'name': 'Busbar'},
    {'key': 'Isolator', 'name': 'Isolator'},
    {'key': 'Other', 'name': 'Other'},
  ];

  final List<String> _dataTypes = [
    'text',
    'number',
    'boolean',
    'date',
    'dropdown',
  ];

  @override
  void initState() {
    super.initState();
    _fetchEquipmentTemplates();
  }

  // Helper method to get the appropriate icon painter for a symbol key
  Widget _getEquipmentIcon(String symbolKey, {double size = 24, Color? color}) {
    final iconColor = color ?? Theme.of(context).colorScheme.primary;
    final iconSize = Size(size, size);

    EquipmentPainter painter;

    switch (symbolKey) {
      case 'Transformer':
        painter = TransformerIconPainter(
          color: iconColor,
          equipmentSize: iconSize,
          symbolSize: iconSize,
        );
        break;
      case 'Circuit Breaker':
        painter = CircuitBreakerIconPainter(
          color: iconColor,
          equipmentSize: iconSize,
          symbolSize: iconSize,
        );
        break;
      case 'Current Transformer':
        painter = CurrentTransformerIconPainter(
          color: iconColor,
          equipmentSize: iconSize,
          symbolSize: iconSize,
        );
        break;
      case 'Voltage Transformer':
        painter = PotentialTransformerIconPainter(
          color: iconColor,
          equipmentSize: iconSize,
          symbolSize: iconSize,
        );
        break;
      case 'Relay':
        painter = RelayIconPainter(
          color: iconColor,
          equipmentSize: iconSize,
          symbolSize: iconSize,
        );
        break;
      case 'Capacitor Bank':
        painter = CapacitorBankIconPainter(
          color: iconColor,
          equipmentSize: iconSize,
          symbolSize: iconSize,
        );
        break;
      case 'Reactor':
        painter = ReactorIconPainter(
          color: iconColor,
          equipmentSize: iconSize,
          symbolSize: iconSize,
        );
        break;
      case 'Surge Arrester':
        painter = SurgeArresterIconPainter(
          color: iconColor,
          equipmentSize: iconSize,
          symbolSize: iconSize,
        );
        break;
      case 'Energy Meter':
        painter = EnergyMeterIconPainter(
          color: iconColor,
          equipmentSize: iconSize,
          symbolSize: iconSize,
        );
        break;
      case 'Ground':
        painter = GroundIconPainter(
          color: iconColor,
          equipmentSize: iconSize,
          symbolSize: iconSize,
        );
        break;
      case 'Busbar':
        painter = BusbarIconPainter(
          color: iconColor,
          equipmentSize: iconSize,
          symbolSize: iconSize,
        );
        break;
      case 'Isolator':
        painter = IsolatorIconPainter(
          color: iconColor,
          equipmentSize: iconSize,
          symbolSize: iconSize,
        );
        break;
      case 'Other':
      default:
        painter = OtherIconPainter(
          color: iconColor,
          equipmentSize: iconSize,
          symbolSize: iconSize,
        );
        break;
    }

    return CustomPaint(painter: painter, size: iconSize);
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
                  ? 'New Equipment Type'
                  : 'Edit Equipment Type')
            : 'Equipment Templates',
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

    return ListView.separated(
      padding: const EdgeInsets.all(24),
      itemCount: _templates.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final template = _templates[index];
        return _buildTemplateCard(template, theme);
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
              Icons.construction_outlined,
              size: 40,
              color: theme.colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'No equipment templates',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: theme.colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap the + button to create your first template',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: theme.colorScheme.onSurface.withOpacity(0.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTemplateCard(MasterEquipmentTemplate template, ThemeData theme) {
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
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Center(
                  child: _getEquipmentIcon(
                    template.symbolKey,
                    size: 20,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      template.equipmentType,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      template.symbolKey,
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.onSurface.withOpacity(0.6),
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'edit') {
                    _showFormForEdit(template);
                  } else if (value == 'delete') {
                    _deleteTemplate(template.id);
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(value: 'edit', child: Text('Edit')),
                  const PopupMenuItem(value: 'delete', child: Text('Delete')),
                ],
                child: Icon(
                  Icons.more_vert,
                  size: 18,
                  color: theme.colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
            ],
          ),
          // ✅ REMOVED: Make and Date of Commissioning display
          const SizedBox(height: 8),
          _buildInfoChip(
            '${template.equipmentCustomFields.length} custom fields',
            Icons.tune,
            theme,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip(String text, IconData icon, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withOpacity(0.05),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: theme.colorScheme.onSurface.withOpacity(0.6),
          ),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: theme.colorScheme.onSurface.withOpacity(0.6),
            ),
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
            _buildBasicInfoSection(theme),
            const SizedBox(height: 24),
            _buildCustomFieldsSection(theme),
            const SizedBox(height: 24),
            _buildActionButtons(theme),
          ],
        ),
      ),
    );
  }

  Widget _buildBasicInfoSection(ThemeData theme) {
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
            'Basic Information',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 16),
          _buildTextField(
            controller: _equipmentTypeController,
            label: 'Equipment Type Name *',
            hint: 'e.g., Power Transformer, Relay',
            theme: theme,
            validator: (value) =>
                value?.trim().isEmpty == true ? 'Required' : null,
          ),
          const SizedBox(height: 16),
          _buildSymbolDropdown(theme),
          // ✅ Fields are hidden from UI but will be saved with default values
        ],
      ),
    );
  }

  // Updated symbol dropdown with icons
  Widget _buildSymbolDropdown(ThemeData theme) {
    return DropdownButtonFormField<String>(
      value: _selectedSymbolKey,
      decoration: InputDecoration(
        labelText: 'Equipment Symbol *',
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
          borderSide: BorderSide(color: theme.colorScheme.primary, width: 2),
        ),
        errorBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: theme.colorScheme.error),
        ),
        focusedErrorBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: theme.colorScheme.error, width: 2),
        ),
      ),
      items: _availableSymbols.map((symbol) {
        return DropdownMenuItem<String>(
          value: symbol['key'],
          child: Row(
            children: [
              SizedBox(
                width: 24,
                height: 24,
                child: _getEquipmentIcon(
                  symbol['key']!,
                  size: 20,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  symbol['name']!,
                  style: TextStyle(
                    fontSize: 14,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
      onChanged: (value) => setState(() => _selectedSymbolKey = value),
      validator: (value) => value == null ? 'Required' : null,
      style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 14),
      dropdownColor: Colors.white,
      icon: Icon(
        Icons.arrow_drop_down,
        color: theme.colorScheme.onSurface.withOpacity(0.6),
      ),
      selectedItemBuilder: (BuildContext context) {
        return _availableSymbols.map<Widget>((symbol) {
          return Row(
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: _getEquipmentIcon(
                  symbol['key']!,
                  size: 16,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                symbol['name']!,
                style: TextStyle(
                  fontSize: 14,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ],
          );
        }).toList();
      },
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required ThemeData theme,
    String? hint,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: TextStyle(
          color: theme.colorScheme.onSurface.withOpacity(0.6),
          fontSize: 14,
        ),
        hintStyle: TextStyle(
          color: theme.colorScheme.onSurface.withOpacity(0.4),
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
          borderSide: BorderSide(color: theme.colorScheme.primary, width: 2),
        ),
        errorBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: theme.colorScheme.error),
        ),
        focusedErrorBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: theme.colorScheme.error, width: 2),
        ),
      ),
      style: TextStyle(fontSize: 14, color: theme.colorScheme.onSurface),
      validator: validator,
    );
  }

  Widget _buildDropdown({
    required String? value,
    required String label,
    required List<String> items,
    required ThemeData theme,
    required ValueChanged<String?> onChanged,
    String? Function(String?)? validator,
  }) {
    return DropdownButtonFormField<String>(
      value: value,
      decoration: InputDecoration(
        labelText: label,
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
          borderSide: BorderSide(color: theme.colorScheme.primary, width: 2),
        ),
        errorBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: theme.colorScheme.error),
        ),
        focusedErrorBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: theme.colorScheme.error, width: 2),
        ),
      ),
      items: items.map((item) {
        return DropdownMenuItem(
          value: item,
          child: Text(
            item,
            style: TextStyle(fontSize: 14, color: theme.colorScheme.onSurface),
          ),
        );
      }).toList(),
      onChanged: onChanged,
      validator: validator,
      style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 14),
      dropdownColor: Colors.white,
      icon: Icon(
        Icons.arrow_drop_down,
        color: theme.colorScheme.onSurface.withOpacity(0.6),
      ),
    );
  }

  Widget _buildDateField(
    String label,
    DateTime? date,
    Function(DateTime?) onChanged,
    ThemeData theme,
  ) {
    return GestureDetector(
      onTap: () => _selectDate(date, onChanged),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          border: Border.all(color: theme.colorScheme.outline.withOpacity(0.3)),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          children: [
            Icon(
              Icons.calendar_today_outlined,
              size: 16,
              color: theme.colorScheme.onSurface.withOpacity(0.6),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                date == null ? label : DateFormat('yyyy-MM-dd').format(date),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: date == null
                      ? theme.colorScheme.onSurface.withOpacity(0.6)
                      : theme.colorScheme.onSurface,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomFieldsSection(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ✅ Header outside the card
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: Text(
            'Custom Fields',
            style: TextStyle(
              fontSize: 18, // ✅ Larger font size for header
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.primary,
              letterSpacing: 0.5,
            ),
          ),
        ),
        const SizedBox(height: 8),

        // ✅ Card content without header inside
        Container(
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
              // ✅ Action buttons row
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: _addCustomField,
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
                  TextButton.icon(
                    onPressed: _addGroupField,
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
              if (_customFields.isEmpty)
                Container(
                  width: double.infinity, // ✅ Make container take full width
                  padding: const EdgeInsets.all(
                    24,
                  ), // ✅ Increased padding for better spacing
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Column(
                    mainAxisAlignment:
                        MainAxisAlignment.center, // ✅ Center content vertically
                    crossAxisAlignment: CrossAxisAlignment
                        .center, // ✅ Center content horizontally
                    children: [
                      Icon(
                        Icons.list_alt,
                        color: theme.colorScheme.onSurface.withOpacity(0.4),
                        size: 40,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'No custom fields or groups defined',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: theme.colorScheme.onSurface.withOpacity(0.5),
                        ),
                        textAlign: TextAlign.center, // ✅ Center text alignment
                      ),
                    ],
                  ),
                )
              else
                ...List.generate(_customFields.length, (index) {
                  final field = _customFields[index];
                  if (field['isGroup'] == true) {
                    return _buildGroupFieldInput(field, index, theme);
                  } else {
                    return _buildCustomFieldInput(field, index, theme);
                  }
                }),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCustomFieldInput(
    Map<String, dynamic> field,
    int index,
    ThemeData theme, {
    bool isSubField = false,
    int? subFieldIndex,
  }) {
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
                      ? _removeSubField(index, subFieldIndex!)
                      : _removeCustomField(index),
                  icon: Icon(
                    Icons.delete_outline,
                    color: theme.colorScheme.error,
                    size: 18,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),

          // Field Name
          TextFormField(
            initialValue: field['name'],
            decoration: InputDecoration(
              labelText: isSubField ? 'Sub-field Name' : 'Field Name',
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

          // Data Type - Using DropdownButtonFormField directly instead of _buildDropdown
          DropdownButtonFormField<String>(
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
            items: _dataTypes.map((item) {
              return DropdownMenuItem(
                value: item,
                child: Text(
                  item,
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
                    field['dataType'] = value;
                    if (value != 'number') {
                      field['hasUnits'] = false;
                      field['units'] = '';
                    }
                  }),
            style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 14),
            dropdownColor: Colors.white,
            icon: Icon(
              Icons.arrow_drop_down,
              color: theme.colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
          const SizedBox(height: 12),

          // Mandatory Checkbox
          CheckboxListTile(
            title: const Text('Mandatory', style: TextStyle(fontSize: 14)),
            value: field['isMandatory'] ?? false,
            onChanged: isDefault
                ? null
                : (value) => setState(() => field['isMandatory'] = value),
            dense: true,
            contentPadding: EdgeInsets.zero,
          ),
          const SizedBox(height: 8),

          // Has Units Checkbox (conditional)
          if (field['dataType'] == 'number')
            CheckboxListTile(
              title: const Text('Has Units', style: TextStyle(fontSize: 14)),
              value: field['hasUnits'] ?? false,
              onChanged: isDefault
                  ? null
                  : (value) => setState(() => field['hasUnits'] = value),
              dense: true,
              contentPadding: EdgeInsets.zero,
            ),

          // Units Field (conditional)
          if (field['hasUnits'] == true && field['dataType'] == 'number') ...[
            const SizedBox(height: 12),
            TextFormField(
              initialValue: field['units'],
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
              onChanged: isDefault ? null : (value) => field['units'] = value,
              readOnly: isDefault,
            ),
          ],

          // Has Remarks Field Checkbox
          CheckboxListTile(
            title: const Text(
              'Has Remarks Field',
              style: TextStyle(fontSize: 14),
            ),
            value: field['hasRemarksField'] ?? false,
            onChanged: isDefault
                ? null
                : (value) => setState(() => field['hasRemarksField'] = value),
            dense: true,
            contentPadding: EdgeInsets.zero,
          ),

          // Template Remark Text (conditional)
          if (field['hasRemarksField'] == true) ...[
            const SizedBox(height: 12),
            TextFormField(
              initialValue: field['templateRemarkText'],
              decoration: InputDecoration(
                labelText: 'Template Remark Text',
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
                  : (value) => field['templateRemarkText'] = value,
              readOnly: isDefault,
            ),
          ],

          // Dropdown Options (conditional)
          if (field['dataType'] == 'dropdown') ...[
            const SizedBox(height: 12),
            Row(
              children: [
                const Text('Options:', style: TextStyle(fontSize: 14)),
                const SizedBox(width: 8),
                if (!isDefault)
                  TextButton.icon(
                    onPressed: () => _addDropdownOption(index),
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text(
                      'Add Option',
                      style: TextStyle(fontSize: 14),
                    ),
                  ),
              ],
            ),
            ...List.generate(
              (field['options'] as List<String>).length,
              (optionIndex) => Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        initialValue:
                            (field['options'] as List<String>)[optionIndex],
                        decoration: InputDecoration(
                          labelText: 'Option ${optionIndex + 1}',
                          isDense: true,
                          labelStyle: const TextStyle(fontSize: 14),
                        ),
                        style: const TextStyle(fontSize: 14),
                        onChanged: isDefault
                            ? null
                            : (value) =>
                                  (field['options']
                                          as List<String>)[optionIndex] =
                                      value,
                        readOnly: isDefault,
                      ),
                    ),
                    if (!isDefault)
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline, size: 16),
                        onPressed: () =>
                            _removeDropdownOption(index, optionIndex),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildGroupFieldInput(
    Map<String, dynamic> group,
    int groupIndex,
    ThemeData theme,
  ) {
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
              onPressed: () => _removeCustomField(groupIndex),
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
                onPressed: () => _addSubFieldToGroup(groupIndex),
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
              (entry) => _buildCustomFieldInput(
                entry.value,
                groupIndex,
                theme,
                isSubField: true,
                subFieldIndex: entry.key,
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

  void _showListView() {
    setState(() {
      _showForm = false;
      _templateToEdit = null;
      _clearForm();
    });
    _fetchEquipmentTemplates();
  }

  void _showFormForNew() {
    setState(() {
      _showForm = true;
      _templateToEdit = null;
      _clearForm();
    });
  }

  void _showFormForEdit(MasterEquipmentTemplate template) {
    setState(() {
      _showForm = true;
      _templateToEdit = template;
      _equipmentTypeController.text = template.equipmentType;
      // ✅ Load hidden field values (even though not shown in UI)
      _makeController.text = template.make ?? '';
      _dateOfManufacture = template.dateOfManufacture?.toDate();
      _dateOfCommissioning = template.dateOfCommissioning?.toDate();
      _selectedSymbolKey = template.symbolKey;
      _customFields = template.equipmentCustomFields
          .map((field) => field.toMap())
          .toList();
    });
  }

  void _clearForm() {
    _equipmentTypeController.clear();
    // ✅ Clear hidden fields too
    _makeController.clear();
    _dateOfManufacture = null;
    _dateOfCommissioning = null;
    _selectedSymbolKey = null;
    _customFields.clear();
  }

  void _addCustomField() {
    setState(() {
      _customFields.add({
        'name': '',
        'dataType': 'text',
        'isMandatory': false,
        'hasUnits': false,
        'units': '',
        'options': <String>[],
        'hasRemarksField': false,
        'templateRemarkText': '',
        'nestedFields': null,
        'isGroup': false,
      });
    });
  }

  void _addGroupField() {
    setState(() {
      _customFields.add({
        'name': '',
        'isGroup': true,
        'nestedFields': <Map<String, dynamic>>[],
        'dataType': 'group',
        'isMandatory': false,
        'hasUnits': false,
        'units': '',
        'options': <String>[],
        'hasRemarksField': false,
        'templateRemarkText': '',
      });
    });
  }

  void _addSubFieldToGroup(int groupIndex) {
    setState(() {
      final group = _customFields[groupIndex];
      (group['nestedFields'] as List<Map<String, dynamic>>).add({
        'name': '',
        'dataType': 'text',
        'isMandatory': false,
        'hasUnits': false,
        'units': '',
        'options': <String>[],
        'hasRemarksField': false,
        'templateRemarkText': '',
        'nestedFields': null,
        'isGroup': false,
      });
    });
  }

  void _removeCustomField(int index) {
    setState(() => _customFields.removeAt(index));
  }

  void _removeSubField(int groupIndex, int subFieldIndex) {
    setState(() {
      final group = _customFields[groupIndex];
      (group['nestedFields'] as List<Map<String, dynamic>>).removeAt(
        subFieldIndex,
      );
    });
  }

  void _addDropdownOption(int fieldIndex) {
    setState(() {
      (_customFields[fieldIndex]['options'] as List<String>).add('');
    });
  }

  void _removeDropdownOption(int fieldIndex, int optionIndex) {
    setState(() {
      (_customFields[fieldIndex]['options'] as List<String>).removeAt(
        optionIndex,
      );
    });
  }

  Future<void> _selectDate(
    DateTime? currentDate,
    Function(DateTime?) onChanged,
  ) async {
    final date = await showDatePicker(
      context: context,
      initialDate: currentDate ?? DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime.now().add(const Duration(days: 365 * 10)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: Theme.of(context).colorScheme.primary,
              onPrimary: Theme.of(context).colorScheme.onPrimary,
              surface: Colors.white,
              onSurface: Theme.of(context).colorScheme.onSurface,
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
          child: child!,
        );
      },
    );
    if (date != null) {
      setState(() => onChanged(date));
    }
  }

  Future<void> _fetchEquipmentTemplates() async {
    setState(() => _isLoading = true);
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('masterEquipmentTemplates')
          .orderBy('equipmentType')
          .get();
      _templates = snapshot.docs
          .map((doc) => MasterEquipmentTemplate.fromFirestore(doc))
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
      final templateData = {
        'equipmentType': _equipmentTypeController.text.trim(),
        'symbolKey': _selectedSymbolKey!,
        // ✅ Include hidden fields with default values
        'make': _makeController.text.trim().isEmpty
            ? null
            : _makeController.text.trim(),
        'dateOfManufacture': _dateOfManufacture != null
            ? Timestamp.fromDate(_dateOfManufacture!)
            : null,
        'dateOfCommissioning': _dateOfCommissioning != null
            ? Timestamp.fromDate(_dateOfCommissioning!)
            : null,
        'equipmentCustomFields': _customFields
            .map((field) => CustomField.fromMap(field).toMap())
            .toList(),
        'createdBy': currentUser.uid,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (_templateToEdit == null) {
        // Creating new template
        await FirebaseFirestore.instance
            .collection('masterEquipmentTemplates')
            .add(templateData);

        SnackBarUtils.showSnackBar(
          context,
          'Equipment template created successfully!',
        );
      } else {
        // Updating existing template
        await FirebaseFirestore.instance
            .collection('masterEquipmentTemplates')
            .doc(_templateToEdit!.id)
            .update(templateData);

        SnackBarUtils.showSnackBar(
          context,
          'Equipment template updated successfully!',
        );
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
    // ✅ Add null check
    if (templateId == null) {
      SnackBarUtils.showSnackBar(
        context,
        'Error: Template ID is null.',
        isError: true,
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Template'),
        content: const Text(
          'Are you sure you want to delete this equipment template?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await FirebaseFirestore.instance
            .collection('masterEquipmentTemplates')
            .doc(templateId) // ✅ Now templateId is guaranteed to be non-null
            .delete();

        SnackBarUtils.showSnackBar(
          context,
          'Equipment template deleted successfully!',
        );

        _fetchEquipmentTemplates();
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
