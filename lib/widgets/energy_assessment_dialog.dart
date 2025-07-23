// lib/widgets/energy_assessment_dialog.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import '../utils/snackbar_utils.dart';
import '../models/bay_model.dart';
import '../models/assessment_model.dart';
import '../screens/subdivision_dashboard_tabs/energy_sld_screen.dart'; // To access BayEnergyData

class EnergyAssessmentDialog extends StatefulWidget {
  final Bay bay;
  final AppUser currentUser;
  final BayEnergyData? currentEnergyData;
  final Function() onSaveAssessment;

  const EnergyAssessmentDialog({
    super.key,
    required this.bay,
    required this.currentUser,
    this.currentEnergyData,
    required this.onSaveAssessment,
    Assessment? latestExistingAssessment,
  });

  @override
  State<EnergyAssessmentDialog> createState() => _EnergyAssessmentDialogState();
}

class _EnergyAssessmentDialogState extends State<EnergyAssessmentDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _importAdjustmentController =
      TextEditingController();
  final TextEditingController _exportAdjustmentController =
      TextEditingController();
  final TextEditingController _reasonController = TextEditingController();
  bool _isSaving = false;

  @override
  void dispose() {
    _importAdjustmentController.dispose();
    _exportAdjustmentController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _saveAssessment() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final double? importAdj = double.tryParse(
        _importAdjustmentController.text.trim(),
      );
      final double? exportAdj = double.tryParse(
        _exportAdjustmentController.text.trim(),
      );

      if (importAdj == null && exportAdj == null) {
        if (mounted) {
          SnackBarUtils.showSnackBar(
            context,
            'Please enter a value for either Import or Export Adjustment.',
            isError: true,
          );
        }
        setState(() => _isSaving = false);
        return;
      }

      final newAssessment = Assessment(
        id: FirebaseFirestore.instance.collection('assessments').doc().id,
        substationId: widget.bay.substationId,
        bayId: widget.bay.id,
        assessmentTimestamp: Timestamp.now(),
        importAdjustment: importAdj,
        exportAdjustment: exportAdj,
        reason: _reasonController.text.trim(),
        createdBy: widget.currentUser.uid,
        createdAt: Timestamp.now(),
      );

      await FirebaseFirestore.instance
          .collection('assessments')
          .add(newAssessment.toFirestore());

      if (mounted) {
        SnackBarUtils.showSnackBar(
          context,
          'Energy assessment saved successfully!',
        );
        widget.onSaveAssessment();
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        SnackBarUtils.showSnackBar(
          context,
          'Failed to save assessment: $e',
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Manual Energy Adjustment for ${widget.bay.name}'),
      // Added maxWidth to constrain the dialog, helping with overflow
      content: SizedBox(
        width: MediaQuery.of(context).size.width * 0.8, // Adjust as needed
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Current Calculated Energy:',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      // Use Flexible to prevent overflow
                      child: Text(
                        'Import: ${widget.currentEnergyData?.impConsumed?.toStringAsFixed(2) ?? 'N/A'} MWH',
                        overflow: TextOverflow.ellipsis, // Handle long text
                      ),
                    ),
                    const SizedBox(width: 8), // Add some spacing
                    Flexible(
                      // Use Flexible to prevent overflow
                      child: Text(
                        'Export: ${widget.currentEnergyData?.expConsumed?.toStringAsFixed(2) ?? 'N/A'} MWH',
                        overflow: TextOverflow.ellipsis, // Handle long text
                      ),
                    ),
                  ],
                ),
                const Divider(height: 24),
                Text(
                  'Add Adjustment (e.g., +100 or -50):',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _importAdjustmentController,
                  decoration: const InputDecoration(
                    labelText: 'Import Adjustment (MWH)',
                    prefixIcon: Icon(Icons.arrow_downward),
                    helperText: 'e.g., +100 or -50',
                  ),
                  // FIX: Changed keyboardType to allow signed numbers
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                    signed: true,
                  ),
                  validator: (value) {
                    if (value != null &&
                        value.isNotEmpty &&
                        double.tryParse(value) == null) {
                      return 'Please enter a valid number.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _exportAdjustmentController,
                  decoration: const InputDecoration(
                    labelText: 'Export Adjustment (MWH)',
                    prefixIcon: Icon(Icons.arrow_upward),
                    helperText: 'e.g., +100 or -50',
                  ),
                  // FIX: Changed keyboardType to allow signed numbers
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                    signed: true,
                  ),
                  validator: (value) {
                    if (value != null &&
                        value.isNotEmpty &&
                        double.tryParse(value) == null) {
                      return 'Please enter a valid number.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _reasonController,
                  decoration: const InputDecoration(
                    labelText: 'Reason for Adjustment (Mandatory Note)',
                    prefixIcon: Icon(Icons.edit_note),
                  ),
                  maxLines: 3,
                  validator: (value) =>
                      value!.isEmpty ? 'Reason is mandatory.' : null,
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isSaving ? null : _saveAssessment,
          child: _isSaving
              ? const CircularProgressIndicator(strokeWidth: 2)
              : const Text('Save Assessment'),
        ),
      ],
    );
  }
}
