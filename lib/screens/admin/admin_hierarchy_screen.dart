import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../constants/app_constants.dart';
import '../../models/app_state_data.dart';
import '../../models/hierarchy_models.dart';

class AdminHierarchyScreen extends StatefulWidget {
  const AdminHierarchyScreen({super.key});

  @override
  State<AdminHierarchyScreen> createState() => _AdminHierarchyScreenState();
}

class _AdminHierarchyScreenState extends State<AdminHierarchyScreen> {
  final _fs = FirebaseFirestore.instance;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: _buildAppBar(theme),
      floatingActionButton: _buildFab(theme),
      body: _buildBody(theme),
    );
  }

  PreferredSizeWidget _buildAppBar(ThemeData theme) {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      title: Text(
        'Manage Hierarchy',
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

  Widget _buildFab(ThemeData theme) => FloatingActionButton(
    onPressed: () => _showAddBottomSheet(itemType: 'AppScreenState'),
    backgroundColor: theme.colorScheme.primary,
    foregroundColor: Colors.white,
    elevation: 2,
    child: const Icon(Icons.add),
  );

  Widget _buildBody(ThemeData theme) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: _buildHierarchyList(theme),
      ),
    );
  }

  Widget _buildHierarchyList(ThemeData theme) {
    return StreamBuilder<QuerySnapshot>(
      stream: _fs.collection('appscreenstates').orderBy('name').snapshots(),
      builder: (_, snap) {
        if (snap.hasError) {
          return _buildError(theme, snap.error.toString());
        }
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.data!.docs.isEmpty) return _buildEmptyState(theme);

        final states =
            snap.data!.docs
                .map((doc) => AppScreenState.fromFirestore(doc))
                .toList()
              ..sort((a, b) => a.name.compareTo(b.name));

        return Column(
          children: states
              .map((state) => _buildStateCard(state, theme))
              .toList(),
        );
      },
    );
  }

  Widget _buildStateCard(AppScreenState state, ThemeData theme) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
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
      child: ExpansionTile(
        tilePadding: const EdgeInsets.all(20),
        childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        leading: _iconBox(Icons.map_outlined, theme.colorScheme.primary),
        title: Text(
          state.name,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
        children: [
          _buildActionRow([
            _ActionButton(
              label: 'Edit',
              icon: Icons.edit_outlined,
              color: Colors.blue,
              onPressed: () => _showAddBottomSheet(
                itemType: 'AppScreenState',
                itemToEdit: state,
              ),
            ),
            _ActionButton(
              label: 'Add Company',
              icon: Icons.add,
              color: Colors.green,
              onPressed: () => _showAddBottomSheet(
                itemType: 'Company',
                parentId: state.id,
                parentName: state.name,
              ),
            ),
            _ActionButton(
              label: 'Delete',
              icon: Icons.delete_outline,
              color: Colors.red,
              onPressed: () =>
                  _confirmDelete('appscreenstates', state.id, state.name),
            ),
          ]),
          const SizedBox(height: 16),
          _buildCompaniesForState(state.id, theme),
        ],
      ),
    );
  }

  Widget _buildCompaniesForState(String stateId, ThemeData theme) {
    return StreamBuilder<QuerySnapshot>(
      stream: _fs
          .collection('companys')
          .where('stateId', isEqualTo: stateId)
          .orderBy('name')
          .snapshots(),
      builder: (_, snap) {
        if (!snap.hasData || snap.data!.docs.isEmpty) {
          return _emptyInnerBox(theme, 'No companies added yet');
        }

        final companies = snap.data!.docs
            .map((doc) => Company.fromFirestore(doc))
            .toList();

        return Column(
          children: companies
              .map((company) => _buildCompanyCard(company, theme))
              .toList(),
        );
      },
    );
  }

  Widget _buildCompanyCard(Company company, ThemeData theme) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.shade100),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.all(16),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        leading: _iconBox(Icons.business_outlined, Colors.blue),
        title: Text(
          company.name,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) => _handleCompanyAction(value, company),
          itemBuilder: (_) => [
            const PopupMenuItem(value: 'edit', child: Text('Edit')),
            const PopupMenuItem(value: 'add_zone', child: Text('Add Zone')),
            const PopupMenuItem(value: 'delete', child: Text('Delete')),
          ],
          child: Icon(Icons.more_vert, size: 18, color: Colors.grey.shade600),
        ),
        children: [
          _buildMiniActionRow([
            _MiniActionButton(
              label: 'Add Zone',
              icon: Icons.add_location,
              onPressed: () => _showAddBottomSheet(
                itemType: 'Zone',
                parentId: company.id,
                parentName: company.name,
              ),
            ),
          ]),
          const SizedBox(height: 12),
          _buildZonesForCompany(company.id, theme),
        ],
      ),
    );
  }

  Widget _buildZonesForCompany(String companyId, ThemeData theme) {
    return StreamBuilder<QuerySnapshot>(
      stream: _fs
          .collection('zones')
          .where('companyId', isEqualTo: companyId)
          .orderBy('name')
          .snapshots(),
      builder: (_, snap) {
        if (!snap.hasData || snap.data!.docs.isEmpty) {
          return _emptyInnerBox(theme, 'No zones added yet');
        }

        final zones = snap.data!.docs
            .map((doc) => Zone.fromFirestore(doc))
            .toList();

        return Column(
          children: zones.map((zone) => _buildZoneCard(zone, theme)).toList(),
        );
      },
    );
  }

  Widget _buildZoneCard(Zone zone, ThemeData theme) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.green.shade100),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.all(12),
        childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        leading: _iconBox(Icons.location_on_outlined, Colors.green, size: 16),
        title: Text(
          zone.name,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) => _handleZoneAction(value, zone),
          itemBuilder: (_) => [
            const PopupMenuItem(value: 'edit', child: Text('Edit')),
            const PopupMenuItem(value: 'add_circle', child: Text('Add Circle')),
            const PopupMenuItem(value: 'delete', child: Text('Delete')),
          ],
          child: Icon(Icons.more_vert, size: 18, color: Colors.grey.shade600),
        ),
        children: [
          _buildMiniActionRow([
            _MiniActionButton(
              label: 'Add Circle',
              icon: Icons.add_circle_outline,
              onPressed: () => _showAddBottomSheet(
                itemType: 'Circle',
                parentId: zone.id,
                parentName: zone.name,
              ),
            ),
          ]),
          const SizedBox(height: 8),
          _buildCirclesForZone(zone.id, theme),
        ],
      ),
    );
  }

  Widget _buildCirclesForZone(String zoneId, ThemeData theme) {
    return StreamBuilder<QuerySnapshot>(
      stream: _fs
          .collection('circles')
          .where('zoneId', isEqualTo: zoneId)
          .orderBy('name')
          .snapshots(),
      builder: (_, snap) {
        if (!snap.hasData || snap.data!.docs.isEmpty) {
          return _emptyInnerBox(theme, 'No circles added yet', small: true);
        }

        final circles = snap.data!.docs
            .map((doc) => Circle.fromFirestore(doc))
            .toList();

        return Column(
          children: circles
              .map((circle) => _buildCircleCard(circle, theme))
              .toList(),
        );
      },
    );
  }

  Widget _buildCircleCard(Circle circle, ThemeData theme) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.orange.shade100),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.all(10),
        childrenPadding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
        leading: _iconBox(
          Icons.radio_button_unchecked,
          Colors.orange,
          size: 16,
        ),
        title: Text(
          circle.name,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) => _handleCircleAction(value, circle),
          itemBuilder: (_) => [
            const PopupMenuItem(value: 'edit', child: Text('Edit')),
            const PopupMenuItem(
              value: 'add_division',
              child: Text('Add Division'),
            ),
            const PopupMenuItem(value: 'delete', child: Text('Delete')),
          ],
          child: Icon(Icons.more_vert, size: 18, color: Colors.grey.shade600),
        ),
        children: [
          _buildMiniActionRow([
            _MiniActionButton(
              label: 'Add Division',
              icon: Icons.add,
              onPressed: () => _showAddBottomSheet(
                itemType: 'Division',
                parentId: circle.id,
                parentName: circle.name,
              ),
            ),
          ]),
          const SizedBox(height: 8),
          _buildDivisionsForCircle(circle.id, theme),
        ],
      ),
    );
  }

  Widget _buildDivisionsForCircle(String circleId, ThemeData theme) {
    return StreamBuilder<QuerySnapshot>(
      stream: _fs
          .collection('divisions')
          .where('circleId', isEqualTo: circleId)
          .orderBy('name')
          .snapshots(),
      builder: (_, snap) {
        if (!snap.hasData || snap.data!.docs.isEmpty) {
          return _emptyInnerBox(theme, 'No divisions added yet', small: true);
        }
        final divisions = snap.data!.docs
            .map((d) => Division.fromFirestore(d))
            .toList();
        return Column(
          children: divisions.map((d) => _buildDivisionCard(d, theme)).toList(),
        );
      },
    );
  }

  Widget _buildDivisionCard(Division div, ThemeData theme) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: Colors.purple.shade50,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.purple.shade100),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.all(10),
        childrenPadding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
        leading: _iconBox(Icons.segment, Colors.purple, size: 16),
        title: Text(
          div.name,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (v) => _handleDivisionAction(v, div),
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'edit', child: Text('Edit')),
            PopupMenuItem(value: 'add_sub', child: Text('Add Sub-division')),
            PopupMenuItem(value: 'delete', child: Text('Delete')),
          ],
          child: Icon(Icons.more_vert, size: 18, color: Colors.grey.shade600),
        ),
        children: [
          _buildMiniActionRow([
            _MiniActionButton(
              label: 'Add Sub-division',
              icon: Icons.add,
              onPressed: () => _showAddBottomSheet(
                itemType: 'Subdivision',
                parentId: div.id,
                parentName: div.name,
              ),
            ),
          ]),
          const SizedBox(height: 8),
          _buildSubdivisionsForDivision(div.id, theme),
        ],
      ),
    );
  }

  Widget _buildSubdivisionsForDivision(String divId, ThemeData theme) {
    return StreamBuilder<QuerySnapshot>(
      stream: _fs
          .collection('subdivisions')
          .where('divisionId', isEqualTo: divId)
          .orderBy('name')
          .snapshots(),
      builder: (_, snap) {
        if (!snap.hasData || snap.data!.docs.isEmpty) {
          return _emptyInnerBox(theme, 'No sub-divisions yet', small: true);
        }
        final subs = snap.data!.docs
            .map((d) => Subdivision.fromFirestore(d))
            .toList();
        return Column(
          children: subs.map((s) => _buildSubdivisionCard(s, theme)).toList(),
        );
      },
    );
  }

  Widget _buildSubdivisionCard(Subdivision subd, ThemeData theme) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: Colors.teal.shade50,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.teal.shade100),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.all(10),
        childrenPadding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
        leading: _iconBox(Icons.account_tree, Colors.teal, size: 16),
        title: Text(
          subd.name,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (v) => _handleSubdivisionAction(v, subd),
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'edit', child: Text('Edit')),
            PopupMenuItem(value: 'add_ss', child: Text('Add Sub-station')),
            PopupMenuItem(value: 'delete', child: Text('Delete')),
          ],
          child: Icon(Icons.more_vert, size: 18, color: Colors.grey.shade600),
        ),
        children: [
          _buildMiniActionRow([
            _MiniActionButton(
              label: 'Add Sub-station',
              icon: Icons.add_home_work_outlined,
              onPressed: () => _showAddBottomSheet(
                itemType: 'Substation',
                parentId: subd.id,
                parentName: subd.name,
              ),
            ),
          ]),
          const SizedBox(height: 8),
          _buildSubstationsForSubdivision(subd.id, theme),
        ],
      ),
    );
  }

  Widget _buildSubstationsForSubdivision(String subDivId, ThemeData theme) {
    return StreamBuilder<QuerySnapshot>(
      stream: _fs
          .collection('substations')
          .where('subdivisionId', isEqualTo: subDivId)
          .orderBy('name')
          .snapshots(),
      builder: (_, snap) {
        if (!snap.hasData || snap.data!.docs.isEmpty) {
          return _emptyInnerBox(theme, 'No sub-stations yet', small: true);
        }
        final sss = snap.data!.docs
            .map((d) => Substation.fromFirestore(d))
            .toList();
        return Column(
          children: sss.map((s) => _buildSubstationCard(s, theme)).toList(),
        );
      },
    );
  }

  Widget _buildSubstationCard(Substation substation, ThemeData theme) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: Colors.cyan.shade50,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.cyan.shade100),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.all(10),
        childrenPadding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
        leading: _iconBox(Icons.electrical_services, Colors.cyan, size: 16),
        title: Text(
          substation.name,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (v) => _handleSubstationAction(v, substation),
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'edit', child: Text('Edit')),
            PopupMenuItem(value: 'delete', child: Text('Delete')),
          ],
          child: Icon(Icons.more_vert, size: 18, color: Colors.grey.shade600),
        ),
      ),
    );
  }

  void _handleCompanyAction(String action, Company company) {
    switch (action) {
      case 'edit':
        _showAddBottomSheet(itemType: 'Company', itemToEdit: company);
        break;
      case 'add_zone':
        _showAddBottomSheet(
          itemType: 'Zone',
          parentId: company.id,
          parentName: company.name,
        );
        break;
      case 'delete':
        _confirmDelete('companys', company.id, company.name);
        break;
    }
  }

  void _handleZoneAction(String action, Zone zone) {
    switch (action) {
      case 'edit':
        _showAddBottomSheet(itemType: 'Zone', itemToEdit: zone);
        break;
      case 'add_circle':
        _showAddBottomSheet(
          itemType: 'Circle',
          parentId: zone.id,
          parentName: zone.name,
        );
        break;
      case 'delete':
        _confirmDelete('zones', zone.id, zone.name);
        break;
    }
  }

  void _handleCircleAction(String action, Circle circle) {
    switch (action) {
      case 'edit':
        _showAddBottomSheet(itemType: 'Circle', itemToEdit: circle);
        break;
      case 'add_division':
        _showAddBottomSheet(
          itemType: 'Division',
          parentId: circle.id,
          parentName: circle.name,
        );
        break;
      case 'delete':
        _confirmDelete('circles', circle.id, circle.name);
        break;
    }
  }

  void _handleDivisionAction(String action, Division division) {
    switch (action) {
      case 'edit':
        _showAddBottomSheet(itemType: 'Division', itemToEdit: division);
        break;
      case 'add_sub':
        _showAddBottomSheet(
          itemType: 'Subdivision',
          parentId: division.id,
          parentName: division.name,
        );
        break;
      case 'delete':
        _confirmDelete('divisions', division.id, division.name);
        break;
    }
  }

  void _handleSubdivisionAction(String action, Subdivision subdivision) {
    switch (action) {
      case 'edit':
        _showAddBottomSheet(itemType: 'Subdivision', itemToEdit: subdivision);
        break;
      case 'add_ss':
        _showAddBottomSheet(
          itemType: 'Substation',
          parentId: subdivision.id,
          parentName: subdivision.name,
        );
        break;
      case 'delete':
        _confirmDelete('subdivisions', subdivision.id, subdivision.name);
        break;
    }
  }

  void _handleSubstationAction(String action, Substation substation) {
    switch (action) {
      case 'edit':
        _showAddBottomSheet(itemType: 'Substation', itemToEdit: substation);
        break;
      case 'delete':
        _confirmDelete('substations', substation.id, substation.name);
        break;
    }
  }

  Widget _buildActionRow(List<_ActionButton> buttons) => Row(
    children: buttons
        .map(
          (b) => Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: TextButton.icon(
                onPressed: b.onPressed,
                icon: Icon(b.icon, size: 16),
                label: Text(b.label, style: const TextStyle(fontSize: 12)),
                style: TextButton.styleFrom(
                  foregroundColor: b.color,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                ),
              ),
            ),
          ),
        )
        .toList(),
  );

  Widget _buildMiniActionRow(List<_MiniActionButton> buttons) => Row(
    children: buttons
        .map(
          (b) => TextButton.icon(
            onPressed: b.onPressed,
            icon: Icon(b.icon, size: 14),
            label: Text(b.label, style: const TextStyle(fontSize: 12)),
            style: TextButton.styleFrom(
              foregroundColor: Colors.blue,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            ),
          ),
        )
        .toList(),
  );

  Widget _iconBox(IconData icon, Color color, {double size = 20}) => Container(
    width: size + 8,
    height: size + 8,
    decoration: BoxDecoration(
      color: color.withOpacity(0.1),
      borderRadius: BorderRadius.circular(4),
    ),
    child: Icon(icon, color: color, size: size),
  );

  Widget _emptyInnerBox(ThemeData theme, String text, {bool small = false}) =>
      Container(
        padding: EdgeInsets.all(small ? 8 : 16),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: small ? 12 : 13,
            color: theme.colorScheme.onSurface.withOpacity(0.5),
          ),
        ),
      );

  Widget _buildEmptyState(ThemeData theme) => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.map_outlined,
          size: 64,
          color: theme.colorScheme.onSurface.withOpacity(0.3),
        ),
        const SizedBox(height: 16),
        Text(
          'No states found',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w500,
            color: theme.colorScheme.onSurface.withOpacity(0.6),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Tap the + button to add your first state',
          style: TextStyle(
            fontSize: 14,
            color: theme.colorScheme.onSurface.withOpacity(0.5),
          ),
        ),
      ],
    ),
  );

  Widget _buildError(ThemeData theme, String err) => Center(
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
          'Error loading data',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w500,
            color: theme.colorScheme.error,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          err,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            color: theme.colorScheme.onSurface.withOpacity(0.6),
          ),
        ),
      ],
    ),
  );

  void _showAddBottomSheet({
    required String itemType,
    String? parentId,
    String? parentName,
    HierarchyItem? itemToEdit,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _AddEditHierarchySheet(
        itemType: itemType,
        existingItem: itemToEdit,
        parentId: parentId,
        parentName: parentName,
        onSave: (payload) async {
          late final String coll;
          switch (itemType) {
            case 'AppScreenState':
              coll = 'appscreenstates';
              break;
            case 'Company':
              coll = 'companys';
              break;
            case 'Zone':
              coll = 'zones';
              break;
            case 'Circle':
              coll = 'circles';
              break;
            case 'Division':
              coll = 'divisions';
              break;
            case 'Subdivision':
              coll = 'subdivisions';
              break;
            case 'Substation':
              coll = 'substations';
              break;
            default:
              coll = '';
          }

          if (itemToEdit == null) {
            await _fs.collection(coll).add(payload);
          } else {
            await _fs.collection(coll).doc(itemToEdit.id).update(payload);
          }
          Navigator.pop(context);
        },
      ),
    );
  }

  void _confirmDelete(String collection, String docId, String name) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete item?'),
        content: Text(
          'This will permanently delete "$name" and all its sub-items.',
        ),
        actions: [
          TextButton(
            onPressed: Navigator.of(context).pop,
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.of(context).pop();
              await _fs.collection(collection).doc(docId).delete();
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

class _ActionButton {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onPressed;
  _ActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onPressed,
  });
}

class _MiniActionButton {
  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  _MiniActionButton({
    required this.label,
    required this.icon,
    required this.onPressed,
  });
}

class _AddEditHierarchySheet extends StatefulWidget {
  const _AddEditHierarchySheet({
    required this.itemType,
    required this.onSave,
    this.existingItem,
    this.parentId,
    this.parentName,
  });

  final String itemType;
  final HierarchyItem? existingItem;
  final String? parentId;
  final String? parentName;
  final Future<void> Function(Map<String, dynamic> payload) onSave;

  @override
  State<_AddEditHierarchySheet> createState() => _AddEditHierarchySheetState();
}

class _AddEditHierarchySheetState extends State<_AddEditHierarchySheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtl = TextEditingController();
  final _descCtl = TextEditingController();
  final _addressCtl = TextEditingController();
  final _landmarkCtl = TextEditingController();
  final _contactNumberCtl = TextEditingController();
  final _contactPersonCtl = TextEditingController();
  final _contactDesignationCtl = TextEditingController();
  final _statusDescriptionCtl = TextEditingController();

  final _selectedVoltageLevel = ValueNotifier<String?>(null);
  final _selectedType = ValueNotifier<String?>(null);
  final _selectedSasStatus = ValueNotifier<String?>(null);
  final _selectedSasMake = ValueNotifier<String?>(null);
  final _selectedGeneralStatus = ValueNotifier<String?>(null);
  final _commissioningDate = ValueNotifier<DateTime?>(null);

  @override
  void initState() {
    super.initState();
    final existing = widget.existingItem;

    _nameCtl.text = existing?.name ?? '';
    _descCtl.text = existing?.description ?? '';
    _addressCtl.text = existing?.address ?? '';
    _landmarkCtl.text = existing?.landmark ?? '';
    _contactNumberCtl.text = existing?.contactNumber ?? '';
    _contactPersonCtl.text = existing?.contactPerson ?? '';
    _contactDesignationCtl.text = existing?.contactDesignation ?? '';

    if (existing is Substation) {
      _selectedVoltageLevel.value = existing.voltageLevel;
      _selectedType.value = existing.type;
      _commissioningDate.value = existing.commissioningDate?.toDate();
      if (existing.type == 'SAS') {
        _selectedSasStatus.value = existing.operation;
        _selectedSasMake.value = existing.sasMake;
        _selectedGeneralStatus.value = existing.status ?? 'Active';
        _statusDescriptionCtl.text = existing.statusDescription ?? '';
      }
    } else {
      _selectedType.value = widget.itemType == 'Substation' ? 'Manual' : null;
    }
  }

  @override
  void dispose() {
    _nameCtl.dispose();
    _descCtl.dispose();
    _addressCtl.dispose();
    _landmarkCtl.dispose();
    _contactNumberCtl.dispose();
    _contactPersonCtl.dispose();
    _contactDesignationCtl.dispose();
    _statusDescriptionCtl.dispose();
    _selectedVoltageLevel.dispose();
    _selectedType.dispose();
    _selectedSasStatus.dispose();
    _selectedSasMake.dispose();
    _selectedGeneralStatus.dispose();
    _commissioningDate.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    final isEdit = widget.existingItem != null;
    final title = isEdit ? 'Edit ${widget.itemType}' : 'Add ${widget.itemType}';
    final isSubstation = widget.itemType == 'Substation';

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 10,
            offset: Offset(0, -5),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: bottom + 16,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _HeaderRow(title: title, theme: theme),
              const SizedBox(height: 24),
              Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SectionTitle(title: 'Basic Information', theme: theme),
                    const SizedBox(height: 16),
                    _TextField(
                      controller: _nameCtl,
                      label: 'Name *',
                      theme: theme,
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),
                    _TextField(
                      controller: _descCtl,
                      label: 'Description',
                      theme: theme,
                      maxLines: 2,
                    ),
                    if (isSubstation) ...[
                      const SizedBox(height: 24),
                      _SectionTitle(
                        title: 'Technical Information',
                        theme: theme,
                      ),
                      const SizedBox(height: 16),
                      _Dropdown(
                        valueNotifier: _selectedVoltageLevel,
                        label: 'Voltage Level *',
                        items: AppConstants.voltageLevel,
                        theme: theme,
                        validator: (v) =>
                            v == null ? 'Please select voltage level' : null,
                      ),
                      const SizedBox(height: 16),
                      _Dropdown(
                        valueNotifier: _selectedType,
                        label: 'Type *',
                        items: AppConstants.substationTypes,
                        theme: theme,
                        onChanged: (value) {
                          _selectedType.value = value;
                          if (value != 'SAS') {
                            _selectedSasStatus.value = null;
                            _selectedSasMake.value = null;
                            _selectedGeneralStatus.value = null;
                            _statusDescriptionCtl.clear();
                          }
                        },
                        validator: (v) =>
                            v == null ? 'Please select type' : null,
                      ),
                      const SizedBox(height: 16),
                      _DateField(
                        commissioningDate: _commissioningDate,
                        theme: theme,
                        onTap: _selectCommissioningDate,
                      ),
                      ValueListenableBuilder<String?>(
                        valueListenable: _selectedType,
                        builder: (context, type, _) {
                          if (type != 'SAS') return const SizedBox.shrink();
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 24),
                              _SectionTitle(
                                title: 'SAS Information',
                                theme: theme,
                              ),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  Expanded(
                                    child: _Dropdown(
                                      valueNotifier: _selectedSasStatus,
                                      label: 'SAS Status *',
                                      items: AppConstants.sasStatus,
                                      theme: theme,
                                      validator: (v) => v == null
                                          ? 'Please select SAS status'
                                          : null,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: _Dropdown(
                                      valueNotifier: _selectedSasMake,
                                      label: 'SAS Make *',
                                      items: AppConstants.commonSasMakes,
                                      theme: theme,
                                      validator: (v) => v == null
                                          ? 'Please select SAS make'
                                          : null,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              _Dropdown(
                                valueNotifier: _selectedGeneralStatus,
                                label: 'Overall Status *',
                                items: AppConstants.generalStatus,
                                theme: theme,
                                validator: (v) => v == null
                                    ? 'Please select overall status'
                                    : null,
                              ),
                              const SizedBox(height: 16),
                              _TextField(
                                controller: _statusDescriptionCtl,
                                label: 'Status Description',
                                hint: 'Details about SAS condition and status',
                                theme: theme,
                                maxLines: 2,
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                    const SizedBox(height: 24),
                    _SectionTitle(title: 'Location Information', theme: theme),
                    const SizedBox(height: 16),
                    _TextField(
                      controller: _addressCtl,
                      label: 'Address',
                      theme: theme,
                      maxLines: 2,
                    ),
                    const SizedBox(height: 16),
                    _TextField(
                      controller: _landmarkCtl,
                      label: 'Landmark',
                      theme: theme,
                    ),
                    const SizedBox(height: 24),
                    _SectionTitle(title: 'Contact Information', theme: theme),
                    const SizedBox(height: 16),
                    _TextField(
                      controller: _contactNumberCtl,
                      label: 'Contact Number',
                      theme: theme,
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _TextField(
                            controller: _contactPersonCtl,
                            label: 'Contact Person',
                            theme: theme,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _TextField(
                            controller: _contactDesignationCtl,
                            label: 'Designation',
                            theme: theme,
                          ),
                        ),
                      ],
                    ),
                    if (widget.parentName != null) ...[
                      const SizedBox(height: 24),
                      _ParentInfo(
                        itemType: widget.itemType,
                        parentName: widget.parentName!,
                        theme: theme,
                      ),
                    ],
                    const SizedBox(height: 32),
                    Row(
                      children: [
                        Expanded(child: _CancelButton(theme: theme)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _SaveButton(
                            isEdit: isEdit,
                            theme: theme,
                            onSave: _save,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Extracted Stateless Widgets
class _HeaderRow extends StatelessWidget {
  final String title;
  final ThemeData theme;

  const _HeaderRow({required this.title, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.onSurface,
          ),
        ),
        IconButton(
          onPressed: () => Navigator.pop(context),
          icon: Icon(
            Icons.close,
            size: 20,
            color: theme.colorScheme.onSurface.withOpacity(0.6),
          ),
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final ThemeData theme;

  const _SectionTitle({required this.title, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: theme.colorScheme.primary,
      ),
    );
  }
}

class _TextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final ThemeData theme;
  final String? hint;
  final int maxLines;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;

  const _TextField({
    required this.controller,
    required this.label,
    required this.theme,
    this.hint,
    this.maxLines = 1,
    this.keyboardType,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
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
      maxLines: maxLines,
      keyboardType: keyboardType,
      validator: validator,
      style: TextStyle(fontSize: 14, color: theme.colorScheme.onSurface),
    );
  }
}

class _Dropdown extends StatelessWidget {
  final ValueNotifier<String?> valueNotifier;
  final String label;
  final List<String> items;
  final ThemeData theme;
  final ValueChanged<String?>? onChanged;
  final String? Function(String?)? validator;

  const _Dropdown({
    required this.valueNotifier,
    required this.label,
    required this.items,
    required this.theme,
    this.onChanged,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String?>(
      valueListenable: valueNotifier,
      builder: (context, value, _) {
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
              borderSide: BorderSide(
                color: theme.colorScheme.primary,
                width: 2,
              ),
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
                style: TextStyle(
                  fontSize: 14,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            );
          }).toList(),
          onChanged: onChanged,
          validator: validator,
          style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 14),
          dropdownColor: theme.colorScheme.surface,
          icon: Icon(
            Icons.arrow_drop_down,
            color: theme.colorScheme.onSurface.withOpacity(0.6),
          ),
        );
      },
    );
  }
}

class _DateField extends StatelessWidget {
  final ValueNotifier<DateTime?> commissioningDate;
  final ThemeData theme;
  final VoidCallback onTap;

  const _DateField({
    required this.commissioningDate,
    required this.theme,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<DateTime?>(
      valueListenable: commissioningDate,
      builder: (context, date, _) {
        return InkWell(
          onTap: onTap,
          child: InputDecorator(
            decoration: InputDecoration(
              labelText: 'Commissioning Date',
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
              suffixIcon: Icon(
                Icons.calendar_today,
                size: 18,
                color: theme.colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
            child: Text(
              date != null
                  ? DateFormat('dd/MM/yyyy').format(date)
                  : 'Select Date',
              style: TextStyle(
                fontSize: 14,
                color: date != null
                    ? theme.colorScheme.onSurface
                    : theme.colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ParentInfo extends StatelessWidget {
  final String itemType;
  final String parentName;
  final ThemeData theme;

  const _ParentInfo({
    required this.itemType,
    required this.parentName,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: theme.colorScheme.primaryContainer.withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.account_tree,
                color: theme.colorScheme.primary,
                size: 16,
              ),
              const SizedBox(width: 8),
              Text(
                'Parent ${itemType == 'Substation' ? 'Subdivision' : 'Entity'}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            parentName,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

class _CancelButton extends StatelessWidget {
  final ThemeData theme;

  const _CancelButton({required this.theme});

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: () => Navigator.pop(context),
      style: TextButton.styleFrom(
        foregroundColor: theme.colorScheme.onSurface.withOpacity(0.7),
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: theme.colorScheme.outline.withOpacity(0.3)),
        ),
      ),
      child: const Text(
        'Cancel',
        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
      ),
    );
  }
}

class _SaveButton extends StatelessWidget {
  final bool isEdit;
  final ThemeData theme;
  final Future<void> Function() onSave;

  const _SaveButton({
    required this.isEdit,
    required this.theme,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onSave,
      style: ElevatedButton.styleFrom(
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary,
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        elevation: 2,
      ),
      child: Text(
        isEdit ? 'Update' : 'Create',
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
      ),
    );
  }
}

extension on _AddEditHierarchySheetState {
  Future<void> _selectCommissioningDate() async {
    final theme = Theme.of(context);
    final picked = await showDatePicker(
      context: context,
      initialDate: _commissioningDate.value ?? DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: theme.colorScheme.copyWith(
              primary: theme.colorScheme.primary,
              onPrimary: theme.colorScheme.onPrimary,
              surface: theme.colorScheme.surface,
              onSurface: theme.colorScheme.onSurface,
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: theme.colorScheme.primary,
              ),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != _commissioningDate.value) {
      _commissioningDate.value = picked;
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final now = Timestamp.now();
    final data = <String, dynamic>{
      'name': _nameCtl.text.trim(),
      'description': _descCtl.text.trim().isNotEmpty
          ? _descCtl.text.trim()
          : null,
      'address': _addressCtl.text.trim().isNotEmpty
          ? _addressCtl.text.trim()
          : null,
      'landmark': _landmarkCtl.text.trim().isNotEmpty
          ? _landmarkCtl.text.trim()
          : null,
      'contactNumber': _contactNumberCtl.text.trim().isNotEmpty
          ? _contactNumberCtl.text.trim()
          : null,
      'contactPerson': _contactPersonCtl.text.trim().isNotEmpty
          ? _contactPersonCtl.text.trim()
          : null,
      'contactDesignation': _contactDesignationCtl.text.trim().isNotEmpty
          ? _contactDesignationCtl.text.trim()
          : null,
      'createdAt': widget.existingItem?.createdAt ?? now,
      'createdBy': widget.existingItem?.createdBy ?? '',
    };

    if (widget.itemType == 'Substation') {
      data.addAll({
        'voltageLevel': _selectedVoltageLevel.value,
        'type': _selectedType.value,
        'commissioningDate': _commissioningDate.value != null
            ? Timestamp.fromDate(_commissioningDate.value!)
            : null,
        'cityId': null,
      });

      if (_selectedType.value == 'SAS') {
        data.addAll({
          'operation': _selectedSasStatus.value,
          'sasMake': _selectedSasMake.value,
          'status': _selectedGeneralStatus.value,
          'statusDescription': _statusDescriptionCtl.text.trim().isNotEmpty
              ? _statusDescriptionCtl.text.trim()
              : null,
        });
      } else {
        data.addAll({
          'operation': null,
          'sasMake': null,
          'status': null,
          'statusDescription': null,
        });
      }
    }

    switch (widget.itemType) {
      case 'AppScreenState':
        break;
      case 'Company':
        data['stateId'] =
            widget.parentId ?? (widget.existingItem as Company).stateId;
        break;
      case 'Zone':
        data['companyId'] =
            widget.parentId ?? (widget.existingItem as Zone).companyId;
        break;
      case 'Circle':
        data['zoneId'] =
            widget.parentId ?? (widget.existingItem as Circle).zoneId;
        break;
      case 'Division':
        data['circleId'] =
            widget.parentId ?? (widget.existingItem as Division).circleId;
        break;
      case 'Subdivision':
        data['divisionId'] =
            widget.parentId ?? (widget.existingItem as Subdivision).divisionId;
        break;
      case 'Substation':
        data['subdivisionId'] =
            widget.parentId ??
            (widget.existingItem as Substation).subdivisionId;
        break;
    }

    try {
      await widget.onSave(data);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }
}
