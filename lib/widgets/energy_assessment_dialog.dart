// lib/widgets/energy_assessment_dialog.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/energy_readings_data.dart';
import '../models/user_model.dart';
import '../utils/snackbar_utils.dart';
import '../models/bay_model.dart';
import '../models/assessment_model.dart';
import '../screens/subdivision_dashboard_tabs/energy_sld_screen.dart';

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
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 0,
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 700),
        decoration: BoxDecoration(
          color: isDarkMode ? Colors.grey.shade900 : Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(theme, isDarkMode),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildCurrentEnergySection(theme, isDarkMode),
                      const SizedBox(height: 24),
                      _buildAdjustmentSection(theme, isDarkMode),
                      const SizedBox(height: 20),
                      _buildReasonSection(theme, isDarkMode),
                    ],
                  ),
                ),
              ),
            ),
            _buildActionButtons(theme, isDarkMode),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme, bool isDarkMode) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primary,
            theme.colorScheme.primary.withOpacity(0.8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.assessment, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Energy Assessment',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${widget.bay.name} • ${widget.bay.voltageLevel}',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.close, color: Colors.white, size: 18),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentEnergySection(ThemeData theme, bool isDarkMode) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.blue.shade50.withOpacity(isDarkMode ? 0.1 : 1.0),
            Colors.blue.shade100.withOpacity(isDarkMode ? 0.05 : 1.0),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.blue.withOpacity(isDarkMode ? 0.3 : 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.electric_meter, color: Colors.blue.shade700, size: 20),
              const SizedBox(width: 8),
              Text(
                'Current Calculated Energy',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: isDarkMode ? Colors.white : Colors.grey.shade800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildEnergyCard(
                  title: 'Import',
                  value:
                      '${widget.currentEnergyData?.impConsumed?.toStringAsFixed(2) ?? 'N/A'} MWH',
                  icon: Icons.arrow_downward,
                  color: Colors.green,
                  isDarkMode: isDarkMode,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildEnergyCard(
                  title: 'Export',
                  value:
                      '${widget.currentEnergyData?.expConsumed?.toStringAsFixed(2) ?? 'N/A'} MWH',
                  icon: Icons.arrow_upward,
                  color: Colors.orange,
                  isDarkMode: isDarkMode,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEnergyCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required bool isDarkMode,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.white.withOpacity(0.05) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
        boxShadow: isDarkMode
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 6),
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: isDarkMode ? Colors.white70 : Colors.grey.shade600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: isDarkMode ? Colors.white : Colors.grey.shade800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdjustmentSection(ThemeData theme, bool isDarkMode) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.tune, color: theme.colorScheme.primary, size: 20),
            const SizedBox(width: 8),
            Text(
              'Manual Adjustments',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: isDarkMode ? Colors.white : Colors.grey.shade800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Enter adjustment values (e.g., +100 or -50)',
          style: TextStyle(
            fontSize: 12,
            color: isDarkMode ? Colors.white60 : Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildStyledTextField(
                controller: _importAdjustmentController,
                label: 'Import Adjustment',
                hint: 'e.g., +100 or -50',
                prefixIcon: Icons.arrow_downward,
                color: Colors.green,
                isDarkMode: isDarkMode,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStyledTextField(
                controller: _exportAdjustmentController,
                label: 'Export Adjustment',
                hint: 'e.g., +100 or -50',
                prefixIcon: Icons.arrow_upward,
                color: Colors.orange,
                isDarkMode: isDarkMode,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildReasonSection(ThemeData theme, bool isDarkMode) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.edit_note, color: theme.colorScheme.primary, size: 20),
            const SizedBox(width: 8),
            Text(
              'Reason for Adjustment',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: isDarkMode ? Colors.white : Colors.grey.shade800,
              ),
            ),
            const SizedBox(width: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'Required',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _reasonController,
          maxLines: 3,
          decoration: InputDecoration(
            hintText: 'Describe the reason for this energy adjustment...',
            hintStyle: TextStyle(
              color: isDarkMode ? Colors.white54 : Colors.grey.shade500,
            ),
            filled: true,
            fillColor: isDarkMode
                ? Colors.white.withOpacity(0.05)
                : Colors.grey.shade50,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: isDarkMode ? Colors.white24 : Colors.grey.shade300,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: isDarkMode ? Colors.white24 : Colors.grey.shade300,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: theme.colorScheme.primary,
                width: 2,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.red),
            ),
            contentPadding: const EdgeInsets.all(16),
          ),
          style: TextStyle(
            color: isDarkMode ? Colors.white : Colors.grey.shade800,
          ),
          validator: (value) => value!.isEmpty ? 'Reason is mandatory.' : null,
        ),
      ],
    );
  }

  Widget _buildStyledTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData prefixIcon,
    required Color color,
    required bool isDarkMode,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(
        decimal: true,
        signed: true,
      ),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        hintStyle: TextStyle(
          color: isDarkMode ? Colors.white54 : Colors.grey.shade500,
          fontSize: 12,
        ),
        prefixIcon: Container(
          margin: const EdgeInsets.all(8),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(prefixIcon, color: color, size: 18),
        ),
        filled: true,
        fillColor: isDarkMode
            ? Colors.white.withOpacity(0.05)
            : Colors.grey.shade50,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: isDarkMode ? Colors.white24 : Colors.grey.shade300,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: isDarkMode ? Colors.white24 : Colors.grey.shade300,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: color, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
      ),
      style: TextStyle(color: isDarkMode ? Colors.white : Colors.grey.shade800),
      validator: (value) {
        if (value != null &&
            value.isNotEmpty &&
            double.tryParse(value) == null) {
          return 'Please enter a valid number.';
        }
        return null;
      },
    );
  }

  Widget _buildActionButtons(ThemeData theme, bool isDarkMode) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDarkMode
            ? Colors.white.withOpacity(0.05)
            : Colors.grey.shade50,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextButton(
              onPressed: () => Navigator.of(context).pop(),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: isDarkMode ? Colors.white24 : Colors.grey.shade300,
                  ),
                ),
              ),
              child: Text(
                'Cancel',
                style: TextStyle(
                  color: isDarkMode ? Colors.white70 : Colors.grey.shade600,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton(
              onPressed: _isSaving ? null : _saveAssessment,
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
                shadowColor: Colors.transparent,
              ),
              child: _isSaving
                  ? const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min, // Added this line
                      children: [
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Saving...',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    )
                  : const Text(
                      'Save Assessment',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center, // Added this line
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
