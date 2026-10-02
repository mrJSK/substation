/**
 * Edge Function: generate-work-orders
 * Runs daily via Supabase cron (set in Dashboard → Edge Functions → Schedule).
 * Cron expression: 0 1 * * *  (1:00 AM IST every day)
 *
 * Checks all maintenance_schedules where next_due_at <= today + 3 days
 * and no open WO already exists, then creates WOs automatically.
 */

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const supabase = createClient(
  Deno.env.get('SUPABASE_URL')!,
  Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!  // service role — bypasses RLS
)

Deno.serve(async (req) => {
  // Allow cron trigger (POST with no body) and manual invocation
  if (req.method !== 'POST') {
    return new Response('Method not allowed', { status: 405 })
  }

  const today = new Date()
  const windowDate = new Date(today)
  windowDate.setDate(windowDate.getDate() + 3)  // 3-day lookahead

  // Fetch overdue/upcoming maintenance schedules
  const { data: schedules, error: schedErr } = await supabase
    .from('maintenance_schedules')
    .select(`
      id,
      equipment_id,
      plan_id,
      next_due_at,
      equipment:equipment_id (
        id, name, tenant_id, org_unit_id
      ),
      plan:plan_id (
        id, title, frequency_type, task_checklist
      )
    `)
    .lte('next_due_at', windowDate.toISOString().split('T')[0])

  if (schedErr) {
    console.error('Error fetching schedules:', schedErr)
    return new Response(JSON.stringify({ error: schedErr.message }), { status: 500 })
  }

  if (!schedules || schedules.length === 0) {
    return new Response(JSON.stringify({ created: 0, message: 'No schedules due' }), { status: 200 })
  }

  let created = 0
  const errors: string[] = []

  for (const schedule of schedules) {
    const eq = schedule.equipment as any
    const plan = schedule.plan as any

    // Check if an open WO already exists for this equipment + plan
    const { count } = await supabase
      .from('work_orders')
      .select('id', { count: 'exact', head: true })
      .eq('equipment_id', schedule.equipment_id)
      .in('status', ['PLANNED', 'ASSIGNED', 'IN_PROGRESS', 'PENDING_PTW'])
      .gte('scheduled_date', new Date(Date.now() - 30 * 86400000).toISOString().split('T')[0])

    if ((count ?? 0) > 0) continue  // WO already open, skip

    // Create the work order
    const { error: woErr } = await supabase
      .from('work_orders')
      .insert({
        tenant_id:      eq.tenant_id,
        substation_id:  eq.org_unit_id,
        equipment_id:   schedule.equipment_id,
        type:           'PREVENTIVE',
        status:         'PLANNED',
        title:          plan.title,
        description:    `Auto-generated: ${plan.title} due ${schedule.next_due_at}`,
        scheduled_date: schedule.next_due_at,
        test_results:   { checklist: plan.task_checklist, status: 'pending' },
      })

    if (woErr) {
      errors.push(`${eq.name}: ${woErr.message}`)
    } else {
      created++
    }
  }

  console.log(`Generated ${created} work orders. Errors: ${errors.length}`)

  return new Response(
    JSON.stringify({ created, errors: errors.length > 0 ? errors : undefined }),
    { status: 200, headers: { 'Content-Type': 'application/json' } }
  )
})
