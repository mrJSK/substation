abstract final class AppConstants {
  // App meta
  static const appName = 'SubERP';
  static const appVersion = '0.1.0';

  // Org hierarchy levels (matches Supabase org_units.level column)
  static const orgLevelTenant = 0;
  static const orgLevelZone = 1;
  static const orgLevelCircle = 2;
  static const orgLevelDivision = 3;
  static const orgLevelSubdivision = 4;
  static const orgLevelSubstation = 5;
  static const orgLevelBay = 6;

  // Operating limits (IEGC / CEA Safety Regs)
  static const freqNormalMin = 49.9;
  static const freqNormalMax = 50.05;
  static const freqEmergencyMin = 49.0;
  static const transformerWtiAlarm = 90.0;
  static const transformerWtiTrip = 105.0;
  static const transformerOtiAlarm = 85.0;
  static const transformerOtiTrip = 95.0;

  // Energy meter reading time (UPPTCL Reg 8)
  static const energyReadingHour = 8; // 8:00 AM daily

  // PTW
  static const ptwMinLeadHours = 24; // SLDC advance notice for planned outage
  static const ptwMinEarthRods = 3;

  // Pagination
  static const pageSize = 25;
}
