// Edge Function: iam-admin-users  (owner: IAM team)
// Creates a sign-in account + profile for a new user (SU01 "Create user").
// Self sign-up is disabled, and creating auth users needs the service key,
// so this runs server-side. The caller must hold USER_ADMIN at the new
// user's home org unit; the optional first role is granted AS THE CALLER so
// the database's no-privilege-escalation guard applies.
//
// POST { email, password, full_name, employee_id?, designation?, phone?,
//        home_org_unit_id, role_id?, scope_org_unit_id? }

import { adminClient, callerClient } from '../_shared/clients.ts'
import { corsHeaders, error, json } from '../_shared/http.ts'

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })
  if (req.method !== 'POST') return error('Method not allowed', 405)

  const caller = callerClient(req)
  const { data: who } = await caller.auth.getUser()
  if (!who?.user) return error('Not signed in', 401)

  let body: Record<string, string | undefined>
  try {
    body = await req.json()
  } catch {
    return error('Invalid JSON body')
  }

  const email = body.email?.trim().toLowerCase()
  const fullName = body.full_name?.trim()
  const homeUnit = body.home_org_unit_id
  if (!email || !email.includes('@')) return error('A valid email is required')
  if (!fullName) return error('Full name is required')
  if (!homeUnit) return error('Home org unit is required')
  if (!body.password || body.password.length < 8) return error('Temporary password must be at least 8 characters')

  const { data: allowed, error: permErr } = await caller.rpc('user_has_permission', {
    p_code: 'USER_ADMIN',
    p_org_unit_id: homeUnit,
  })
  if (permErr) return error(permErr.message, 400)
  if (!allowed) return error('You need USER_ADMIN at this org unit', 403)

  const { data: tenantId } = await caller.rpc('current_tenant_id')
  if (!tenantId) return error('Your account has no active tenant', 403)

  const admin = adminClient()
  const { data: created, error: createErr } = await admin.auth.admin.createUser({
    email,
    password: body.password,
    email_confirm: true,
    user_metadata: { full_name: fullName },
  })
  if (createErr || !created.user) return error(createErr?.message ?? 'Could not create the account', 400)

  const userId = created.user.id
  const { error: profileErr } = await admin.from('user_profiles').insert({
    id: userId,
    tenant_id: tenantId,
    full_name: fullName,
    email,
    employee_id: body.employee_id || null,
    designation: body.designation || null,
    phone: body.phone || null,
    home_org_unit_id: homeUnit,
  })
  if (profileErr) {
    await admin.auth.admin.deleteUser(userId)
    return error(profileErr.message, 400)
  }

  if (body.role_id) {
    const { error: roleErr } = await caller.from('user_role_assignments').insert({
      tenant_id: tenantId,
      user_id: userId,
      role_id: body.role_id,
      org_unit_id: body.scope_org_unit_id ?? homeUnit,
    })
    if (roleErr) return json({ user_id: userId, warning: `User created, but the role was not granted: ${roleErr.message}` }, 201)
  }

  return json({ user_id: userId }, 201)
})
