// lib/screens/admin/bay_relationship_management_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dropdown_search/dropdown_search.dart';

import '../../models/hierarchy_models.dart';
import '../../models/bay_model.dart';
import '../../models/bay_relationships_model.dart';
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
  List<BayRelationship> _relationships = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchSubstations();
  }

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
    });

    try {
      final baySnapshot = await FirebaseFirestore.instance
          .collection('bays')
          .where('substationId', isEqualTo: substation.id)
          .get();
      _baysInSubstation = baySnapshot.docs
          .map((doc) => Bay.fromFirestore(doc))
          .toList();

      final relationshipSnapshot = await FirebaseFirestore.instance
          .collection('bay_relationships')
          .where('substationId', isEqualTo: substation.id)
          .get();
      _relationships = relationshipSnapshot.docs
          .map((doc) => BayRelationship.fromFirestore(doc))
          .toList();
    } catch (e) {
      SnackBarUtils.showSnackBar(
        context,
        'Error fetching data: $e',
        isError: true,
      );
    }

    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Bay Relationship Management')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: DropdownSearch<Substation>(
              items: _substations,
              itemAsString: (Substation s) => '${s.voltageLevel} - ${s.name}',
              onChanged: _onSubstationSelected,
              selectedItem: _selectedSubstation,
              popupProps: PopupProps.menu(showSearchBox: true),
              dropdownDecoratorProps: const DropDownDecoratorProps(
                dropdownSearchDecoration: InputDecoration(
                  labelText: "Select Substation",
                  hintText: "Choose the substation to manage",
                ),
              ),
            ),
          ),
          if (_isLoading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else if (_selectedSubstation != null)
            Expanded(
              child: ListView(
                children: _relationships
                    .map((rel) => _buildRelationshipCard(rel))
                    .toList(),
              ),
            ),
        ],
      ),
      floatingActionButton: _selectedSubstation != null
          ? FloatingActionButton.extended(
              onPressed: () => _showRelationshipDialog(),
              label: const Text('Add Relationship'),
              icon: const Icon(Icons.add),
            )
          : null,
    );
  }

  Widget _buildRelationshipCard(BayRelationship relationship) {
    final transformer = _baysInSubstation.firstWhere(
      (b) => b.id == relationship.transformerBayId,
      orElse: () => Bay(
        id: '',
        name: 'Unknown',
        substationId: '',
        voltageLevel: '',
        bayType: '',
        createdBy: '',
        createdAt: Timestamp.now(),
      ),
    );
    final incoming = _baysInSubstation.firstWhere(
      (b) => b.id == relationship.incomingBayId,
      orElse: () => Bay(
        id: '',
        name: 'Unknown',
        substationId: '',
        voltageLevel: '',
        bayType: '',
        createdBy: '',
        createdAt: Timestamp.now(),
      ),
    );
    final outgoing = relationship.outgoingBayIds
        .map(
          (id) => _baysInSubstation.firstWhere(
            (b) => b.id == id,
            orElse: () => Bay(
              id: '',
              name: 'Unknown',
              substationId: '',
              voltageLevel: '',
              bayType: '',
              createdBy: '',
              createdAt: Timestamp.now(),
            ),
          ),
        )
        .toList();

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Transformer: ${transformer.name}",
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              "Incoming: ${incoming.name}",
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text("Outgoing:", style: Theme.of(context).textTheme.titleMedium),
            ...outgoing.map((bay) => Text("- ${bay.name}")),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: () =>
                      _showRelationshipDialog(relationship: relationship),
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () => _deleteRelationship(relationship.id!),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteRelationship(String id) async {
    await FirebaseFirestore.instance
        .collection('bay_relationships')
        .doc(id)
        .delete();
    _onSubstationSelected(_selectedSubstation); // Refresh
  }

  void _showRelationshipDialog({BayRelationship? relationship}) {
    showDialog(
      context: context,
      builder: (context) => _RelationshipDialog(
        currentUser: widget.currentUser,
        substationId: _selectedSubstation!.id,
        bays: _baysInSubstation,
        relationship: relationship,
        onSave: () {
          Navigator.of(context).pop();
          _onSubstationSelected(_selectedSubstation);
        },
      ),
    );
  }
}

class _RelationshipDialog extends StatefulWidget {
  final AppUser currentUser;
  final String substationId;
  final List<Bay> bays;
  final BayRelationship? relationship;
  final VoidCallback onSave;

  const _RelationshipDialog({
    required this.currentUser,
    required this.substationId,
    required this.bays,
    this.relationship,
    required this.onSave,
  });

  @override
  __RelationshipDialogState createState() => __RelationshipDialogState();
}

class __RelationshipDialogState extends State<_RelationshipDialog> {
  final _formKey = GlobalKey<FormState>();
  Bay? _selectedTransformer;
  Bay? _selectedIncoming;
  List<Bay> _selectedOutgoing = [];
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    if (widget.relationship != null) {
      _selectedTransformer = widget.bays.firstWhere(
        (b) => b.id == widget.relationship!.transformerBayId,
      );
      _selectedIncoming = widget.bays.firstWhere(
        (b) => b.id == widget.relationship!.incomingBayId,
      );
      _selectedOutgoing = widget.relationship!.outgoingBayIds
          .map((id) => widget.bays.firstWhere((b) => b.id == id))
          .toList();
    }
  }

  Future<void> _saveRelationship() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    final newRelationship = BayRelationship(
      substationId: widget.substationId,
      transformerBayId: _selectedTransformer!.id,
      incomingBayId: _selectedIncoming!.id,
      outgoingBayIds: _selectedOutgoing.map((b) => b.id).toList(),
      createdBy: widget.currentUser.uid,
      createdAt: Timestamp.now(),
    );

    try {
      if (widget.relationship == null) {
        await FirebaseFirestore.instance
            .collection('bay_relationships')
            .add(newRelationship.toFirestore());
      } else {
        await FirebaseFirestore.instance
            .collection('bay_relationships')
            .doc(widget.relationship!.id)
            .update(newRelationship.toFirestore());
      }
      widget.onSave();
    } catch (e) {
      SnackBarUtils.showSnackBar(
        context,
        'Error saving relationship: $e',
        isError: true,
      );
    }

    if (mounted) setState(() => _isSaving = false);
  }

  @override
  Widget build(BuildContext context) {
    final transformerBays = widget.bays
        .where((b) => b.bayType == 'Transformer')
        .toList();

    return AlertDialog(
      title: Text(
        widget.relationship == null ? 'Add Relationship' : 'Edit Relationship',
      ),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownSearch<Bay>(
                items: transformerBays,
                itemAsString: (Bay b) => b.name,
                selectedItem: _selectedTransformer,
                onChanged: (Bay? data) =>
                    setState(() => _selectedTransformer = data),
                validator: (v) => v == null ? 'Transformer is required' : null,
                dropdownDecoratorProps: const DropDownDecoratorProps(
                  dropdownSearchDecoration: InputDecoration(
                    labelText: 'Transformer',
                  ),
                ),
                popupProps: PopupProps.menu(showSearchBox: true),
              ),
              const SizedBox(height: 16),
              DropdownSearch<Bay>(
                items: widget.bays,
                itemAsString: (Bay b) => b.name,
                selectedItem: _selectedIncoming,
                onChanged: (Bay? data) =>
                    setState(() => _selectedIncoming = data),
                validator: (v) => v == null ? 'Incoming bay is required' : null,
                dropdownDecoratorProps: const DropDownDecoratorProps(
                  dropdownSearchDecoration: InputDecoration(
                    labelText: 'Incoming Bay',
                  ),
                ),
                popupProps: PopupProps.menu(showSearchBox: true),
              ),
              const SizedBox(height: 16),
              DropdownSearch<Bay>.multiSelection(
                items: widget.bays,
                itemAsString: (Bay b) => b.name,
                selectedItems: _selectedOutgoing,
                onChanged: (List<Bay> data) =>
                    setState(() => _selectedOutgoing = data),
                validator: (v) => v == null || v.isEmpty
                    ? 'At least one outgoing bay is required'
                    : null,
                dropdownDecoratorProps: const DropDownDecoratorProps(
                  dropdownSearchDecoration: InputDecoration(
                    labelText: 'Outgoing Bays',
                  ),
                ),
                popupProps: PopupPropsMultiSelection.menu(showSearchBox: true),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isSaving ? null : _saveRelationship,
          child: const Text('Save'),
        ),
      ],
    );
  }
}
