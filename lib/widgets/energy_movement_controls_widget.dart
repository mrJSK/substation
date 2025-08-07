// lib/widgets/energy_movement_controls_widget.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:collection/collection.dart';
import '../controllers/sld_controller.dart';
import '../enums/movement_mode.dart';
import '../utils/snackbar_utils.dart';

class EnergyMovementControlsWidget extends StatefulWidget {
  final VoidCallback onSave;
  final bool isViewingSavedSld;

  const EnergyMovementControlsWidget({
    super.key,
    required this.onSave,
    required this.isViewingSavedSld,
  });

  @override
  State<EnergyMovementControlsWidget> createState() =>
      _EnergyMovementControlsWidgetState();
}

class _EnergyMovementControlsWidgetState
    extends State<EnergyMovementControlsWidget>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _slideAnimation;
  late Animation<double> _fadeAnimation;

  bool _wasVisible = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 250),
      vsync: this,
    );

    _slideAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  bool _shouldShowWidget(SldController sldController) {
    if (widget.isViewingSavedSld) return false;

    final selectedBayId = sldController.selectedBayForMovementId;
    if (selectedBayId == null) return false;

    final selectedBay = sldController.baysMap[selectedBayId];
    if (selectedBay == null) return false;

    final selectedBayRenderData = sldController.bayRenderDataList
        .firstWhereOrNull((data) => data.bay.id == selectedBayId);
    return selectedBayRenderData != null;
  }

  @override
  Widget build(BuildContext context) {
    final sldController = Provider.of<SldController>(context);
    final shouldShow = _shouldShowWidget(sldController);

    // Handle animation based on visibility change
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (shouldShow && !_wasVisible) {
        // Show with animation
        _animationController.forward();
        _wasVisible = true;
      } else if (!shouldShow && _wasVisible) {
        // Hide with animation
        _animationController.reverse();
        _wasVisible = false;
      }
    });

    if (!shouldShow && !_wasVisible) {
      return const SizedBox.shrink();
    }

    final selectedBayId = sldController.selectedBayForMovementId!;
    final selectedBay = sldController.baysMap[selectedBayId]!;
    final selectedBayRenderData = sldController.bayRenderDataList.firstWhere(
      (data) => data.bay.id == selectedBayId,
    );

    final theme = Theme.of(context);
    final hasUnsavedChanges = sldController.hasUnsavedChanges();
    final isDarkMode = theme.brightness == Brightness.dark;

    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _slideAnimation.value * 200), // Slide from bottom
          child: Opacity(
            opacity: _fadeAnimation.value,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isDarkMode
                      ? [Colors.grey.shade900, Colors.blueGrey.shade800]
                      : [Colors.white, Colors.grey.shade50],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                boxShadow: [
                  BoxShadow(
                    color: isDarkMode
                        ? Colors.black.withOpacity(0.3)
                        : Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, -2),
                  ),
                ],
                border: isDarkMode
                    ? null
                    : Border(top: BorderSide(color: Colors.grey.shade200)),
              ),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Compact header with bay info and mode selector
                      Row(
                        children: [
                          // Bay info
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: isDarkMode
                                  ? Colors.white.withOpacity(0.1)
                                  : Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.tune,
                                  color: theme.colorScheme.primary,
                                  size: 16,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  selectedBay.name,
                                  style: TextStyle(
                                    color: isDarkMode
                                        ? Colors.white
                                        : Colors.grey.shade800,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                if (hasUnsavedChanges) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    width: 6,
                                    height: 6,
                                    decoration: BoxDecoration(
                                      color: Colors.orange,
                                      borderRadius: BorderRadius.circular(3),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          // Compact mode selector
                          Expanded(
                            child: _buildCompactModeSelector(
                              sldController,
                              theme,
                              isDarkMode,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Movement controls and specific controls in one row
                      Row(
                        children: [
                          // Movement controls
                          _buildCompactMovementControls(
                            sldController,
                            theme,
                            isDarkMode,
                          ),
                          const SizedBox(width: 16),

                          // Mode-specific controls
                          Expanded(
                            child: _buildCompactModeSpecificControls(
                              selectedBay,
                              selectedBayRenderData,
                              sldController,
                              theme,
                              isDarkMode,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Compact action buttons
                      _buildCompactActionButtons(
                        context,
                        sldController,
                        theme,
                        isDarkMode,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCompactModeSelector(
    SldController sldController,
    ThemeData theme,
    bool isDarkMode,
  ) {
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: isDarkMode
            ? Colors.white.withOpacity(0.1)
            : Colors.grey.shade200,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          _buildCompactModeButton(
            icon: Icons.open_with,
            label: 'Bay',
            isSelected: sldController.movementMode == MovementMode.bay,
            onTap: () => sldController.setMovementMode(MovementMode.bay),
            theme: theme,
            isDarkMode: isDarkMode,
          ),
          _buildCompactModeButton(
            icon: Icons.text_fields,
            label: 'Text',
            isSelected: sldController.movementMode == MovementMode.text,
            onTap: () => sldController.setMovementMode(MovementMode.text),
            theme: theme,
            isDarkMode: isDarkMode,
          ),
          _buildCompactModeButton(
            icon: Icons.format_list_numbered,
            label: 'Reading',
            isSelected: sldController.movementMode == MovementMode.energyText,
            onTap: () => sldController.setMovementMode(MovementMode.energyText),
            theme: theme,
            isDarkMode: isDarkMode,
          ),
        ],
      ),
    );
  }

  Widget _buildCompactModeButton({
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    required ThemeData theme,
    required bool isDarkMode,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: isSelected
                ? (isDarkMode ? Colors.white : theme.colorScheme.primary)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 16,
                color: isSelected
                    ? (isDarkMode ? theme.colorScheme.primary : Colors.white)
                    : (isDarkMode ? Colors.white70 : Colors.grey.shade600),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: isSelected
                      ? (isDarkMode ? theme.colorScheme.primary : Colors.white)
                      : (isDarkMode ? Colors.white70 : Colors.grey.shade600),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCompactMovementControls(
    SldController sldController,
    ThemeData theme,
    bool isDarkMode,
  ) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: isDarkMode
            ? Colors.white.withOpacity(0.1)
            : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildCompactDirectionButton(
            Icons.keyboard_arrow_up,
            () => sldController.moveSelectedItem(0, -5.0),
            theme,
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildCompactDirectionButton(
                Icons.keyboard_arrow_left,
                () => sldController.moveSelectedItem(-5.0, 0),
                theme,
              ),
              const SizedBox(width: 4),
              _buildCompactDirectionButton(
                Icons.keyboard_arrow_right,
                () => sldController.moveSelectedItem(5.0, 0),
                theme,
              ),
            ],
          ),
          _buildCompactDirectionButton(
            Icons.keyboard_arrow_down,
            () => sldController.moveSelectedItem(0, 5.0),
            theme,
          ),
        ],
      ),
    );
  }

  Widget _buildCompactDirectionButton(
    IconData icon,
    VoidCallback onPressed,
    ThemeData theme,
  ) {
    return Container(
      width: 32,
      height: 32,
      margin: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary,
        borderRadius: BorderRadius.circular(4),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.primary.withOpacity(0.3),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(4),
          child: Icon(icon, color: Colors.white, size: 16),
        ),
      ),
    );
  }

  Widget _buildCompactModeSpecificControls(
    dynamic selectedBay,
    dynamic selectedBayRenderData,
    SldController sldController,
    ThemeData theme,
    bool isDarkMode,
  ) {
    if (sldController.movementMode == MovementMode.energyText) {
      return _buildCompactEnergyControls(
        selectedBayRenderData,
        sldController,
        theme,
        isDarkMode,
      );
    } else if (sldController.movementMode == MovementMode.bay &&
        selectedBay.bayType == 'Busbar') {
      return _buildCompactBusbarControls(
        selectedBayRenderData,
        sldController,
        theme,
        isDarkMode,
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildCompactEnergyControls(
    dynamic selectedBayRenderData,
    SldController sldController,
    ThemeData theme,
    bool isDarkMode,
  ) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: isDarkMode
            ? Colors.white.withOpacity(0.1)
            : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          // Font size controls
          Expanded(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildTinyButton(
                  Icons.remove,
                  () => sldController.adjustEnergyReadingFontSize(-0.5),
                  theme,
                ),
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 6),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: isDarkMode
                        ? Colors.white.withOpacity(0.2)
                        : Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    selectedBayRenderData.energyReadingFontSize.toStringAsFixed(
                      1,
                    ),
                    style: TextStyle(
                      color: isDarkMode ? Colors.white : Colors.grey.shade800,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                _buildTinyButton(
                  Icons.add,
                  () => sldController.adjustEnergyReadingFontSize(0.5),
                  theme,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Bold toggle
          GestureDetector(
            onTap: () => sldController.toggleEnergyReadingBold(),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: selectedBayRenderData.energyReadingIsBold
                    ? theme.colorScheme.primary.withOpacity(0.2)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: selectedBayRenderData.energyReadingIsBold
                      ? theme.colorScheme.primary
                      : (isDarkMode ? Colors.white38 : Colors.grey.shade400),
                ),
              ),
              child: Text(
                'B',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: selectedBayRenderData.energyReadingIsBold
                      ? theme.colorScheme.primary
                      : (isDarkMode ? Colors.white70 : Colors.grey.shade600),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactBusbarControls(
    dynamic selectedBayRenderData,
    SldController sldController,
    ThemeData theme,
    bool isDarkMode,
  ) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: isDarkMode
            ? Colors.white.withOpacity(0.1)
            : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildTinyButton(
            Icons.remove,
            () => sldController.adjustBusbarLength(-10.0),
            theme,
          ),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 8),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: isDarkMode
                  ? Colors.white.withOpacity(0.2)
                  : Colors.grey.shade200,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              '${selectedBayRenderData.busbarLength.toStringAsFixed(0)}px',
              style: TextStyle(
                color: isDarkMode ? Colors.white : Colors.grey.shade800,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          _buildTinyButton(
            Icons.add,
            () => sldController.adjustBusbarLength(10.0),
            theme,
          ),
        ],
      ),
    );
  }

  Widget _buildTinyButton(
    IconData icon,
    VoidCallback onPressed,
    ThemeData theme,
  ) {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: theme.colorScheme.primary.withOpacity(0.3)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(4),
          child: Icon(icon, color: theme.colorScheme.primary, size: 14),
        ),
      ),
    );
  }

  Widget _buildCompactActionButtons(
    BuildContext context,
    SldController sldController,
    ThemeData theme,
    bool isDarkMode,
  ) {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 36,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.blue.shade600, Colors.blue.shade500],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.blue.withOpacity(0.3),
                  blurRadius: 2,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () async {
                  final success = await sldController
                      .saveSelectedBayLayoutChanges();
                  if (context.mounted) {
                    SnackBarUtils.showSnackBar(
                      context,
                      success ? 'Saved!' : 'Save failed',
                      isError: !success,
                    );
                    // Clear selection after save (will trigger smooth close animation)
                    sldController.setSelectedBayForMovement(null);
                  }
                },
                borderRadius: BorderRadius.circular(8),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.save_outlined, color: Colors.white, size: 16),
                    SizedBox(width: 4),
                    Text(
                      'Save Bay',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Container(
            height: 36,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.grey.shade600, Colors.grey.shade500],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.3),
                  blurRadius: 2,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  // Clear selection (will trigger smooth close animation)
                  sldController.setSelectedBayForMovement(null);
                  SnackBarUtils.showSnackBar(context, 'Selection cleared');
                },
                borderRadius: BorderRadius.circular(8),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.clear, color: Colors.white, size: 16),
                    SizedBox(width: 4),
                    Text(
                      'Clear',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
