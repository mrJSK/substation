# Equipment Testing & Maintenance Schedules

**Primary Source**: UPPTCL Best O&M Practices Manual (2020) + IEC/IS standards + POWERGRID maintenance practices

---

## 1. Circuit Breaker Maintenance Schedule (UPPTCL Section 2.6)

### Monthly Maintenance
- Record operation counter reading
- Cleaning and checking of Control Cubicle; tighten all connections therein

### Quarterly Maintenance
- Measurement of Insulation Resistance between upper and lower terminals of same pole (VCB, CB open position) — **acceptable: >50 GΩ**
- Check air leakage from storage tank and pipe joints (pneumatic operated CBs); check V-belt tension of air compressor; replace if required
- Check Alarm & Indication circuits
- Check/clean/tighten control & relay panel wiring
- Check CB operation (through protection system) if not operated in last 3 months

### Half-Yearly Maintenance
- Tightening of clamps, fixtures, jumpers; linkages and rods in mechanism
- Maintenance of Air Compressor

### Yearly Maintenance
- Check pole discrepancy relay (220kV and above)
- Check operation times (C, O, C-O) — **pole discrepancy limit: 3.33 ms (design), 5 ms (in-service O&M)**; difference between two breaks of same pole: 2.5 ms
- Check all operational lockouts (SF6 gas lockout, pneumatic lockout, hydraulic lockout)
- Measurement of Contact Resistance (100A DC micro-ohm meter)

### Trip/Operation Based (Manufacturer's O&M manual)
- After specified number of fault interruptions: major overhauling
- SF6 CB: full overhaul per manufacturer schedule (typically after 2000–5000 operations or X fault MVA interrupted)

### SF6 Gas Dew Point Measurement (IEC 480 / IEC 60376)
- At commissioning
- After 6 months
- After 1 year
- Once every **2 years** thereafter
- Acceptable limit: typically −5°C dew point at rated pressure (convert to atmospheric pressure per IEC 480 table)
- Gas pressure settings: alarm and lockout within 0.1 bar (kg/cm²) of set value

---

## 2. Transformer Maintenance Schedule (UPPTCL Sections 1.1–1.20)

### Daily (Shift Log – every shift/every 4 hours)
- Winding temperature (°C) — fans start AUTO at **60°C winding temperature**
- Oil temperature (°C) — check vs load and ambient
- Oil level in conservator — corresponds to oil temperature marking on MOG (Magnetic Oil Gauge)
- Oil level in sight glass (air cell type conservator) — should be full
- Silica gel colour in breather — **must be blue**; if changed, report to AE(M)/JE(M)
- Oil level in breather oil cup — maintain to marked level
- Diaphragm of relief vent pipe — must be intact
- No oil in sight glass of relief vent pipe
- Fan/pump operation at rated temperature
- Sound/vibration — any abnormality reported immediately
- OLTC position (tap position) — recorded
- Load (MW/MVAR/MVA) vs rated capacity — overloading NOT permitted

### Quarterly Maintenance (Transformer Register)
- External inspection: oil samples, bushing inspection, gasket check, radiator fins, conservator
- Check all terminal connections for tightness
- Cleaning of insulators and bushings
- Check marshalling kiosk/control panel: door seals, lights, heaters, thermostats, alarm annunciator
- Check cooling fans: visual for contamination, moisture, bearing noise, rotation, corrosion
- Check oil pumps: rotation, vibration, electrical connections

### Half-Yearly Maintenance (Transformer Register)
- Comprehensive internal inspection preparation checks
- Buchholz relay test (trip and alarm contacts function)
- Oil filtration decision based on BDV results
- Pressure Relief Device (PRD) / Relief Vent Pipe inspection
- WTI/OTI calibration check

### Yearly Maintenance (Transformer Register)
- **Oil BDV Test (IS 335 / IEC 60156)**: Minimum acceptable: **60 kV (new oil)**, **40 kV (service oil at 33kV/66kV)**, **50 kV (at 132kV and above)** using 2.5 mm gap stirred sample
- **Insulation Resistance (IR) / Polarization Index**: HV-to-LV-and-Earth, LV-to-HV-and-Earth; PI (10-min/1-min ratio) should be **>1.5** (minimum acceptable)
- **Turns Ratio Test (TTR)**: All tap positions; deviation from nameplate **<0.5%** acceptable
- **Winding Resistance**: Compare with commissioning values; deviation indicates OLTC contact problem or winding fault
- **Bushing Tan Delta / Capacitance**: Annual for HV bushings (OIP type); tan delta **<0.7%** (new), **<1.0%** (service) per IEC 60137
- **OLTC Maintenance**: Contact resistance check, oil change (per operation counter), mechanism inspection, overhauling per manufacturer schedule

### 3-Yearly (Major Checks)
- **Tan Delta / Power Factor of winding insulation**: Transformer de-energized; max acceptable tan delta **<3%** (varies with insulation class and age)
- Complete OLTC overhaul including contact replacement

### 5-Yearly (or on indication)
- **Dissolved Gas Analysis (DGA) — IEC 60599**: Sample analysis for H2, CH4, C2H2, C2H4, C2H6, CO, CO2
  - Key gas method: C2H2 >5 ppm indicates arcing; CO2/CO ratio <7 indicates cellulose degradation
  - TDCG (Total Dissolved Combustible Gas): Normal <720 ppm; Caution 720–1920 ppm; Action >1920 ppm
  - Schedule: On commissioning, then at 1 year, then every 3 years (more frequent if trends indicate)
- **Oil Moisture Content (IEC 60422)**: Maximum 15 ppm (in-service EHV transformer oil); above 20 ppm: oil reconditioning required
- **Internal Inspection**: Every 5–7 years or after a major fault; core and winding inspection

---

## 3. CT, CVT, and PT Maintenance Schedule

### Half-Yearly
- Visual inspection: oil level (oil-type CTs), porcelain/polymer condition, gasket condition
- Surge counter ammeter reading (for CVTs with surge counters)

### Yearly (CT/CVT/PT Maintenance Register)
- **Insulation Resistance Test**: HV-to-secondary-and-earth, secondary-to-earth; minimum 1000 MΩ under dry conditions
- **Ratio and Polarity Check**: Verify ratio matches nameplate; check polarity for protection CTs
- **Knee Point Voltage (Protection CTs)**: Verify Vk not degraded from commissioning value
- **Burden Measurement**: Verify connected burden within CT rated burden
- **Oil BDV (Oil-filled CTs)**: Same limits as transformer oil
- **Tan Delta / Capacitance (CVTs and oil CTs)**: Compare with previous year; any >10% change warrants investigation
- **Secondary Circuit IR**: CT secondary wiring IR test

---

## 4. Protective Relay Testing Schedule

### Monthly
- Check trip circuit healthiness for ALL panels (after assuming shift, and after every CB operation)
- Check annunciation panel/facia by pressing lamp test push button — all windows must light up

### Yearly (Relay Test Register)
- **Secondary Injection Testing**: Apply test currents to verify pickup, time-delay, and tripping of each protection function
  - Overcurrent relay: pickup value, time-multiplier setting verification
  - Earth fault relay: verification of setting
  - Distance relay: zone 1, 2, 3 reach verification
  - Differential relay: operate and restrain zone verification
  - Buchholz relay: alarm and trip contact function test
  - Temperature relay (OTI/WTI): alarm and trip settings
  - Auto-reclose relay: timing and functional test
  - Pole discrepancy relay: per UPPTCL: test when CB in open and closed positions; trip after 1.5 sec timer

### 3-Yearly
- **End-to-end testing** of differential and distance protection schemes (primary injection preferred)
- Full relay coordination review and settings audit

### Numerical Relay Specific (IEC 60255 series)
- Self-monitoring function check (relays flag own faults internally)
- Setting file backup and version control
- Software/firmware version tracking (critical for microprocessor-based relays)
- CT/PT connection check (directional relays)

---

## 5. Earthing System (IS 3043 / CEA Safety Regulations 2010)

### Monthly
- Visual check of earthing connections, bonding
- Check earth pits for dryness, salt treatment if required

### Yearly (Earth Resistance Register)
- **Earth Resistance Measurement**: Fall-of-potential method (IS 3043)
  - Maximum acceptable: **1 Ω** for EHV substation main earth mat
  - Tower footing resistance: UPPCT manual — **once every 2 years** for normal locations, **yearly** for critical locations
  - Acceptable tower footing resistance: **<10 Ω** (general); **<5 Ω** (critical lines per POWERGRID standard)
- Check all earth bonds of surge arrestors, structures, equipment tanks

---

## 6. Battery and DC System (Battery Maintenance Register)

### Daily
- Float charge voltage: check per cell and overall — typical 2.25 V/cell (VRLA), 2.23 V/cell (flooded)
- Overall DC bus voltage: 110V or 220V DC (as designed)
- Check charger AC input voltage, DC output voltage, and current
- Check pilot cell specific gravity (flooded batteries)

### Monthly
- Individual cell voltage check — any cell <1.95V under float → flag for attention
- Specific gravity of all cells (flooded type) — acceptable: **1.200–1.215** at 27°C
- Check electrolyte level (flooded type) — top up with distilled water
- Check inter-cell connectors for corrosion/tightness
- Charger: check all alarm contacts, boost charge settings

### Yearly (Battery Maintenance Register — Yearly section)
- **Capacity / Discharge Test (10-hour rate / C10 test)**: Battery must deliver ≥80% of rated Ah capacity; if <80%, battery replacement warranted
- Full specific gravity and voltage measurement of all cells before and after capacity test
- Check battery room: ventilation (hydrogen build-up hazard), temperature control, eyewash

### 3-Yearly (or on battery aging indication)
- Impedance/conductance test as health indicator
- Replace individual cells showing low capacity

---

## 7. Lightning Arrestors / Surge Arresters (Half-Yearly / Yearly)

### Daily
- **Surge counter ammeter reading** — recorded in LA Surge Counter Register (Register 18)

### Half-Yearly (LA Maintenance Register)
- Visual inspection: porcelain/polymer condition, flange, mounting
- Check surge counter and ammeter for proper operation
- Check earthing connections

### Yearly (LA Maintenance Register)
- **IR Test**: HV-to-earth; minimum acceptable 1000 MΩ (dry/clean condition)
- **Leakage current measurement** (online): >1 mA resistive component = investigation needed
- **Thermal imaging**: overheating indicates internal defect
- Check pressure relief vent condition (older porcelain type)

---

## 8. Capacitor Banks

### Monthly
- Visual inspection: bulging/leaking capacitor units, oil seepage
- Check capacitor bank protection relay settings
- Record reactive power output

### Yearly
- **Capacitance measurement**: deviation >5% from nameplate = defective unit
- **IR test**: each unit
- Cleaning of insulators
- Check fuse conditions (internally fused banks)
- Structural inspection

---

## 9. Insulators

### Half-Yearly
- Visual inspection from ground with binoculars for flashover marks, chips, cracks
- After monsoon: cleaning in polluted areas (critical pollution zones: twice yearly; normal: yearly)

### Yearly
- **Insulator IR test** (string insulators): Megger at 5kV; acceptable: **>1000 MΩ** under dry conditions
- Punctured insulator detection for critical line locations
- Thermovision scanning of jumpers/spacer-dampers annually

---

## 10. Isolators (Isolator Maintenance Register — Yearly)

- Visual and mechanical inspection: blade alignment, jaw contact condition
- Contact resistance measurement: micro-ohm meter
- Lubrication of moving parts, pivot pins
- Check interlocks (mechanical and electrical)
- Adjustment of contacts for proper engagement
- Check earth switch operation and interlock with main isolator

---

## 11. Cables (IR Test Register)

### On Installation / After Major Work
- **IR test** (Megger): 1 kV Megger minimum; acceptable: >1000 MΩ·km for LT; **>100 MΩ** for HV cables
- **HV pressure test**: After major repair; DC or AC hi-pot as specified

### Yearly (for critical feeders)
- IR test
- Thermal imaging of cable terminations and joints
- Visual inspection of cable trenches/ducts for water ingress, rodent damage

---

## Summary: Critical "First-Time Fail" Limits

| Equipment | Test | Alarm/Action Limit |
|-----------|------|-------------------|
| Transformer oil | BDV | <40 kV (HV) → process oil; <30 kV → replace |
| Transformer oil | Moisture | >15 ppm → reconditioning; >20 ppm → mandatory |
| Transformer oil | DGA C2H2 | >5 ppm → investigation; >35 ppm → take off-line |
| Transformer | PI (polarization index) | <1.0 → fail; 1.0–1.5 → monitor; >1.5 → OK |
| Transformer windings | WTI alarm | 90°C (typical alarm), 105°C (trip) |
| Transformer oil | OTI alarm | 85°C (alarm), 95°C (trip) |
| CB VCB | IR (open position) | <50 GΩ → investigate |
| CB SF6 | Gas dew point | >−5°C at rated pressure → dry gas |
| CT/PT | IR | <1000 MΩ → investigate |
| Battery | Capacity test | <80% rated → replace bank |
| Battery | Cell voltage (float) | <1.95V → replace cell |
| Battery | Specific gravity | <1.190 → recharge; <1.180 → investigate |
| Earth resistance | Main earth mat | >1 Ω → improve earthing |
| Earth resistance | Tower footing | >10 Ω → improve |
| LA | Leakage current | Resistive component >1 mA → investigate |
| Insulator | IR (5kV Megger) | <1000 MΩ → reject/replace |
