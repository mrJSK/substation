# India Power Utility ERP — Regulatory & Operational Requirements Research

**Prepared for:** Software Development Team — Indian Power Utility ERP System
**Scope:** EHV/HV Electrical Substations (400kV / 220kV / 132kV / 33kV / 11kV)
**Date:** October 2026
**Primary Sources:** UPPTCL Best O&M Practices for EHV Sub-stations and Lines (First Edition, October 2020); CEA (Measures Relating to Safety and Electric Supply) Regulations 2010; Indian Electricity Grid Code (IEGC) 2010 (amended 2023); CERC Metering Regulations 2006; IS 335, IS 3043, IS 2026; IEC 60156, IEC 60599, IEC 60076, IEC 60137, IEC 60480, IEC 60255

---

## Executive Summary

Indian EHV/HV substations operate under a dense, multi-layered regulatory framework that spans statutory law (Electricity Act 2003, Indian Electricity Rules 1956), Central Electricity Authority (CEA) regulations, Central Electricity Regulatory Commission (CERC) orders, state-level SERC tariff orders, and TRANSCO/DISCOM operational manuals. Any ERP system targeting Indian power utilities must treat regulatory compliance not as a peripheral module but as its central organizing principle.

The UPPTCL (U.P. Power Transmission Corporation Ltd) O&M Manual — the most comprehensive publicly available TRANSCO standard in India, covering 765kV/400kV/220kV/132kV substations — mandates **19 numbered operational registers** plus an additional 11 statutory/maintenance registers, totalling 30+ distinct record-keeping obligations per substation. Each register has defined fields, signature requirements, and retention obligations. An ERP that cannot generate, populate, and audit these registers electronically will fail adoption.

Logsheet requirements differ by voltage tier: EHV substations (132kV and above) record operational parameters **hourly**, 33kV/11kV DISCOM substations record every **4 hours**, and ABT boundary meters capture **15-minute block energy data** per CERC Metering Regulations 2006. The specific parameters, normal operating bands (e.g., frequency 49.9–50.05 Hz normal; 400kV bus 380–420 kV), and alarm thresholds are prescribed in IEGC and CEA standards and must be hardcoded as reference data in the ERP.

Equipment maintenance schedules are equipment-specific and frequency-specific. A power transformer requires daily shift checks, quarterly external inspection, half-yearly functional tests, annual oil BDV/IR/TTR tests, and 5-yearly DGA/internal inspection — each with specific pass/fail limits (e.g., BDV ≥50 kV at 132kV and above per IEC 60156, PI ≥1.5 per IEC 60076, C2H2 <5 ppm per IEC 60599). The ERP must implement a work-order generation engine tied to equipment calendars and operation counters.

The Permit to Work (PTW) system is a **statutory requirement** under CEA Safety Regulations 2010 (Regulation 30), not merely best practice. A 7-step workflow — from ALDC/SLDC outage request through isolation, earthing, PTW issue, work execution, PTW return, and re-energization — must be faithfully implemented with digital signatures, ALDC/SLDC reference numbers, and automatic linkage to Stoppage Register entries.

Reliability performance is measured against CERC normative transmission availability of **≥98.5%** and SERC-mandated SAIDI/SAIFI targets (which vary by state and consumer category). AT&C loss reduction to **≤15%** under the RDSS scheme (2021–26) is a MoP mandate with financial consequences. Energy accounting from substation meter data — specifically the 8:00 AM daily readings and the monthly energy balance — feeds both regulatory reporting and commercial settlement. The ABT/DSM framework (CERC DSM Regulations 2014) adds a real-time financial dimension: 15-minute deviations from schedule incur UI/DSM charges that can dwarf fixed tariff earnings.

For the ERP development team, the critical design insight is this: **every register, logsheet, and test record ultimately feeds one of three regulatory outputs** — the monthly energy account submitted to SLDC, the reliability index reported to SERC, or the safety compliance record audited by CEA/CEIG. Structuring the database schema around these three outputs, with registers and logsheets as input tables, is the architecturally sound approach.

---

## 1. Mandatory Registers and Record-Keeping

### 1.1 The 19 Essential Operational Registers (UPPTCL Standard)

UPPTCL mandates 19 machine-numbered registers at every EHV substation. "Machine-numbered" means pre-printed sequential page numbers — this prevents back-filling or removal of pages. All registers must be maintained formally and are subject to inspection by CEA and SERC.

> **Source note**: All 19 registers are from **UPPTCL O&M Manual, Section 10.0** (TRANSCO best practice, not CEA regulation, except where noted). CEA Safety Regulations 2010 additionally mandate the Accident Register and Earth Resistance Register.

| Reg No. | Register Name | Key Fields (Database Columns) | Responsible | Signature Required | Retention |
|---------|--------------|-------------------------------|-------------|-------------------|-----------|
| 1 | Index Register | serial_no, register_name, subject, remarks | AE/JE (O&M) | AE | Life of substation |
| 2 | Plant History Register | equipment_id, spec_sheet, commissioning_date, event_date, event_type, event_description, done_by | AE (Maintenance) | AE | Life of equipment + 10 yr |
| 3 | O&M Manual | equipment_id, manufacturer, manual_ref, recommendation_text, revision_date | AE (Maintenance) | — | Life of equipment |
| 4 | Shift Arrangement Register | month, year, staff_id, date, shift_code (E/N/M/G/R) | JE (Operation) | SE | Yearly |
| 5 | Attendance Register | staff_id, date, time_in, time_out, category | JE (Operation) | SE | 3 years |
| 6 | Testing Register | test_date, equipment_id, test_type, test_details, result, tested_by, jE_ae_signature | JE/AE (T&C) | JE/AE | Life of equipment |
| 7 | Defect Register | defect_date, defect_time, equipment_id, defect_description, reported_by, compliance_date, action_taken, jE_ae_signature | Shift Staff | JE/AE | 5 years |
| 8 | Energy Account Register | feeder_id, reading_date (8:00 AM), prev_reading, curr_reading, difference, multiplying_factor, net_energy_mwh, direction (import/export) | JE(M)/AE(M) | JE(M)/AE(M) | 5 years |
| 9(a) | Shutdown Form Register | shutdown_id, equipment_id, requested_by, aldc_sldc_ref, approved_time, actual_start, actual_end, reason | SE | SE + ALDC/SLDC | 5 years |
| 9(b) | Work Permit Form Register | ptw_number, issue_datetime, equipment_id, isolation_points, earthing_points, person_in_charge, valid_from, valid_to, return_datetime, restoring_datetime, aldc_ref | SE (Issuing) | SE + Worker | 5 years |
| 10 | Tripping Register (Primary) | trip_id, datetime, breaker_id, feeder_id, trip_time_ms, close_time, cp_flags, rp_flags, far_end_flags, other_breakers_tripped, fault_analysis | SE | SE | 5 years |
| 11 | Stoppage Register | feeder_id, month, tripping_from, tripping_to, tripping_duration, tripping_flags, breakdown_from, breakdown_to, breakdown_reason, shutdown_from, shutdown_to, shutdown_reason, rostering_from, rostering_to, effective_duration_hr, availability_pct_incl_rostering, availability_pct_excl_rostering | SE / JE | AE | 5 years |
| 12 | Authorization Register | auth_id, staff_id, work_authorized, authorization_date, authorized_by | AE | Authorizing authority + staff | Life of employment |
| 13 | Instruction Register | instruction_date, details, issued_by, noted_by, compliance_date, compliance_details | AE/SE | Staff | 3 years |
| 14 | Inspection Register | inspection_date, inspector_name, designation, observation, signature, noted_by, compliance | Inspecting Officer | Inspector + AE | 5 years |
| 15 | Rostering Register | programme_date, received_from, code_no, communicated_to, remark | SE | SE | 1 year |
| 16(a) | Message Register (Control/ALDC) | datetime, direction (in/out), sending_end, receiving_end, from_person, to_person, message_details, action_taken, sso_je_signature | SSO/JE | SSO/JE | 3 years |
| 16(b) | Message Register (Local) | same as 16(a) | SSO/JE | SSO/JE | 3 years |
| 17 | Max/Min Load Register | feeder_id, transformer_id, max_load_mw, max_load_datetime, min_load_mw, min_load_datetime, month | JE | AE | 5 years |
| 18 | LA Surge Counter Register | la_id, phase (R/Y/B), reading_date, counter_reading, ammeter_reading_ma | Shift SSO | SE | 3 years |
| 19 | Daily Log Sheet | See Section 2 for full field specification | Shift In-Charge | SE (Outgoing + Incoming) | 5 years |

### 1.2 Additional Statutory and Maintenance Registers

Beyond the 19 primary registers, the following are required by CEA regulations or IEC/IS standards:

| Register | Statutory Basis | Key Fields |
|---------|-----------------|-----------|
| Accident / Dangerous Occurrence Register | **CEA Safety Regulations 2010, Reg. 46** (STATUTORY) | accident_id, datetime, location, equipment_id, persons_involved, injury_nature, cause_immediate, cause_root, corrective_action, reported_to_ceig_date |
| Oil Testing / BDV Register | IS 335, IEC 60156 | equipment_id, test_date, sample_ref, bdv_kv_1 through bdv_kv_6, average_bdv, moisture_ppm, decision, tested_by |
| Earth Resistance Register | IS 3043, **CEA Safety Regs** (STATUTORY) | earth_point_id, measurement_date, measured_resistance_ohm, method, pass_fail, tested_by |
| Relay Test Register | CEA Technical Standards | relay_id, test_date, function_tested, setting_applied, result_pickup, result_time_ms, pass_fail, tested_by |
| DGA (Dissolved Gas Analysis) Register | IEC 60599 | transformer_id, sample_date, h2_ppm, ch4_ppm, c2h2_ppm, c2h4_ppm, c2h6_ppm, co_ppm, co2_ppm, tdcg_ppm, co2_co_ratio, key_gas_interpretation, tdcg_condition (normal/caution/action) |
| IR / Megger Test Register | IEC 60076, IS 2026 | equipment_id, test_date, voltage_kv, ir_reading_mohm, pi_ratio, pass_fail, tested_by |
| SF6 Gas Analysis Register | IEC 60480, IEC 60376 | cb_id, pole (A/B/C), test_date, dew_point_c, purity_pct, pressure_bar, pass_fail |
| OLTC Maintenance Register | CBIP Guide 14 | transformer_id, maintenance_date, tap_counter_reading, operation_count_since_last, oil_changed_y_n, contact_resistance_mohm, remarks |
| Key Register | Safety / PTW | key_id, equipment_room_id, issued_to, issue_datetime, returned_datetime |
| Battery Maintenance Register | UPPTCL / Manufacturer | battery_id, cell_no, float_voltage_v, specific_gravity, electrolyte_level, maintenance_date, capacity_test_result_pct |

### 1.3 Drawings to Be Maintained (Document Register)

Each substation must maintain the following drawings in a dedicated almirah in the control room, indexed bay-wise:
1. General Arrangement (GA) diagrams for all equipment and structures
2. Schematic diagrams — control panels, relay panels, all bays
3. Manufacturer's erection/commissioning/maintenance manuals
4. Cable schedules and interconnection diagrams per bay
5. Electrical layout plan
6. Foundation plan and earthmat drawing
7. Site layout plan
8. Substation Maintenance Manual

**ERP implication**: A Document Management module must link each drawing to the relevant equipment records (Plant History Register) with version control and revision history.

### 1.4 ERP Module Mapping — Registers

| Register Group | ERP Module |
|---------------|-----------|
| Registers 1–5 (Index, Plant History, O&M Manual, Shift, Attendance) | Asset Management + HR/Rostering |
| Register 6, Testing Register, DGA, BDV, IR, SF6 | Preventive Maintenance (Work Orders + Test Results) |
| Register 7 (Defects) | Corrective Maintenance / Work Order Management |
| Register 8 (Energy Account) | Energy Accounting Module |
| Registers 9(a), 9(b) (Shutdown + PTW) | Outage Management + PTW Module |
| Registers 10, 11 (Tripping, Stoppage) | Reliability / SCADA Integration |
| Registers 12–14 (Authorization, Instructions, Inspection) | Compliance / Audit Module |
| Registers 15–16 (Rostering, Messages) | Operations Module (Dispatch Communication) |
| Registers 17–19 (Load, LA, Logsheet) | Operations Logbook / SCADA |

---

## 2. Logsheet Requirements — Field-by-Field Specification

### 2.1 Logsheet Header Block (All Tiers)

Every logsheet page must include:

| Field | Type | Notes |
|-------|------|-------|
| substation_name | VARCHAR(100) | Official name as per SLDC records |
| date | DATE | |
| shift | ENUM('Morning','Evening','Night') | |
| shift_incharge_name | VARCHAR(100) | |
| shift_incharge_designation | VARCHAR(50) | |
| handover_time | TIME | Relief time — when shift actually handed over |
| outgoing_shift_signature | TEXT | Digital signature in ERP |
| incoming_shift_signature | TEXT | |
| checking_ae_je_signature | TEXT | |

### 2.2 Hourly Parameters — EHV Substations (132kV / 220kV / 400kV)

Recorded every hour (00:00 to 23:00). Per SLDC/ALDC requirements.

**Per Bay (one set of columns per transformer, feeder, bus coupler):**

| Parameter | Column Name | Unit | Normal Band | Alarm Condition |
|-----------|-------------|------|-------------|-----------------|
| Timestamp | reading_time | HH:MM | — | — |
| Current | current_a | A | Per equipment rating | >100% rated current |
| Voltage (bus) | voltage_kv | kV | 400kV: 380–420; 220kV: 200–245; 132kV: 121–145 | Outside IEGC band |
| Active Power | mw | MW | — | >rated MVA capacity |
| Reactive Power | mvar | MVAR | >0 = lagging | Negative MVAR beyond rated |
| Apparent Power | mva | MVA | ≤rated MVA | >rated MVA |
| Power Factor | power_factor | — | ≥0.90 lagging | <0.85 lag → SERC penalty |
| Frequency | frequency_hz | Hz | 49.9–50.05 (IEGC normal) | <49.5 → UFLS; <49.0 → emergency |
| OLTC Tap Position | oltc_tap | Integer | Per voltage regulation target | Per SE instruction |
| Winding Temperature | wti_deg_c | °C | Normal: <80°C | Alarm: 90°C; Trip: 105°C |
| Oil Temperature | oti_deg_c | °C | Normal: <75°C | Alarm: 85°C; Trip: 95°C |
| CB Status | cb_status | ENUM('Open','Closed') | — | Unexpected open/close |
| Isolator Status | iso_status | ENUM('Open','Closed') | — | Unexpected |
| Earth Switch Status | es_status | ENUM('Open','Closed') | — | Must be open when energized |

**Per Station (overall):**

| Parameter | Column Name | Unit | Notes |
|-----------|-------------|------|-------|
| 33kV Bus Voltage | v_33kv_bus | kV | Secondary bus |
| 11kV Bus Voltage | v_11kv_bus | kV | Distribution (DISCOM substations) |
| Station Aux Load | aux_load_mw | MW | Colony + auxiliaries |
| Ambient Temperature | ambient_temp_c | °C | Twice per shift minimum |
| Weather | weather_code | ENUM('Clear','Cloudy','Rain','Fog','Haze','Thunderstorm') | Affects insulator performance |
| Remarks | remarks | TEXT | Any abnormality, operation, message — free text |

### 2.3 4-Hourly Parameters — 33kV/11kV DISCOM Substations

Readings at 06:00 / 10:00 / 14:00 / 18:00 / 22:00 / 02:00:

| Parameter | Column Name | Unit | Normal Band |
|-----------|-------------|------|-------------|
| 33kV Incoming Voltage | v_33kv_in | kV | 30.25–36.3 (IEGC) |
| 11kV Bus Voltage | v_11kv_bus | kV | 9.9–12.1 (±10% of 11kV) |
| Transformer Current | xfmr_current_a | A | ≤rated current |
| Power Factor | pf | — | ≥0.90 lag |
| Transformer OTI | oti_deg_c | °C | Alarm: 85°C; Trip: 95°C |
| Cumulative Energy Import | energy_kwh | kWh | Meter reading (cumulative) |
| Feeder Current (per feeder) | feeder_current_a | A | Per feeder rating |
| Feeder Status | feeder_on | BOOLEAN | Rostering compliance |
| Frequency | frequency_hz | Hz | 49.9–50.05 |
| Remarks | remarks | TEXT | Trippings, complaints |

### 2.4 15-Minute ABT Block Parameters (CERC Metering Regulations 2006)

At all inter-state interchange points and generating station boundaries:

| Parameter | Column Name | Unit | Notes |
|-----------|-------------|------|-------|
| Block start time | block_start_time | DATETIME | GPS/IST synchronized, within 30 seconds per CERC |
| Block end time | block_end_time | DATETIME | Always 15 minutes after start |
| Import energy | block_import_mwh | MWh | From ABT trivector meter |
| Export energy | block_export_mwh | MWh | |
| Import reactive energy | block_import_mvarh | MVArh | |
| Export reactive energy | block_export_mvarh | MVArh | |
| Maximum demand | max_demand_kw | kW | |
| Meter ID (main) | main_meter_id | VARCHAR | Class 0.2S or better per CERC |
| Meter ID (check) | check_meter_id | VARCHAR | Mandatory redundant meter |
| Meter ID (standby) | standby_meter_id | VARCHAR | Third meter per CERC |
| Schedule (MW) | scheduled_mw | MW | From SLDC day-ahead schedule |
| Deviation | deviation_mw | MW | Actual minus scheduled |
| UI/DSM applicable | dsm_applicable | BOOLEAN | |

**Note**: ABT meters must be Class 0.2S (inter-state) or Class 0.5 (state boundary 33kV). GPS clock synchronization to IST within 30 seconds is mandatory (CERC requirement).

### 2.5 Daily Parameters (8:00 AM Standard Readings)

| Parameter | Column Name | Unit | Source Register |
|-----------|-------------|------|----------------|
| Energy meter reading (per feeder) | em_reading_kwh | kWh | Register 8 |
| Transformer oil BDV (if tested) | oil_bdv_kv | kV | BDV Register |
| Battery pilot cell voltage | battery_pilot_v | V | Battery Register |
| Battery pilot cell specific gravity | battery_pilot_sg | — | Battery Register |
| LA surge counter (per LA, per phase) | la_counter | Integer | Register 18 |

### 2.6 Monthly Parameters and Computations

| Parameter | Formula / Source | Output |
|-----------|-----------------|--------|
| Energy input (MWh) | Σ(curr_reading − prev_reading) × MF for all incoming feeders | energy_input_mwh |
| Energy output (MWh) | Σ(curr_reading − prev_reading) × MF for all outgoing feeders + aux consumption | energy_output_mwh |
| T&D loss (MWh) | energy_input_mwh − energy_output_mwh | loss_mwh |
| T&D loss (%) | (loss_mwh / energy_input_mwh) × 100 | loss_pct |
| Max load (per feeder/xfmr) | MAX(mw) for the month with datetime | max_load_mw, max_load_datetime |
| Min load | MIN(mw) for the month with datetime | min_load_mw |
| Availability % (per element) | (scheduled_hrs − forced_outage_hrs) / scheduled_hrs × 100 | availability_pct |
| SAIDI (DISCOM) | Σ(interrupted_customers × duration_hr) / total_customers | saidi_hr |
| SAIFI (DISCOM) | Σ(interrupted_customers) / total_customers | saifi |
| Tripping count | COUNT(trip_id) for month per feeder | trips_per_month |
| Number of interruptions | COUNT(stoppage_id) for month per feeder | interruptions_per_month |

### 2.7 Alarm Thresholds — What Triggers an Alarm vs. Normal Entry

| Parameter | Normal Entry | Alarm Entry | Action Required |
|-----------|-------------|-------------|-----------------|
| Frequency | 49.9–50.05 Hz | <49.5 Hz or >50.2 Hz | IEGC action — UFLS or generation reduction |
| Voltage | Within IEGC bands | Outside IEGC band | Reactive power control; notify SLDC |
| OTI | <75°C | ≥85°C (alarm), ≥95°C (trip) | Reduce load; start fans; investigate |
| WTI | <80°C | ≥90°C (alarm), ≥105°C (trip) | Reduce load; investigate |
| Power Factor | ≥0.90 lag | <0.85 lag | SERC commercial penalty; capacitor bank |
| Transformer loading | ≤100% rated MVA | >100% rated; >120% = emergency | Load transfer; outage request |
| Battery cell voltage | 2.20–2.27 V (float) | <1.95 V per cell | Flag cell; test capacity |

---

## 3. Equipment Testing and Maintenance Schedules

### 3.1 Power Transformers

> **Source**: UPPTCL O&M Manual Sections 1.1–1.20; IEC 60156, IEC 60599, IEC 60076, IEC 60422, IEC 60137

| Test / Activity | Frequency | Pass / Fail Criteria | Standard | What to Record |
|----------------|-----------|---------------------|----------|---------------|
| Shift visual checks (oil level, silica gel, WTI, OTI, sounds, fans) | Every shift (8-hourly) | Silica gel = blue; oil level per MOG; no abnormal sound | UPPTCL Shift Log | Logsheet + Defect Register if abnormal |
| External inspection (bushings, gaskets, radiators, conservator) | Quarterly | No oil leak, cracks, or corrosion visible | UPPTCL | Transformer Maintenance Register |
| Buchholz relay test (trip + alarm contacts) | Half-yearly | Both contacts operate correctly | UPPTCL | Transformer Maintenance Register |
| WTI / OTI calibration check | Half-yearly | Within ±2°C of reference | CBIP Guide | Transformer Maintenance Register |
| Oil BDV test | Yearly | ≥50 kV (132kV+); ≥40 kV (33–66kV) using 2.5mm gap per IS 335/IEC 60156 | IS 335, IEC 60156 | BDV Register: 6 readings, average |
| Insulation Resistance (IR) | Yearly | PI ≥1.5 (10-min/1-min ratio); any PI <1.0 = fail | IEC 60076, IS 2026 | IR/Megger Register |
| Turns Ratio Test (TTR) | Yearly | Deviation from nameplate <0.5% on all tap positions | IEC 60076 | Testing Register |
| Winding Resistance | Yearly | Compare with commissioning baseline; >2% deviation = investigate | IEC 60076 | Testing Register |
| Bushing Tan Delta / Capacitance | Yearly (HV OIP bushings) | Tan δ <0.7% new; <1.0% service per IEC 60137 | IEC 60137 | Testing Register |
| OLTC: contact resistance, oil, mechanism | Yearly (or per operation counter) | Per manufacturer specification | CBIP Guide 14 | OLTC Maintenance Register |
| Tan Delta — winding insulation | 3-yearly | <3% (varies with age/class) | IEC 60076 | Testing Register |
| Dissolved Gas Analysis (DGA) | Commissioning → 1 year → 3-yearly | C2H2 <5 ppm (normal); TDCG <720 ppm (normal); CO2/CO >7 (healthy cellulose) | IEC 60599 | DGA Register |
| Oil moisture content | 3–5 yearly or on indication | <15 ppm (in-service); >20 ppm = mandatory reconditioning | IEC 60422 | Oil Testing Register |
| Internal inspection (core + winding) | 5–7 yearly or after major fault | No carbonized insulation, no distorted coils | CBIP | Plant History Register |

**Critical DGA interpretation table (IEC 60599):**

| Gas | Normal (<720 TDCG) | Caution (720–1920 TDCG) | Action (>1920 TDCG) |
|-----|--------------------|------------------------|---------------------|
| C2H2 (Acetylene) | <5 ppm | 5–35 ppm | >35 ppm → take offline |
| H2 (Hydrogen) | <100 ppm | 100–700 ppm | >700 ppm |
| CO (Carbon monoxide) | <350 ppm | 350–570 ppm | >570 ppm |
| CO2/CO ratio | >7 = healthy | 5–7 = monitor | <5 = cellulose degradation |

### 3.2 Circuit Breakers (SF6 and VCB)

> **Source**: UPPTCL O&M Manual Section 2.6; IEC 60480, IEC 60376

| Test / Activity | Frequency | Pass / Fail Criteria | Standard | What to Record |
|----------------|-----------|---------------------|----------|---------------|
| Operation counter reading | Monthly | Log reading only | UPPTCL | Breaker Maintenance Register |
| Control cubicle cleaning, connection tightening | Monthly | No loose connections | UPPTCL | Maintenance Register |
| IR test (open position, same pole upper-to-lower) | Quarterly | >50 GΩ (VCB); investigate if below | UPPTCL | IR Register |
| Air leakage check (pneumatic CBs) | Quarterly | No visible/audible leakage | UPPTCL | Maintenance Register |
| Alarm & indication circuit check | Quarterly | All alarms and indications functional | UPPTCL | Maintenance Register |
| CB operation check (if not operated in 3 months) | Quarterly (trigger-based) | Successful O, C, CO operation | UPPTCL | Maintenance Register |
| Contact resistance measurement (100A DC micro-ohm meter) | Yearly | Per manufacturer; typical <100 μΩ for EHV CBs | IEC 62271 | Testing Register |
| Pole discrepancy relay test (220kV and above) | Yearly | Trip after 1.5 sec timer; pole discrepancy <3.33 ms design / <5 ms in-service | UPPTCL | Relay Test Register |
| Operation times (C, O, CO) — pole timing | Yearly | Between-break difference of same pole: ≤2.5 ms | UPPTCL | Testing Register |
| SF6 gas dew point measurement | Commissioning → 6 months → 1 year → every 2 years | ≤−5°C at rated pressure (per IEC 60480 table) | IEC 60480, IEC 60376 | SF6 Gas Register |
| Full overhaul | Per operation count (2,000–5,000 ops or X fault-MVA per manufacturer) | All wear parts replaced per manufacturer schedule | Manufacturer Manual | Plant History Register |

### 3.3 CT, CVT, and PT

> **Source**: UPPTCL; IEC 60044-1/-2/-5; IS 2705

| Test / Activity | Frequency | Pass / Fail Criteria | Standard |
|----------------|-----------|---------------------|----------|
| Visual inspection (oil level, porcelain condition) | Half-yearly | No cracks, oil seepage | UPPTCL |
| IR test (HV-to-secondary-and-earth; secondary-to-earth) | Yearly | >1000 MΩ (dry condition) | IEC 60044-1 |
| Ratio and polarity check | Yearly | Ratio within nameplate tolerance; polarity correct | IEC 60044-1 |
| Knee point voltage (protection CTs) | Yearly | Not degraded from commissioning value | IEC 60044-1 |
| Burden measurement | Yearly | Connected burden ≤ rated CT burden | IEC 60044-1 |
| Oil BDV (oil-filled CTs) | Yearly | Same limits as transformer oil (IS 335) | IS 335, IEC 60156 |
| Tan Delta / Capacitance (CVTs, oil CTs) | Yearly | Any >10% change from previous year = investigate | IEC 60044-5 |
| Secondary circuit IR | Yearly | No ground faults on secondary wiring | IEC 60044-1 |

### 3.4 Protective Relays

> **Source**: UPPTCL O&M Manual; IEC 60255 series; CEA Technical Standards for Protection

| Test / Activity | Frequency | Pass / Fail Criteria | Standard |
|----------------|-----------|---------------------|----------|
| Trip circuit healthiness check | Every shift (after each CB operation) | Trip circuit healthy indication on panel | UPPTCL |
| Annunciation lamp test | Monthly | All facia windows illuminate | UPPTCL |
| Secondary injection — overcurrent relay (pickup, TMS, time) | Yearly | Within ±5% of set value | IEC 60255-151 |
| Secondary injection — earth fault relay | Yearly | Within ±5% of set value | IEC 60255-151 |
| Secondary injection — distance relay (zone 1, 2, 3 reach) | Yearly | Within ±5% of reach setting | IEC 60255-121 |
| Secondary injection — differential relay (operate/restrain) | Yearly | Correct operation in operate zone; stable in restrain | IEC 60255-187 |
| Buchholz relay functional test | Yearly | Alarm and trip contacts operate at correct float position | CBIP Guide |
| OTI/WTI alarm and trip contact test | Yearly | Contacts operate within ±2°C of set temperature | CBIP Guide |
| Auto-reclose relay timing test | Yearly | Dead time and reclaim time within ±50 ms of setting | IEC 60255 |
| End-to-end scheme test (differential, distance) | 3-yearly | Correct tripping at both ends; correct time coordination | IEC 60255 |
| Full settings audit and coordination review | 3-yearly | All settings per approved protection philosophy | CEA Tech Standards |
| Numerical relay: setting file backup, firmware version log | At each test and after any setting change | File backed up and version logged | IEC 60255 |

### 3.5 Earthing System

> **Source**: IS 3043; CEA Safety Regulations 2010 (STATUTORY requirement for annual measurement)

| Test / Activity | Frequency | Pass / Fail Criteria | Standard |
|----------------|-----------|---------------------|----------|
| Visual check of earth connections and bonds | Monthly | No broken bonds, loose clamps | IS 3043 |
| Earth resistance measurement (fall-of-potential method) | Yearly | Main earth mat: ≤1 Ω; Tower footing: ≤10 Ω general, ≤5 Ω critical lines | IS 3043, CEA Safety Regs 2010 |
| Tower footing resistance (normal locations) | Every 2 years | ≤10 Ω | POWERGRID / UPPTCL |
| Tower footing resistance (critical locations) | Yearly | ≤5 Ω | POWERGRID standard |
| Earth mat continuity check | Yearly | All bonds continuous (< test instrument sensitivity) | IS 3043 |

### 3.6 Battery and DC System

> **Source**: UPPTCL; IEEE 1188; IEC 60896

| Test / Activity | Frequency | Pass / Fail Criteria | What to Record |
|----------------|-----------|---------------------|---------------|
| Float charge voltage (overall bus) | Daily | 110V / 220V DC ±5% (per design) | Battery Maintenance Register (daily) |
| Pilot cell specific gravity (flooded type) | Daily | 1.200–1.215 at 27°C | Battery Maintenance Register |
| Individual cell voltage (float) | Monthly | No cell <1.95 V; typical 2.20–2.27 V/cell | Battery Maintenance Register (monthly) |
| Specific gravity all cells (flooded type) | Monthly | 1.200–1.215; <1.190 → recharge; <1.180 → investigate | Battery Maintenance Register |
| Electrolyte level check and distilled water top-up | Monthly | Plates covered; not overflowing | Battery Maintenance Register |
| Inter-cell connector corrosion/tightness | Monthly | Clean and tight | Battery Maintenance Register |
| Capacity/Discharge Test (C10 10-hour rate) | Yearly | ≥80% rated Ah capacity; <80% = replace bank | Battery Maintenance Register (yearly) |
| Battery room: ventilation, temperature, eyewash check | Yearly | H2 build-up prevention; eyewash functional | Safety Register |
| Impedance/conductance health test | 3-yearly | Compare with baseline; declining trend = replace | Battery Maintenance Register |

### 3.7 Lightning Arresters

> **Source**: UPPTCL; IEC 60099-4

| Test / Activity | Frequency | Pass / Fail Criteria |
|----------------|-----------|---------------------|
| Surge counter ammeter reading (Register 18) | Daily (every shift) | Log value; trend analysis |
| Visual inspection: porcelain/polymer, mounting, earth | Half-yearly | No cracks, carbon tracks, or loose earthing |
| IR test (HV-to-earth) | Yearly | ≥1000 MΩ (dry/clean condition) |
| Leakage current measurement (online monitoring) | Yearly | Resistive component <1 mA; >1 mA = investigate |
| Thermal imaging | Yearly | No hot spots; hotspot >10°C above ambient = investigate |
| Pressure relief vent inspection (porcelain type) | Yearly | Diaphragm intact |

### 3.8 Capacitor Banks

| Test / Activity | Frequency | Pass / Fail Criteria | Standard |
|----------------|-----------|---------------------|----------|
| Visual inspection (bulging, oil seepage) | Monthly | No bulging or leaks | CBIP Guide 6 |
| Capacitance measurement per unit | Yearly | Deviation ≤5% from nameplate | IEC 60871 |
| IR test per unit | Yearly | Adequate IR (per IEC 60871) | IEC 60871 |
| Structural inspection and fuse condition | Yearly | No corrosion; fuses intact | CBIP Guide 6 |
| Insulator cleaning (pollution zones) | Half-yearly to yearly | Clean, no tracking marks | CBIP Guide 6 |

### 3.9 Insulators

| Test / Activity | Frequency | Pass / Fail Criteria |
|----------------|-----------|---------------------|
| Visual inspection (binoculars from ground) | Half-yearly (post-monsoon mandatory) | No flashover marks, chips, cracks |
| IR test (string insulators — 5kV Megger) | Yearly | >1000 MΩ per disc under dry conditions |
| Cleaning (normal pollution zone) | Yearly | Clean surface, no tracking |
| Cleaning (critical pollution zone) | Twice yearly | Clean surface |
| Thermovision scan (jumpers, spacer-dampers) | Yearly | No hotspots >10°C above ambient |

### 3.10 Isolators

| Test / Activity | Frequency | Pass / Fail Criteria |
|----------------|-----------|---------------------|
| Visual and mechanical inspection | Yearly | Blade alignment correct; jaw contact engagement proper |
| Contact resistance measurement (micro-ohm meter) | Yearly | Per manufacturer; typical <200 μΩ for EHV |
| Lubrication of moving parts and pivot pins | Yearly | Smooth operation, no stiffness |
| Interlock check (mechanical + electrical) | Yearly | No bypass possible; interlock prevents unsafe operation |
| Earth switch operation and interlock check | Yearly | Earth switch interlock prevents operation when main closed |

### 3.11 Cables

| Test / Activity | Frequency | Pass / Fail Criteria | Standard |
|----------------|-----------|---------------------|----------|
| IR test on installation / after major work | At installation | >100 MΩ (HV cables); >1000 MΩ·km (LT) | IEC 60229 |
| HV pressure test (DC or AC hipot) | After major repair | Per cable rating and IEC specification | IEC 60229 |
| IR test (critical feeders) | Yearly | Same as installation limits | IEC 60229 |
| Thermal imaging of terminations and joints | Yearly | No hotspots | — |
| Visual inspection of trenches/ducts | Yearly | No water ingress, rodent damage | — |

---

## 4. Permit to Work (PTW) System

### 4.1 Statutory Basis

The PTW system is mandated under **CEA (Measures Relating to Safety and Electric Supply) Regulations 2010, Regulation 30** — this is a STATUTORY requirement, not merely TRANSCO best practice. Rule 44 of the Indian Electricity Rules 1956 further requires that only qualified persons operate EHV systems.

### 4.2 Three Safety Document Types (UPPTCL Section 6)

| Document | When Used | Issued By |
|----------|----------|-----------|
| Permit to Work (PTW) | Work on fully isolated and earthed equipment | Shift Engineer (SE) |
| Permit to Test | Testing involving application of test voltages | Shift Engineer (SE) |
| Caution Notice | Work near (not on) live equipment — demarcation only | SE / JE |

### 4.3 PTW Workflow — Complete 7-Step Process

**Step 1: Outage Request**
- Work requesting authority fills Shutdown Request form (feeds Register 9a)
- Submitted to ALDC/SLDC minimum **24 hours in advance** for planned outages (IEGC requirement; **72 hours** for 400kV and above)
- ALDC/SLDC approves and schedules shutdown window; assigns reference number
- Database fields: `shutdown_request_id`, `equipment_id`, `requested_by`, `requested_datetime`, `requested_outage_start`, `requested_outage_end`, `work_description`, `aldc_sldc_ref`, `approval_status`, `approved_by_sldc`

**Step 2: System Isolation**
- SE gets shutdown permission from ALDC/SLDC (reference number logged)
- Trip CB of equipment to be maintained (mimic board trip indication verified)
- Open all isolators on both sides
- Close Earth Switches (both sides)
- Physically lock isolators in OPEN position (padlock + tag)
- Confirm no back-feed path; verify busbar voltage gone
- Database fields: `isolation_step_id`, `ptw_id`, `action_type`, `action_datetime`, `done_by`, `confirmed_by`, `aldc_permission_ref`

**Step 3: Earthing**
- Apply temporary earthing rods at work site — minimum three (one each side + one at work location)
- Record all earthing points in PTW form
- Database fields: `temp_earth_id`, `ptw_id`, `location_description`, `applied_by`, `applied_datetime`, `removed_by`, `removed_datetime`

**Step 4: Issue PTW**
- SE fills PTW form (Register 9b)
- Original handed to person in charge of work; duplicate retained in PTW register
- PTW number is sequential machine-number

**Step 5: Work Execution**
- Work only within demarcated area
- Caution notices on adjacent live equipment
- No second PTW on same equipment while one is active

**Step 6: PTW Return**
- Person in charge confirms work complete, all staff clear
- Returns PTW to SE: signed and dated
- SE cancels PTW in register; enters return time

**Step 7: Re-energization**
- Verify all temporary earths removed (checklist)
- Verify all tools and persons clear
- Open Earth Switches
- Close isolators (nearest first)
- Get ALDC/SLDC permission to charge
- Close CB
- Notify ALDC/SLDC: equipment returned to service
- Update Stoppage Register with restoration time

### 4.4 PTW Register (Register 9b) — Field-Level Database Schema

| Field Name | Data Type | Notes |
|-----------|-----------|-------|
| ptw_number | VARCHAR(20) | Sequential; machine-numbered |
| issue_datetime | DATETIME | |
| equipment_id | FK → equipment | |
| voltage_level_kv | INTEGER | |
| isolation_points | TEXT / JSON | Array of CB/isolator IDs opened |
| earthing_points | TEXT / JSON | Array of earth switch IDs + temp earth locations |
| safety_precautions | TEXT | Free text — specific to job |
| person_in_charge | FK → staff | |
| valid_from | DATETIME | |
| valid_to | DATETIME | PTW cannot be extended beyond this without re-issue |
| issued_by_se | FK → staff | Shift Engineer |
| issued_by_signature | TEXT | Digital signature |
| return_datetime | DATETIME | Filled when work completes |
| returning_person_signature | TEXT | |
| se_acknowledgment_signature | TEXT | |
| equipment_restored_datetime | DATETIME | |
| aldc_sldc_permission_ref | VARCHAR(50) | Mandatory — ALDC/SLDC sanction number |
| shutdown_request_id | FK → shutdown_requests | Link to Register 9a |
| stoppage_register_id | FK → stoppages | Auto-link to Register 11 entry |

### 4.5 Key PTW Safety Rules

1. Confirmation before PTW issue is mandatory — no pre-arranged signals or time intervals
2. Isolation and earthing must be CONFIRMED (not assumed) before PTW issue
3. No second PTW on same equipment while one is active
4. When induced voltage risk exists: additional temporary earths mandatory
5. PTW must not be extended beyond original validity — re-issue required

### 4.6 Integration with ALDC/SLDC Outage Management

The ERP must implement a bi-directional interface with SLDC/ALDC:
- **Outbound**: Shutdown request with equipment ID, voltage level, start/end time, work type
- **Inbound**: Approval confirmation with SLDC reference number and approved window
- **Outbound on restoration**: Equipment back-in-service notification with actual time
- This interface drives the Stoppage Register (Register 11) which feeds SERC reliability reporting

---

## 5. Safety and Statutory Compliance

### 5.1 Statutory Framework

| Law / Regulation | Key Provisions for Substations |
|-----------------|-------------------------------|
| Electricity Act 2003, Section 53 | CEA shall specify safety requirements for electrical plants |
| Electricity Act 2003, Section 161 | CEA and Electrical Inspectors (CEIG) may inspect any substation |
| Indian Electricity Rules 1956, Rule 44 | Only qualified persons may operate EHV systems |
| Indian Electricity Rules 1956, Rule 46 | All EHV substations must have an approved Safety Manual |
| Indian Electricity Rules 1956, Rule 67 | Earthing requirements; protection against electrical shock |
| Indian Electricity Rules 1956, Rule 68 | Mandatory warning notices, caution boards, safety signs |
| **CEA Safety Regulations 2010, Reg. 3** | All electrical installations maintained in safe condition |
| **CEA Safety Regulations 2010, Reg. 30** | Safe working procedures and PTW system mandated for EHV |
| **CEA Safety Regulations 2010, Reg. 31** | Personal Protective Equipment (PPE) requirements |
| **CEA Safety Regulations 2010, Reg. 46** | Accident and dangerous occurrence reporting obligations |

### 5.2 Staff Qualification Requirements

| Role | Minimum Qualification | Basis |
|------|-----------------------|-------|
| Shift Engineer (SE / Shift In-Charge) | Degree in Electrical Engineering + CEA Competency Certificate for EHV | CEA Safety Regs 2010 / IER Rule 44 |
| Assistant Engineer (Maintenance) | Degree or Diploma in Electrical Engineering | CEA / TRANSCO rules |
| Junior Engineer (Operation/Maintenance) | Diploma in Electrical Engineering | CEA / TRANSCO rules |
| Sub-Station Operator (SSO) | ITI Electrician + State Licensed Electrician certificate | Indian Electricity Rules 1956 |
| Lineman | ITI Electrician / Wireman License under IER | Indian Electricity Rules 1956 |

**ERP implication**: The Authorization Register (Register 12) must be linked to staff qualification records. The system must prevent issuing a PTW unless the issuing officer holds a valid competency certificate.

### 5.3 Accident Reporting Requirements (CEA Safety Regulations 2010, Reg. 46)

| Event Type | Report To | Timeline |
|-----------|----------|----------|
| Any electrical accident (fatal or injurious) | Chief Electrical Inspector to Government (CEIG) of state | Verbal within **24 hours**; written within **48 hours** |
| Dangerous occurrence (major equipment failure, fire, near-miss) | CEIG | Same as above |
| Supply failure (>10 MW or >1 lakh consumers per state norms) | SLDC + SERC | Immediate notification + detailed report |

**Important**: Evidence must be preserved — supply must NOT be restored until the CEIG permits (except where life safety requires immediate action).

**Accident Register minimum fields**: `accident_id`, `datetime`, `location`, `equipment_id`, `persons_involved`, `injury_nature`, `immediate_cause`, `root_cause`, `corrective_action`, `reported_to_ceig_datetime`, `ceig_clearance_datetime`

### 5.4 Physical Safety Requirements (CEA Safety Regulations 2010 / DESCOBERT)

| Requirement | Specification | Statutory Basis |
|-------------|---------------|-----------------|
| Danger boards | "HIGH VOLTAGE — KEEP AWAY" at all equipment | IER Rule 68 |
| Rubber mats | In front of all LT panels, control panels, battery chargers | CEA Safety Regs 2010, Reg. 31 |
| Rubber gloves and boots | Mandatory PPE for anyone entering live switchyard | CEA Safety Regs 2010, Reg. 31 |
| First aid kit | Control room; trained first-aider on every shift | CEA Safety Regs 2010 |
| Fire extinguishers | CO2 near transformer and electrical panels; sand buckets in switchyard | CEA Safety Regs 2010 |
| Emergency contacts display | ALDC/SLDC, AE, EE, CE, Fire Brigade in control room | UPPTCL O&M Manual |
| Safe approach distances | 400kV: 3.70 m; 220kV: 2.60 m; 132kV: 1.90 m | IER Rule 44 + Schedule |
| Safety Manual at substation | Approved by AE/EE; updated; accessible | IER Rule 46 |

---

## 6. Reliability Indices and Performance KPIs

### 6.1 Transmission Reliability — CERC Mechanism

**Primary metric for transmission**: Availability (%)

**Formula**: `Availability = (Scheduled Hours − Forced Outage Hours) / Scheduled Hours × 100`

Per CERC Transmission Tariff Regulations 2019:
- **Normative availability target**: **≥98.5%** for inter-state transmission lines and substations
- Availability ≥98.5%: Full transmission charge paid + incentive for each 0.1% above 98.5%
- Availability <98.5%: Proportional deduction in transmission charge

POWERGRID (central TRANSCO) typically achieves 99.5%+. State STUs (e.g., UPTCL) typically achieve 95–98%.

**ERP implication**: The Availability KPI must be computed from Stoppage Register data (Register 11) automatically at month-end, expressed per element (line or substation bay), and submitted to SLDC/CERC.

### 6.2 Distribution Reliability — SAIDI, SAIFI, CAIDI

> Used by DISCOMs; targets set by each state SERC in tariff orders.

**SAIDI (System Average Interruption Duration Index)**
- `SAIDI = Σ(Interrupted_Customers_i × Duration_hr_i) / Total_Customers`
- Unit: hours per customer per year

**SAIFI (System Average Interruption Frequency Index)**
- `SAIFI = Σ(Interrupted_Customers_i) / Total_Customers`
- Unit: interruptions per customer per year

**CAIDI (Customer Average Interruption Duration Index)**
- `CAIDI = SAIDI / SAIFI`
- Unit: hours per interruption

| State | DISCOM | SAIDI Urban Target | SAIFI Urban Target | Source |
|-------|--------|-------------------|-------------------|--------|
| Maharashtra | MSEDCL | 4 hr/yr | 6 | MERC MYT Order |
| Uttar Pradesh | UPPCL/DISCOMs | 8 hr/yr | 10 | UPERC Tariff Order |
| Karnataka | BESCOM | 3 hr/yr | 5 | KERC Order |
| Delhi | BRPL/BYPL | <2 hr/yr | <5 | DERC Order |
| Telangana | TSSPDCL | 5 hr/yr | 8 | TSERC Order |
| Andhra Pradesh | APDISCOMs | 6 hr/yr | — | APERC Order |

**Rural targets** are typically 2–3x the urban targets; each SERC specifies separately in its Multi-Year Tariff (MYT) order.

### 6.3 AT&C Loss Targets

AT&C (Aggregate Technical and Commercial) losses = T&D technical losses + billing losses + collection losses.

Formula: `AT&C Loss % = (Input Energy − Billed and Collected Energy) / Input Energy × 100`

| Scheme | Target | Timeline |
|--------|--------|----------|
| RDSS (Revamped Distribution Sector Scheme) | AT&C ≤15% for eligible DISCOMs | 2021–2026 |
| UDAY (Ujwal DISCOM Assurance Yojana) | Defined per state MoU | 2015–2020 (ongoing monitoring) |
| MoP National Electricity Plan | AT&C reduction roadmap | Rolling 5-year plans |

### 6.4 Computing Indices from ERP Data

| Index | Input Tables in ERP | Computation |
|-------|---------------------|-------------|
| Transmission Availability | stoppage_register (Register 11): forced_outage_hrs per element per month | (Scheduled_hrs − forced_outage_hrs) / scheduled_hrs × 100 |
| SAIDI | stoppage_register + consumer_count_per_feeder | Σ(consumers_affected × duration_hr) / total_consumers |
| SAIFI | stoppage_register + consumer_count_per_feeder | Σ(consumers_affected) / total_consumers |
| AT&C Loss | energy_account_register (Register 8) + billing_data + collection_data | (input_kwh − collected_kwh) / input_kwh × 100 |
| T&D Technical Loss | energy_account_register | (import_mwh − export_mwh − aux_mwh) / import_mwh × 100 |

---

## 7. Energy Accounting and Grid Code

### 7.1 Energy Account Register — Computation (Register 8, UPPTCL)

Readings taken at **8:00 AM daily** (UPPTCL standard). Monthly energy balance computed at month-end.

**Per Feeder / Transformer:**

| Column | Description |
|--------|-------------|
| feeder_id | Feeder / transformer identifier |
| direction | Import / Export |
| prev_month_reading | Meter reading at 8:00 AM on 1st of previous month (kWh) |
| curr_month_reading | Meter reading at 8:00 AM on 1st of current month (kWh) |
| difference | curr − prev |
| multiplying_factor | CT ratio × PT ratio (dimensionless multiplier) |
| net_energy_mwh | (difference × multiplying_factor) / 1000 |

**Monthly Balance (computed fields):**

| Computation Step | Field Name | Formula |
|----------------|-----------|---------|
| Total input (A) | total_input_mwh | Σ net_energy_mwh (import) |
| Colony + aux consumption | aux_mwh | Separate sub-meter |
| Energy to consumers (direct) | direct_consumer_mwh | From billing system |
| Total export to Transmission (B) | total_export_mwh | Σ net_energy_mwh (export) |
| Difference | loss_mwh | A − B |
| Loss percentage | loss_pct | (A − B) / A × 100 |

Signed by JE(M)/AE(M). Submitted to ALDC/SLDC by 5th of following month.

### 7.2 ABT Metering Requirements (CERC Metering Regulations 2006)

**Meter types by application:**

| Application | Meter Type | Accuracy Class | Redundancy |
|-------------|-----------|---------------|------------|
| Inter-state ABT boundary | Trivector / Multi-function ABT meter | Class 0.2S (per CERC) | Main + Check + Standby |
| 33kV state boundary | Trivector meter | Class 0.5 | Main + Check |
| 11kV feeder (DISCOM) | Static energy meter | Class 1.0 | Main |
| Consumer LT | Static electronic meter | Class 1.0 or 2.0 | Main |

**Time synchronization**: GPS clock synchronization to IST within **30 seconds** (CERC Metering Regulations 2006 requirement). This is a hard technical requirement for the SCADA/RTU system the ERP interfaces with.

### 7.3 ABT / DSM Framework (CERC DSM Regulations 2014)

The Deviation Settlement Mechanism (DSM) replaced the old UI charge mechanism. For generating stations and large consumers:

| Frequency Band | DSM Rate Direction | Financial Impact |
|---------------|-------------------|-----------------|
| >50.05 Hz | Lower DSM rate for generation | Incentive to reduce generation |
| 49.90–50.05 Hz | Standard settlement rate | Neutral |
| <49.90 Hz | Higher DSM rate for drawal | Penalty for excess drawal |

**Deviation limit**: ±12% of scheduled drawal without higher penalty. Beyond ±12%: enhanced penalty rate applies.

**ERP implication**: The energy accounting module must capture 15-minute scheduled MW, actual MW (from ABT meter), and compute deviation for each block. Monthly DSM settlement statement is submitted to SLDC/RLDC.

### 7.4 Indian Electricity Grid Code (IEGC) — Operating Standards

**Frequency standards (IEGC 2010, amended 2023, Schedule 5):**

| Frequency Band | Status | Required Action |
|---------------|--------|----------------|
| 50.05–50.20 Hz | Over-frequency | Generating stations reduce output; loads increase |
| 49.95–50.05 Hz | Normal band | No action |
| 49.90–49.95 Hz | Under-frequency caution | Initiate load shedding |
| 49.50–49.90 Hz | Under-frequency emergency | UFLS (Under Frequency Load Shedding) auto-trip |
| <49.0 Hz | Severe emergency | All possible load shedding; grid separation risk |

**Voltage standards (IEGC Schedule 6):**

| Voltage Level | Minimum (kV) | Maximum (kV) |
|--------------|-------------|-------------|
| 400 kV | 380 | 420 |
| 220 kV | 200 | 245 |
| 132 kV | 121 | 145 |
| 66 kV | 63 | 72 |
| 33 kV | 30.25 | 36.3 |

### 7.5 SLDC Reporting Requirements

| Report | Deadline | Content |
|--------|----------|---------|
| Hourly generation/drawal data | Real-time via SCADA/RTU (phone backup if SCADA fails) | MW, MVAR per unit |
| Day-ahead schedule | By 10:00 AM for next day | Hour-block MW schedule |
| Forced outage notification | Within **15 minutes** of occurrence | Equipment, cause, estimated restoration time |
| Planned outage notification | **24 hours** in advance (132kV and below); **72 hours** (400kV and above) | Equipment ID, window, work description |
| Monthly energy statement | By **5th of following month** | Energy account (Register 8 data) |
| Monthly reliability report | By **5th of following month** | Availability %, tripping summary, SAIDI/SAIFI |

### 7.6 Monthly Energy Statement — Column Structure

| Column | Source |
|--------|--------|
| Substation name | Master data |
| Voltage level | Master data |
| Feeder / transformer name | Master data |
| Energy meter serial no. | Asset register |
| Reading at start of month | Register 8 |
| Reading at end of month | Register 8 |
| Multiplying factor | Register 8 |
| Net energy (MWh) | Computed |
| Direction (import/export) | Register 8 |
| Verified signature | JE(M)/AE(M) |
| Submitted to SLDC date | Workflow |

---

## 8. ERP Module Mapping

### 8.1 Complete Module Map

| Regulatory Requirement | ERP Module | Key Implementation |
|----------------------|-----------|-------------------|
| 19+ mandatory registers | **Records Management** | Digital register pages with machine-number simulation, mandatory signature workflows, audit trail, retention policy enforcement |
| Hourly / 4-hourly logsheet | **Operations Logbook** (SCADA integration) | Auto-populate from SCADA readings; allow manual entry with timestamp; alarm flags for out-of-band values; shift handover workflow |
| 15-minute ABT block data | **Energy Accounting / ABT Module** | Meter data acquisition interface (MDI); 15-min block storage; GPS time sync verification |
| Equipment test schedules | **Preventive Maintenance (PM)** | Work order engine driven by calendar + operation counter triggers; test result entry forms with pass/fail logic; auto-escalation on fail |
| Defect management | **Corrective Maintenance (CM)** | Defect entry from field (mobile app); work order creation; parts requisition; closure with root cause |
| PTW system | **Outage Management + PTW** | 7-step workflow with digital approvals; integration to SLDC interface; auto-populate Stoppage Register; prevent PTW issue if equipment not isolated |
| Shutdown coordination | **Outage Scheduling** | SLDC submission interface; 24/72-hr advance notification; outage window management; N-1 security awareness |
| Staff qualification / authorization | **HR + Competency Management** | Qualification certificates with expiry; authorization matrix per equipment; PTW issue locked to qualified SE |
| Accident reporting | **Safety & Compliance** | Accident register with 24/48-hr CEA reporting workflow; CEIG notification auto-draft; evidence preservation lock on equipment |
| Energy balance (Register 8) | **Energy Accounting** | Daily 8:00 AM meter reading capture; monthly balance computation; loss % calculation; SLDC submission workflow |
| SAIDI / SAIFI computation | **Reliability Analytics** | Auto-compute from Stoppage Register + consumer count master; monthly SERC report generation |
| Transmission availability | **Reliability Analytics** | Auto-compute per element from Stoppage Register; CERC incentive/disincentive calculation |
| AT&C loss reporting | **Energy Accounting + Billing Interface** | Integration with billing system; AT&C loss computation; RDSS/UDAY portal submission |
| DGA / oil test trending | **Predictive Maintenance** | Gas concentration trend charts; TDCG condition alerts; auto work order on threshold breach |
| Relay settings management | **Protection Management** | Setting file version control; firmware log; end-to-end test scheduling; settings audit workflow |
| Drawings management | **Document Management** | Bay-wise drawing register; revision control; mandatory read-before-work acknowledgment |
| Rostering / load shedding | **Operations — Rostering Module** | Load shedding programme receipt from SLDC; communication to field; compliance recording in Register 15 |
| DSM / deviation settlement | **Commercial / Energy Trading Interface** | 15-min schedule vs actual; deviation computation; DSM rate table; monthly settlement statement |

### 8.2 Critical Integration Points

| Integration | Direction | Protocol / Standard |
|-------------|-----------|---------------------|
| SCADA / RTU → ERP | Inbound | IEC 60870-5-104 or DNP3; real-time MW, MVAR, voltage, CB status |
| ERP → SLDC (outage management) | Outbound | SLDC-specific web service (varies by state); email + phone backup |
| ABT meter → ERP | Inbound | Meter data acquisition; IEC 62056 (DLMS/COSEM) or proprietary |
| ERP → CERC portal | Outbound | CERC WRIS / SRMS portal API |
| ERP → SERC / MoP portal | Outbound | State-specific; RDSS portal API for loss data |
| ERP → Billing system | Bi-directional | Input energy for billed unit reconciliation |
| ERP → Financial system | Outbound | Transmission charge / DSM settlement data |

### 8.3 Database Design Principles

1. **Equipment Master table** is the hub: every register entry, test record, logsheet reading, PTW, and tripping record must foreign-key to `equipment_id`. This enables plant history reconstruction per equipment at any time.

2. **Time-series partitioning**: Logsheet readings (hourly/15-min) are high-volume. Partition by `reading_date` monthly. Retain minimum 5 years online; archive to cold storage thereafter.

3. **Immutability for statutory records**: Register entries, once signed, must be immutable. Implement append-only with correction mechanism (new row with `supersedes_id` reference). This mirrors the paper register intent of machine-numbered pages.

4. **Multiplying factors as configuration**: Energy meter multiplying factors change when CTs or PTs are replaced. Store `mf_history` table with `effective_from` and `effective_to` dates per meter. All energy computations must join on the correct MF for the reading date.

5. **State/SERC configuration tables**: SAIDI/SAIFI targets, voltage bands, frequency bands, and DSM rate tables all vary by state and are revised periodically. These must be configuration tables, not hardcoded, to support multi-state deployments.

6. **PTW state machine**: PTW states are: `DRAFT → REQUESTED → SLDC_APPROVED → ISOLATION_CONFIRMED → EARTHING_CONFIRMED → ISSUED → ACTIVE → RETURNED → CANCELLED → EQUIPMENT_RESTORED`. Transitions must be gated by role/qualification checks.

---

## Conclusion

Building a compliant ERP for Indian power utilities requires treating the **UPPTCL O&M Manual and CEA Safety Regulations 2010 as the primary specification documents**, not as advisory inputs. The 19 mandatory registers, each with its specific field structure, define the minimum viable data model. The equipment-specific test schedules, with their IEC/IS standard-derived pass/fail limits, define the preventive maintenance engine logic. The IEGC voltage and frequency bands are configuration constants that must be stored as reference data, not hardcoded, to accommodate CERC/SERC amendments.

The single most consequential architectural decision is the integration design between the ERP's Outage Management / PTW module and the SLDC communication interface. Every planned outage flows through this channel in both directions — shutdown request out, SLDC approval in, restoration notification out — and failures here directly affect both safety compliance (CEA Regulations 2010) and commercial performance (CERC transmission availability incentives). A utility that cannot demonstrate a complete, timestamped, ALDC/SLDC-referenced PTW audit trail for every equipment outage is exposed to statutory liability under the Electricity Act 2003 and financial disincentive under CERC tariff regulations simultaneously. Getting this module right is the make-or-break deliverable of the entire ERP.
