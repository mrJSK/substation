/**
 * Edge Function: notify-deadlines
 * Runs every 4 hours via Supabase cron.
 * Cron expression: 0 */4 * * *
 *
 * Checks:
 * 1. Accident reports unnotified to CEIG within 20 hrs (warns 4 hrs before 24-hr CEA deadline)
 * 2. Monthly energy statements due by 5th of next month (reminds on 3rd and 5th)
 * 3. PTW work-time overruns (work in progress past end_time)
 *
 * Notifications are written to a `notifications` table so the app can
 * show them offline. No external email/SMS in this version — that's a Phase 7 add-on.
 */

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const supabase = createClient(
  Deno.env.get('SUPABASE_URL')!,
  Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
)

interface NotificationRow {
  tenant_id:    string
  org_unit_id:  string
  type:         string
  priority:     'CRITICAL' | 'HIGH' | 'MEDIUM'
  title:        string
  body:         string
  entity_type:  string
  entity_id:    string
}

async function upsertNotification(n: NotificationRow) {
  // Deduplicate: same entity_id + type within 24 hours = don't spam
  const { data: existing } = await supabase
    .from('notifications')
    .select('id')
    .eq('entity_id', n.entity_id)
    .eq('type', n.type)
    .gte('created_at', new Date(Date.now() - 24 * 3600000).toISOString())
    .maybeSingle()

  if (existing) return  // already notified recently

  await supabase.from('notifications').insert(n)
}

Deno.serve(async (req) => {
  if (req.method !== 'POST') {
    return new Response('Method not allowed', { status: 405 })
  }

  const now = new Date()
  const errors: string[] = []
  let notified = 0

  // ── 1. Accident report CEIG deadline ──────────────────────────────────────
  // CEA Safety Regs 2010, Reg 46: notify CEIG within 24 hrs of occurrence.
  // We warn when 20 hrs have passed without ceig_notified_at being set.
  try {
    const cutoff20h = new Date(now.getTime() - 20 * 3600000)
    const cutoff24h = new Date(now.getTime() - 24 * 3600000)

    const { data: accidents } = await supabase
      .from('accident_reports')
      .select('id, tenant_id, substation_id, occurred_at, severity, accident_number')
      .is('ceig_notified_at', null)
      .lte('occurred_at', cutoff20h.toISOString())  // occurred 20+ hrs ago
      .gte('occurred_at', cutoff24h.toISOString())  // but not yet past 24 hrs (still actionable)

    for (const acc of (accidents ?? [])) {
      const hoursElapsed = (now.getTime() - new Date(acc.occurred_at).getTime()) / 3600000
      const hoursLeft = Math.max(0, 24 - hoursElapsed)

      await upsertNotification({
        tenant_id:   acc.tenant_id,
        org_unit_id: acc.substation_id,
        type:        'CEIG_DEADLINE',
        priority:    hoursLeft < 2 ? 'CRITICAL' : 'HIGH',
        title:       `CEIG notification due in ${hoursLeft.toFixed(1)} hrs`,
        body:        `Accident ${acc.accident_number} occurred ${hoursElapsed.toFixed(1)} hrs ago. CEA Reg 46 requires CEIG notification within 24 hrs.`,
        entity_type: 'accident_reports',
        entity_id:   acc.id,
      })
      notified++
    }
  } catch (e) {
    errors.push(`accident check: ${e}`)
  }

  // ── 2. Monthly energy statement deadline ──────────────────────────────────
  // Remind on 3rd and 5th of month — statements due by 5th for previous month.
  try {
    const dayOfMonth = now.getDate()
    if (dayOfMonth === 3 || dayOfMonth === 5) {
      const prevMonth = now.getMonth() === 0 ? 12 : now.getMonth()
      const prevYear  = now.getMonth() === 0 ? now.getFullYear() - 1 : now.getFullYear()

      // Find tenants/substations with NO energy_readings for prev month
      const { data: substations } = await supabase
        .from('org_units')
        .select('id, name, tenant_id')
        .eq('level', 5)  // substation level

      for (const sub of (substations ?? [])) {
        const { count } = await supabase
          .from('energy_readings')
          .select('id', { count: 'exact', head: true })
          .eq('substation_id', sub.id)
          .eq('reading_type', 'IMPORT')
          .filter('reading_date', 'gte', `${prevYear}-${String(prevMonth).padStart(2,'0')}-01`)
          .filter('reading_date', 'lt',  `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2,'0')}-01`)

        if ((count ?? 0) === 0) {
          await upsertNotification({
            tenant_id:   sub.tenant_id,
            org_unit_id: sub.id,
            type:        'ENERGY_STATEMENT_DUE',
            priority:    dayOfMonth === 5 ? 'CRITICAL' : 'HIGH',
            title:       `Monthly energy statement not submitted`,
            body:        `${sub.name}: No energy readings recorded for ${prevYear}-${prevMonth}. Submit by 5th as per CERC Metering Regs 2006.`,
            entity_type: 'org_units',
            entity_id:   sub.id,
          })
          notified++
        }
      }
    }
  } catch (e) {
    errors.push(`energy statement check: ${e}`)
  }

  // ── 3. PTW work-time overrun ───────────────────────────────────────────────
  // Flag PTWs with status WORK_IN_PROGRESS where end_time has passed.
  try {
    const { data: overrunPtws } = await supabase
      .from('ptw_requests')
      .select('id, tenant_id, substation_id, ptw_number, end_time, work_description')
      .eq('status', 'WORK_IN_PROGRESS')
      .lt('end_time', now.toISOString())

    for (const ptw of (overrunPtws ?? [])) {
      const hoursOver = (now.getTime() - new Date(ptw.end_time).getTime()) / 3600000

      await upsertNotification({
        tenant_id:   ptw.tenant_id,
        org_unit_id: ptw.substation_id,
        type:        'PTW_OVERRUN',
        priority:    hoursOver > 2 ? 'CRITICAL' : 'HIGH',
        title:       `PTW ${ptw.ptw_number} overrun by ${hoursOver.toFixed(1)} hrs`,
        body:        `Work is still in progress past the permitted end time. Either extend the PTW or clear it immediately per CEA Safety Regs 2010 Reg 30.`,
        entity_type: 'ptw_requests',
        entity_id:   ptw.id,
      })
      notified++
    }
  } catch (e) {
    errors.push(`PTW overrun check: ${e}`)
  }

  console.log(`notify-deadlines: ${notified} notifications created. Errors: ${errors.length}`)

  return new Response(
    JSON.stringify({ notified, errors: errors.length > 0 ? errors : undefined }),
    { status: 200, headers: { 'Content-Type': 'application/json' } }
  )
})
