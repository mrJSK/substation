import { createClient, SupabaseClient } from 'https://esm.sh/@supabase/supabase-js@2'

const url = Deno.env.get('SUPABASE_URL')!

// Bypasses RLS. Use only for work the caller is not allowed to do directly
// (creating auth users, writing system notifications).
export function adminClient(): SupabaseClient {
  return createClient(url, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!, {
    auth: { persistSession: false, autoRefreshToken: false },
  })
}

// Acts as the calling user: every RLS rule and permission check applies.
export function callerClient(req: Request): SupabaseClient {
  return createClient(url, Deno.env.get('SUPABASE_ANON_KEY')!, {
    global: { headers: { Authorization: req.headers.get('Authorization') ?? '' } },
    auth: { persistSession: false, autoRefreshToken: false },
  })
}
