// lib/screens/admin/bay_relationship_management_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dropdown_search/dropdown_search.dart';
import '../../models/hierarchy_models.dart';
import '../../models/bay_model.dart';
import '../../models/user_model.dart';
import '../../utils/snackbar_utils.dart';

class BayRelationshipManagementScreen extends StatefulWidget {
  final AppUser currentUser;

  const BayRelationshipManagementScreen({super.key, required this.currentUser});

  @override
  _BayRelationshipManagementScreenState createState() =>
      _BayRelationshipManagementScreenState();
}

class _BayRelationshipManagementScreenState
    extends State<BayRelationshipManagementScreen> {
  Substation? _selectedSubstation;
  List<Substation> _substations = [];
  List<Bay> _baysInSubstation = [];
  List<Bay> _busbarsInSubstation = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchSubstations();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: _buildAppBar(theme),
      body: _buildBody(theme),
    );
  }

  PreferredSizeWidget _buildAppBar(ThemeData theme) {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      title: Text(
        'Bay Connections',
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

  Widget _buildBody(ThemeData theme) {
    return Column(
      children: [
        _buildSubstationSelector(theme),
        if (_isLoading)
          const Expanded(child: Center(child: CircularProgressIndicator()))
        else if (_selectedSubstation != null)
          Expanded(child: _buildBaysList(theme))
        else
          Expanded(child: _buildEmptyState(theme)),
      ],
    );
  }

  Widget _buildSubstationSelector(ThemeData theme) {
    return Container(
      margin: const EdgeInsets.all(24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: DropdownSearch<Substation>(
        items: _substations,
        itemAsString: (Substation s) => '${s.voltageLevel} - ${s.name}',
        selectedItem: _selectedSubstation,
        onChanged: _onSubstationSelected,
        dropdownDecoratorProps: DropDownDecoratorProps(
          dropdownSearchDecoration: InputDecoration(
            labelText: 'Select Substation',
            border: InputBorder.none,
            labelStyle: TextStyle(color: theme.colorScheme.primary),
          ),
        ),
        popupProps: PopupProps.menu(
          showSearchBox: true,
          searchFieldProps: TextFieldProps(
            decoration: InputDecoration(
              hintText: 'Search substations...',
              prefixIcon: Icon(Icons.search, color: theme.colorScheme.primary),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.electrical_services_outlined,
            size: 64,
            color: theme.colorScheme.onSurface.withOpacity(0.3),
          ),
          const SizedBox(height: 16),
          Text(
            'Select a substation',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: theme.colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Choose a substation to manage bay connections',
            style: TextStyle(
              fontSize: 14,
              color: theme.colorScheme.onSurface.withOpacity(0.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBaysList(ThemeData theme) {
    final connectableBays = _baysInSubstation
        .where((bay) => bay.bayType != 'Busbar')
        .toList();

    if (connectableBays.isEmpty) {
      return _buildNoBaysState(theme);
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      itemCount: connectableBays.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final bay = connectableBays[index];
        return _buildBayConnectionCard(bay, theme);
      },
    );
  }

  Widget _buildNoBaysState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.device_hub_outlined,
            size: 64,
            color: theme.colorScheme.onSurface.withOpacity(0.3),
          ),
          const SizedBox(height: 16),
          Text(
            'No connectable bays',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: theme.colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'This substation has no bays that can be connected',
            style: TextStyle(
              fontSize: 14,
              color: theme.colorScheme.onSurface.withOpacity(0.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBayConnectionCard(Bay bay, ThemeData theme) {
    final connectionStatus = _getBayConnectionStatus(bay);

    return Container(
      padding: const EdgeInsets.all(16),
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
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: _getBayTypeColor(bay.bayType),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      bay.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      '${bay.bayType} • ${bay.voltageLevel}',
                      style: TextStyle(
                        fontSize: 13,
                        color: theme.colorScheme.onSurface.withOpacity(0.6),
                      ),
                    ),
                  ],
                ),
              ),
              TextButton.icon(
                onPressed: () => _showConnectionDialog(bay),
                icon: const Icon(Icons.settings, size: 16),
                label: const Text('Configure'),
                style: TextButton.styleFrom(
                  foregroundColor: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.link,
                  size: 16,
                  color: theme.colorScheme.onSurface.withOpacity(0.6),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    connectionStatus,
                    style: TextStyle(
                      fontSize: 13,
                      color: theme.colorScheme.onSurface.withOpacity(0.8),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
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
      default:
        return Colors.grey;
    }
  }

  String _getBayConnectionStatus(Bay bay) {
    if (bay.bayType == 'Transformer') {
      final hvBus = _busbarsInSubstation.firstWhere(
        (b) => b.id == bay.hvBusId,
        orElse: () => Bay(
          id: '',
          name: 'Not connected',
          substationId: '',
          voltageLevel: '',
          bayType: '',
          createdBy: '',
          createdAt: Timestamp.now(),
        ),
      );

      final lvBus = _busbarsInSubstation.firstWhere(
        (b) => b.id == bay.lvBusId,
        orElse: () => Bay(
          id: '',
          name: 'Not connected',
          substationId: '',
          voltageLevel: '',
          bayType: '',
          createdBy: '',
          createdAt: Timestamp.now(),
        ),
      );

      return 'HV: ${hvBus.name} • LV: ${lvBus.name}';
    } else if (bay.bayType != 'Battery') {
      return 'Single connection - Configure via Edit';
    }

    return 'No connection required';
  }

  // Existing methods remain the same
  Future<void> _fetchSubstations() async {
    setState(() => _isLoading = true);
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('substations')
          .orderBy('name')
          .get();
      _substations = snapshot.docs
          .map((doc) => Substation.fromFirestore(doc))
          .toList();
    } catch (e) {
      SnackBarUtils.showSnackBar(
        context,
        'Error fetching substations: $e',
        isError: true,
      );
    }
    setState(() => _isLoading = false);
  }

  Future<void> _onSubstationSelected(Substation? substation) async {
    if (substation == null) return;

    setState(() {
      _selectedSubstation = substation;
      _isLoading = true;
      _baysInSubstation.clear();
      _busbarsInSubstation.clear();
    });

    try {
      final baySnapshot = await FirebaseFirestore.instance
          .collection('bays')
          .where('substationId', isEqualTo: substation.id)
          .get();

      _baysInSubstation = baySnapshot.docs
          .map((doc) => Bay.fromFirestore(doc))
          .toList();

      _busbarsInSubstation = _baysInSubstation
          .where((bay) => bay.bayType == 'Busbar')
          .toList();
    } catch (e) {
      SnackBarUtils.showSnackBar(
        context,
        'Error fetching bays: $e',
        isError: true,
      );
    }

    setState(() => _isLoading = false);
  }

  void _showConnectionDialog(Bay bay) {
    showDialog(
      context: context,
      builder: (context) => _BayConnectionDialog(
        currentUser: widget.currentUser,
        substationId: _selectedSubstation!.id,
        bays: _baysInSubstation,
        busbars: _busbarsInSubstation,
        bayToEdit: bay,
        onSave: () {
          Navigator.of(context).pop();
          _onSubstationSelected(_selectedSubstation);
        },
      ),
    );
  }
}

// Connection dialog remains the same but with cleaner styling
class _BayConnectionDialog extends StatefulWidget {
  final AppUser currentUser;
  final String substationId;
  final List<Bay> bays;
  final List<Bay> busbars;
  final Bay? bayToEdit;
  final VoidCallback onSave;

  const _BayConnectionDialog({
    required this.currentUser,
    required this.substationId,
    required this.bays,
    required this.busbars,
    this.bayToEdit,
    required this.onSave,
  });

  @override
  __BayConnectionDialogState createState() => __BayConnectionDialogState();
}

class __BayConnectionDialogState extends State<_BayConnectionDialog> {
  final _formKey = GlobalKey<FormState>();
  bool _isSaving = false;
  String? _selectedSingleBusId;
  String? _selectedHvBusId;
  String? _selectedLvBusId;
  String? _bayHvVoltage;
  String? _bayLvVoltage;

  @override
  void initState() {
    super.initState();
    if (widget.bayToEdit != null) {
      final bay = widget.bayToEdit!;
      if (bay.bayType == 'Transformer') {
        _selectedHvBusId = bay.hvBusId;
        _selectedLvBusId = bay.lvBusId;
        _bayHvVoltage = bay.hvVoltage;
        _bayLvVoltage = bay.lvVoltage;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bay = widget.bayToEdit!;
    final bool isTransformer = bay.bayType == 'Transformer';
    final bool isBusbarOrBattery =
        bay.bayType == 'Busbar' || bay.bayType == 'Battery';

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        width: 500,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Configure ${bay.name}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 20),

            if (isTransformer) ...[
              _buildConnectionSection(
                'HV Connection',
                _bayHvVoltage,
                _selectedHvBusId,
                (value) {
                  setState(() => _selectedHvBusId = value?.id);
                },
              ),
              const SizedBox(height: 16),
              _buildConnectionSection(
                'LV Connection',
                _bayLvVoltage,
                _selectedLvBusId,
                (value) {
                  setState(() => _selectedLvBusId = value?.id);
                },
              ),
            ] else if (!isBusbarOrBattery) ...[
              _buildConnectionSection(
                'Bus Connection',
                bay.voltageLevel,
                _selectedSingleBusId,
                (value) {
                  setState(() => _selectedSingleBusId = value?.id);
                },
              ),
            ] else ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'This bay type does not require bus connections.',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              ),
            ],

            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: _isSaving ? null : _saveConnections,
                  child: _isSaving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Save'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConnectionSection(
    String title,
    String? voltage,
    String? selectedId,
    Function(Bay?) onChanged,
  ) {
    final compatibleBusbars = widget.busbars
        .where((b) => b.voltageLevel == voltage)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
        if (voltage != null)
          Text(
            'Voltage: $voltage',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
        const SizedBox(height: 8),
        DropdownSearch<Bay>(
          items: compatibleBusbars,
          itemAsString: (Bay b) => '${b.name} (${b.voltageLevel})',
          selectedItem: compatibleBusbars.firstWhere(
            (b) => b.id == selectedId,
            orElse: () => Bay(
              id: '',
              name: 'Select bus',
              substationId: '',
              voltageLevel: '',
              bayType: '',
              createdBy: '',
              createdAt: Timestamp.now(),
            ),
          ),
          onChanged: onChanged,
          dropdownDecoratorProps: DropDownDecoratorProps(
            dropdownSearchDecoration: InputDecoration(
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 8,
              ),
            ),
          ),
          popupProps: PopupProps.menu(showSearchBox: true),
        ),
      ],
    );
  }

  Future<void> _saveConnections() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    try {
      final bayRef = FirebaseFirestore.instance
          .collection('bays')
          .doc(widget.bayToEdit!.id);
      Map<String, dynamic> updateData = {};

      if (widget.bayToEdit!.bayType == 'Transformer') {
        updateData['hvBusId'] = _selectedHvBusId;
        updateData['lvBusId'] = _selectedLvBusId;
      }

      await bayRef.update(updateData);

      SnackBarUtils.showSnackBar(context, 'Connections saved successfully!');

      widget.onSave();
    } catch (e) {
      SnackBarUtils.showSnackBar(
        context,
        'Error saving connections: $e',
        isError: true,
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
}
