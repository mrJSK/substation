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

  // Voltage level options
  final List<int> _voltageOptions = [11, 33, 66, 110, 132, 220, 400, 765];

  // Bay type options
  final List<String> _bayTypeOptions = [
    'Feeder',
    'Transformer',
    'Line',
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
        // Create default preferences
        _preferences = NotificationPreferences(
          userId: widget.currentUser.uid,
          subscribedVoltageThresholds: [],
          subscribedBayTypes: ['all'],
          subscribedSubstations: ['all'],
        );
      }

      // Load available substations
      final substationsSnapshot = await FirebaseFirestore.instance
          .collection('substations')
          .orderBy('name')
          .get();

      _availableSubstations = substationsSnapshot.docs
          .map((doc) => doc.id)
          .toList();
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
                    setState(() {
                      _preferences = NotificationPreferences(
                        userId: _preferences!.userId,
                        subscribedVoltageThresholds:
                            _preferences!.subscribedVoltageThresholds,
                        subscribedBayTypes: _preferences!.subscribedBayTypes,
                        subscribedSubstations:
                            _preferences!.subscribedSubstations,
                        enableTrippingNotifications: value,
                        enableShutdownNotifications:
                            _preferences!.enableShutdownNotifications,
                      );
                    });
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
                    setState(() {
                      _preferences = NotificationPreferences(
                        userId: _preferences!.userId,
                        subscribedVoltageThresholds:
                            _preferences!.subscribedVoltageThresholds,
                        subscribedBayTypes: _preferences!.subscribedBayTypes,
                        subscribedSubstations:
                            _preferences!.subscribedSubstations,
                        enableTrippingNotifications:
                            _preferences!.enableTrippingNotifications,
                        enableShutdownNotifications: value,
                      );
                    });
                  },
                  contentPadding: EdgeInsets.zero,
                ),
              ],
            ),
          ),

          // Voltage Level Filters
          _buildPreferenceCard(
            title: 'Voltage Level Thresholds',
            icon: Icons.flash_on,
            iconColor: Colors.orange,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Receive notifications for events at or above these voltage levels:',
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8.0,
                  runSpacing: 8.0,
                  children: _voltageOptions.map((voltage) {
                    bool isSelected =
                        _preferences?.subscribedVoltageThresholds.contains(
                          voltage,
                        ) ??
                        false;
                    return FilterChip(
                      label: Text('${voltage}kV'),
                      selected: isSelected,
                      onSelected: (selected) {
                        setState(() {
                          final thresholds = List<int>.from(
                            _preferences!.subscribedVoltageThresholds,
                          );
                          if (selected) {
                            thresholds.add(voltage);
                          } else {
                            thresholds.remove(voltage);
                          }
                          _preferences = NotificationPreferences(
                            userId: _preferences!.userId,
                            subscribedVoltageThresholds: thresholds,
                            subscribedBayTypes:
                                _preferences!.subscribedBayTypes,
                            subscribedSubstations:
                                _preferences!.subscribedSubstations,
                            enableTrippingNotifications:
                                _preferences!.enableTrippingNotifications,
                            enableShutdownNotifications:
                                _preferences!.enableShutdownNotifications,
                          );
                        });
                      },
                      selectedColor: theme.colorScheme.primary.withOpacity(0.2),
                      checkmarkColor: theme.colorScheme.primary,
                    );
                  }).toList(),
                ),
              ],
            ),
          ),

          // Bay Type Filters
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
                  title: const Text('All Bay Types'),
                  value:
                      _preferences?.subscribedBayTypes.contains('all') ?? false,
                  onChanged: (value) {
                    setState(() {
                      final bayTypes = value == true ? ['all'] : <String>[];
                      _preferences = NotificationPreferences(
                        userId: _preferences!.userId,
                        subscribedVoltageThresholds:
                            _preferences!.subscribedVoltageThresholds,
                        subscribedBayTypes: bayTypes,
                        subscribedSubstations:
                            _preferences!.subscribedSubstations,
                        enableTrippingNotifications:
                            _preferences!.enableTrippingNotifications,
                        enableShutdownNotifications:
                            _preferences!.enableShutdownNotifications,
                      );
                    });
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
                    return CheckboxListTile(
                      title: Text(bayType),
                      value: isSelected,
                      onChanged: (selected) {
                        setState(() {
                          final bayTypes = List<String>.from(
                            _preferences!.subscribedBayTypes,
                          );
                          if (selected == true) {
                            bayTypes.add(bayType);
                          } else {
                            bayTypes.remove(bayType);
                          }
                          _preferences = NotificationPreferences(
                            userId: _preferences!.userId,
                            subscribedVoltageThresholds:
                                _preferences!.subscribedVoltageThresholds,
                            subscribedBayTypes: bayTypes,
                            subscribedSubstations:
                                _preferences!.subscribedSubstations,
                            enableTrippingNotifications:
                                _preferences!.enableTrippingNotifications,
                            enableShutdownNotifications:
                                _preferences!.enableShutdownNotifications,
                          );
                        });
                      },
                      contentPadding: const EdgeInsets.only(left: 16),
                    );
                  }).toList(),
                ],
              ],
            ),
          ),

          // Substation Filters
          _buildPreferenceCard(
            title: 'Substations',
            icon: Icons.account_tree,
            iconColor: Colors.purple,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Receive notifications from these substations:',
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
                const SizedBox(height: 12),
                CheckboxListTile(
                  title: const Text('All Substations'),
                  value:
                      _preferences?.subscribedSubstations.contains('all') ??
                      false,
                  onChanged: (value) {
                    setState(() {
                      final substations = value == true ? ['all'] : <String>[];
                      _preferences = NotificationPreferences(
                        userId: _preferences!.userId,
                        subscribedVoltageThresholds:
                            _preferences!.subscribedVoltageThresholds,
                        subscribedBayTypes: _preferences!.subscribedBayTypes,
                        subscribedSubstations: substations,
                        enableTrippingNotifications:
                            _preferences!.enableTrippingNotifications,
                        enableShutdownNotifications:
                            _preferences!.enableShutdownNotifications,
                      );
                    });
                  },
                  contentPadding: EdgeInsets.zero,
                ),
                if (!(_preferences?.subscribedSubstations.contains('all') ??
                    false)) ...[
                  const Divider(),
                  Container(
                    height: 200,
                    child: ListView.builder(
                      itemCount: _availableSubstations.length,
                      itemBuilder: (context, index) {
                        final substationId = _availableSubstations[index];
                        bool isSelected =
                            _preferences?.subscribedSubstations.contains(
                              substationId,
                            ) ??
                            false;
                        return CheckboxListTile(
                          title: Text(substationId),
                          value: isSelected,
                          onChanged: (selected) {
                            setState(() {
                              final substations = List<String>.from(
                                _preferences!.subscribedSubstations,
                              );
                              if (selected == true) {
                                substations.add(substationId);
                              } else {
                                substations.remove(substationId);
                              }
                              _preferences = NotificationPreferences(
                                userId: _preferences!.userId,
                                subscribedVoltageThresholds:
                                    _preferences!.subscribedVoltageThresholds,
                                subscribedBayTypes:
                                    _preferences!.subscribedBayTypes,
                                subscribedSubstations: substations,
                                enableTrippingNotifications:
                                    _preferences!.enableTrippingNotifications,
                                enableShutdownNotifications:
                                    _preferences!.enableShutdownNotifications,
                              );
                            });
                          },
                          contentPadding: const EdgeInsets.only(left: 16),
                        );
                      },
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
