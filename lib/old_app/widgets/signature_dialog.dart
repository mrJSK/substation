import 'package:flutter/material.dart';
import '../models/signature_models.dart';

class SignatureDialog extends StatefulWidget {
  final Function(List<SignatureData>) onSignaturesAdded;
  final List<SignatureData>? existingSignatures;

  const SignatureDialog({
    super.key,
    required this.onSignaturesAdded,
    this.existingSignatures,
  });

  @override
  State<SignatureDialog> createState() => _SignatureDialogState();
}

class _SignatureDialogState extends State<SignatureDialog> {
  final List<SignatureEntry> _signatureEntries = [];
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    // Load existing signatures or start with one empty entry
    if (widget.existingSignatures?.isNotEmpty ?? false) {
      _loadExistingSignatures();
    } else {
      _addEmptySignatureEntry();
    }
  }

  void _loadExistingSignatures() {
    for (var signature in widget.existingSignatures!) {
      _signatureEntries.add(
        SignatureEntry(
          nameController: TextEditingController(text: signature.name),
          designationController: TextEditingController(
            text: signature.designation,
          ),
          departmentController: TextEditingController(
            text: signature.department,
          ),
        ),
      );
    }
  }

  void _addEmptySignatureEntry() {
    setState(() {
      _signatureEntries.add(
        SignatureEntry(
          nameController: TextEditingController(),
          designationController: TextEditingController(),
          departmentController: TextEditingController(text: 'Electrical'),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final bool isDarkMode = theme.brightness == Brightness.dark;

    return Dialog(
      backgroundColor: colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 650,
        height: 600,
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(context),
            const SizedBox(height: 16),
            _buildDescription(context),
            const SizedBox(height: 20),
            _buildSignatureList(context),
            const SizedBox(height: 16),
            _buildActionButtons(context),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: colorScheme.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            Icons.draw_outlined,
            color: colorScheme.primary,
            size: 24,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Add Signatures',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Configure approval signatures for the report',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.close),
          tooltip: 'Close',
        ),
      ],
    );
  }

  Widget _buildDescription(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colorScheme.outline),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: colorScheme.primary, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Add the name and designation of officials who will sign this energy report. You can add multiple signatories as needed.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSignatureList(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;

    return Expanded(
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            Row(
              children: [
                Text(
                  'Signatories (${_signatureEntries.length})',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  ),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: _addEmptySignatureEntry,
                  icon: Icon(Icons.add, size: 18, color: colorScheme.primary),
                  label: Text(
                    'Add Another',
                    style: TextStyle(color: colorScheme.primary),
                  ),
                  style: TextButton.styleFrom(
                    foregroundColor: colorScheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.builder(
                itemCount: _signatureEntries.length,
                itemBuilder: (context, index) {
                  return _buildSignatureEntryCard(context, index);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSignatureEntryCard(BuildContext context, int index) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final bool isDarkMode = theme.brightness == Brightness.dark;
    final entry = _signatureEntries[index];

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Signatory ${index + 1}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const Spacer(),
                if (_signatureEntries.length > 1)
                  IconButton(
                    onPressed: () => _removeSignatureEntry(index),
                    icon: const Icon(Icons.delete_outline, size: 20),
                    tooltip: 'Remove this signatory',
                    style: IconButton.styleFrom(
                      foregroundColor: colorScheme.error,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: entry.nameController,
                    decoration: InputDecoration(
                      labelText: 'Full Name *',
                      hintText: 'Enter signatory name',
                      prefixIcon: const Icon(Icons.person_outline, size: 20),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 16,
                      ),
                      filled: true,
                      fillColor: colorScheme.surfaceVariant,
                      labelStyle: TextStyle(color: colorScheme.onSurface),
                      hintStyle: TextStyle(color: colorScheme.onSurfaceVariant),
                      prefixIconColor: colorScheme.onSurfaceVariant,
                    ),
                    style: TextStyle(color: colorScheme.onSurface),
                    validator: (value) {
                      if (value?.trim().isEmpty ?? true) {
                        return 'Name is required';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: entry.designationController,
                    decoration: InputDecoration(
                      labelText: 'Designation *',
                      hintText: 'e.g., Executive Engineer',
                      prefixIcon: const Icon(Icons.work_outline, size: 20),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 16,
                      ),
                      filled: true,
                      fillColor: colorScheme.surfaceVariant,
                      labelStyle: TextStyle(color: colorScheme.onSurface),
                      hintStyle: TextStyle(color: colorScheme.onSurfaceVariant),
                      prefixIconColor: colorScheme.onSurfaceVariant,
                    ),
                    style: TextStyle(color: colorScheme.onSurface),
                    validator: (value) {
                      if (value?.trim().isEmpty ?? true) {
                        return 'Designation is required';
                      }
                      return null;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: entry.departmentController,
              decoration: InputDecoration(
                labelText: 'Department',
                hintText: 'e.g., Electrical, Operations',
                prefixIcon: const Icon(Icons.business_outlined, size: 20),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 16,
                ),
                filled: true,
                fillColor: colorScheme.surfaceVariant,
                labelStyle: TextStyle(color: colorScheme.onSurface),
                hintStyle: TextStyle(color: colorScheme.onSurfaceVariant),
                prefixIconColor: colorScheme.onSurfaceVariant,
              ),
              style: TextStyle(color: colorScheme.onSurface),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final bool isDarkMode = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.only(top: 16),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: colorScheme.outlineVariant)),
      ),
      child: Row(
        children: [
          TextButton.icon(
            onPressed: _clearAllEntries,
            icon: Icon(Icons.clear_all, size: 18, color: colorScheme.error),
            label: Text(
              'Clear All',
              style: TextStyle(color: colorScheme.error),
            ),
          ),
          const Spacer(),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(color: colorScheme.onSurfaceVariant),
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton.icon(
            onPressed: _saveSignatures,
            icon: Icon(Icons.save, size: 18, color: colorScheme.onPrimary),
            label: Text(
              'Save ${_signatureEntries.length} Signature${_signatureEntries.length != 1 ? 's' : ''}',
              style: TextStyle(color: colorScheme.onPrimary),
            ),
            style: ElevatedButton.styleFrom(
              foregroundColor: colorScheme.onPrimary,
              backgroundColor: colorScheme.primary,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  void _removeSignatureEntry(int index) {
    setState(() {
      _signatureEntries[index].dispose(); // Clean up controllers
      _signatureEntries.removeAt(index);
    });
  }

  void _clearAllEntries() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: Text(
          'Clear All Signatures',
          style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
        ),
        content: Text(
          'Are you sure you want to clear all signature entries? This action cannot be undone.',
          style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                for (var entry in _signatureEntries) {
                  entry.dispose();
                }
                _signatureEntries.clear();
                _addEmptySignatureEntry(); // Always keep at least one entry
              });
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: Text(
              'Clear All',
              style: TextStyle(color: Theme.of(context).colorScheme.onError),
            ),
          ),
        ],
      ),
    );
  }

  void _saveSignatures() {
    if (_formKey.currentState?.validate() ?? false) {
      final signatures = _signatureEntries
          .map((entry) {
            return SignatureData(
              name: entry.nameController.text.trim(),
              designation: entry.designationController.text.trim(),
              department: entry.departmentController.text.trim().isNotEmpty
                  ? entry.departmentController.text.trim()
                  : 'Electrical',
              signedAt: DateTime.now(),
            );
          })
          .where((sig) => sig.name.isNotEmpty && sig.designation.isNotEmpty)
          .toList();

      if (signatures.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Please add at least one valid signature entry.',
            ),
            backgroundColor: Theme.of(context).colorScheme.errorContainer,
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      widget.onSignaturesAdded(signatures);
      Navigator.pop(context);
    }
  }

  @override
  void dispose() {
    // Clean up all controllers
    for (var entry in _signatureEntries) {
      entry.dispose();
    }
    super.dispose();
  }
}

// Helper class to manage signature entry controllers
class SignatureEntry {
  final TextEditingController nameController;
  final TextEditingController designationController;
  final TextEditingController departmentController;

  SignatureEntry({
    required this.nameController,
    required this.designationController,
    required this.departmentController,
  });

  void dispose() {
    nameController.dispose();
    designationController.dispose();
    departmentController.dispose();
  }
}
