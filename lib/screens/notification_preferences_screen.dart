// lib/screens/notification_preferences_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import '../models/notification_preferences_model.dart';
import '../utils/snackbar_utils.dart';

class NotificationPreferencesScreen extends StatefulWidget {
  final AppUser currentUser;

  const NotificationPreferencesScreen({super.key, required this.currentUser});

  @override
  State<NotificationPreferencesScreen> createState() =>
      _NotificationPreferencesScreenState();
}

class _NotificationPreferencesScreenState
    extends State<NotificationPreferencesScreen> {
  bool _isLoading = true;
  bool _isSaving = false;
  NotificationPreferences? _preferences;
  List<String> _availableSubstations = [];
  Map<String, String> _substationIdToName = {};

  // UPDATED: Default mandatory voltages and optional voltages
  final List<int> _defaultMandatoryVoltages = [132, 220, 400, 765];
  final List<int> _optionalVoltages = [11, 33, 66, 110];

  // Bay type options - UPDATED to include Transformer and Line as specified
  final List<String> _bayTypeOptions = [
    'Transformer',
    'Line',
    'Feeder',
    'Busbar',
    'Capacitor Bank',
    'Reactor',
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      // Load existing preferences
      final preferencesDoc = await FirebaseFirestore.instance
          .collection('notificationPreferences')
          .doc(widget.currentUser.uid)
          .get();

      if (preferencesDoc.exists) {
        _preferences = NotificationPreferences.fromFirestore(preferencesDoc);
      } else {
        // Create default preferences with correct defaults
        _preferences = NotificationPreferences.withDefaults(
          widget.currentUser.uid,
        );
      }

      // Load available substations with hierarchical filtering
      await _loadAvailableSubstations();
    } catch (e) {
      if (mounted) {
        SnackBarUtils.showSnackBar(
          context,
          'Error loading preferences: $e',
          isError: true,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // UPDATED: Complete hierarchical filtering for available substations
  Future<void> _loadAvailableSubstations() async {
    _availableSubstations.clear();
    _substationIdToName.clear();

    try {
      Query<Map<String, dynamic>> substationsQuery = FirebaseFirestore.instance
          .collection('substations')
          .orderBy('name');

      // Apply hierarchy-based filtering based on user role
      if (widget.currentUser.assignedLevels != null) {
        final assignedLevels = widget.currentUser.assignedLevels!;

        switch (widget.currentUser.role) {
          case UserRole.subdivisionManager:
            // Subdivision managers: only their subdivision's substations
            final subdivisionId = assignedLevels['subdivisionId'];
            if (subdivisionId != null) {
              substationsQuery = substationsQuery.where(
                'subdivisionId',
                isEqualTo: subdivisionId,
              );
            }
            break;

          case UserRole.divisionManager:
            // Division managers: all substations in all subdivisions under their division
            final divisionId = assignedLevels['divisionId'];
            if (divisionId != null) {
              final subdivisionsSnapshot = await FirebaseFirestore.instance
                  .collection('subdivisions')
                  .where('divisionId', isEqualTo: divisionId)
                  .get();

              final subdivisionIds = subdivisionsSnapshot.docs
                  .map((doc) => doc.id)
                  .toList();

              if (subdivisionIds.isNotEmpty) {
                substationsQuery = substationsQuery.where(
                  'subdivisionId',
                  whereIn: subdivisionIds,
                );
              }
            }
            break;

          case UserRole.circleManager:
            // Circle managers: all substations in all subdivisions in all divisions under their circle
            final circleId = assignedLevels['circleId'];
            if (circleId != null) {
              // Get all divisions in this circle
              final divisionsSnapshot = await FirebaseFirestore.instance
                  .collection('divisions')
                  .where('circleId', isEqualTo: circleId)
                  .get();

              final divisionIds = divisionsSnapshot.docs
                  .map((doc) => doc.id)
                  .toList();

              if (divisionIds.isNotEmpty) {
                // Get all subdivisions in these divisions
                final subdivisionsSnapshot = await FirebaseFirestore.instance
                    .collection('subdivisions')
                    .where('divisionId', whereIn: divisionIds)
                    .get();

                final subdivisionIds = subdivisionsSnapshot.docs
                    .map((doc) => doc.id)
                    .toList();

                if (subdivisionIds.isNotEmpty) {
                  substationsQuery = substationsQuery.where(
                    'subdivisionId',
                    whereIn: subdivisionIds,
                  );
                }
              }
            }
            break;

          case UserRole.zoneManager:
            // Zone managers: all substations in their zone hierarchy
            final zoneId = assignedLevels['zoneId'];
            if (zoneId != null) {
              // Get all circles in this zone
              final circlesSnapshot = await FirebaseFirestore.instance
                  .collection('circles')
                  .where('zoneId', isEqualTo: zoneId)
                  .get();

              final circleIds = circlesSnapshot.docs
                  .map((doc) => doc.id)
                  .toList();

              if (circleIds.isNotEmpty) {
                // Get all divisions in these circles
                final divisionsSnapshot = await FirebaseFirestore.instance
                    .collection('divisions')
                    .where('circleId', whereIn: circleIds)
                    .get();

                final divisionIds = divisionsSnapshot.docs
                    .map((doc) => doc.id)
                    .toList();

                if (divisionIds.isNotEmpty) {
                  // Get all subdivisions in these divisions
                  final subdivisionsSnapshot = await FirebaseFirestore.instance
                      .collection('subdivisions')
                      .where('divisionId', whereIn: divisionIds)
                      .get();

                  final subdivisionIds = subdivisionsSnapshot.docs
                      .map((doc) => doc.id)
                      .toList();

                  if (subdivisionIds.isNotEmpty) {
                    substationsQuery = substationsQuery.where(
                      'subdivisionId',
                      whereIn: subdivisionIds,
                    );
                  }
                }
              }
            }
            break;

          case UserRole.admin:
            // Admins: all substations (no filter needed)
            break;

          default:
            // For other roles (like substationUser), no substations available for subscription
            // They only work at specific substations, they don't manage notifications for multiple substations
            return;
        }
      }

      final substationsSnapshot = await substationsQuery.get();

      for (var doc in substationsSnapshot.docs) {
        final substationId = doc.id;
        final substationData = doc.data();
        final substationName = substationData['name'] as String?;

        if (substationName != null && substationName.trim().isNotEmpty) {
          _availableSubstations.add(substationId);
          _substationIdToName[substationId] = substationName.trim();
        }
      }

      print(
        'Found ${_availableSubstations.length} substations for ${widget.currentUser.role}',
      );
    } catch (e) {
      print('Error loading substations: $e');
    }
  }

  Future<void> _savePreferences() async {
    if (_preferences == null) return;

    setState(() => _isSaving = true);
    try {
      await FirebaseFirestore.instance
          .collection('notificationPreferences')
          .doc(widget.currentUser.uid)
          .set(_preferences!.toFirestore());

      if (mounted) {
        SnackBarUtils.showSnackBar(
          context,
          'Notification preferences saved successfully!',
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        SnackBarUtils.showSnackBar(
          context,
          'Error saving preferences: $e',
          isError: true,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Widget _buildPreferenceCard({
    required String title,
    required Widget child,
    IconData? icon,
    Color? iconColor,
  }) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (icon != null) ...[
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: (iconColor ?? theme.colorScheme.primary)
                          .withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      icon,
                      color: iconColor ?? theme.colorScheme.primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }

  // UPDATED: Method to update preferences immutably
  void _updatePreferences(NotificationPreferences newPreferences) {
    setState(() {
      _preferences = newPreferences;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isLoading) {
      return Scaffold(
        backgroundColor: const Color(0xFFFAFAFA),
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          title: const Text(
            'Notification Preferences',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Notification Preferences',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: theme.colorScheme.onSurface),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Enable/Disable Notifications
          _buildPreferenceCard(
            title: 'Event Notifications',
            icon: Icons.notifications,
            iconColor: Colors.blue,
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('Tripping Events'),
                  subtitle: const Text(
                    'Receive notifications for tripping events',
                  ),
                  value: _preferences?.enableTrippingNotifications ?? true,
                  onChanged: (value) {
                    _updatePreferences(
                      _preferences!.copyWith(
                        enableTrippingNotifications: value,
                      ),
                    );
                  },
                  contentPadding: EdgeInsets.zero,
                ),
                SwitchListTile(
                  title: const Text('Shutdown Events'),
                  subtitle: const Text(
                    'Receive notifications for shutdown events',
                  ),
                  value: _preferences?.enableShutdownNotifications ?? true,
                  onChanged: (value) {
                    _updatePreferences(
                      _preferences!.copyWith(
                        enableShutdownNotifications: value,
                      ),
                    );
                  },
                  contentPadding: EdgeInsets.zero,
                ),
              ],
            ),
          ),

          // UPDATED: Voltage Level Filters with Default and Optional sections
          _buildPreferenceCard(
            title: 'Voltage Level Thresholds',
            icon: Icons.flash_on,
            iconColor: Colors.orange,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Default Mandatory Voltages Section
                const Text(
                  'Default voltages (recommended):',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.green,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8.0,
                  runSpacing: 8.0,
                  children: _defaultMandatoryVoltages.map((voltage) {
                    bool isSelected =
                        _preferences?.subscribedVoltageThresholds.contains(
                          voltage,
                        ) ??
                        false;
                    return FilterChip(
                      label: Text('${voltage}kV'),
                      selected: isSelected,
                      onSelected: (selected) {
                        final currentThresholds = List<int>.from(
                          _preferences!.subscribedVoltageThresholds,
                        );
                        if (selected) {
                          currentThresholds.add(voltage);
                        } else {
                          currentThresholds.remove(voltage);
                        }
                        _updatePreferences(
                          _preferences!.copyWith(
                            subscribedVoltageThresholds: currentThresholds,
                          ),
                        );
                      },
                      selectedColor: Colors.green.withOpacity(0.2),
                      checkmarkColor: Colors.green,
                      backgroundColor: Colors.green.withOpacity(0.05),
                    );
                  }).toList(),
                ),

                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 8),

                // Optional Voltages Section
                const Text(
                  'Optional voltages (you can enable these):',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.orange,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8.0,
                  runSpacing: 8.0,
                  children: _optionalVoltages.map((voltage) {
                    bool isEnabled =
                        _preferences?.enabledOptionalVoltages.contains(
                          voltage,
                        ) ??
                        false;
                    return FilterChip(
                      label: Text('${voltage}kV'),
                      selected: isEnabled,
                      onSelected: (selected) {
                        if (selected) {
                          _updatePreferences(
                            _preferences!.enableOptionalVoltage(voltage),
                          );
                        } else {
                          _updatePreferences(
                            _preferences!.disableOptionalVoltage(voltage),
                          );
                        }
                      },
                      selectedColor: Colors.orange.withOpacity(0.2),
                      checkmarkColor: Colors.orange,
                      backgroundColor: Colors.orange.withOpacity(0.05),
                    );
                  }).toList(),
                ),

                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.withOpacity(0.2)),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: Colors.blue.shade600,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Active: ${_preferences?.allActiveVoltageThresholds.map((v) => '${v}kV').join(', ') ?? 'None'}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.blue.shade700,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // UPDATED: Bay Type Filters with Transformer and Line highlighted
          _buildPreferenceCard(
            title: 'Bay Types',
            icon: Icons.electrical_services,
            iconColor: Colors.green,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Receive notifications for these bay types:',
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
                const SizedBox(height: 12),
                CheckboxListTile(
                  title: const Text(
                    'All Bay Types',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: const Text(
                    'Includes Transformer, Line, and all others',
                  ),
                  value:
                      _preferences?.subscribedBayTypes.contains('all') ?? false,
                  onChanged: (value) {
                    if (value == true) {
                      _updatePreferences(
                        _preferences!.copyWith(subscribedBayTypes: ['all']),
                      );
                    } else {
                      _updatePreferences(
                        _preferences!.copyWith(subscribedBayTypes: []),
                      );
                    }
                  },
                  contentPadding: EdgeInsets.zero,
                ),
                if (!(_preferences?.subscribedBayTypes.contains('all') ??
                    false)) ...[
                  const Divider(),
                  ..._bayTypeOptions.map((bayType) {
                    bool isSelected =
                        _preferences?.subscribedBayTypes.contains(bayType) ??
                        false;
                    bool isRecommended =
                        bayType == 'Transformer' || bayType == 'Line';

                    return CheckboxListTile(
                      title: Row(
                        children: [
                          Text(bayType),
                          if (isRecommended) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.green.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'Recommended',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.green.shade700,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      value: isSelected,
                      onChanged: (selected) {
                        final bayTypes = List<String>.from(
                          _preferences!.subscribedBayTypes,
                        );
                        if (selected == true) {
                          bayTypes.add(bayType);
                        } else {
                          bayTypes.remove(bayType);
                        }
                        _updatePreferences(
                          _preferences!.copyWith(subscribedBayTypes: bayTypes),
                        );
                      },
                      contentPadding: const EdgeInsets.only(left: 16),
                    );
                  }).toList(),
                ],
              ],
            ),
          ),

          // UPDATED: Substation Filters with hierarchy information
          _buildPreferenceCard(
            title: 'Substations',
            icon: Icons.account_tree,
            iconColor: Colors.purple,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Receive notifications from these substations (${widget.currentUser.role} level):',
                  style: const TextStyle(fontSize: 14, color: Colors.grey),
                ),
                const SizedBox(height: 12),
                CheckboxListTile(
                  title: const Text(
                    'All Substations',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    'All substations under your ${widget.currentUser.role} authority',
                  ),
                  value:
                      _preferences?.subscribedSubstations.contains('all') ??
                      false,
                  onChanged: (value) {
                    if (value == true) {
                      _updatePreferences(
                        _preferences!.subscribeToAllSubstations(),
                      );
                    } else {
                      _updatePreferences(
                        _preferences!.copyWith(subscribedSubstations: []),
                      );
                    }
                  },
                  contentPadding: EdgeInsets.zero,
                ),
                if (!(_preferences?.subscribedSubstations.contains('all') ??
                    false)) ...[
                  const Divider(),
                  if (_availableSubstations.isNotEmpty)
                    Container(
                      height: 200,
                      child: ListView.builder(
                        itemCount: _availableSubstations.length,
                        itemBuilder: (context, index) {
                          final substationId = _availableSubstations[index];
                          final substationName =
                              _substationIdToName[substationId] ??
                              'Unknown Substation';
                          bool isSelected =
                              _preferences?.subscribedSubstations.contains(
                                substationId,
                              ) ??
                              false;

                          return CheckboxListTile(
                            title: Text(
                              substationName,
                              style: const TextStyle(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            subtitle: Text(
                              'ID: ${substationId.length > 8 ? '${substationId.substring(0, 8)}...' : substationId}',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.grey.shade500,
                                fontFamily: 'monospace',
                              ),
                            ),
                            value: isSelected,
                            onChanged: (selected) {
                              if (selected == true) {
                                _updatePreferences(
                                  _preferences!.addSubstation(substationId),
                                );
                              } else {
                                _updatePreferences(
                                  _preferences!.removeSubstation(substationId),
                                );
                              }
                            },
                            contentPadding: const EdgeInsets.only(left: 16),
                          );
                        },
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, color: Colors.grey.shade600),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'No substations available in your ${widget.currentUser.role} area',
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 100), // Space for FAB
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isSaving ? null : _savePreferences,
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary,
        icon: _isSaving
            ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: theme.colorScheme.onPrimary,
                ),
              )
            : const Icon(Icons.save),
        label: Text(
          _isSaving ? 'Saving...' : 'Save Preferences',
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
      ),
    );
  }
}
