// Supabase project credentials — replace with your project values
// Dashboard → Settings → API
const supabaseUrl = String.fromEnvironment(
  'SUPABASE_URL',
  defaultValue: 'https://YOUR_PROJECT_REF.supabase.co',
);

const supabaseAnonKey = String.fromEnvironment(
  'SUPABASE_ANON_KEY',
  defaultValue: 'YOUR_ANON_KEY',
);
