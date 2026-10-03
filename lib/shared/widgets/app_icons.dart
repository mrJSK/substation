import 'package:flutter/material.dart';

/// Maps icon names stored in app_catalog.icon to Material icons.
/// Icons are a closed set in the client; unknown names fall back to [Icons.apps].
const _icons = <String, IconData>{
  'menu_book': Icons.menu_book_outlined,
  'flash_on': Icons.flash_on_outlined,
  'pause_circle': Icons.pause_circle_outline,
  'forum': Icons.forum_outlined,
  'assignment': Icons.assignment_outlined,
  'health_and_safety': Icons.health_and_safety_outlined,
  'build': Icons.build_outlined,
  'report_problem': Icons.report_problem_outlined,
  'event_repeat': Icons.event_repeat_outlined,
  'precision_manufacturing': Icons.precision_manufacturing_outlined,
  'speed': Icons.speed_outlined,
  'balance': Icons.balance_outlined,
  'dashboard': Icons.dashboard_outlined,
  'account_tree': Icons.account_tree_outlined,
  'manage_accounts': Icons.manage_accounts_outlined,
  'admin_panel_settings': Icons.admin_panel_settings_outlined,
  'dynamic_form': Icons.dynamic_form_outlined,
  'history': Icons.history,
  'apps': Icons.apps,
};

IconData appIcon(String name) => _icons[name] ?? Icons.apps;
