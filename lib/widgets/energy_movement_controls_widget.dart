// lib/widgets/energy_movement_controls_widget.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:collection/collection.dart';
import '../controllers/sld_controller.dart';
import '../enums/movement_mode.dart';
import '../utils/snackbar_utils.dart';
import '../models/bay_model.dart';
import '../painters/single_line_diagram_painter.dart'; // For BayRenderData

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
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _slideAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic),
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
        _animationController.forward();
        _wasVisible = true;
      } else if (!shouldShow && _wasVisible) {
        _animationController.reverse().then((_) {
          if (!shouldShow) {
            _wasVisible = false;
          }
        });
      }
    });

    if (!shouldShow && !_wasVisible && _animationController.isDismissed) {
      return const SizedBox.shrink();
    }

    final selectedBayId = sldController.selectedBayForMovementId;
    if (selectedBayId == null) return const SizedBox.shrink();

    final selectedBay = sldController.baysMap[selectedBayId];
    if (selectedBay == null) return const SizedBox.shrink();

    final selectedBayRenderData = sldController.bayRenderDataList
        .firstWhereOrNull((data) => data.bay.id == selectedBayId);
    if (selectedBayRenderData == null) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final hasUnsavedChanges = sldController.hasUnsavedChanges();
    final isDarkMode = theme.brightness == Brightness.dark;

    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _slideAnimation.value * 250),
          child: Opacity(
            opacity: _fadeAnimation.value,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isDarkMode
                      ? [
                          Colors.grey.shade900,
                          Colors.blueGrey.shade800.withOpacity(0.95),
                        ]
                      : [Colors.white, Colors.grey.shade50.withOpacity(0.98)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                boxShadow: [
                  BoxShadow(
                    color: isDarkMode
                        ? Colors.black.withOpacity(0.4)
                        : Colors.black.withOpacity(0.15),
                    blurRadius: 12,
                    offset: const Offset(0, -4),
                    spreadRadius: 1,
                  ),
                ],
                border: isDarkMode
                    ? null
                    : Border(
                        top: BorderSide(color: Colors.grey.shade300, width: 1),
                      ),
              ),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Enhanced header with bay info and mode selector
                      _buildEnhancedHeader(
                        selectedBay,
                        sldController,
                        theme,
                        isDarkMode,
                        hasUnsavedChanges,
                      ),
                      const SizedBox(height: 14),

                      // Movement controls and specific controls
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Movement controls
                          _buildEnhancedMovementControls(
                            sldController,
                            theme,
                            isDarkMode,
                          ),
                          const SizedBox(width: 16),

                          // Mode-specific controls
                          Expanded(
                            child: _buildEnhancedModeSpecificControls(
                              selectedBay,
                              selectedBayRenderData,
                              sldController,
                              theme,
                              isDarkMode,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Enhanced action buttons
                      _buildEnhancedActionButtons(
                        context,
                        sldController,
                        theme,
                        isDarkMode,
                        hasUnsavedChanges,
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

  Widget _buildEnhancedHeader(
    Bay selectedBay,
    SldController sldController,
    ThemeData theme,
    bool isDarkMode,
    bool hasUnsavedChanges,
  ) {
    return Row(
      children: [
        // Enhanced bay info with energy data indicator
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isDarkMode
                  ? [
                      Colors.white.withOpacity(0.12),
                      Colors.white.withOpacity(0.08),
                    ]
                  : [Colors.grey.shade100, Colors.grey.shade50],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isDarkMode
                  ? Colors.white.withOpacity(0.2)
                  : Colors.grey.shade200,
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(
                  _getBayIcon(selectedBay.bayType),
                  color: theme.colorScheme.primary,
                  size: 16,
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
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
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.orange.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: Colors.orange.withOpacity(0.4),
                              width: 1,
                            ),
                          ),
                          child: Text(
                            'MODIFIED',
                            style: TextStyle(
                              fontSize: 8,
                              fontWeight: FontWeight.bold,
                              color: Colors.orange.shade700,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${selectedBay.bayType} • ${selectedBay.voltageLevel}',
                    style: TextStyle(
                      color: isDarkMode
                          ? Colors.white.withOpacity(0.7)
                          : Colors.grey.shade600,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              // Energy data indicator (if available)
              if (sldController.bayEnergyData.containsKey(selectedBay.id)) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Icon(
                    Icons.bolt,
                    color: Colors.green.shade600,
                    size: 12,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: 12),

        // Enhanced mode selector
        Expanded(
          child: _buildEnhancedModeSelector(sldController, theme, isDarkMode),
        ),
      ],
    );
  }

  IconData _getBayIcon(String bayType) {
    switch (bayType.toLowerCase()) {
      case 'transformer':
        return Icons.electrical_services;
      case 'line':
        return Icons.linear_scale;
      case 'feeder':
        return Icons.cable;
      case 'busbar':
        return Icons.horizontal_rule;
      default:
        return Icons.square;
    }
  }

  Widget _buildEnhancedModeSelector(
    SldController sldController,
    ThemeData theme,
    bool isDarkMode,
  ) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: isDarkMode
            ? Colors.white.withOpacity(0.08)
            : Colors.grey.shade200,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDarkMode
              ? Colors.white.withOpacity(0.15)
              : Colors.grey.shade300,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          _buildEnhancedModeButton(
            icon: Icons.open_with,
            label: 'Position',
            isSelected: sldController.movementMode == MovementMode.bay,
            onTap: () => sldController.setMovementMode(MovementMode.bay),
            theme: theme,
            isDarkMode: isDarkMode,
          ),
          _buildEnhancedModeButton(
            icon: Icons.text_fields,
            label: 'Label',
            isSelected: sldController.movementMode == MovementMode.text,
            onTap: () => sldController.setMovementMode(MovementMode.text),
            theme: theme,
            isDarkMode: isDarkMode,
          ),
          _buildEnhancedModeButton(
            icon: Icons.format_list_numbered,
            label: 'Energy',
            isSelected: sldController.movementMode == MovementMode.energyText,
            onTap: () => sldController.setMovementMode(MovementMode.energyText),
            theme: theme,
            isDarkMode: isDarkMode,
          ),
        ],
      ),
    );
  }

  Widget _buildEnhancedModeButton({
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
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          decoration: BoxDecoration(
            gradient: isSelected
                ? LinearGradient(
                    colors: isDarkMode
                        ? [Colors.white, Colors.white.withOpacity(0.9)]
                        : [
                            theme.colorScheme.primary,
                            theme.colorScheme.primary.withOpacity(0.8),
                          ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  )
                : null,
            borderRadius: BorderRadius.circular(7),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color:
                          (isDarkMode
                                  ? Colors.white
                                  : theme.colorScheme.primary)
                              .withOpacity(0.3),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
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
              const SizedBox(height: 3),
              Text(
                label,
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
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

  Widget _buildEnhancedMovementControls(
    SldController sldController,
    ThemeData theme,
    bool isDarkMode,
  ) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDarkMode
              ? [Colors.white.withOpacity(0.1), Colors.white.withOpacity(0.05)]
              : [Colors.grey.shade100, Colors.grey.shade50],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDarkMode
              ? Colors.white.withOpacity(0.15)
              : Colors.grey.shade200,
          width: 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Up button
          _buildEnhancedDirectionButton(
            Icons.keyboard_arrow_up,
            () => sldController.moveSelectedItem(0, -5.0),
            theme,
            isDarkMode,
          ),
          const SizedBox(height: 6),
          // Left and Right buttons
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildEnhancedDirectionButton(
                Icons.keyboard_arrow_left,
                () => sldController.moveSelectedItem(-5.0, 0),
                theme,
                isDarkMode,
              ),
              const SizedBox(width: 6),
              _buildEnhancedDirectionButton(
                Icons.keyboard_arrow_right,
                () => sldController.moveSelectedItem(5.0, 0),
                theme,
                isDarkMode,
              ),
            ],
          ),
          const SizedBox(height: 6),
          // Down button
          _buildEnhancedDirectionButton(
            Icons.keyboard_arrow_down,
            () => sldController.moveSelectedItem(0, 5.0),
            theme,
            isDarkMode,
          ),
        ],
      ),
    );
  }

  Widget _buildEnhancedDirectionButton(
    IconData icon,
    VoidCallback onPressed,
    ThemeData theme,
    bool isDarkMode,
  ) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primary,
            theme.colorScheme.primary.withOpacity(0.8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.primary.withOpacity(0.3),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(8),
          child: Icon(icon, color: Colors.white, size: 18),
        ),
      ),
    );
  }

  Widget _buildEnhancedModeSpecificControls(
    Bay selectedBay,
    BayRenderData selectedBayRenderData,
    SldController sldController,
    ThemeData theme,
    bool isDarkMode,
  ) {
    if (sldController.movementMode == MovementMode.energyText) {
      return _buildEnhancedEnergyControls(
        selectedBayRenderData,
        sldController,
        theme,
        isDarkMode,
      );
    } else if (sldController.movementMode == MovementMode.bay &&
        selectedBay.bayType == 'Busbar') {
      return _buildEnhancedBusbarControls(
        selectedBayRenderData,
        sldController,
        theme,
        isDarkMode,
      );
    }
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDarkMode
            ? Colors.white.withOpacity(0.05)
            : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDarkMode
              ? Colors.white.withOpacity(0.1)
              : Colors.grey.shade200,
        ),
      ),
      child: Center(
        child: Text(
          'Use directional controls to position the selected ${selectedBay.bayType.toLowerCase()}',
          style: TextStyle(
            color: isDarkMode
                ? Colors.white.withOpacity(0.7)
                : Colors.grey.shade600,
            fontSize: 12,
            fontStyle: FontStyle.italic,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _buildEnhancedEnergyControls(
    BayRenderData selectedBayRenderData,
    SldController sldController,
    ThemeData theme,
    bool isDarkMode,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDarkMode
              ? [
                  Colors.orange.withOpacity(0.15),
                  Colors.orange.withOpacity(0.08),
                ]
              : [Colors.orange.shade50, Colors.orange.shade50],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.withOpacity(0.3), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Icon(Icons.text_format, color: Colors.orange.shade700, size: 16),
              const SizedBox(width: 6),
              Text(
                'Energy Reading Style',
                style: TextStyle(
                  color: isDarkMode ? Colors.white : Colors.orange.shade700,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Font size controls
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Font Size',
                      style: TextStyle(
                        color: isDarkMode
                            ? Colors.white.withOpacity(0.8)
                            : Colors.grey.shade700,
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        _buildStyledControlButton(
                          Icons.remove,
                          () => sldController.adjustEnergyReadingFontSize(-0.5),
                          theme,
                          isDarkMode,
                          isSmall: true,
                        ),
                        Expanded(
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 8),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: isDarkMode
                                  ? Colors.white.withOpacity(0.1)
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: Colors.orange.withOpacity(0.3),
                              ),
                            ),
                            child: Text(
                              '${selectedBayRenderData.energyReadingFontSize.toStringAsFixed(1)}pt',
                              style: TextStyle(
                                color: isDarkMode
                                    ? Colors.white
                                    : Colors.grey.shade800,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                        _buildStyledControlButton(
                          Icons.add,
                          () => sldController.adjustEnergyReadingFontSize(0.5),
                          theme,
                          isDarkMode,
                          isSmall: true,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),

              // Bold toggle
              Column(
                children: [
                  Text(
                    'Style',
                    style: TextStyle(
                      color: isDarkMode
                          ? Colors.white.withOpacity(0.8)
                          : Colors.grey.shade700,
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 6),
                  GestureDetector(
                    onTap: () => sldController.toggleEnergyReadingBold(),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        gradient: selectedBayRenderData.energyReadingIsBold
                            ? LinearGradient(
                                colors: [
                                  Colors.orange.shade600,
                                  Colors.orange.shade500,
                                ],
                              )
                            : null,
                        color: selectedBayRenderData.energyReadingIsBold
                            ? null
                            : (isDarkMode
                                  ? Colors.white.withOpacity(0.1)
                                  : Colors.white),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: selectedBayRenderData.energyReadingIsBold
                              ? Colors.orange.shade600
                              : Colors.orange.withOpacity(0.3),
                          width: 1.5,
                        ),
                        boxShadow: selectedBayRenderData.energyReadingIsBold
                            ? [
                                BoxShadow(
                                  color: Colors.orange.withOpacity(0.3),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ]
                            : null,
                      ),
                      child: Text(
                        'Bold',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: selectedBayRenderData.energyReadingIsBold
                              ? Colors.white
                              : (isDarkMode
                                    ? Colors.white70
                                    : Colors.grey.shade600),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEnhancedBusbarControls(
    BayRenderData selectedBayRenderData,
    SldController sldController,
    ThemeData theme,
    bool isDarkMode,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDarkMode
              ? [Colors.blue.withOpacity(0.15), Colors.blue.withOpacity(0.08)]
              : [Colors.blue.shade50, Colors.blue.shade50],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.withOpacity(0.3), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Icon(
                Icons.horizontal_rule,
                color: Colors.blue.shade700,
                size: 16,
              ),
              const SizedBox(width: 6),
              Text(
                'Busbar Length',
                style: TextStyle(
                  color: isDarkMode ? Colors.white : Colors.blue.shade700,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Length controls
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildStyledControlButton(
                Icons.remove,
                () => sldController.adjustBusbarLength(-10.0),
                theme,
                isDarkMode,
              ),
              Expanded(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 12),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: isDarkMode
                        ? Colors.white.withOpacity(0.1)
                        : Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.blue.withOpacity(0.3)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.blue.withOpacity(0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    '${selectedBayRenderData.busbarLength.toStringAsFixed(0)} px',
                    style: TextStyle(
                      color: isDarkMode ? Colors.white : Colors.grey.shade800,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              _buildStyledControlButton(
                Icons.add,
                () => sldController.adjustBusbarLength(10.0),
                theme,
                isDarkMode,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStyledControlButton(
    IconData icon,
    VoidCallback onPressed,
    ThemeData theme,
    bool isDarkMode, {
    bool isSmall = false,
  }) {
    final size = isSmall ? 28.0 : 32.0;
    final iconSize = isSmall ? 14.0 : 16.0;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primary.withOpacity(0.8),
            theme.colorScheme.primary.withOpacity(0.6),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: theme.colorScheme.primary.withOpacity(0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.primary.withOpacity(0.2),
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(8),
          child: Icon(icon, color: Colors.white, size: iconSize),
        ),
      ),
    );
  }

  // CORRECTED ACTION BUTTONS - No longer saves individual changes
  Widget _buildEnhancedActionButtons(
    BuildContext context,
    SldController sldController,
    ThemeData theme,
    bool isDarkMode,
    bool hasUnsavedChanges,
  ) {
    return Row(
      children: [
        // Info button showing unsaved changes status
        Expanded(
          flex: 3,
          child: Container(
            height: 42,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: hasUnsavedChanges
                    ? [Colors.orange.shade600, Colors.orange.shade500]
                    : [Colors.blue.shade600, Colors.blue.shade500],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: (hasUnsavedChanges ? Colors.orange : Colors.blue)
                      .withOpacity(0.3),
                  blurRadius: 6,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  // Show info about changes
                  final String message = hasUnsavedChanges
                      ? 'You have unsaved layout changes. Use back button to save or discard changes.'
                      : 'Continue making layout adjustments. Changes will be saved when you exit.';

                  SnackBarUtils.showSnackBar(context, message, isError: false);
                },
                borderRadius: BorderRadius.circular(12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      hasUnsavedChanges ? Icons.edit : Icons.info_outline,
                      color: Colors.white,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        hasUnsavedChanges
                            ? 'Changes Pending'
                            : 'Editing Layout',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),

        // Clear selection button
        Expanded(
          flex: 2,
          child: Container(
            height: 42,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.grey.shade600, Colors.grey.shade500],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.3),
                  blurRadius: 6,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  // Clear selection only, don't save
                  sldController.setSelectedBayForMovement(null);
                  SnackBarUtils.showSnackBar(context, 'Selection cleared');
                },
                borderRadius: BorderRadius.circular(12),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.close, color: Colors.white, size: 18),
                    SizedBox(width: 6),
                    Text(
                      'Done',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
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
