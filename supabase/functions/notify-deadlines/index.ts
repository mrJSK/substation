// Edge Function: notify-deadlines  (owner: Platform team)
// Runs every 4 hours (pg_cron). Writes notifications for:
//   1. Accidents not yet reported to the Electrical Inspector within 20 h
//      (statutory limit 24 h, CEA Safety Regulations)
//   2. Operational units with no energy readings for last month (on the 3rd and 5th)
//   3. Permits still in WORK_IN_PROGRESS after their planned end
// The same alert is not repeated within 24 hours. Service-role calls only.

import { adminClient } from '../_shared/clients.ts'
import { corsHeaders, error, isServiceRoleCall, json } from '../_shared/http.ts'

type Alert = {
  tenant_id: string
  org_unit_id: string
  type: string
  priority: 'CRITICAL' | 'HIGH' | 'MEDIUM'
  title: string
  body: string
  entity_type: string
  entity_id: string
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })
  if (!isServiceRoleCall(req)) return error('Scheduled job: service role only', 403)

  const db = adminClient()
  const now = new Date()
  const alerts: Alert[] = []
  const failures: string[] = []

  // 1. CEIG notification deadline
  {
    const from = new Date(now.getTime() - 24 * 3_600_000).toISOString()
    const to = new Date(now.getTime() - 20 * 3_600_000).toISOString()
    const { data, error: e } = await db
      .from('accident_reports')
      .select('id, tenant_id, org_unit_id, report_number, occurred_at')
      .is('ceig_notified_at', null)
      .gte('occurred_at', from)
      .lte('occurred_at', to)
    if (e) failures.push(`accidents: ${e.message}`)
    for (const a of data ?? []) {
      const hoursLeft = Math.max(0, 24 - (now.getTime() - new Date(a.occurred_at).getTime()) / 3_600_000)
      alerts.push({
        tenant_id: a.tenant_id, org_unit_id: a.org_unit_id, type: 'CEIG_DEADLINE',
        priority: hoursLeft < 2 ? 'CRITICAL' : 'HIGH',
        title: `Report ${a.report_number} to the Electrical Inspector within ${hoursLeft.toFixed(1)} h`,
        body: 'Accidents must be notified to the Electrical Inspector within 24 hours of occurrence.',
        entity_type: 'accident_reports', entity_id: a.id,
      })
    }
  }

  // 2. Monthly energy readings missing (checked on the 3rd and 5th)
  if (now.getUTCDate() === 3 || now.getUTCDate() === 5) {
    const monthStart = new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth() - 1, 1)).toISOString().slice(0, 10)
    const monthEnd = new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), 1)).toISOString().slice(0, 10)
    const { data: units, error: e } = await db
      .from('org_tree').select('id, tenant_id, name').eq('is_operational', true).eq('is_active', true)
    if (e) failures.push(`units: ${e.message}`)
    for (const u of units ?? []) {
      const { count } = await db
        .from('energy_readings').select('id', { count: 'exact', head: true })
        .eq('org_unit_id', u.id).gte('reading_date', monthStart).lt('reading_date', monthEnd)
      if ((count ?? 0) === 0) {
        alerts.push({
          tenant_id: u.tenant_id, org_unit_id: u.id, type: 'ENERGY_STATEMENT_DUE',
          priority: now.getUTCDate() === 5 ? 'CRITICAL' : 'HIGH',
          title: `${u.name}: energy readings for ${monthStart.slice(0, 7)} are missing`,
          body: 'The monthly energy statement is due by the 5th.',
          entity_type: 'org_units', entity_id: u.id,
        })
      }
    }
  }

  // 3. Permit overruns
  {
    const { data, error: e } = await db
      .from('ptw_requests')
      .select('id, tenant_id, org_unit_id, ptw_number, planned_end')
      .eq('status', 'WORK_IN_PROGRESS')
      .lt('planned_end', now.toISOString())
    if (e) failures.push(`permits: ${e.message}`)
    for (const p of data ?? []) {
      const hoursOver = (now.getTime() - new Date(p.planned_end).getTime()) / 3_600_000
      alerts.push({
        tenant_id: p.tenant_id, org_unit_id: p.org_unit_id, type: 'PTW_OVERRUN',
        priority: hoursOver > 2 ? 'CRITICAL' : 'HIGH',
        title: `Permit ${p.ptw_number} is ${hoursOver.toFixed(1)} h past its planned end`,
        body: 'Extend the permit or return and close it.',
        entity_type: 'ptw_requests', entity_id: p.id,
      })
    }
  }

  // De-duplicate against the last 24 hours, then insert in one batch
  const since = new Date(now.getTime() - 24 * 3_600_000).toISOString()
  const fresh: Alert[] = []
  for (const a of alerts) {
    const { count } = await db
      .from('notifications').select('id', { count: 'exact', head: true })
      .eq('entity_id', a.entity_id).eq('type', a.type).gte('created_at', since)
    if ((count ?? 0) === 0) fresh.push(a)
  }
  if (fresh.length > 0) {
    const { error: e } = await db.from('notifications').insert(fresh)
    if (e) failures.push(`insert: ${e.message}`)
  }

  return json({ created: fresh.length, failures })
})
