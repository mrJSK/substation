// lib/screens/busbar_configuration_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/bay_model.dart';

class BusbarConfigurationScreen extends StatefulWidget {
  final Bay busbar;
  final List<Bay> connectedBays;

  const BusbarConfigurationScreen({
    super.key,
    required this.busbar,
    required this.connectedBays,
    required Null Function(dynamic inclusionMap) onSaveConfiguration,
  });

  @override
  State<BusbarConfigurationScreen> createState() =>
      _BusbarConfigurationScreenState();
}

class _BusbarConfigurationScreenState extends State<BusbarConfigurationScreen> {
  late Map<String, String> _bayImpSelectionMap;
  late Map<String, String> _bayExpSelectionMap;
  bool _isSaving = false;
  bool _hasUnsavedChanges = false;

  @override
  void initState() {
    super.initState();
    _bayImpSelectionMap = {};
    _bayExpSelectionMap = {};
    for (var bay in widget.connectedBays) {
      _bayImpSelectionMap[bay.id] = 'add_to_busbar_imp';
      _bayExpSelectionMap[bay.id] = 'add_to_busbar_imp';
    }
  }

  void _markAsChanged() {
    if (!_hasUnsavedChanges) {
      setState(() => _hasUnsavedChanges = true);
    }
  }

  Future<bool> _onWillPop() async {
    if (!_hasUnsavedChanges) return true;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Unsaved Changes'),
        content: const Text(
          'You have unsaved changes. Do you want to discard them?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _saveConfiguration() async {
    setState(() => _isSaving = true);

    try {
      await Future.delayed(const Duration(seconds: 1));

      final configMap = {
        'imp': _bayImpSelectionMap,
        'exp': _bayExpSelectionMap,
      };

      if (mounted) {
        Navigator.pop(context, configMap);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving configuration: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    // Set system status bar to match AppBar
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: isDarkMode ? theme.colorScheme.primary : Colors.white,
        statusBarIconBrightness: isDarkMode
            ? Brightness.light
            : Brightness.dark,
        statusBarBrightness: isDarkMode ? Brightness.dark : Brightness.light,
      ),
    );

    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        backgroundColor: const Color(0xFFFAFAFA),
        appBar: AppBar(
          backgroundColor: isDarkMode ? Colors.grey.shade800 : Colors.white,
          foregroundColor: isDarkMode ? Colors.white : Colors.black87,
          elevation: 1,
          shadowColor: Colors.black26,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            'Busbar Configuration',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: isDarkMode ? Colors.white : Colors.black87,
            ),
          ),
          actions: [
            if (_hasUnsavedChanges)
              Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.orange,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Unsaved',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            IconButton(
              onPressed: _isSaving ? null : _saveConfiguration,
              icon: _isSaving
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: isDarkMode ? Colors.white : Colors.black87,
                      ),
                    )
                  : const Icon(Icons.save),
              tooltip: 'Save Configuration',
            ),
          ],
        ),
        body: Column(
          children: [
            // Busbar Info Header - Fixed height and better spacing
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDarkMode ? Colors.grey.shade800 : Colors.white,
                border: Border(
                  bottom: BorderSide(
                    color: isDarkMode
                        ? Colors.grey.shade700
                        : Colors.grey.shade300,
                    width: 1,
                  ),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.electrical_services,
                          color: Colors.blue,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${widget.busbar.voltageLevel} ${widget.busbar.name}',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: isDarkMode
                                    ? Colors.white
                                    : Colors.black87,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Configure energy mapping for connected bays',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDarkMode
                                    ? Colors.white70
                                    : Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _buildInfoChip(
                        icon: Icons.flash_on,
                        label: widget.busbar.voltageLevel,
                        color: Colors.orange,
                      ),
                      const SizedBox(width: 8),
                      _buildInfoChip(
                        icon: Icons.account_tree,
                        label: '${widget.connectedBays.length} bays',
                        color: Colors.green,
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Connected Bays List - Better scrolling
            Expanded(
              child: widget.connectedBays.isEmpty
                  ? _buildEmptyState()
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: widget.connectedBays.length,
                      itemBuilder: (context, index) {
                        final bay = widget.connectedBays[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _buildConnectedBayCard(bay, theme, isDarkMode),
                        );
                      },
                    ),
            ),
          ],
        ),
        bottomNavigationBar: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDarkMode ? Colors.grey.shade800 : Colors.white,
            border: Border(
              top: BorderSide(
                color: isDarkMode ? Colors.grey.shade700 : Colors.grey.shade300,
                width: 1,
              ),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 4,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: SafeArea(
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: BorderSide(
                        color: isDarkMode
                            ? Colors.white54
                            : Colors.grey.shade400,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      'Cancel',
                      style: TextStyle(
                        color: isDarkMode
                            ? Colors.white70
                            : Colors.grey.shade700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _saveConfiguration,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      elevation: 2,
                    ),
                    child: _isSaving
                        ? const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              ),
                              SizedBox(width: 8),
                              Text('Saving...'),
                            ],
                          )
                        : const Text('Save Configuration'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoChip({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.account_tree_outlined,
              size: 48,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              'No Connected Bays',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'This busbar has no connected equipment',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConnectedBayCard(Bay bay, ThemeData theme, bool isDarkMode) {
    final impSelection = _bayImpSelectionMap[bay.id] ?? 'add_to_busbar_imp';
    final expSelection = _bayExpSelectionMap[bay.id] ?? 'add_to_busbar_imp';

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: isDarkMode ? Colors.grey.shade800 : Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Bay Header - More compact
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _getBayTypeColor(bay.bayType).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    _getBayTypeIcon(bay.bayType),
                    color: _getBayTypeColor(bay.bayType),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        bay.name,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: isDarkMode ? Colors.white : Colors.black87,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        '${bay.bayType} • ${bay.voltageLevel}',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDarkMode
                              ? Colors.white60
                              : Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Energy Configuration - Better layout
            Row(
              children: [
                // IMP Configuration
                Expanded(
                  child: _buildEnergyConfigCard(
                    title: 'IMP',
                    icon: Icons.arrow_downward,
                    color: Colors.green,
                    value: impSelection,
                    onChanged: (value) {
                      setState(() {
                        _bayImpSelectionMap[bay.id] = value;
                        _markAsChanged();
                      });
                    },
                    isDarkMode: isDarkMode,
                  ),
                ),
                const SizedBox(width: 12),

                // EXP Configuration
                Expanded(
                  child: _buildEnergyConfigCard(
                    title: 'EXP',
                    icon: Icons.arrow_upward,
                    color: Colors.orange,
                    value: expSelection,
                    onChanged: (value) {
                      setState(() {
                        _bayExpSelectionMap[bay.id] = value;
                        _markAsChanged();
                      });
                    },
                    isDarkMode: isDarkMode,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEnergyConfigCard({
    required String title,
    required IconData icon,
    required Color color,
    required String value,
    required Function(String) onChanged,
    required bool isDarkMode,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: value,
            isDense: true,
            decoration: InputDecoration(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 6,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: BorderSide(color: Colors.grey.withOpacity(0.3)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: BorderSide(color: Colors.grey.withOpacity(0.3)),
              ),
            ),
            style: TextStyle(
              fontSize: 11,
              color: isDarkMode ? Colors.white : Colors.black87,
            ),
            items: const [
              DropdownMenuItem(
                value: 'add_to_busbar_imp',
                child: Text('→ Busbar IMP'),
              ),
              DropdownMenuItem(
                value: 'add_to_busbar_exp',
                child: Text('→ Busbar EXP'),
              ),
            ],
            onChanged: (newValue) {
              if (newValue != null) {
                onChanged(newValue);
              }
            },
          ),
        ],
      ),
    );
  }

  Color _getBayTypeColor(String bayType) {
    switch (bayType.toLowerCase()) {
      case 'transformer':
        return Colors.purple;
      case 'line':
        return Colors.blue;
      case 'feeder':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  IconData _getBayTypeIcon(String bayType) {
    switch (bayType.toLowerCase()) {
      case 'transformer':
        return Icons.transform;
      case 'line':
        return Icons.power_input;
      case 'feeder':
        return Icons.cable;
      default:
        return Icons.electrical_services;
    }
  }
}
