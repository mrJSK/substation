// lib/screens/admin/user_management_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:dropdown_search/dropdown_search.dart';

import '../../models/user_model.dart';
import '../../models/hierarchy_models.dart'; // For hierarchy models
import '../../utils/snackbar_utils.dart';

enum UserManagementViewMode { list, edit }

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  UserManagementViewMode _viewMode = UserManagementViewMode.list;
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  AppUser? _userToEdit; // The user currently being edited

  // Controllers for the edit form
  late UserRole _selectedRole;
  late bool _isApproved;
  Map<String, String>? _assignedLevels = {};

  // For cascading hierarchy dropdowns
  String? _selectedZoneId;
  String? _selectedCircleId;
  String? _selectedDivisionId;
  String? _selectedSubdivisionId;
  String? _selectedSubstationId; // To hold selected substation ID

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
  }

  void _showListView() {
    setState(() {
      _viewMode = UserManagementViewMode.list;
      _userToEdit = null;
      _assignedLevels = {}; // Clear assigned levels when returning to list
      // Clear hierarchy selections
      _selectedZoneId = null;
      _selectedCircleId = null;
      _selectedDivisionId = null;
      _selectedSubdivisionId = null;
      _selectedSubstationId = null; // Clear selected substation
    });
  }

  void _showEditForm(AppUser user) {
    setState(() {
      _viewMode = UserManagementViewMode.edit;
      _userToEdit = user;
      _selectedRole = user.role;
      _isApproved = user.approved;
      _assignedLevels = user.assignedLevels != null
          ? Map<String, String>.from(user.assignedLevels!)
          : {};

      // Initialize dropdowns with existing assigned levels
      _selectedZoneId = _assignedLevels!['zoneId'];
      _selectedCircleId = _assignedLevels!['circleId'];
      _selectedDivisionId = _assignedLevels!['divisionId'];
      _selectedSubdivisionId = _assignedLevels!['subdivisionId'];
      _selectedSubstationId =
          _assignedLevels!['substationId']; // Initialize selected substation
    });
  }

  Future<void> _saveUserChanges() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_userToEdit == null) {
      SnackBarUtils.showSnackBar(
        context,
        'Error: No user selected for editing.',
        isError: true,
      );
      return;
    }

    // Validate assigned levels for manager roles
    if (_selectedRole == UserRole.zoneManager && _selectedZoneId == null) {
      SnackBarUtils.showSnackBar(
        context,
        'Please assign a Zone for Zone Manager.',
        isError: true,
      );
      return;
    } else if (_selectedRole == UserRole.circleManager &&
        _selectedCircleId == null) {
      SnackBarUtils.showSnackBar(
        context,
        'Please assign a Circle for Circle Manager.',
        isError: true,
      );
      return;
    } else if (_selectedRole == UserRole.divisionManager &&
        _selectedDivisionId == null) {
      SnackBarUtils.showSnackBar(
        context,
        'Please assign a Division for Division Manager.',
        isError: true,
      );
      return;
    } else if (_selectedRole == UserRole.subdivisionManager &&
        _selectedSubdivisionId == null) {
      SnackBarUtils.showSnackBar(
        context,
        'Please assign a Subdivision for Subdivision Manager.',
        isError: true,
      );
      return;
    } else if (_selectedRole == UserRole.substationUser &&
        _selectedSubstationId == null) {
      SnackBarUtils.showSnackBar(
        context,
        'Please assign a Substation for Substation User.',
        isError: true,
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      // Prepare assignedLevels based on selected role and hierarchy
      _assignedLevels = {};
      if (_selectedRole == UserRole.zoneManager && _selectedZoneId != null) {
        _assignedLevels!['zoneId'] = _selectedZoneId!;
      } else if (_selectedRole == UserRole.circleManager &&
          _selectedCircleId != null) {
        _assignedLevels!['circleId'] = _selectedCircleId!;
        // Also carry up parent IDs for proper hierarchy access checks if needed later
        if (_selectedZoneId != null)
          _assignedLevels!['zoneId'] = _selectedZoneId!;
      } else if (_selectedRole == UserRole.divisionManager &&
          _selectedDivisionId != null) {
        _assignedLevels!['divisionId'] = _selectedDivisionId!;
        if (_selectedCircleId != null)
          _assignedLevels!['circleId'] = _selectedCircleId!;
        if (_selectedZoneId != null)
          _assignedLevels!['zoneId'] = _selectedZoneId!;
      } else if (_selectedRole == UserRole.subdivisionManager &&
          _selectedSubdivisionId != null) {
        _assignedLevels!['subdivisionId'] = _selectedSubdivisionId!;
        if (_selectedDivisionId != null)
          _assignedLevels!['divisionId'] = _selectedDivisionId!;
        if (_selectedCircleId != null)
          _assignedLevels!['circleId'] = _selectedCircleId!;
        if (_selectedZoneId != null)
          _assignedLevels!['zoneId'] = _selectedZoneId!;
      } else if (_selectedRole == UserRole.substationUser &&
          _selectedSubstationId != null) {
        _assignedLevels!['substationId'] = _selectedSubstationId!;
        // Also carry up parent IDs for proper hierarchy access if needed
        if (_selectedSubdivisionId != null)
          _assignedLevels!['subdivisionId'] = _selectedSubdivisionId!;
        if (_selectedDivisionId != null)
          _assignedLevels!['divisionId'] = _selectedDivisionId!;
        if (_selectedCircleId != null)
          _assignedLevels!['circleId'] = _selectedCircleId!;
        if (_selectedZoneId != null)
          _assignedLevels!['zoneId'] = _selectedZoneId!;
      }

      await FirebaseFirestore.instance
          .collection('users')
          .doc(_userToEdit!.uid)
          .update({
            'role': _selectedRole.toString().split('.').last,
            'approved': _isApproved,
            'assignedLevels': _assignedLevels,
          });

      if (mounted) {
        SnackBarUtils.showSnackBar(
          context,
          'User ${_userToEdit!.email} updated successfully!',
        );
        _showListView(); // Go back to list view
      }
    } catch (e) {
      print("Error saving user: $e");
      if (mounted) {
        SnackBarUtils.showSnackBar(
          context,
          'Failed to update user: $e',
          isError: true,
        );
      }
    } finally {
      setState(() {
        _isSaving = false;
      });
    }
  }

  Future<void> _deleteUser(String userId, String email) async {
    final bool confirm =
        await showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text('Confirm Delete'),
              content: Text(
                'Are you sure you want to delete user "$email"? This action cannot be undone and will not delete the Firebase Authentication user.',
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  child: const Text('Delete'),
                ),
              ],
            );
          },
        ) ??
        false;

    if (confirm) {
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .delete();
        if (mounted) {
          SnackBarUtils.showSnackBar(
            context,
            'User $email deleted successfully!',
          );
        }
      } catch (e) {
        print("Error deleting user: $e");
        if (mounted) {
          SnackBarUtils.showSnackBar(
            context,
            'Failed to delete user: $e',
            isError: true,
          );
        }
      }
    }
  }

  // Helper to build hierarchy dropdowns
  Widget _buildHierarchyDropdown<T extends HierarchyItem>({
    required String label,
    required String collectionName,
    required String? parentId,
    required String parentIdFieldName, // e.g., 'zoneId' for circles
    required Function(String? value) onChanged,
    required String? currentValue,
    required T Function(DocumentSnapshot) fromFirestore,
    required String? Function(String?) validator,
  }) {
    // Determine visibility based on selected role and parent selection
    bool shouldShow = false;
    if (collectionName == 'zones') {
      shouldShow = true; // Zones are always top-level selectable
    } else if (collectionName == 'circles' &&
        (_selectedRole == UserRole.circleManager ||
            _selectedRole == UserRole.divisionManager ||
            _selectedRole == UserRole.subdivisionManager ||
            _selectedRole == UserRole.substationUser)) {
      shouldShow = _selectedZoneId != null;
    } else if (collectionName == 'divisions' &&
        (_selectedRole == UserRole.divisionManager ||
            _selectedRole == UserRole.subdivisionManager ||
            _selectedRole == UserRole.substationUser)) {
      shouldShow = _selectedCircleId != null;
    } else if (collectionName == 'subdivisions' &&
        (_selectedRole == UserRole.subdivisionManager ||
            _selectedRole == UserRole.substationUser)) {
      shouldShow = _selectedDivisionId != null;
    } else if (collectionName == 'substations' &&
        _selectedRole == UserRole.substationUser) {
      shouldShow = _selectedSubdivisionId != null;
    }

    if (!shouldShow) {
      return const SizedBox.shrink();
    }

    Query query = FirebaseFirestore.instance.collection(collectionName);
    if (parentId != null && parentIdFieldName.isNotEmpty) {
      query = query.where(parentIdFieldName, isEqualTo: parentId);
    }
    query = query.orderBy('name');

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: StreamBuilder<QuerySnapshot>(
        stream: query.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Text('Error: ${snapshot.error}');
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return DropdownButtonFormField<String>(
              decoration: InputDecoration(
                labelText: 'Loading $label...',
                border: const OutlineInputBorder(),
              ),
              items: const [],
              onChanged: null,
              value: null,
              hint: const CircularProgressIndicator(strokeWidth: 2),
            );
          }

          final items = snapshot.data!.docs
              .map((doc) => fromFirestore(doc))
              .toList();
          final List<DropdownMenuItem<String>> dropdownItems = items.map((
            item,
          ) {
            return DropdownMenuItem<String>(
              value: item.id,
              child: Text(item.name),
            );
          }).toList();

          // Check if currentValue is present in the new list of items.
          // If not, set it to null to avoid the assertion error.
          String? validatedCurrentValue = currentValue;
          if (currentValue != null &&
              !dropdownItems.any((item) => item.value == currentValue)) {
            validatedCurrentValue = null;
          }

          return DropdownButtonFormField<String>(
            value: validatedCurrentValue, // Use the validated value
            decoration: InputDecoration(
              labelText: label,
              border: const OutlineInputBorder(),
            ),
            items: dropdownItems.isEmpty
                ? [
                    const DropdownMenuItem(
                      value: null,
                      enabled: false,
                      child: Text('No options available'),
                    ),
                  ]
                : dropdownItems,
            onChanged: (value) {
              onChanged(value);
              // Reset child selections when a parent changes
              if (collectionName == 'zones') {
                setState(() {
                  _selectedCircleId = null;
                  _selectedDivisionId = null;
                  _selectedSubdivisionId = null;
                  _selectedSubstationId = null;
                });
              } else if (collectionName == 'circles') {
                setState(() {
                  _selectedDivisionId = null;
                  _selectedSubdivisionId = null;
                  _selectedSubstationId = null;
                });
              } else if (collectionName == 'divisions') {
                setState(() {
                  _selectedSubdivisionId = null;
                  _selectedSubstationId = null;
                });
              } else if (collectionName == 'subdivisions') {
                setState(() {
                  _selectedSubstationId = null;
                });
              }
            },
            validator: validator,
            hint: Text('Select $label'),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _viewMode == UserManagementViewMode.list
              ? 'User Management'
              : 'Edit User',
        ),
        leading: _viewMode == UserManagementViewMode.edit
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: _showListView,
              )
            : null,
      ),
      body: _viewMode == UserManagementViewMode.list
          ? _buildUserListView()
          : _buildUserEditForm(),
    );
  }

  Widget _buildUserListView() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .orderBy('email')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Error: ${snapshot.error}',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          );
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.data!.docs.isEmpty) {
          return const Center(
            child: Text(
              'No users found. Users will appear here after they sign up.',
            ),
          );
        }

        final users = snapshot.data!.docs
            .map((doc) => AppUser.fromFirestore(doc))
            .toList();

        // Group users by role
        final Map<UserRole, List<AppUser>> usersByRole = {};
        for (var role in UserRole.values) {
          usersByRole[role] = [];
        }
        for (var user in users) {
          usersByRole[user.role]?.add(user);
        }

        // Sort roles for display order (e.g., admin, then managers, then others, then pending)
        final List<UserRole> sortedRoles = [
          UserRole.admin,
          UserRole.zoneManager,
          UserRole.circleManager,
          UserRole.divisionManager,
          UserRole.subdivisionManager,
          UserRole.substationUser,
          UserRole.pending,
        ].where((role) => usersByRole[role]!.isNotEmpty).toList();

        return ListView.builder(
          padding: const EdgeInsets.all(16.0),
          itemCount: sortedRoles.length,
          itemBuilder: (context, index) {
            final role = sortedRoles[index];
            final usersInRole = usersByRole[role]!;

            return Card(
              margin: const EdgeInsets.symmetric(vertical: 8.0),
              elevation: 3,
              child: ExpansionTile(
                initiallyExpanded:
                    role == UserRole.pending, // Expand pending users by default
                title: Text(
                  '${role.toString().split('.').last.capitalize()} Users (${usersInRole.length})',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                children: usersInRole.map((user) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16.0,
                      vertical: 4.0,
                    ),
                    child: Column(
                      children: [
                        ListTile(
                          leading: CircleAvatar(
                            backgroundColor: user.approved
                                ? Colors.green.shade100
                                : Colors.orange.shade100,
                            child: Icon(
                              user.approved
                                  ? Icons.check_circle
                                  : Icons.pending,
                              color: user.approved
                                  ? Colors.green.shade700
                                  : Colors.orange.shade700,
                            ),
                          ),
                          title: Text(user.email),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Role: ${user.role.toString().split('.').last}',
                              ),
                              if (user.assignedLevels != null &&
                                  user.assignedLevels!.isNotEmpty)
                                Text(
                                  'Assigned: ${user.assignedLevels!.entries.map((e) {
                                    // Map ID to Name if possible for better display
                                    String key = e.key;
                                    String value = e.value;
                                    // More complex mapping would require fetching names from hierarchy collections
                                    // For simplicity, just display key-value for now.
                                    return '${key.replaceAll('Id', '')}: $value';
                                  }).join(', ')}',
                                ),
                            ],
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit),
                                tooltip: 'Edit User',
                                onPressed: () => _showEditForm(user),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline),
                                tooltip: 'Delete User',
                                color: Theme.of(context).colorScheme.error,
                                onPressed: () =>
                                    _deleteUser(user.uid, user.email),
                              ),
                            ],
                          ),
                        ),
                        const Divider(
                          height: 1,
                        ), // Separator between users in the group
                      ],
                    ),
                  );
                }).toList(),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildUserEditForm() {
    if (_userToEdit == null) {
      return const Center(child: Text('No user selected for editing.'));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Editing User: ${_userToEdit!.email}',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 20),
            TextFormField(
              initialValue: _userToEdit!.email,
              readOnly: true,
              decoration: const InputDecoration(
                labelText: 'User Email',
                prefixIcon: Icon(Icons.email),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text('Approved Account'),
              value: _isApproved,
              onChanged: (value) {
                setState(() {
                  _isApproved = value;
                });
              },
              secondary: const Icon(Icons.approval),
              contentPadding: EdgeInsets.zero,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<UserRole>(
              value: _selectedRole,
              decoration: const InputDecoration(
                labelText: 'Assign Role',
                prefixIcon: Icon(Icons.person),
                border: OutlineInputBorder(),
              ),
              items: UserRole.values
                  .map(
                    (role) => DropdownMenuItem(
                      value: role,
                      child: Text(role.toString().split('.').last),
                    ),
                  )
                  .toList(),
              onChanged: (newValue) {
                setState(() {
                  _selectedRole = newValue!;
                  // Clear hierarchy selections if role changes to non-managerial
                  if (![
                    UserRole.zoneManager,
                    UserRole.circleManager,
                    UserRole.divisionManager,
                    UserRole.subdivisionManager,
                    UserRole.substationUser,
                  ].contains(_selectedRole)) {
                    _selectedZoneId = null;
                    _selectedCircleId = null;
                    _selectedDivisionId = null;
                    _selectedSubdivisionId = null;
                    _selectedSubstationId = null;
                    _assignedLevels = {};
                  } else {
                    // If switching TO a managerial role, reset only if previous role wasn't managerial
                    // to avoid carrying over incorrect hierarchy if it changed to a non-managerial role first.
                    if (_userToEdit!.role != UserRole.zoneManager &&
                        _userToEdit!.role != UserRole.circleManager &&
                        _userToEdit!.role != UserRole.divisionManager &&
                        _userToEdit!.role != UserRole.subdivisionManager &&
                        _userToEdit!.role != UserRole.substationUser) {
                      _selectedZoneId = null;
                      _selectedCircleId = null;
                      _selectedDivisionId = null;
                      _selectedSubdivisionId = null;
                      _selectedSubstationId = null;
                      _assignedLevels = {};
                    }
                  }
                });
              },
            ),
            const SizedBox(height: 20),

            // Conditional Hierarchy Assignment
            if ([
              UserRole.zoneManager,
              UserRole.circleManager,
              UserRole.divisionManager,
              UserRole.subdivisionManager,
              UserRole.substationUser,
            ].contains(_selectedRole)) ...[
              Text(
                'Assign Hierarchy Levels',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 10),
              _buildHierarchyDropdown<Zone>(
                label: 'Zone',
                collectionName: 'zones',
                parentId: null, // Top-level for Zone
                parentIdFieldName: '', // Not applicable for top-level
                onChanged: (value) => setState(() => _selectedZoneId = value),
                currentValue: _selectedZoneId,
                fromFirestore: Zone.fromFirestore,
                validator: (value) {
                  if (_selectedRole == UserRole.zoneManager && value == null) {
                    return 'Zone is mandatory for Zone Manager';
                  }
                  return null;
                },
              ),
              // Show Circle dropdown if Zone is selected OR if the role itself requires a Circle
              _buildHierarchyDropdown<Circle>(
                label: 'Circle',
                collectionName: 'circles',
                parentId: _selectedZoneId,
                parentIdFieldName: 'zoneId',
                onChanged: (value) => setState(() => _selectedCircleId = value),
                currentValue: _selectedCircleId,
                fromFirestore: Circle.fromFirestore,
                validator: (value) {
                  if (_selectedRole == UserRole.circleManager &&
                      value == null) {
                    return 'Circle is mandatory for Circle Manager';
                  }
                  return null;
                },
              ),
              // Show Division dropdown if Circle is selected OR if the role itself requires a Division
              _buildHierarchyDropdown<Division>(
                label: 'Division',
                collectionName: 'divisions',
                parentId: _selectedCircleId,
                parentIdFieldName: 'circleId',
                onChanged: (value) =>
                    setState(() => _selectedDivisionId = value),
                currentValue: _selectedDivisionId,
                fromFirestore: Division.fromFirestore,
                validator: (value) {
                  if (_selectedRole == UserRole.divisionManager &&
                      value == null) {
                    return 'Division is mandatory for Division Manager';
                  }
                  return null;
                },
              ),
              // Show Subdivision dropdown if Division is selected OR if the role itself requires a Subdivision/Substation
              _buildHierarchyDropdown<Subdivision>(
                label: 'Subdivision',
                collectionName: 'subdivisions',
                parentId: _selectedDivisionId,
                parentIdFieldName: 'divisionId',
                onChanged: (value) =>
                    setState(() => _selectedSubdivisionId = value),
                currentValue: _selectedSubdivisionId,
                fromFirestore: Subdivision.fromFirestore,
                validator: (value) {
                  if (_selectedRole == UserRole.subdivisionManager &&
                      value == null) {
                    return 'Subdivision is mandatory for Subdivision Manager';
                  }
                  if (_selectedRole == UserRole.substationUser &&
                      value == null) {
                    return 'Subdivision is mandatory for Substation User';
                  }
                  return null;
                },
              ),
              // Show Substation dropdown if Subdivision is selected AND role is SubstationUser
              _buildHierarchyDropdown<Substation>(
                label: 'Substation',
                collectionName: 'substations',
                parentId: _selectedSubdivisionId,
                parentIdFieldName: 'subdivisionId',
                onChanged: (value) =>
                    setState(() => _selectedSubstationId = value),
                currentValue: _selectedSubstationId,
                fromFirestore: Substation.fromFirestore,
                validator: (value) {
                  if (_selectedRole == UserRole.substationUser &&
                      value == null) {
                    return 'Substation is mandatory for Substation User';
                  }
                  return null;
                },
              ),
            ],
            const SizedBox(height: 32),
            Center(
              child: _isSaving
                  ? const CircularProgressIndicator()
                  : ElevatedButton.icon(
                      onPressed: _saveUserChanges,
                      icon: const Icon(Icons.save),
                      label: const Text('Save Changes'),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 50),
                      ),
                    ),
            ),
            const SizedBox(height: 16),
            Center(
              child: TextButton(
                onPressed: _showListView,
                child: const Text('Cancel'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Extension to capitalize first letter for display purposes
extension StringExtension on String {
  String capitalize() {
    if (isEmpty) {
      return this;
    }
    return "${this[0].toUpperCase()}${substring(1)}";
  }
}
