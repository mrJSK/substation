// lib/widgets/energy_speed_dial_widget.dart

import 'package:flutter/material.dart';
import 'dart:math' as math;

class EnergySpeedDialWidget extends StatefulWidget {
  final bool isViewingSavedSld;
  final bool showTables;
  final VoidCallback onToggleTables;
  final VoidCallback onSaveSld;
  final VoidCallback onSharePdf;
  final VoidCallback onConfigureBusbar;
  final VoidCallback onAddAssessment;

  const EnergySpeedDialWidget({
    super.key,
    required this.isViewingSavedSld,
    required this.showTables,
    required this.onToggleTables,
    required this.onSaveSld,
    required this.onSharePdf,
    required this.onConfigureBusbar,
    required this.onAddAssessment,
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
      ),
      _SpeedDialAction(
        icon: Icons.share_outlined,
        label: 'Share PDF',
        onTap: widget.onSharePdf,
        isEnabled: true,
      ),
      _SpeedDialAction(
        icon: widget.showTables
            ? Icons.visibility_off_outlined
            : Icons.visibility_outlined,
        label: widget.showTables ? 'Hide Tables' : 'Show Tables',
        onTap: widget.onToggleTables,
        isEnabled: true,
      ),
      _SpeedDialAction(
        icon: Icons.settings_input_antenna_outlined,
        label: 'Configure Busbar',
        onTap: widget.onConfigureBusbar,
        isEnabled: !widget.isViewingSavedSld,
      ),
      _SpeedDialAction(
        icon: Icons.assessment_outlined,
        label: 'Add Assessment',
        onTap: widget.onAddAssessment,
        isEnabled: !widget.isViewingSavedSld,
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
                  final delay = index * 0.1;
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
        // Tooltip
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: theme.colorScheme.inverseSurface,
            borderRadius: BorderRadius.circular(4),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Text(
            action.label,
            style: TextStyle(
              color: theme.colorScheme.onInverseSurface,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const SizedBox(width: 12),

        // Action button
        Material(
          elevation: 6,
          shadowColor: Colors.black.withOpacity(0.3),
          borderRadius: BorderRadius.circular(28),
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: action.isEnabled
                  ? theme.colorScheme.surface
                  : theme.colorScheme.surface.withOpacity(0.6),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: theme.colorScheme.outline.withOpacity(0.2),
                width: 1,
              ),
            ),
            child: InkWell(
              onTap: action.isEnabled
                  ? () {
                      _toggle();
                      action.onTap?.call();
                    }
                  : null,
              borderRadius: BorderRadius.circular(20),
              child: Icon(
                action.icon,
                size: 20,
                color: action.isEnabled
                    ? theme.colorScheme.onSurface
                    : theme.colorScheme.onSurface.withOpacity(0.4),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMainFAB(ThemeData theme) {
    return Stack(
      children: [
        // Backdrop/Overlay when open
        if (_isOpen)
          Positioned.fill(
            child: GestureDetector(
              onTap: _toggle,
              child: Container(color: Colors.transparent),
            ),
          ),

        // Main floating action button
        AnimatedBuilder(
          animation: _rotationAnimation,
          builder: (context, child) {
            return Material(
              elevation: 6,
              shadowColor: Colors.black.withOpacity(0.3),
              borderRadius: BorderRadius.circular(28),
              child: Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  borderRadius: BorderRadius.circular(28),
                ),
                child: InkWell(
                  onTap: _toggle,
                  borderRadius: BorderRadius.circular(28),
                  child: Transform.rotate(
                    angle: _rotationAnimation.value * 2 * math.pi,
                    child: Icon(
                      _isOpen ? Icons.close : Icons.add,
                      color: theme.colorScheme.onPrimary,
                      size: 24,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _SpeedDialAction {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool isEnabled;

  _SpeedDialAction({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.isEnabled,
  });
}
