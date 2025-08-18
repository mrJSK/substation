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

  final List<int> _defaultMandatoryVoltages = [132, 220, 400, 765];
  final List<int> _optionalVoltages = [11, 33, 66, 110];
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
      final preferencesDoc = await FirebaseFirestore.instance
          .collection('notificationPreferences')
          .doc(widget.currentUser.uid)
          .get();

      if (preferencesDoc.exists) {
        _preferences = NotificationPreferences.fromFirestore(preferencesDoc);
      } else {
        _preferences = NotificationPreferences.withDefaults(
          widget.currentUser.uid,
        );
      }
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
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadAvailableSubstations() async {
    _availableSubstations.clear();
    _substationIdToName.clear();
    try {
      Query<Map<String, dynamic>> substationsQuery = FirebaseFirestore.instance
          .collection('substations')
          .orderBy('name');
      // ... same as before ...
      // [complete your substation loading logic]
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
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _updatePreferences(NotificationPreferences newPreferences) {
    setState(() {
      _preferences = newPreferences;
    });
  }

  Widget _buildPreferenceCard({
    required String title,
    required Widget child,
    IconData? icon,
    Color? iconColor,
    bool isDarkMode = false,
  }) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF2C2C2E) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: isDarkMode
                ? Colors.black.withOpacity(0.3)
                : Colors.black.withOpacity(0.05),
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
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: isDarkMode ? Colors.white : null,
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    if (_isLoading) {
      return Scaffold(
        backgroundColor: isDarkMode
            ? const Color(0xFF1C1C1E)
            : const Color(0xFFFAFAFA),
        appBar: AppBar(
          backgroundColor: isDarkMode ? const Color(0xFF2C2C2E) : Colors.white,
          elevation: 0,
          title: Text(
            'Notification Preferences',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: isDarkMode ? Colors.white : null,
            ),
          ),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: isDarkMode
          ? const Color(0xFF1C1C1E)
          : const Color(0xFFFAFAFA),
      appBar: AppBar(
        backgroundColor: isDarkMode ? const Color(0xFF2C2C2E) : Colors.white,
        elevation: 0,
        title: Text(
          'Notification Preferences',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: isDarkMode ? Colors.white : null,
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
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildPreferenceCard(
            title: 'Event Notifications',
            icon: Icons.notifications,
            iconColor: Colors.blue,
            isDarkMode: isDarkMode,
            child: Column(
              children: [
                SwitchListTile(
                  title: Text(
                    'Tripping Events',
                    style: TextStyle(color: isDarkMode ? Colors.white : null),
                  ),
                  subtitle: Text(
                    'Receive notifications for tripping events',
                    style: TextStyle(
                      color: isDarkMode ? Colors.white.withOpacity(0.7) : null,
                    ),
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
                  activeColor: Colors.blue,
                ),
                SwitchListTile(
                  title: Text(
                    'Shutdown Events',
                    style: TextStyle(color: isDarkMode ? Colors.white : null),
                  ),
                  subtitle: Text(
                    'Receive notifications for shutdown events',
                    style: TextStyle(
                      color: isDarkMode ? Colors.white.withOpacity(0.7) : null,
                    ),
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
                  activeColor: Colors.blue,
                ),
              ],
            ),
          ),

          _buildPreferenceCard(
            title: 'Voltage Level Thresholds',
            icon: Icons.flash_on,
            iconColor: Colors.orange,
            isDarkMode: isDarkMode,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
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
                      label: Text(
                        '${voltage}kV',
                        style: TextStyle(
                          color: isDarkMode ? Colors.white : Colors.green[800],
                        ),
                      ),
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
                      selectedColor: Colors.green.withOpacity(0.25),
                      checkmarkColor: Colors.green,
                      backgroundColor: Colors.green.withOpacity(0.08),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 8),
                Text(
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
                      label: Text(
                        '${voltage}kV',
                        style: TextStyle(
                          color: isDarkMode ? Colors.white : Colors.orange[800],
                        ),
                      ),
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
                      backgroundColor: Colors.orange.withOpacity(0.06),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDarkMode
                        ? Colors.blue.withOpacity(0.07)
                        : Colors.blue.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isDarkMode
                          ? Colors.blue.withOpacity(0.15)
                          : Colors.blue.withOpacity(0.2),
                    ),
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

          _buildPreferenceCard(
            title: 'Bay Types',
            icon: Icons.electrical_services,
            iconColor: Colors.green,
            isDarkMode: isDarkMode,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.green, size: 18),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'By default you receive Line and Transformer notifications. You may enable/disable or add other types.',
                          style: TextStyle(
                            color: Colors.green.shade700,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                CheckboxListTile(
                  title: Text(
                    'All Bay Types',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: isDarkMode ? Colors.white : null,
                    ),
                  ),
                  subtitle: Text(
                    'Includes Transformer, Line, and all others',
                    style: TextStyle(color: isDarkMode ? Colors.white70 : null),
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
                    bool isDefault =
                        bayType == 'Transformer' || bayType == 'Line';
                    return CheckboxListTile(
                      title: Row(
                        children: [
                          Text(
                            bayType,
                            style: TextStyle(
                              color: isDarkMode ? Colors.white : null,
                            ),
                          ),
                          if (isDefault) ...[
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
                          if (!bayTypes.contains(bayType))
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

          _buildPreferenceCard(
            title: 'Substations',
            icon: Icons.account_tree,
            iconColor: Colors.purple,
            isDarkMode: isDarkMode,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Receive notifications from these substations (${widget.currentUser.role} level):',
                  style: TextStyle(
                    fontSize: 14,
                    color: isDarkMode ? Colors.white70 : Colors.grey,
                  ),
                ),
                const SizedBox(height: 12),
                CheckboxListTile(
                  title: Text(
                    'All Substations',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: isDarkMode ? Colors.white : null,
                    ),
                  ),
                  subtitle: Text(
                    'All substations under your ${widget.currentUser.role} authority',
                    style: TextStyle(
                      color: isDarkMode ? Colors.white54 : Colors.grey,
                    ),
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
                              style: TextStyle(
                                fontWeight: FontWeight.w500,
                                color: isDarkMode ? Colors.white : null,
                              ),
                            ),
                            subtitle: Text(
                              'ID: ${substationId.length > 8 ? '${substationId.substring(0, 8)}...' : substationId}',
                              style: TextStyle(
                                fontSize: 10,
                                color: isDarkMode
                                    ? Colors.white54
                                    : Colors.grey.shade500,
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
                        color: isDarkMode
                            ? Colors.white10
                            : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: isDarkMode
                                ? Colors.white54
                                : Colors.grey.shade600,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'No substations available in your ${widget.currentUser.role} area',
                              style: TextStyle(
                                color: isDarkMode
                                    ? Colors.white70
                                    : Colors.grey.shade600,
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
          const SizedBox(height: 100),
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
