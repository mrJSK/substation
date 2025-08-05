// lib/widgets/energy_movement_controls_widget.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:collection/collection.dart';

import '../controllers/sld_controller.dart';
import '../enums/movement_mode.dart';
import '../utils/snackbar_utils.dart';

class EnergyMovementControlsWidget extends StatelessWidget {
  final VoidCallback onSave;
  final bool isViewingSavedSld;

  const EnergyMovementControlsWidget({
    super.key,
    required this.onSave,
    required this.isViewingSavedSld,
  });

  @override
  Widget build(BuildContext context) {
    if (isViewingSavedSld) return const SizedBox.shrink();

    final sldController = Provider.of<SldController>(context);
    final selectedBayId = sldController.selectedBayForMovementId;

    if (selectedBayId == null) return const SizedBox.shrink();

    final selectedBay = sldController.baysMap[selectedBayId];
    if (selectedBay == null) return const SizedBox.shrink();

    final selectedBayRenderData = sldController.bayRenderDataList
        .firstWhereOrNull((data) => data.bay.id == selectedBayId);
    if (selectedBayRenderData == null) return const SizedBox.shrink();

    return Container(
      decoration: BoxDecoration(
        color: Colors.blueGrey.shade800,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildHeader(selectedBay),
              const SizedBox(height: 16),
              _buildModeSelector(sldController),
              const SizedBox(height: 16),
              _buildMovementControls(sldController),
              if (sldController.movementMode == MovementMode.energyText) ...[
                const SizedBox(height: 16),
                _buildEnergyTextControls(selectedBayRenderData, sldController),
              ],
              const SizedBox(height: 16),
              _buildActionButtons(context, sldController),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(dynamic selectedBay) {
    return Text(
      'Adjusting: ${selectedBay.name}',
      style: const TextStyle(
        color: Colors.white,
        fontSize: 16,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _buildModeSelector(SldController sldController) {
    return SegmentedButton<MovementMode>(
      segments: const [
        ButtonSegment(
          value: MovementMode.bay,
          label: Text('Move Bay'),
          icon: Icon(Icons.open_with, size: 16),
        ),
        ButtonSegment(
          value: MovementMode.text,
          label: Text('Move Name'),
          icon: Icon(Icons.text_fields, size: 16),
        ),
        ButtonSegment(
          value: MovementMode.energyText,
          label: Text('Move Readings'),
          icon: Icon(Icons.format_list_numbered, size: 16),
        ),
      ],
      selected: {sldController.movementMode},
      onSelectionChanged: (newSelection) {
        sldController.setMovementMode(newSelection.first);
      },
      style: ButtonStyle(
        foregroundColor: MaterialStateProperty.resolveWith((states) {
          return states.contains(MaterialState.selected)
              ? Colors.blue.shade900
              : Colors.blue.shade100;
        }),
        backgroundColor: MaterialStateProperty.resolveWith((states) {
          return states.contains(MaterialState.selected)
              ? Colors.white
              : Colors.blue.shade700;
        }),
      ),
    );
  }

  Widget _buildMovementControls(SldController sldController) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blueGrey.shade700,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildDirectionButton(
            Icons.arrow_back,
            () => sldController.moveSelectedItem(-5.0, 0),
          ),
          const SizedBox(width: 16),
          Column(
            children: [
              _buildDirectionButton(
                Icons.arrow_upward,
                () => sldController.moveSelectedItem(0, -5.0),
              ),
              const SizedBox(height: 8),
              _buildDirectionButton(
                Icons.arrow_downward,
                () => sldController.moveSelectedItem(0, 5.0),
              ),
            ],
          ),
          const SizedBox(width: 16),
          _buildDirectionButton(
            Icons.arrow_forward,
            () => sldController.moveSelectedItem(5.0, 0),
          ),
        ],
      ),
    );
  }

  Widget _buildDirectionButton(IconData icon, VoidCallback onPressed) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.blue.shade600,
        borderRadius: BorderRadius.circular(6),
      ),
      child: IconButton(
        icon: Icon(icon, color: Colors.white),
        onPressed: onPressed,
        constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
      ),
    );
  }

  Widget _buildEnergyTextControls(
    dynamic selectedBayRenderData,
    SldController sldController,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blueGrey.shade700,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          const Text(
            'Energy Reading Font Size',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.remove, color: Colors.white),
                onPressed: () =>
                    sldController.adjustEnergyReadingFontSize(-0.5),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.blueGrey.shade600,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  selectedBayRenderData.energyReadingFontSize.toStringAsFixed(
                    1,
                  ),
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add, color: Colors.white),
                onPressed: () => sldController.adjustEnergyReadingFontSize(0.5),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('Bold Text', style: TextStyle(color: Colors.white)),
              const SizedBox(width: 12),
              Switch(
                value: selectedBayRenderData.energyReadingIsBold,
                onChanged: (value) => sldController.toggleEnergyReadingBold(),
                activeColor: Colors.blue.shade300,
                inactiveThumbColor: Colors.grey.shade400,
                inactiveTrackColor: Colors.grey.shade700,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(
    BuildContext context,
    SldController sldController,
  ) {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () async {
              final success = await sldController
                  .saveSelectedBayLayoutChanges();
              if (context.mounted) {
                if (success) {
                  SnackBarUtils.showSnackBar(
                    context,
                    'Layout changes saved successfully!',
                  );
                  onSave();
                } else {
                  SnackBarUtils.showSnackBar(
                    context,
                    'Failed to save layout changes.',
                    isError: true,
                  );
                }
              }
            },
            icon: const Icon(Icons.save),
            label: const Text('Save Changes'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green.shade600,
              foregroundColor: Colors.white,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () {
              sldController.cancelLayoutChanges();
              SnackBarUtils.showSnackBar(context, 'Changes cancelled.');
            },
            icon: const Icon(Icons.cancel),
            label: const Text('Cancel'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
            ),
          ),
        ),
      ],
    );
  }
}
