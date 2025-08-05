// lib/screens/admin/user_management_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:dropdown_search/dropdown_search.dart';
import '../../models/user_model.dart';
import '../../models/hierarchy_models.dart';
import '../../utils/snackbar_utils.dart';

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  bool _showForm = false;
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  AppUser? _userToEdit;
  late UserRole _selectedRole;
  late bool _isApproved;
  Map<String, dynamic>? _assignedLevels = {};

  // Hierarchy selections
  String? _selectedZoneId;
  String? _selectedCircleId;
  String? _selectedDivisionId;
  String? _selectedSubdivisionId;
  String? _selectedSubstationId;

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: _buildAppBar(theme),
      body: _showForm ? _buildFormView(theme) : _buildListView(theme),
    );
  }

  PreferredSizeWidget _buildAppBar(ThemeData theme) {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      title: Text(
        _showForm ? 'Edit User' : 'User Management',
        style: TextStyle(
          color: theme.colorScheme.onSurface,
          fontSize: 18,
          fontWeight: FontWeight.w500,
        ),
      ),
      leading: _showForm
          ? IconButton(
              icon: Icon(Icons.arrow_back, color: theme.colorScheme.onSurface),
              onPressed: _showListView,
            )
          : IconButton(
              icon: Icon(Icons.arrow_back, color: theme.colorScheme.onSurface),
              onPressed: () => Navigator.pop(context),
            ),
    );
  }

  Widget _buildListView(ThemeData theme) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .orderBy('email')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _buildErrorState(theme, snapshot.error.toString());
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.data!.docs.isEmpty) {
          return _buildEmptyState(theme);
        }

        final users = snapshot.data!.docs
            .map((doc) => AppUser.fromFirestore(doc))
            .toList();

        // Group users by status (pending vs approved)
        final pendingUsers = users.where((user) => !user.approved).toList();
        final approvedUsers = users.where((user) => user.approved).toList();

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (pendingUsers.isNotEmpty) ...[
                _buildUserSection(
                  'Pending Approval',
                  pendingUsers,
                  theme,
                  true,
                ),
                const SizedBox(height: 24),
              ],
              if (approvedUsers.isNotEmpty)
                _buildUserSection('Active Users', approvedUsers, theme, false),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.people_outline,
            size: 64,
            color: theme.colorScheme.onSurface.withOpacity(0.3),
          ),
          const SizedBox(height: 16),
          Text(
            'No users found',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: theme.colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Users will appear here after they sign up',
            style: TextStyle(
              fontSize: 14,
              color: theme.colorScheme.onSurface.withOpacity(0.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(ThemeData theme, String error) {
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
            'Error loading users',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: theme.colorScheme.error,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            error,
            style: TextStyle(
              fontSize: 14,
              color: theme.colorScheme.onSurface.withOpacity(0.6),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildUserSection(
    String title,
    List<AppUser> users,
    ThemeData theme,
    bool isPending,
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
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isPending
                  ? Colors.orange.shade50
                  : theme.colorScheme.primary.withOpacity(0.05),
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
                    color: isPending
                        ? Colors.orange
                        : theme.colorScheme.primary,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    isPending ? Icons.pending_actions : Icons.people,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        '${users.length} user${users.length == 1 ? '' : 's'}',
                        style: TextStyle(
                          fontSize: 13,
                          color: theme.colorScheme.onSurface.withOpacity(0.6),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          ...users.asMap().entries.map((entry) {
            final index = entry.key;
            final user = entry.value;
            final isLast = index == users.length - 1;
            return _buildUserItem(user, theme, !isLast);
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildUserItem(AppUser user, ThemeData theme, bool showDivider) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        border: showDivider
            ? Border(bottom: BorderSide(color: Colors.grey.shade100))
            : null,
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _getRoleColor(user.role).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              _getRoleIcon(user.role),
              color: _getRoleColor(user.role),
              size: 20,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.email,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _getRoleDisplayName(user.role),
                  style: TextStyle(
                    fontSize: 12,
                    color: _getRoleColor(user.role),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (user.assignedLevels != null &&
                    user.assignedLevels!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    _getAssignmentText(user.assignedLevels!),
                    style: TextStyle(
                      fontSize: 11,
                      color: theme.colorScheme.onSurface.withOpacity(0.6),
                    ),
                  ),
                ],
              ],
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!user.approved)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'PENDING',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: Colors.orange.shade700,
                    ),
                  ),
                ),
              const SizedBox(width: 12),
              IconButton(
                onPressed: () => _showEditForm(user),
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(
                    Icons.edit_outlined,
                    color: theme.colorScheme.primary,
                    size: 16,
                  ),
                ),
                tooltip: 'Edit user',
              ),
              IconButton(
                onPressed: () => _deleteUser(user.uid, user.email),
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.error.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(
                    Icons.delete_outline,
                    color: theme.colorScheme.error,
                    size: 16,
                  ),
                ),
                tooltip: 'Delete user',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFormView(ThemeData theme) {
    if (_userToEdit == null) {
      return const Center(child: Text('No user selected for editing.'));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildUserInfoSection(theme),
            const SizedBox(height: 24),
            _buildRoleSection(theme),
            if (_isManagerRole(_selectedRole)) ...[
              const SizedBox(height: 24),
              _buildHierarchySection(theme),
            ],
            const SizedBox(height: 32),
            _buildSaveButton(theme),
          ],
        ),
      ),
    );
  }

  Widget _buildUserInfoSection(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(20),
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
              Icon(
                Icons.person_outline,
                color: theme.colorScheme.primary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'User Information',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          TextFormField(
            initialValue: _userToEdit!.email,
            readOnly: true,
            decoration: InputDecoration(
              labelText: 'Email Address',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              prefixIcon: const Icon(Icons.email_outlined),
              filled: true,
              fillColor: Colors.grey.shade50,
            ),
          ),

          const SizedBox(height: 16),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _isApproved ? Colors.green.shade50 : Colors.orange.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: _isApproved
                    ? Colors.green.shade200
                    : Colors.orange.shade200,
              ),
            ),
            child: SwitchListTile(
              title: const Text('Account Status'),
              subtitle: Text(_isApproved ? 'Approved' : 'Pending approval'),
              value: _isApproved,
              onChanged: (value) => setState(() => _isApproved = value),
              secondary: Icon(
                _isApproved ? Icons.check_circle : Icons.pending,
                color: _isApproved ? Colors.green : Colors.orange,
              ),
              contentPadding: EdgeInsets.zero,
              activeColor: Colors.green,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoleSection(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(20),
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
              Icon(
                Icons.admin_panel_settings_outlined,
                color: theme.colorScheme.primary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Role Assignment',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          DropdownButtonFormField<UserRole>(
            value: _selectedRole,
            decoration: InputDecoration(
              labelText: 'User Role',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              prefixIcon: const Icon(Icons.person_outline),
            ),
            items: UserRole.values
                .map(
                  (role) => DropdownMenuItem(
                    value: role,
                    child: Row(
                      children: [
                        Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: _getRoleColor(role),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Icon(
                            _getRoleIcon(role),
                            color: Colors.white,
                            size: 14,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(_getRoleDisplayName(role)),
                      ],
                    ),
                  ),
                )
                .toList(),
            onChanged: (newValue) {
              setState(() {
                _selectedRole = newValue!;
                _clearHierarchySelections();
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildHierarchySection(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(20),
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
              Icon(
                Icons.account_tree_outlined,
                color: theme.colorScheme.primary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Hierarchy Assignment',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Build hierarchy dropdowns based on role
          ...(_buildHierarchyDropdowns(theme)),
        ],
      ),
    );
  }

  List<Widget> _buildHierarchyDropdowns(ThemeData theme) {
    List<Widget> dropdowns = [];

    // Add dropdowns based on selected role
    if ([
      UserRole.zoneManager,
      UserRole.circleManager,
      UserRole.divisionManager,
      UserRole.subdivisionManager,
      UserRole.substationUser,
    ].contains(_selectedRole)) {
      dropdowns.add(
        _buildHierarchyDropdown<Zone>(
          label: 'Zone',
          collection: 'zones',
          value: _selectedZoneId,
          onChanged: (value) => setState(() {
            _selectedZoneId = value;
            _selectedCircleId = null;
            _selectedDivisionId = null;
            _selectedSubdivisionId = null;
            _selectedSubstationId = null;
          }),
          fromFirestore: Zone.fromFirestore,
          isRequired: _selectedRole == UserRole.zoneManager,
        ),
      );

      // Add Circle dropdown if zone is selected or role needs it
      if (_selectedZoneId != null ||
          [
            UserRole.circleManager,
            UserRole.divisionManager,
            UserRole.subdivisionManager,
            UserRole.substationUser,
          ].contains(_selectedRole)) {
        dropdowns.add(
          _buildHierarchyDropdown<Circle>(
            label: 'Circle',
            collection: 'circles',
            value: _selectedCircleId,
            onChanged: (value) => setState(() {
              _selectedCircleId = value;
              _selectedDivisionId = null;
              _selectedSubdivisionId = null;
              _selectedSubstationId = null;
            }),
            fromFirestore: Circle.fromFirestore,
            isRequired: _selectedRole == UserRole.circleManager,
            parentField: 'zoneId',
            parentValue: _selectedZoneId,
          ),
        );
      }

      // Add Division dropdown
      if (_selectedCircleId != null ||
          [
            UserRole.divisionManager,
            UserRole.subdivisionManager,
            UserRole.substationUser,
          ].contains(_selectedRole)) {
        dropdowns.add(
          _buildHierarchyDropdown<Division>(
            label: 'Division',
            collection: 'divisions',
            value: _selectedDivisionId,
            onChanged: (value) => setState(() {
              _selectedDivisionId = value;
              _selectedSubdivisionId = null;
              _selectedSubstationId = null;
            }),
            fromFirestore: Division.fromFirestore,
            isRequired: _selectedRole == UserRole.divisionManager,
            parentField: 'circleId',
            parentValue: _selectedCircleId,
          ),
        );
      }

      // Add Subdivision dropdown
      if (_selectedDivisionId != null ||
          [
            UserRole.subdivisionManager,
            UserRole.substationUser,
          ].contains(_selectedRole)) {
        dropdowns.add(
          _buildHierarchyDropdown<Subdivision>(
            label: 'Subdivision',
            collection: 'subdivisions',
            value: _selectedSubdivisionId,
            onChanged: (value) => setState(() {
              _selectedSubdivisionId = value;
              _selectedSubstationId = null;
            }),
            fromFirestore: Subdivision.fromFirestore,
            isRequired: _selectedRole == UserRole.subdivisionManager,
            parentField: 'divisionId',
            parentValue: _selectedDivisionId,
          ),
        );
      }

      // Add Substation dropdown for substation users
      if (_selectedSubdivisionId != null &&
          _selectedRole == UserRole.substationUser) {
        dropdowns.add(
          _buildHierarchyDropdown<Substation>(
            label: 'Substation',
            collection: 'substations',
            value: _selectedSubstationId,
            onChanged: (value) => setState(() {
              _selectedSubstationId = value;
            }),
            fromFirestore: Substation.fromFirestore,
            isRequired: true,
            parentField: 'subdivisionId',
            parentValue: _selectedSubdivisionId,
          ),
        );
      }
    }

    return dropdowns;
  }

  Widget _buildHierarchyDropdown<T extends HierarchyItem>({
    required String label,
    required String collection,
    required String? value,
    required Function(String?) onChanged,
    required T Function(DocumentSnapshot) fromFirestore,
    bool isRequired = false,
    String? parentField,
    String? parentValue,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: StreamBuilder<QuerySnapshot>(
        stream: _buildHierarchyQuery(collection, parentField, parentValue),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return DropdownButtonFormField<String>(
              decoration: InputDecoration(
                labelText: 'Loading $label...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              items: const [],
              onChanged: null,
            );
          }

          final items = snapshot.data!.docs
              .map((doc) => fromFirestore(doc))
              .toList();

          return DropdownButtonFormField<String>(
            value: value,
            decoration: InputDecoration(
              labelText: label,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              prefixIcon: Icon(_getHierarchyIcon(label)),
            ),
            items: items
                .map(
                  (item) =>
                      DropdownMenuItem(value: item.id, child: Text(item.name)),
                )
                .toList(),
            onChanged: onChanged,
            validator: isRequired ? (v) => v == null ? 'Required' : null : null,
          );
        },
      ),
    );
  }

  IconData _getHierarchyIcon(String label) {
    switch (label.toLowerCase()) {
      case 'zone':
        return Icons.domain;
      case 'circle':
        return Icons.circle_outlined;
      case 'division':
        return Icons.corporate_fare;
      case 'subdivision':
        return Icons.apartment;
      case 'substation':
        return Icons.electrical_services;
      default:
        return Icons.location_on_outlined;
    }
  }

  Stream<QuerySnapshot> _buildHierarchyQuery(
    String collection,
    String? parentField,
    String? parentValue,
  ) {
    Query query = FirebaseFirestore.instance.collection(collection);
    if (parentField != null && parentValue != null) {
      query = query.where(parentField, isEqualTo: parentValue);
    }
    return query.orderBy('name').snapshots();
  }

  Widget _buildSaveButton(ThemeData theme) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton(
        onPressed: _isSaving ? null : _saveUserChanges,
        style: ElevatedButton.styleFrom(
          backgroundColor: theme.colorScheme.primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
            : const Text(
                'Save Changes',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
              ),
      ),
    );
  }

  // Helper methods - FIXED all UnimplementedError issues
  Color _getRoleColor(UserRole role) {
    switch (role) {
      case UserRole.admin:
        return Colors.red.shade700;
      case UserRole.superAdmin:
        return Colors.deepPurple.shade700;
      case UserRole.stateManager:
        return Colors.indigo.shade700;
      case UserRole.companyManager:
        return Colors.blue.shade700;
      case UserRole.zoneManager:
        return Colors.cyan.shade700;
      case UserRole.circleManager:
        return Colors.green.shade700;
      case UserRole.divisionManager:
        return Colors.orange.shade700;
      case UserRole.subdivisionManager:
        return Colors.purple.shade700;
      case UserRole.substationUser:
        return Colors.teal.shade700;
      case UserRole.pending:
        return Colors.grey.shade700;
    }
  }

  IconData _getRoleIcon(UserRole role) {
    switch (role) {
      case UserRole.admin:
        return Icons.admin_panel_settings;
      case UserRole.superAdmin:
        return Icons.supervisor_account;
      case UserRole.stateManager:
        return Icons.map;
      case UserRole.companyManager:
        return Icons.business;
      case UserRole.zoneManager:
        return Icons.domain;
      case UserRole.circleManager:
        return Icons.circle;
      case UserRole.divisionManager:
        return Icons.corporate_fare;
      case UserRole.subdivisionManager:
        return Icons.apartment;
      case UserRole.substationUser:
        return Icons.electrical_services;
      case UserRole.pending:
        return Icons.hourglass_empty;
    }
  }

  String _getRoleDisplayName(UserRole role) {
    switch (role) {
      case UserRole.admin:
        return 'Administrator';
      case UserRole.superAdmin:
        return 'Super Administrator';
      case UserRole.stateManager:
        return 'State Manager';
      case UserRole.companyManager:
        return 'Company Manager';
      case UserRole.zoneManager:
        return 'Zone Manager';
      case UserRole.circleManager:
        return 'Circle Manager';
      case UserRole.divisionManager:
        return 'Division Manager';
      case UserRole.subdivisionManager:
        return 'Subdivision Manager';
      case UserRole.substationUser:
        return 'Substation User';
      case UserRole.pending:
        return 'Pending Approval';
    }
  }

  String _getAssignmentText(Map<String, dynamic> assignments) {
    if (assignments.isEmpty) return 'No assignments';

    List<String> parts = [];
    if (assignments['zoneId'] != null) parts.add('Zone');
    if (assignments['circleId'] != null) parts.add('Circle');
    if (assignments['divisionId'] != null) parts.add('Division');
    if (assignments['subdivisionId'] != null) parts.add('Subdivision');
    if (assignments['substationId'] != null) parts.add('Substation');

    return parts.isNotEmpty
        ? 'Assigned to: ${parts.join(' → ')}'
        : 'No assignments';
  }

  bool _isManagerRole(UserRole role) {
    return [
      UserRole.stateManager,
      UserRole.companyManager,
      UserRole.zoneManager,
      UserRole.circleManager,
      UserRole.divisionManager,
      UserRole.subdivisionManager,
      UserRole.substationUser,
    ].contains(role);
  }

  void _showListView() {
    setState(() {
      _showForm = false;
      _userToEdit = null;
      _clearHierarchySelections();
    });
  }

  void _showEditForm(AppUser user) {
    setState(() {
      _showForm = true;
      _userToEdit = user;
      _selectedRole = user.role;
      _isApproved = user.approved;
      _assignedLevels = user.assignedLevels != null
          ? Map<String, dynamic>.from(user.assignedLevels!)
          : {};

      // Initialize hierarchy selections
      _selectedZoneId = _assignedLevels!['zoneId'];
      _selectedCircleId = _assignedLevels!['circleId'];
      _selectedDivisionId = _assignedLevels!['divisionId'];
      _selectedSubdivisionId = _assignedLevels!['subdivisionId'];
      _selectedSubstationId = _assignedLevels!['substationId'];
    });
  }

  void _clearHierarchySelections() {
    _selectedZoneId = null;
    _selectedCircleId = null;
    _selectedDivisionId = null;
    _selectedSubdivisionId = null;
    _selectedSubstationId = null;
    _assignedLevels = {};
  }

  Future<void> _saveUserChanges() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      // Prepare assigned levels based on role and selections
      _assignedLevels = {};

      if (_selectedZoneId != null)
        _assignedLevels!['zoneId'] = _selectedZoneId!;
      if (_selectedCircleId != null)
        _assignedLevels!['circleId'] = _selectedCircleId!;
      if (_selectedDivisionId != null)
        _assignedLevels!['divisionId'] = _selectedDivisionId!;
      if (_selectedSubdivisionId != null)
        _assignedLevels!['subdivisionId'] = _selectedSubdivisionId!;
      if (_selectedSubstationId != null)
        _assignedLevels!['substationId'] = _selectedSubstationId!;

      await FirebaseFirestore.instance
          .collection('users')
          .doc(_userToEdit!.uid)
          .update({
            'role': _selectedRole.toString().split('.').last,
            'approved': _isApproved,
            'assignedLevels': _assignedLevels,
            'updatedAt': FieldValue.serverTimestamp(),
          });

      if (mounted) {
        SnackBarUtils.showSnackBar(context, 'User updated successfully!');
        _showListView();
      }
    } catch (e) {
      if (mounted) {
        SnackBarUtils.showSnackBar(
          context,
          'Failed to update user: $e',
          isError: true,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _deleteUser(String userId, String email) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete User'),
        content: Text(
          'Are you sure you want to delete user "$email"?\n\nThis action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .delete();

        if (mounted) {
          SnackBarUtils.showSnackBar(context, 'User deleted successfully!');
        }
      } catch (e) {
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
}
