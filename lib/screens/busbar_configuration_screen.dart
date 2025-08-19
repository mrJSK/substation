// lib/screens/busbar_configuration_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/bay_model.dart';
import '../models/busbar_energy_map.dart';

class BusbarConfigurationScreen extends StatefulWidget {
  final Bay busbar;
  final List<Bay> connectedBays;
  final List<Bay>?
  allSubstationBays; // All bays in substation for substation config
  final Map<String, BusbarEnergyMap>? currentConfiguration;
  final Map<String, BusbarEnergyMap>?
  substationConfiguration; // Substation config
  // Updated callback to accept selection DTOs instead of BusbarEnergyMap objects
  final Function(
    Map<String, Map<String, EnergyContributionType>>, // Busbar selections DTO
    Map<
      String,
      Map<String, EnergyContributionType>
    >?, // Substation selections DTO
  )
  onSaveConfiguration;

  const BusbarConfigurationScreen({
    super.key,
    required this.busbar,
    required this.connectedBays,
    this.allSubstationBays,
    this.currentConfiguration,
    this.substationConfiguration,
    required this.onSaveConfiguration,
  });

  @override
  State<BusbarConfigurationScreen> createState() =>
      _BusbarConfigurationScreenState();
}

class _BusbarConfigurationScreenState extends State<BusbarConfigurationScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Busbar configuration selections
  late Map<String, EnergyContributionType> _bayImpSelectionMap;
  late Map<String, EnergyContributionType> _bayExpSelectionMap;

  // Substation configuration selections
  late Map<String, EnergyContributionType> _substationImpSelectionMap;
  late Map<String, EnergyContributionType> _substationExpSelectionMap;

  bool _isSaving = false;
  bool _hasUnsavedChanges = false;

  @override
  void initState() {
    super.initState();

    // Initialize tab controller (2 tabs if substation bays provided, 1 otherwise)
    final tabCount = widget.allSubstationBays != null ? 2 : 1;
    _tabController = TabController(length: tabCount, vsync: this);

    _bayImpSelectionMap = {};
    _bayExpSelectionMap = {};

    // Initialize busbar configuration from existing mappings
    for (var bay in widget.connectedBays) {
      final existingConfig = widget.currentConfiguration?[bay.id];
      _bayImpSelectionMap[bay.id] =
          existingConfig?.importContribution ?? EnergyContributionType.none;
      _bayExpSelectionMap[bay.id] =
          existingConfig?.exportContribution ?? EnergyContributionType.none;
    }

    // Initialize substation configuration
    _substationImpSelectionMap = {};
    _substationExpSelectionMap = {};

    if (widget.allSubstationBays != null) {
      final allBusbars = widget.allSubstationBays!
          .where((bay) => bay.bayType == 'Busbar')
          .toList();

      for (var busbar in allBusbars) {
        final existingConfig = widget.substationConfiguration?[busbar.id];
        _substationImpSelectionMap[busbar.id] =
            existingConfig?.importContribution ??
            EnergyContributionType.busImport;
        _substationExpSelectionMap[busbar.id] =
            existingConfig?.exportContribution ??
            EnergyContributionType.busExport;
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _markAsChanged() {
    if (!_hasUnsavedChanges) {
      setState(() => _hasUnsavedChanges = true);
    }
  }

  Future<bool> _onWillPop() async {
    if (!_hasUnsavedChanges) return true;

    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDarkMode ? const Color(0xFF1C1C1E) : null,
        title: Text(
          'Unsaved Changes',
          style: TextStyle(color: isDarkMode ? Colors.white : null),
        ),
        content: Text(
          'You have unsaved changes. Do you want to discard them?',
          style: TextStyle(color: isDarkMode ? Colors.white : null),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'Discard',
              style: TextStyle(color: Colors.red.shade600),
            ),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  // Updated save method - creates simple selection DTOs instead of BusbarEnergyMap objects
  Future<void> _saveConfiguration() async {
    setState(() => _isSaving = true);

    try {
      await Future.delayed(const Duration(milliseconds: 300));

      // Create busbar selections DTO
      final Map<String, Map<String, EnergyContributionType>> busbarSelections =
          {};

      for (var bay in widget.connectedBays) {
        busbarSelections[bay.id] = {
          'imp': _bayImpSelectionMap[bay.id] ?? EnergyContributionType.none,
          'exp': _bayExpSelectionMap[bay.id] ?? EnergyContributionType.none,
        };
      }

      // Create substation selections DTO if applicable
      Map<String, Map<String, EnergyContributionType>>? substationSelections;

      if (widget.allSubstationBays != null) {
        substationSelections = {};
        final allBusbars = widget.allSubstationBays!
            .where((bay) => bay.bayType == 'Busbar')
            .toList();

        for (var busbar in allBusbars) {
          substationSelections[busbar.id] = {
            'imp':
                _substationImpSelectionMap[busbar.id] ??
                EnergyContributionType.busImport,
            'exp':
                _substationExpSelectionMap[busbar.id] ??
                EnergyContributionType.busExport,
          };
        }
      }

      // Call the service with selection DTOs
      await widget.onSaveConfiguration(busbarSelections, substationSelections);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Text('Configuration saved successfully!'),
              ],
            ),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(child: Text('Error saving configuration: $e')),
              ],
            ),
            backgroundColor: Colors.red,
          ),
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

    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: isDarkMode ? const Color(0xFF1C1C1E) : Colors.white,
        statusBarIconBrightness: isDarkMode
            ? Brightness.light
            : Brightness.dark,
        statusBarBrightness: isDarkMode ? Brightness.dark : Brightness.light,
      ),
    );

    return PopScope(
      canPop: !_hasUnsavedChanges,
      onPopInvoked: (didPop) async {
        if (!didPop && _hasUnsavedChanges) {
          final shouldPop = await _onWillPop();
          if (shouldPop && mounted) {
            Navigator.of(context).pop();
          }
        }
      },
      child: Scaffold(
        backgroundColor: isDarkMode
            ? const Color(0xFF1C1C1E)
            : const Color(0xFFFAFAFA),
        appBar: AppBar(
          backgroundColor: isDarkMode ? const Color(0xFF2C2C2E) : Colors.white,
          foregroundColor: isDarkMode ? Colors.white : Colors.black87,
          elevation: 1,
          shadowColor: isDarkMode
              ? Colors.black.withOpacity(0.5)
              : Colors.black26,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () async {
              if (_hasUnsavedChanges) {
                final shouldPop = await _onWillPop();
                if (shouldPop && mounted) {
                  Navigator.pop(context);
                }
              } else {
                Navigator.pop(context);
              }
            },
          ),
          title: Text(
            'Energy Mapping Configuration',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: isDarkMode ? Colors.white : Colors.black87,
            ),
          ),
          bottom: widget.allSubstationBays != null
              ? TabBar(
                  controller: _tabController,
                  indicatorColor: theme.colorScheme.primary,
                  labelColor: theme.colorScheme.primary,
                  unselectedLabelColor: isDarkMode
                      ? Colors.white60
                      : Colors.grey.shade600,
                  tabs: const [
                    Tab(
                      icon: Icon(Icons.electrical_services, size: 20),
                      text: 'Busbar',
                    ),
                    Tab(
                      icon: Icon(Icons.account_tree, size: 20),
                      text: 'Substation',
                    ),
                  ],
                )
              : null,
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
        body: widget.allSubstationBays != null
            ? TabBarView(
                controller: _tabController,
                children: [
                  _buildBusbarTab(isDarkMode),
                  _buildSubstationTab(isDarkMode),
                ],
              )
            : _buildBusbarTab(isDarkMode),
        bottomNavigationBar: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDarkMode ? const Color(0xFF2C2C2E) : Colors.white,
            border: Border(
              top: BorderSide(
                color: isDarkMode
                    ? Colors.white.withOpacity(0.1)
                    : Colors.grey.shade300,
                width: 1,
              ),
            ),
            boxShadow: [
              BoxShadow(
                color: isDarkMode
                    ? Colors.black.withOpacity(0.3)
                    : Colors.black.withOpacity(0.05),
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
                    onPressed: () async {
                      if (_hasUnsavedChanges) {
                        final shouldPop = await _onWillPop();
                        if (shouldPop && mounted) {
                          Navigator.pop(context);
                        }
                      } else {
                        Navigator.pop(context);
                      }
                    },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: BorderSide(
                        color: isDarkMode
                            ? Colors.white.withOpacity(0.3)
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
                            ? Colors.white.withOpacity(0.7)
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

  Widget _buildBusbarTab(bool isDarkMode) {
    return Column(
      children: [
        // Busbar Info Header
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDarkMode ? const Color(0xFF2C2C2E) : Colors.white,
            border: Border(
              bottom: BorderSide(
                color: isDarkMode
                    ? Colors.white.withOpacity(0.1)
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
                            color: isDarkMode ? Colors.white : Colors.black87,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Configure how each bay\'s import/export contributes to busbar energy',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDarkMode
                                ? Colors.white.withOpacity(0.7)
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

        // Connected Bays List
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
                      child: _buildConnectedBayCard(
                        bay,
                        Theme.of(context),
                        isDarkMode,
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildSubstationTab(bool isDarkMode) {
    final allBusbars =
        widget.allSubstationBays
            ?.where((bay) => bay.bayType == 'Busbar')
            .toList() ??
        [];

    return Column(
      children: [
        // Substation Info Header
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDarkMode ? const Color(0xFF2C2C2E) : Colors.white,
            border: Border(
              bottom: BorderSide(
                color: isDarkMode
                    ? Colors.white.withOpacity(0.1)
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
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.account_tree,
                      color: Colors.green,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Substation Energy Abstract',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isDarkMode ? Colors.white : Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Configure how busbars contribute to substation totals',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDarkMode
                                ? Colors.white.withOpacity(0.7)
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
                    icon: Icons.electrical_services,
                    label: '${allBusbars.length} busbars',
                    color: Colors.purple,
                  ),
                  const SizedBox(width: 8),
                  _buildInfoChip(
                    icon: Icons.settings,
                    label: 'Abstract Config',
                    color: Colors.blue,
                  ),
                ],
              ),
            ],
          ),
        ),

        // Busbars List for Substation Configuration
        Expanded(
          child: allBusbars.isEmpty
              ? _buildEmptySubstationState()
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: allBusbars.length,
                  itemBuilder: (context, index) {
                    final busbar = allBusbars[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _buildSubstationBusbarCard(busbar, isDarkMode),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildSubstationBusbarCard(Bay busbar, bool isDarkMode) {
    final impSelection =
        _substationImpSelectionMap[busbar.id] ??
        EnergyContributionType.busImport;
    final expSelection =
        _substationExpSelectionMap[busbar.id] ??
        EnergyContributionType.busExport;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: isDarkMode ? const Color(0xFF2C2C2E) : Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Busbar Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.purple.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.electrical_services,
                    color: Colors.purple,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${busbar.voltageLevel} ${busbar.name}',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: isDarkMode ? Colors.white : Colors.black87,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'Busbar contribution to substation abstract',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDarkMode
                              ? Colors.white.withOpacity(0.6)
                              : Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Energy Configuration for Substation
            Row(
              children: [
                Expanded(
                  child: _buildSubstationEnergyConfigCard(
                    title: 'IMPORT',
                    icon: Icons.arrow_downward,
                    color: Colors.green,
                    value: impSelection,
                    onChanged: (value) {
                      setState(() {
                        _substationImpSelectionMap[busbar.id] = value;
                        _markAsChanged();
                      });
                    },
                    isDarkMode: isDarkMode,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildSubstationEnergyConfigCard(
                    title: 'EXPORT',
                    icon: Icons.arrow_upward,
                    color: Colors.orange,
                    value: expSelection,
                    onChanged: (value) {
                      setState(() {
                        _substationExpSelectionMap[busbar.id] = value;
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

  Widget _buildSubstationEnergyConfigCard({
    required String title,
    required IconData icon,
    required Color color,
    required EnergyContributionType value,
    required Function(EnergyContributionType) onChanged,
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
          DropdownButtonFormField<EnergyContributionType>(
            value: value,
            isDense: true,
            dropdownColor: isDarkMode ? const Color(0xFF2C2C2E) : Colors.white,
            decoration: InputDecoration(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 6,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: BorderSide(
                  color: isDarkMode
                      ? Colors.white.withOpacity(0.3)
                      : Colors.grey.withOpacity(0.3),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: BorderSide(
                  color: isDarkMode
                      ? Colors.white.withOpacity(0.3)
                      : Colors.grey.withOpacity(0.3),
                ),
              ),
            ),
            style: TextStyle(
              fontSize: 11,
              color: isDarkMode ? Colors.white : Colors.black87,
            ),
            items: EnergyContributionType.values.map((type) {
              String label;
              switch (type) {
                case EnergyContributionType.busImport:
                  label = '→ Substation IMP';
                  break;
                case EnergyContributionType.busExport:
                  label = '→ Substation EXP';
                  break;
                case EnergyContributionType.none:
                  label = 'Not Included';
                  break;
              }
              return DropdownMenuItem(
                value: type,
                child: Text(
                  label,
                  style: TextStyle(
                    color: isDarkMode ? Colors.white : Colors.black87,
                  ),
                ),
              );
            }).toList(),
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

  Widget _buildEmptySubstationState() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.account_tree_outlined,
              size: 48,
              color: isDarkMode
                  ? Colors.white.withOpacity(0.4)
                  : Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              'No Busbars Found',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: isDarkMode
                    ? Colors.white.withOpacity(0.6)
                    : Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'No busbars available for substation configuration',
              style: TextStyle(
                fontSize: 14,
                color: isDarkMode
                    ? Colors.white.withOpacity(0.5)
                    : Colors.grey.shade500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
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
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.account_tree_outlined,
              size: 48,
              color: isDarkMode
                  ? Colors.white.withOpacity(0.4)
                  : Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              'No Connected Bays',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: isDarkMode
                    ? Colors.white.withOpacity(0.6)
                    : Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'This busbar has no connected equipment',
              style: TextStyle(
                fontSize: 14,
                color: isDarkMode
                    ? Colors.white.withOpacity(0.5)
                    : Colors.grey.shade500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConnectedBayCard(Bay bay, ThemeData theme, bool isDarkMode) {
    final impSelection =
        _bayImpSelectionMap[bay.id] ?? EnergyContributionType.none;
    final expSelection =
        _bayExpSelectionMap[bay.id] ?? EnergyContributionType.none;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: isDarkMode ? const Color(0xFF2C2C2E) : Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Bay Header
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
                              ? Colors.white.withOpacity(0.6)
                              : Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Energy Configuration - IMP and EXP Dropdowns
            Row(
              children: [
                // IMP Configuration
                Expanded(
                  child: _buildEnergyConfigCard(
                    title: 'IMPORT',
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
                    title: 'EXPORT',
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
    required EnergyContributionType value,
    required Function(EnergyContributionType) onChanged,
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
          DropdownButtonFormField<EnergyContributionType>(
            value: value,
            isDense: true,
            dropdownColor: isDarkMode ? const Color(0xFF2C2C2E) : Colors.white,
            decoration: InputDecoration(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 6,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: BorderSide(
                  color: isDarkMode
                      ? Colors.white.withOpacity(0.3)
                      : Colors.grey.withOpacity(0.3),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: BorderSide(
                  color: isDarkMode
                      ? Colors.white.withOpacity(0.3)
                      : Colors.grey.withOpacity(0.3),
                ),
              ),
            ),
            style: TextStyle(
              fontSize: 11,
              color: isDarkMode ? Colors.white : Colors.black87,
            ),
            items: EnergyContributionType.values.map((type) {
              String label;
              switch (type) {
                case EnergyContributionType.busImport:
                  label = '→ Busbar IMP';
                  break;
                case EnergyContributionType.busExport:
                  label = '→ Busbar EXP';
                  break;
                case EnergyContributionType.none:
                  label = 'Not Included';
                  break;
              }
              return DropdownMenuItem(
                value: type,
                child: Text(
                  label,
                  style: TextStyle(
                    color: isDarkMode ? Colors.white : Colors.black87,
                  ),
                ),
              );
            }).toList(),
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
