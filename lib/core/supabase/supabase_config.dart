// Public client credentials (safe to ship: access is enforced by RLS).
// Override per environment: flutter run --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_PUBLISHABLE_KEY=...
// Never put the secret / service-role key in the app.
const supabaseUrl = String.fromEnvironment(
  'SUPABASE_URL',
  defaultValue: 'https://ciznlknixpddqwrbvyvc.supabase.co',
);

const supabasePublishableKey = String.fromEnvironment(
  'SUPABASE_PUBLISHABLE_KEY',
  defaultValue: 'sb_publishable_etxteaSAoBtRVvuB0_GuIA_LPba1JlG',
);
