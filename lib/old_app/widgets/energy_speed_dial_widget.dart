// lib/widgets/energy_speed_dial_widget.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Add this import for haptic feedback
import 'dart:math' as math;

class EnergySpeedDialWidget extends StatefulWidget {
  final bool isViewingSavedSld;
  final bool showTables;
  final VoidCallback onToggleTables;
  final VoidCallback onSaveSld;
  final VoidCallback onSharePdf;
  final VoidCallback onConfigureBusbar;
  final VoidCallback onAddAssessment;
  final VoidCallback onAddSignatures; // New callback for signatures

  const EnergySpeedDialWidget({
    super.key,
    required this.isViewingSavedSld,
    required this.showTables,
    required this.onToggleTables,
    required this.onSaveSld,
    required this.onSharePdf,
    required this.onConfigureBusbar,
    required this.onAddAssessment,
    required this.onAddSignatures, // Add this parameter
  });

  @override
  State<EnergySpeedDialWidget> createState() => _EnergySpeedDialWidgetState();
}

class _EnergySpeedDialWidgetState extends State<EnergySpeedDialWidget>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _rotationAnimation;
  bool _isOpen = false;

  List<_SpeedDialAction> _actions = [];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 250),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _rotationAnimation = Tween<double>(
      begin: 0.0,
      end: 0.125,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _setupActions();
  }

  void _setupActions() {
    _actions.clear();

    _actions.addAll([
      _SpeedDialAction(
        icon: Icons.save_outlined,
        label: 'Save SLD',
        onTap: widget.isViewingSavedSld ? null : widget.onSaveSld,
        isEnabled: !widget.isViewingSavedSld,
        color: Colors.blue,
      ),
      _SpeedDialAction(
        icon: Icons.share_outlined,
        label: 'Share PDF',
        onTap: widget.onSharePdf,
        isEnabled: true,
        color: Colors.green,
      ),
      _SpeedDialAction(
        icon: widget.showTables
            ? Icons.visibility_off_outlined
            : Icons.visibility_outlined,
        label: widget.showTables ? 'Hide Tables' : 'Show Tables',
        onTap: widget.onToggleTables,
        isEnabled: true,
        color: Colors.orange,
      ),
      _SpeedDialAction(
        icon: Icons.settings_input_antenna_outlined,
        label: 'Configure Busbar',
        onTap: widget.onConfigureBusbar,
        isEnabled: !widget.isViewingSavedSld,
        color: Colors.purple,
      ),
      _SpeedDialAction(
        icon: Icons.assessment_outlined,
        label: 'Add Assessment',
        onTap: widget.onAddAssessment,
        isEnabled: !widget.isViewingSavedSld,
        color: Colors.red,
      ),
      _SpeedDialAction(
        icon: Icons.draw_outlined,
        label: 'Add Signatures',
        onTap: widget.onAddSignatures, // New signature action
        isEnabled: true, // Always enabled for adding signatures
        color: Colors.teal,
      ),
    ]);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() {
      _isOpen = !_isOpen;
    });

    if (_isOpen) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Positioned(
      bottom: 16,
      right: 16,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Action buttons
          AnimatedBuilder(
            animation: _scaleAnimation,
            builder: (context, child) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: _actions.asMap().entries.map((entry) {
                  final index = entry.key;
                  final action = entry.value;

                  // Staggered animation delay
                  final delay = index * 0.08; // Slightly faster stagger
                  final animationValue = Curves.easeOut.transform(
                    math.max(
                      0.0,
                      (_scaleAnimation.value - delay) / (1.0 - delay),
                    ),
                  );

                  return Transform.scale(
                    scale: animationValue,
                    child: Transform.translate(
                      offset: Offset(0, (1 - animationValue) * 20),
                      child: Opacity(
                        opacity: animationValue,
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: _buildActionButton(action, theme),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),

          // Main FAB
          const SizedBox(height: 8),
          _buildMainFAB(theme),
        ],
      ),
    );
  }

  Widget _buildActionButton(_SpeedDialAction action, ThemeData theme) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Tooltip with enhanced styling
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: theme.colorScheme.inverseSurface,
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Text(
            action.label,
            style: TextStyle(
              color: theme.colorScheme.onInverseSurface,
              fontSize: 13,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.2,
            ),
          ),
        ),
        const SizedBox(width: 12),

        // Use Listener instead of InkWell to avoid gesture conflicts
        Material(
          elevation: action.isEnabled ? 6 : 2,
          shadowColor: action.isEnabled
              ? action.color.withOpacity(0.3)
              : Colors.black.withOpacity(0.1),
          borderRadius: BorderRadius.circular(22),
          child: Listener(
            // Changed from InkWell to Listener
            onPointerDown: action.isEnabled
                ? (_) {
                    _toggle();
                    _triggerHapticFeedback();
                    action.onTap?.call();
                  }
                : null,
            behavior: HitTestBehavior.opaque, // Ensures it consumes the tap
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: action.isEnabled
                    ? action.color.withOpacity(0.9)
                    : theme.colorScheme.surface.withOpacity(0.6),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: action.isEnabled
                      ? action.color.withOpacity(0.3)
                      : theme.colorScheme.outline.withOpacity(0.2),
                  width: 1,
                ),
              ),
              child: Icon(
                action.icon,
                size: 20,
                color: action.isEnabled
                    ? Colors.white
                    : theme.colorScheme.onSurface.withOpacity(0.4),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMainFAB(ThemeData theme) {
    return Material(
      elevation: 8,
      shadowColor: theme.colorScheme.primary.withOpacity(0.4),
      borderRadius: BorderRadius.circular(28),
      child: Listener(
        // Use Listener instead of GestureDetector/InkWell
        onPointerDown: (_) {
          _triggerHapticFeedback();
          _toggle();
        },
        behavior: HitTestBehavior.opaque,
        child: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: theme.colorScheme.primary,
            borderRadius: BorderRadius.circular(28),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                theme.colorScheme.primary,
                theme.colorScheme.primary.withOpacity(0.8),
              ],
            ),
          ),
          child: AnimatedBuilder(
            animation: _rotationAnimation,
            builder: (context, child) {
              return Transform.rotate(
                angle: _rotationAnimation.value * 2 * math.pi,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  transitionBuilder:
                      (Widget child, Animation<double> animation) {
                        return RotationTransition(
                          turns: animation,
                          child: child,
                        );
                      },
                  child: Icon(
                    _isOpen ? Icons.close : Icons.speed,
                    key: ValueKey(_isOpen),
                    color: theme.colorScheme.onPrimary,
                    size: 24,
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  void _triggerHapticFeedback() {
    // Add haptic feedback for better user experience
    try {
      HapticFeedback.lightImpact(); // Now properly implemented
    } catch (e) {
      // Ignore if haptic feedback is not available
      print('Haptic feedback not available: $e');
    }
  }
}

class _SpeedDialAction {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool isEnabled;
  final Color color; // New color property for visual distinction

  _SpeedDialAction({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.isEnabled,
    this.color = Colors.blue, // Default color
  });
}
