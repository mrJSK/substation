import 'dart:async';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:collection/collection.dart';

import '../../models/bay_model.dart';
import '../../models/user_model.dart';
import '../../models/equipment_model.dart';
import '../../painters/single_line_diagram_painter.dart';
import '../../utils/snackbar_utils.dart';
import 'bay_form_screen.dart';
import '../bay_equipment_management_screen.dart';
import '../bay_reading_assignment_screen.dart';
import 'energy_sld_screen.dart';
import '../../controllers/sld_controller.dart';
import '../../enums/movement_mode.dart';

// Enhanced Equipment Icon Widget
class _EquipmentIcon extends StatelessWidget {
  final String equipmentType;
  final double size;
  final Color color;

  const _EquipmentIcon({
    required this.equipmentType,
    this.size = 24.0,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    // Safe fallback icons using Material Icons
    IconData iconData;

    switch (equipmentType.toLowerCase()) {
      case 'transformer':
        iconData = Icons.electrical_services;
        break;
      case 'circuit breaker':
        iconData = Icons.power_settings_new;
        break;
      case 'isolator':
        iconData = Icons.power_off;
        break;
      case 'current transformer':
      case 'voltage transformer':
        iconData = Icons.transform;
        break;
      case 'relay':
        iconData = Icons.settings_input_component;
        break;
      case 'capacitor bank':
        iconData = Icons.battery_charging_full;
        break;
      case 'reactor':
        iconData = Icons.device_hub;
        break;
      case 'surge arrester':
        iconData = Icons.flash_on;
        break;
      case 'energy meter':
        iconData = Icons.speed;
        break;
      case 'ground':
        iconData = Icons.golf_course;
        break;
      case 'busbar':
        iconData = Icons.horizontal_rule;
        break;
      case 'feeder':
        iconData = Icons.arrow_forward;
        break;
      default:
        iconData = Icons.settings;
        break;
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Icon(iconData, size: size * 0.7, color: color),
    );
  }
}

// Enhanced Bay Equipment List Screen with better UI
class BayEquipmentListScreen extends StatelessWidget {
  final String bayId;
  final String bayName;
  final AppUser currentUser;

  const BayEquipmentListScreen({
    super.key,
    required this.bayId,
    required this.bayName,
    required this.currentUser,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDarkMode
          ? const Color(0xFF1C1C1E) // Dark mode background
          : const Color(0xFFFAFAFA),
      appBar: AppBar(
        backgroundColor: isDarkMode
            ? const Color(0xFF2C2C2E) // Dark elevated surface
            : Colors.white,
        elevation: 0,
        title: Text(
          'Equipment in $bayName',
          style: TextStyle(
            color: isDarkMode ? Colors.white : theme.colorScheme.onSurface,
            fontSize: 18,
            fontWeight: FontWeight.w500,
          ),
        ),
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back,
            color: isDarkMode ? Colors.white : theme.colorScheme.onSurface,
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('equipment_instances')
            .where('bayId', isEqualTo: bayId)
            .where('status', isEqualTo: 'active')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: CircularProgressIndicator(
                color: theme.colorScheme.primary,
              ),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 64,
                    color: theme.colorScheme.error.withOpacity(0.6),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Error loading equipment',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                      color: theme.colorScheme.error,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    snapshot.error.toString(),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: isDarkMode
                          ? Colors.white.withOpacity(0.6)
                          : theme.colorScheme.onSurface.withOpacity(0.6),
                    ),
                  ),
                ],
              ),
            );
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.electrical_services,
                      size: 48,
                      color: isDarkMode
                          ? Colors.white.withOpacity(0.6)
                          : theme.colorScheme.onSurface.withOpacity(0.6),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'No equipment found',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                      color: isDarkMode
                          ? Colors.white.withOpacity(0.6)
                          : theme.colorScheme.onSurface.withOpacity(0.6),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Add equipment to this bay to get started',
                    style: TextStyle(
                      fontSize: 14,
                      color: isDarkMode
                          ? Colors.white.withOpacity(0.5)
                          : theme.colorScheme.onSurface.withOpacity(0.5),
                    ),
                  ),
                ],
              ),
            );
          }

          final equipmentDocs = snapshot.data!.docs;

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: equipmentDocs.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final equipment = EquipmentInstance.fromFirestore(
                equipmentDocs[index],
              );

              return Container(
                decoration: BoxDecoration(
                  color: isDarkMode
                      ? const Color(0xFF2C2C2E) // Dark elevated surface
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
                  leading: _EquipmentIcon(
                    equipmentType: equipment.equipmentTypeName,
                    size: 40,
                    color: theme.colorScheme.primary,
                  ),
                  title: Text(
                    equipment.equipmentTypeName,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: isDarkMode ? Colors.white : null,
                    ),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Text(
                        'Make: ${equipment.make}',
                        style: TextStyle(
                          fontSize: 14,
                          color: isDarkMode
                              ? Colors.white.withOpacity(0.6)
                              : theme.colorScheme.onSurface.withOpacity(0.6),
                        ),
                      ),
                    ],
                  ),
                  trailing: Container(
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: IconButton(
                      icon: Icon(
                        Icons.settings,
                        color: theme.colorScheme.primary,
                      ),
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => BayEquipmentManagementScreen(
                              bayId: bayId,
                              bayName: bayName,
                              substationId:
                                  equipmentDocs[index]['substationId'] ?? '',
                              currentUser: currentUser,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => BayEquipmentManagementScreen(
                bayId: bayId,
                bayName: bayName,
                substationId: '',
                currentUser: currentUser,
              ),
            ),
          );
        },
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Add Equipment'),
      ),
    );
  }
}

enum BayDetailViewMode { list, add, edit }

class SubstationDetailScreen extends StatefulWidget {
  final String substationId;
  final String substationName;
  final AppUser currentUser;

  const SubstationDetailScreen({
    super.key,
    required this.substationId,
    required this.substationName,
    required this.currentUser,
  });

  @override
  State<SubstationDetailScreen> createState() => _SubstationDetailScreenState();
}

class _SubstationDetailScreenState extends State<SubstationDetailScreen> {
  BayDetailViewMode _viewMode = BayDetailViewMode.list;
  Bay? _bayToEdit;
  static const double _movementStep = 5.0;
  static const double _busbarLengthStep = 5.0;
  List<Bay> _availableBusbars = [];
  bool _isLoadingBusbars = true;

  @override
  void initState() {
    super.initState();
    _fetchBusbarsInSubstation();
  }

  Future<void> _fetchBusbarsInSubstation() async {
    if (!mounted) return;
    setState(() {
      _isLoadingBusbars = true;
    });
    try {
      final busbarSnapshot = await FirebaseFirestore.instance
          .collection('bays')
          .where('substationId', isEqualTo: widget.substationId)
          .where('bayType', isEqualTo: 'Busbar')
          .get();
      _availableBusbars = busbarSnapshot.docs
          .map((doc) => Bay.fromFirestore(doc))
          .toList();
    } catch (e) {
      if (mounted) {
        SnackBarUtils.showSnackBar(
          context,
          "Error fetching busbars: $e",
          isError: true,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingBusbars = false;
        });
      }
    }
  }

  void _setViewMode(BayDetailViewMode mode, {Bay? bay}) {
    setState(() {
      _viewMode = mode;
      _bayToEdit = bay;
      final sldController = Provider.of<SldController>(context, listen: false);
      if (mode == BayDetailViewMode.list) {
        sldController.setSelectedBayForMovement(null);
      }
    });
    if (mode != BayDetailViewMode.list) {
      _fetchBusbarsInSubstation();
    }
  }

  void _onBayFormSaveSuccess() {
    _setViewMode(BayDetailViewMode.list);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    final sldController = Provider.of<SldController>(context);

    if (sldController.substationId != widget.substationId) {
      debugPrint(
        "WARNING: SldController substationId mismatch! Expected ${widget.substationId}, got ${sldController.substationId}",
      );
    }

    return PopScope(
      canPop:
          _viewMode == BayDetailViewMode.list &&
          sldController.selectedBayForMovementId == null,
      onPopInvoked: (didPop) {
        if (!didPop) {
          if (sldController.selectedBayForMovementId != null) {
            sldController.cancelLayoutChanges();
            SnackBarUtils.showSnackBar(
              context,
              'Movement cancelled. Position not saved.',
            );
          } else if (_viewMode != BayDetailViewMode.list) {
            _setViewMode(BayDetailViewMode.list);
          }
        }
      },
      child: Scaffold(
        backgroundColor: isDarkMode
            ? const Color(0xFF1C1C1E) // Dark mode background
            : const Color(0xFFFAFAFA),
        appBar: AppBar(
          backgroundColor: isDarkMode
              ? const Color(0xFF2C2C2E) // Dark elevated surface
              : Colors.white,
          elevation: 0,
          title: Text(
            'Substation: ${widget.substationName}',
            style: TextStyle(
              color: isDarkMode ? Colors.white : theme.colorScheme.onSurface,
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),
          ),
          leading: IconButton(
            icon: Icon(
              Icons.arrow_back,
              color: isDarkMode ? Colors.white : theme.colorScheme.onSurface,
            ),
            onPressed: () => Navigator.pop(context),
          ),
          actions: [
            Container(
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: IconButton(
                icon: Icon(Icons.schema, color: theme.colorScheme.primary),
                tooltip: 'View SLD',
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) =>
                          ChangeNotifierProvider<SldController>(
                            create: (context) => SldController(
                              substationId: widget.substationId,
                              transformationController:
                                  TransformationController(),
                            ),
                            child: EnergySldScreen(
                              substationId: widget.substationId,
                              substationName: widget.substationName,
                              currentUser: widget.currentUser,
                            ),
                          ),
                    ),
                  );
                },
              ),
            ),
            if (_viewMode != BayDetailViewMode.list ||
                sldController.selectedBayForMovementId != null)
              Container(
                margin: const EdgeInsets.only(right: 16),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.orange),
                  onPressed: () {
                    if (sldController.selectedBayForMovementId != null) {
                      sldController.cancelLayoutChanges();
                      SnackBarUtils.showSnackBar(
                        context,
                        'Movement cancelled. Position not saved.',
                      );
                    } else {
                      _setViewMode(BayDetailViewMode.list);
                    }
                  },
                ),
              ),
          ],
        ),
        body: _viewMode == BayDetailViewMode.list
            ? _buildBaysAndEquipmentList()
            : BayFormScreen(
                bayToEdit: _bayToEdit,
                substationId: widget.substationId,
                currentUser: widget.currentUser,
                onSaveSuccess: _onBayFormSaveSuccess,
                onCancel: () => _setViewMode(BayDetailViewMode.list),
                availableBusbars: _isLoadingBusbars ? [] : _availableBusbars,
              ),
        floatingActionButton:
            _viewMode == BayDetailViewMode.list &&
                sldController.selectedBayForMovementId == null
            ? _buildFloatingActionButtons(theme)
            : null,
        bottomNavigationBar: sldController.selectedBayForMovementId != null
            ? _buildMovementControls(sldController, isDarkMode)
            : null,
      ),
    );
  }

  Widget _buildFloatingActionButtons(ThemeData theme) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        FloatingActionButton.extended(
          onPressed: () => _setViewMode(BayDetailViewMode.add),
          backgroundColor: theme.colorScheme.primary,
          foregroundColor: Colors.white,
          label: const Text('Add New Bay'),
          icon: const Icon(Icons.add),
          heroTag: 'addBay',
        ),
        const SizedBox(height: 12),
        FloatingActionButton.extended(
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => BayEquipmentManagementScreen(
                  bayId: '', // Empty bayId for standalone equipment
                  bayName: 'Standalone Equipment',
                  substationId: widget.substationId,
                  currentUser: widget.currentUser,
                ),
              ),
            );
          },
          backgroundColor: theme.colorScheme.secondary,
          foregroundColor: Colors.white,
          label: const Text('Add Equipment'),
          icon: const Icon(Icons.electrical_services),
          heroTag: 'addEquipment',
        ),
      ],
    );
  }

  Widget _buildBaysAndEquipmentList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('bays')
          .where('substationId', isEqualTo: widget.substationId)
          .snapshots(),
      builder: (context, baySnapshot) {
        if (baySnapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: CircularProgressIndicator(
              color: Theme.of(context).colorScheme.primary,
            ),
          );
        }

        if (baySnapshot.hasError) {
          final isDarkMode = Theme.of(context).brightness == Brightness.dark;
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 64,
                  color: Theme.of(context).colorScheme.error.withOpacity(0.6),
                ),
                const SizedBox(height: 16),
                Text(
                  'Error loading bays',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  baySnapshot.error.toString(),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: isDarkMode
                        ? Colors.white.withOpacity(0.6)
                        : Theme.of(
                            context,
                          ).colorScheme.onSurface.withOpacity(0.6),
                  ),
                ),
              ],
            ),
          );
        }

        final bays =
            baySnapshot.data?.docs
                .map((doc) => Bay.fromFirestore(doc))
                .toList() ??
            [];

        // Group bays by voltage level
        final Map<String, List<Bay>> baysByVoltage = {};
        for (var bay in bays) {
          final voltage = bay.voltageLevel;
          if (!baysByVoltage.containsKey(voltage)) {
            baysByVoltage[voltage] = [];
          }
          baysByVoltage[voltage]!.add(bay);
        }

        // Fetch standalone equipment
        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('equipment_instances')
              .where('substationId', isEqualTo: widget.substationId)
              .where('bayId', isEqualTo: '')
              .where('status', isEqualTo: 'active')
              .snapshots(),
          builder: (context, equipmentSnapshot) {
            if (equipmentSnapshot.connectionState == ConnectionState.waiting) {
              return Center(
                child: CircularProgressIndicator(
                  color: Theme.of(context).colorScheme.primary,
                ),
              );
            }

            if (equipmentSnapshot.hasError) {
              final isDarkMode =
                  Theme.of(context).brightness == Brightness.dark;
              return Center(
                child: Text(
                  'Error loading equipment: ${equipmentSnapshot.error}',
                  style: TextStyle(color: isDarkMode ? Colors.white : null),
                ),
              );
            }

            final standaloneEquipment =
                equipmentSnapshot.data?.docs
                    .map((doc) => EquipmentInstance.fromFirestore(doc))
                    .toList() ??
                [];

            // FIXED: Check the correct collection for reading assignments
            return StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection(
                    'bayReadingAssignments',
                  ) // CORRECTED COLLECTION NAME
                  .snapshots(),
              builder: (context, readingAssignmentSnapshot) {
                if (readingAssignmentSnapshot.connectionState ==
                    ConnectionState.waiting) {
                  return Center(
                    child: CircularProgressIndicator(
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  );
                }

                if (readingAssignmentSnapshot.hasError) {
                  final isDarkMode =
                      Theme.of(context).brightness == Brightness.dark;
                  return Center(
                    child: Text(
                      'Error loading reading assignments: ${readingAssignmentSnapshot.error}',
                      style: TextStyle(color: isDarkMode ? Colors.white : null),
                    ),
                  );
                }

                // FIXED: Collect assigned bay IDs from the correct structure
                final assignedBays = <String>{};
                for (var doc in readingAssignmentSnapshot.data!.docs) {
                  final data = doc.data() as Map<String, dynamic>;
                  final bayId = data['bayId'] as String?;
                  if (bayId != null) {
                    assignedBays.add(bayId);
                  }
                }

                return _buildContentList(
                  baysByVoltage,
                  standaloneEquipment,
                  assignedBays,
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildContentList(
    Map<String, List<Bay>> baysByVoltage,
    List<EquipmentInstance> standaloneEquipment,
    Set<String> assignedBays,
  ) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    if (baysByVoltage.isEmpty && standaloneEquipment.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                Icons.electrical_services,
                size: 64,
                color: isDarkMode
                    ? Colors.white.withOpacity(0.6)
                    : theme.colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No bays or equipment yet',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w500,
                color: isDarkMode
                    ? Colors.white.withOpacity(0.6)
                    : theme.colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Start by adding a bay or standalone equipment',
              style: TextStyle(
                fontSize: 14,
                color: isDarkMode
                    ? Colors.white.withOpacity(0.5)
                    : theme.colorScheme.onSurface.withOpacity(0.5),
              ),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: 160, // Add substantial bottom padding for two FABs
      ),
      children: [
        // Bays grouped by voltage level
        ...baysByVoltage.entries.map((entry) {
          final voltage = entry.key;
          final bays = entry.value;

          return Container(
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: isDarkMode
                  ? const Color(0xFF2C2C2E) // Dark elevated surface
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
            child: Theme(
              data: theme.copyWith(
                dividerColor: isDarkMode ? Colors.white.withOpacity(0.1) : null,
                listTileTheme: ListTileThemeData(
                  iconColor: isDarkMode ? Colors.white : null,
                  textColor: isDarkMode ? Colors.white : null,
                ),
              ),
              child: ExpansionTile(
                tilePadding: const EdgeInsets.all(16),
                childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.flash_on,
                    color: theme.colorScheme.primary,
                    size: 24,
                  ),
                ),
                title: Text(
                  '$voltage Bays',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: isDarkMode ? Colors.white : null,
                  ),
                ),
                subtitle: Text(
                  '${bays.length} bay${bays.length != 1 ? 's' : ''}',
                  style: TextStyle(
                    fontSize: 14,
                    color: isDarkMode
                        ? Colors.white.withOpacity(0.6)
                        : theme.colorScheme.onSurface.withOpacity(0.6),
                  ),
                ),
                children: bays.map((bay) {
                  final isAssigned = assignedBays.contains(bay.id);

                  // CORRECTED: Updated the ListTile with proper reading assignment icon handling
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: isDarkMode
                          ? const Color(0xFF3C3C3E)
                          : theme.colorScheme.surfaceVariant.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(12),
                      leading: _getBayTypeIcon(bay.bayType, theme, isDarkMode),
                      title: Text(
                        bay.name,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: isDarkMode ? Colors.white : null,
                        ),
                      ),
                      subtitle: Text(
                        'Type: ${bay.bayType}',
                        style: TextStyle(
                          fontSize: 13,
                          color: isDarkMode
                              ? Colors.white.withOpacity(0.6)
                              : theme.colorScheme.onSurface.withOpacity(0.6),
                        ),
                      ),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => BayEquipmentListScreen(
                              bayId: bay.id,
                              bayName: bay.name,
                              currentUser: widget.currentUser,
                            ),
                          ),
                        );
                      },
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // CORRECTED: Reading assignment icon with proper navigation and refresh
                          _buildReadingAssignmentIcon(
                            bay,
                            isAssigned,
                            isDarkMode,
                          ),
                          const SizedBox(width: 4),
                          // Delete icon
                          Container(
                            decoration: BoxDecoration(
                              color: theme.colorScheme.error.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: IconButton(
                              icon: Icon(
                                Icons.delete,
                                color: theme.colorScheme.error,
                                size: 20,
                              ),
                              tooltip: 'Delete Bay',
                              onPressed: () => _confirmDeleteBay(context, bay),
                            ),
                          ),
                          const SizedBox(width: 4),
                          // Edit icon
                          Container(
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: IconButton(
                              icon: Icon(
                                Icons.edit,
                                color: theme.colorScheme.primary,
                                size: 20,
                              ),
                              tooltip: 'Edit Bay Details',
                              onPressed: () => _setViewMode(
                                BayDetailViewMode.edit,
                                bay: bay,
                              ),
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
        }).toList(),

        // Standalone Equipment Section
        if (standaloneEquipment.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: isDarkMode
                  ? const Color(0xFF2C2C2E) // Dark elevated surface
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
            child: Theme(
              data: theme.copyWith(
                dividerColor: isDarkMode ? Colors.white.withOpacity(0.1) : null,
                listTileTheme: ListTileThemeData(
                  iconColor: isDarkMode ? Colors.white : null,
                  textColor: isDarkMode ? Colors.white : null,
                ),
              ),
              child: ExpansionTile(
                tilePadding: const EdgeInsets.all(16),
                childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.secondary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.settings,
                    color: theme.colorScheme.secondary,
                    size: 24,
                  ),
                ),
                title: Text(
                  'Standalone Equipment',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: isDarkMode ? Colors.white : null,
                  ),
                ),
                subtitle: Text(
                  '${standaloneEquipment.length} equipment',
                  style: TextStyle(
                    fontSize: 14,
                    color: isDarkMode
                        ? Colors.white.withOpacity(0.6)
                        : theme.colorScheme.onSurface.withOpacity(0.6),
                  ),
                ),
                children: standaloneEquipment.map((equipment) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: isDarkMode
                          ? const Color(0xFF3C3C3E)
                          : theme.colorScheme.surfaceVariant.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(12),
                      leading: _EquipmentIcon(
                        equipmentType: equipment.equipmentTypeName,
                        size: 32,
                        color: theme.colorScheme.secondary,
                      ),
                      title: Text(
                        equipment.equipmentTypeName,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: isDarkMode ? Colors.white : null,
                        ),
                      ),
                      subtitle: Text(
                        'Make: ${equipment.make}',
                        style: TextStyle(
                          fontSize: 13,
                          color: isDarkMode
                              ? Colors.white.withOpacity(0.6)
                              : theme.colorScheme.onSurface.withOpacity(0.6),
                        ),
                      ),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => BayEquipmentManagementScreen(
                              bayId: '',
                              bayName: equipment.equipmentTypeName,
                              substationId: widget.substationId,
                              currentUser: widget.currentUser,
                            ),
                          ),
                        );
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
      ],
    );
  }

  // NEW: Reading assignment icon widget with proper state management
  Widget _buildReadingAssignmentIcon(
    Bay bay,
    bool isAssigned,
    bool isDarkMode,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: isAssigned
            ? Colors.green.withOpacity(0.1)
            : Colors.grey.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isAssigned
              ? Colors.green.withOpacity(0.3)
              : Colors.grey.withOpacity(0.3),
        ),
      ),
      child: IconButton(
        icon: Icon(
          Icons.menu_book,
          color: isAssigned ? Colors.green.shade600 : Colors.grey.shade600,
          size: 20,
        ),
        tooltip: isAssigned
            ? 'Reading template assigned'
            : 'No reading template assigned',
        onPressed: () async {
          final result = await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => BayReadingAssignmentScreen(
                bayId: bay.id,
                bayName: bay.name,
                currentUser: widget.currentUser,
              ),
            ),
          );

          // Refresh the UI if assignment was saved
          if (result == true && mounted) {
            setState(
              () {},
            ); // This will trigger rebuild and refresh the icon colors
          }
        },
      ),
    );
  }

  Widget _getBayTypeIcon(String bayType, ThemeData theme, bool isDarkMode) {
    IconData iconData;
    Color iconColor;

    switch (bayType.toLowerCase()) {
      case 'busbar':
        iconData = Icons.horizontal_rule;
        iconColor = Colors.blue;
        break;
      case 'feeder':
        iconData = Icons.arrow_forward;
        iconColor = Colors.green;
        break;
      case 'transformer':
        iconData = Icons.electrical_services;
        iconColor = Colors.orange;
        break;
      case 'capacitor':
        iconData = Icons.battery_charging_full;
        iconColor = Colors.cyan;
        break;
      case 'reactor':
        iconData = Icons.device_hub;
        iconColor = Colors.purple;
        break;
      default:
        iconData = Icons.power;
        iconColor = theme.colorScheme.primary;
        break;
    }

    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: iconColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Icon(iconData, color: iconColor, size: 20),
    );
  }

  Widget _buildMovementControls(SldController sldController, bool isDarkMode) {
    final selectedBay =
        sldController.baysMap[sldController.selectedBayForMovementId!];
    if (selectedBay == null) return const SizedBox.shrink();

    final BayRenderData? selectedBayRenderData = sldController.bayRenderDataList
        .firstWhereOrNull(
          (data) => data.bay.id == sldController.selectedBayForMovementId,
        );

    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: isDarkMode
            ? const Color(0xFF2C2C2E) // Dark elevated surface
            : Colors.blueGrey.shade800,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.edit, color: Colors.white, size: 16),
                const SizedBox(width: 8),
                Text(
                  'Editing: ${selectedBay.name}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SegmentedButton<MovementMode>(
            segments: const [
              ButtonSegment(
                value: MovementMode.bay,
                label: Text('Move Bay'),
                icon: Icon(Icons.move_up, size: 16),
              ),
              ButtonSegment(
                value: MovementMode.text,
                label: Text('Move Name'),
                icon: Icon(Icons.text_fields, size: 16),
              ),
            ],
            selected: {sldController.movementMode},
            onSelectionChanged: (newSelection) {
              sldController.setMovementMode(newSelection.first);
            },
            style: ButtonStyle(
              foregroundColor: MaterialStateProperty.resolveWith<Color>((
                states,
              ) {
                return states.contains(MaterialState.selected)
                    ? Colors.blue.shade900
                    : Colors.blue.shade100;
              }),
              backgroundColor: MaterialStateProperty.resolveWith<Color>((
                states,
              ) {
                return states.contains(MaterialState.selected)
                    ? Colors.white
                    : Colors.white.withOpacity(0.2);
              }),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                const Text(
                  'Movement Controls',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildControlButton(
                      Icons.arrow_back,
                      () => sldController.moveSelectedItem(-_movementStep, 0),
                    ),
                    Column(
                      children: [
                        _buildControlButton(
                          Icons.arrow_upward,
                          () =>
                              sldController.moveSelectedItem(0, -_movementStep),
                        ),
                        const SizedBox(height: 8),
                        _buildControlButton(
                          Icons.arrow_downward,
                          () =>
                              sldController.moveSelectedItem(0, _movementStep),
                        ),
                      ],
                    ),
                    _buildControlButton(
                      Icons.arrow_forward,
                      () => sldController.moveSelectedItem(_movementStep, 0),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (selectedBay.bayType == 'Busbar') ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  const Text(
                    'Busbar Length',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildControlButton(
                        Icons.remove,
                        () => sldController.adjustBusbarLength(
                          -_busbarLengthStep,
                        ),
                      ),
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 16),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          selectedBayRenderData?.busbarLength.toStringAsFixed(
                                0,
                              ) ??
                              'Auto',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      _buildControlButton(
                        Icons.add,
                        () =>
                            sldController.adjustBusbarLength(_busbarLengthStep),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () async {
                final bool confirm =
                    await showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        backgroundColor: isDarkMode
                            ? const Color(0xFF1C1C1E)
                            : Colors.white,
                        title: Text(
                          'Save All Changes?',
                          style: TextStyle(
                            color: isDarkMode ? Colors.white : null,
                          ),
                        ),
                        content: Text(
                          'This will save all layout changes made in this session. '
                          'Do you want to continue?',
                          style: TextStyle(
                            color: isDarkMode ? Colors.white : null,
                          ),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(false),
                            child: const Text('Cancel'),
                          ),
                          ElevatedButton(
                            onPressed: () => Navigator.of(context).pop(true),
                            child: const Text('Save All'),
                          ),
                        ],
                      ),
                    ) ??
                    false;

                if (confirm) {
                  final bool success = await sldController
                      .saveAllPendingChanges();
                  if (mounted) {
                    if (success) {
                      SnackBarUtils.showSnackBar(
                        context,
                        'All changes saved successfully!',
                      );
                    } else {
                      SnackBarUtils.showSnackBar(
                        context,
                        'Failed to save changes.',
                        isError: true,
                      );
                    }
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              icon: const Icon(Icons.save),
              label: const Text(
                'Save All Changes',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControlButton(IconData icon, VoidCallback onPressed) {
    return Container(
      margin: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: IconButton(
        icon: Icon(icon),
        color: Colors.white,
        onPressed: onPressed,
        iconSize: 24,
      ),
    );
  }

  Future<void> _confirmDeleteBay(BuildContext context, Bay bay) async {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    final bool? confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: isDarkMode ? const Color(0xFF1C1C1E) : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.error.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.warning_amber_rounded,
                  color: theme.colorScheme.error,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Delete Bay?',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: isDarkMode ? Colors.white : null,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Are you sure you want to delete "${bay.name}"?',
                style: TextStyle(
                  fontSize: 16,
                  color: isDarkMode ? Colors.white : null,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.error.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: theme.colorScheme.error.withOpacity(0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: theme.colorScheme.error,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'This will also remove all associated equipment and connections. This action cannot be undone.',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: isDarkMode ? Colors.white : null,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(
                'Cancel',
                style: TextStyle(
                  color: isDarkMode
                      ? Colors.white.withOpacity(0.6)
                      : theme.colorScheme.onSurface.withOpacity(0.6),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 8),
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
    );

    if (confirmed == true) {
      await _performAnimatedDeletion(context, bay);
    }
  }

  Future<void> _performAnimatedDeletion(BuildContext context, Bay bay) async {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: isDarkMode ? const Color(0xFF1C1C1E) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.0, end: 1.0),
                  duration: const Duration(milliseconds: 500),
                  builder: (context, value, child) {
                    return Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          width: 60,
                          height: 60,
                          child: CircularProgressIndicator(
                            value: value,
                            strokeWidth: 4,
                            backgroundColor: theme.colorScheme.error
                                .withOpacity(0.2),
                            valueColor: AlwaysStoppedAnimation<Color>(
                              theme.colorScheme.error,
                            ),
                          ),
                        ),
                        AnimatedScale(
                          scale: value,
                          duration: const Duration(milliseconds: 200),
                          child: Icon(
                            Icons.delete,
                            color: theme.colorScheme.error,
                            size: 24,
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 20),
                Text(
                  'Deleting ${bay.name}...',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: isDarkMode ? Colors.white : null,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Please wait while we remove the bay',
                  style: TextStyle(
                    fontSize: 14,
                    color: isDarkMode
                        ? Colors.white.withOpacity(0.6)
                        : theme.colorScheme.onSurface.withOpacity(0.6),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    try {
      final deletionFuture = _deleteBay(bay);
      final delayFuture = Future.delayed(const Duration(milliseconds: 1500));

      await Future.wait([deletionFuture, delayFuture]);

      if (context.mounted) {
        Navigator.of(context).pop();
      }

      if (context.mounted) {
        await _showSuccessAnimation(context, bay);
      }

      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context).pop();
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(child: Text('Failed to delete ${bay.name}: $e')),
              ],
            ),
            backgroundColor: theme.colorScheme.error,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: () => _confirmDeleteBay(context, bay),
            ),
          ),
        );
      }
    }
  }

  Future<void> _showSuccessAnimation(BuildContext context, Bay bay) async {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        Timer(const Duration(milliseconds: 1000), () {
          if (context.mounted && Navigator.canPop(context)) {
            Navigator.of(context).pop();
          }
        });

        return Dialog(
          backgroundColor: Colors.transparent,
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 500),
            builder: (context, value, child) {
              return Transform.scale(
                scale: value,
                child: Opacity(
                  opacity: value,
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: isDarkMode
                          ? const Color(0xFF1C1C1E)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0.0, end: 1.0),
                          duration: const Duration(milliseconds: 300),
                          builder: (context, iconValue, child) {
                            return Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                color: Colors.green.withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Transform.scale(
                                scale: iconValue,
                                child: const Icon(
                                  Icons.check_circle,
                                  color: Colors.green,
                                  size: 48,
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Bay Deleted Successfully!',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: isDarkMode ? Colors.white : null,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${bay.name} has been permanently removed',
                          style: TextStyle(
                            fontSize: 14,
                            color: isDarkMode
                                ? Colors.white.withOpacity(0.6)
                                : theme.colorScheme.onSurface.withOpacity(0.6),
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: 60,
                          child: LinearProgressIndicator(
                            backgroundColor: Colors.green.withOpacity(0.2),
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              Colors.green,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _deleteBay(Bay bay) async {
    try {
      debugPrint('Attempting to delete bay: ${bay.id}');

      await FirebaseFirestore.instance.collection('bays').doc(bay.id).delete();

      debugPrint('Bay deleted: ${bay.id}. Now deleting connections...');

      final batch = FirebaseFirestore.instance.batch();
      final connectionsSnapshot = await FirebaseFirestore.instance
          .collection('bay_connections')
          .where('substationId', isEqualTo: widget.substationId)
          .where(
            Filter.or(
              Filter('sourceBayId', isEqualTo: bay.id),
              Filter('targetBayId', isEqualTo: bay.id),
            ),
          )
          .get();

      for (var doc in connectionsSnapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();

      debugPrint('Connections deleted for bay: ${bay.id}');
    } catch (e) {
      debugPrint('Error deleting bay: $e');
      throw Exception('Failed to delete bay: $e');
    }
  }
}
