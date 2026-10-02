# SubERP — Regulatory Context

**Entry point:** See `CLAUDE.md`. Full detail in `research_notes/India substation O&M regulations/`.

This ERP must comply with Indian statutory requirements for power utilities. Build every module against these standards.

---

## Primary Standards

| Standard | What it governs | Key requirement for ERP |
|----------|----------------|------------------------|
| UPPTCL O&M Manual 2020 | 19 mandatory registers at every EHV substation | All 19 registers must have digital equivalents with PDF export |
| CEA Safety Regulations 2010 | PTW system, accident reporting, PPE, staff qualification | PTW module (Reg 30), Accident Register (Reg 46) |
| CERC Metering Regs 2006 | ABT meters, 15-min energy blocks, meter accuracy | Energy module: 15-min ABT blocks, Class 0.2S meters |
| IEGC 2010 (amended 2023) | Frequency bands, voltage limits, SLDC reporting | Operating limits validation, outage notification workflows |
| IEC 60076/60156/60599/60480/60255 | Equipment test limits | Maintenance module: test result fields with pass/fail |
| IS 335, IS 3043 | Transformer oil, earthing | Oil BDV limits, earth resistance limits |
| Electricity Act 2003 | Statutory authority | Legal basis for CEA regulations |

---

## The 19 UPPTCL Mandatory Registers

| No. | Register | ERP Module | Statutory |
|-----|---------|-----------|-----------|
| 1 | Index Register | Admin | Yes |
| 2 | Plant History | Assets | Yes |
| 3 | O&M Manual | Assets (Documents) | Yes |
| 4 | Shift Arrangement | HR/Shifts | Yes |
| 5 | Attendance | HR/Shifts | Yes |
| 6 | Testing Register | Maintenance | Yes |
| 7 | Defect Register | Maintenance (Work Orders) | Yes |
| 8 | Energy Account | Energy | Yes |
| 9a | Shutdown Form | PTW | Yes |
| 9b | Work Permit (PTW) | PTW | Yes — CEA Reg 30 |
| 10 | Tripping Register | Operations | Yes |
| 11 | Stoppage Register | Operations (feeds SAIDI/SAIFI) | Yes |
| 12 | Authorization Register | IAM | Yes |
| 13 | Instruction Register | Operations | Yes |
| 14 | Inspection Register | Operations | Yes |
| 15 | Rostering Register | Energy | Yes |
| 16a | Message Register – Control | Operations | Yes |
| 16b | Message Register – Local | Operations | Yes |
| 17 | Max/Min Load Register | Energy | Yes |
| 18 | LA Surge Counter | Maintenance | Yes |
| 19 | Daily Log Sheet | Operations (Shift Logsheet) | Yes |

---

## PTW (Permit to Work) — 7 Steps (CEA Safety Reg 30)

1. **Outage Request** → SLDC minimum 24 hrs in advance
2. **System Isolation** → CB trip, isolators open, earth switches closed, locked + tagged
3. **Earthing** → min 3 rods at work site (both sides + work location)
4. **Issue PTW** → Shift Engineer fills Reg 9b, hands original to workman
5. **Work Execution** → within demarcated area only; no other PTW on same equipment
6. **PTW Return** → workman returns signed PTW; cancelled in register
7. **Re-energization** → all earths removed, SLDC permission, CB closed, SLDC notified

SoD rule: PTW issuer (Shift Engineer) ≠ workman (person in charge of work)

---

## Critical Operating Limits (AppConstants)

| Parameter | Alarm | Trip | Standard |
|-----------|-------|------|---------|
| Transformer WTI | 90°C | 105°C | UPPTCL |
| Transformer OTI | 85°C | 95°C | UPPTCL |
| Transformer BDV oil | < 40 kV → process | < 30 kV → replace | IS 335 / IEC 60156 |
| Transformer DGA C₂H₂ | > 5 ppm → investigate | > 35 ppm → offline | IEC 60599 |
| Frequency | 49.9–50.05 Hz normal | < 49.0 Hz emergency | IEGC |
| Battery capacity | < 80% → plan replace | — | UPPTCL |
| Earth resistance | — | > 1 Ω main mat | IS 3043 |

---

## Statutory Deadlines (must be enforced in the ERP)

| Event | Deadline | Action |
|-------|---------|--------|
| Fatal accident | 24 hrs | Notify CEIG (Chief Electrical Inspector) |
| Written accident report | 48 hrs | Submit to CEIG |
| Planned outage (132kV) | 24 hrs advance | Notify SLDC |
| Planned outage (400kV+) | 72 hrs advance | Notify RLDC |
| Forced outage | 15 min | Notify SLDC |
| Monthly energy statement | 5th of following month | Submit to SLDC |

These deadlines should trigger notifications/alerts in the ERP when approaching.

---

## SAIDI / SAIFI (Reliability Indices)

Computed from `stoppages` table:
- `SAIDI = Σ(interrupted customers × duration hours) / total customers`
- `SAIFI = Σ(interrupted customers) / total customers`
- CERC normative availability for transmission: ≥ 98.5%
- AT&C loss target under RDSS (2021–26): ≤ 15%

---

## Energy Accounting (Reg 8)

- Readings at 8:00 AM daily on 1st of each month (or daily for running balance)
- Loss % = (Import − Export) / Import × 100
- Monthly statement to SLDC by 5th of following month
- ABT meters: 15-min blocks, GPS time-synchronized within 30 seconds

---

## Full Research Notes

Detailed field-level specifications (database column names, pass/fail criteria, form field lists):
- `research_notes/India substation O&M regulations/mandatory_registers.md`
- `research_notes/India substation O&M regulations/logsheet_formats.md`
- `research_notes/India substation O&M regulations/equipment_maintenance.md`
- `research_notes/India substation O&M regulations/safety_ptw_compliance.md`
- `research_notes/India substation O&M regulations/reliability_energy_gridcode.md`
- `reports/India substation O&M regulations.md` (798-line comprehensive report)
