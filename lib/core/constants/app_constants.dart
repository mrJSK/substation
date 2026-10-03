// Business limits (WTI/OTI alarms etc.) and hierarchy levels are tenant data
// (ui_forms, org_levels) and must not be hard-coded here.
abstract final class AppConstants {
  static const appName = 'GridERP';
  static const appVersion = '0.1.0';

  // Offline cache lifetimes
  static const accessCacheMaxAge = Duration(days: 7);
  static const catalogCacheMaxAge = Duration(days: 7);
  static const orgTreeCacheMaxAge = Duration(days: 7);

  static const pageSize = 50;
}
