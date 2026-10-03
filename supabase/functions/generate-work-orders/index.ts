// Edge Function: generate-work-orders  (owner: Maintenance team)
// Daily job (pg_cron, 01:00 IST). Creates PREVENTIVE work orders for every
// active maintenance schedule due within the next 3 days, unless an open
// work order already exists for that schedule. Service-role calls only.

import { adminClient } from '../_shared/clients.ts'
import { corsHeaders, error, isServiceRoleCall, json } from '../_shared/http.ts'

const LOOKAHEAD_DAYS = 3
const OPEN_STATUSES = ['PLANNED', 'ASSIGNED', 'IN_PROGRESS', 'PENDING_PTW']

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })
  if (!isServiceRoleCall(req)) return error('Scheduled job: service role only', 403)

  const db = adminClient()
  const horizon = new Date(Date.now() + LOOKAHEAD_DAYS * 86_400_000).toISOString().slice(0, 10)

  const { data: schedules, error: schedErr } = await db
    .from('maintenance_schedules')
    .select('id, tenant_id, equipment_id, next_due_on, equipment:equipment_id(org_unit_id, name, is_active), plan:plan_id(title, task_checklist, is_active)')
    .eq('is_active', true)
    .lte('next_due_on', horizon)

  if (schedErr) return error(schedErr.message, 500)

  let created = 0
  const failures: string[] = []

  for (const s of schedules ?? []) {
    // deno-lint-ignore no-explicit-any
    const eq = s.equipment as any
    // deno-lint-ignore no-explicit-any
    const plan = s.plan as any
    if (!eq?.is_active || !plan?.is_active) continue

    const { count } = await db
      .from('work_orders')
      .select('id', { count: 'exact', head: true })
      .eq('schedule_id', s.id)
      .in('status', OPEN_STATUSES)
    if ((count ?? 0) > 0) continue

    const { error: insErr } = await db.from('work_orders').insert({
      tenant_id: s.tenant_id,
      org_unit_id: eq.org_unit_id,
      equipment_id: s.equipment_id,
      schedule_id: s.id,
      type: 'PREVENTIVE',
      status: 'PLANNED',
      title: plan.title,
      description: `Preventive maintenance due ${s.next_due_on}`,
      scheduled_date: s.next_due_on,
      checklist: plan.task_checklist ?? [],
    })
    if (insErr) failures.push(`${eq.name}: ${insErr.message}`)
    else created++
  }

  return json({ created, failures })
})
