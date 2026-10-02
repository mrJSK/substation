# Reliability Indices, Energy Accounting, and Grid Code

**Sources**: CERC Metering Regulations 2006, Indian Electricity Grid Code (IEGC) 2010 (amended 2023), CERC availability performance standards, POWERGRID reliability reports, various SERC tariff orders

---

## Reliability Indices — Definitions and Indian Targets

### Transmission System (TRANSCOs — POWERGRID / State STUs)

**Availability (%) — Most-used metric for transmission**
- Formula: `Availability = (Scheduled Hours − Forced Outage Hours) / Scheduled Hours × 100`
- CERC target for inter-state transmission: **≥98.5%** availability (normative for incentive/disincentive mechanism under Transmission Tariff regulations)
- POWERGRID typical achievement: 99.5%+
- State STUs (TRANSCO): 95–99% typical range

**System Average Interruption Duration Index (SAIDI)**
- Formula: `SAIDI = Σ(Ri × Ui) / NT` where Ri = customers interrupted, Ui = duration (hours), NT = total customers
- Used primarily for DISCOM distribution performance
- Indian targets vary by SERC; typical urban: 2–8 hours/year; rural: 10–30 hours/year

**System Average Interruption Frequency Index (SAIFI)**
- Formula: `SAIFI = Σ(λi × Ni) / NT`
- Urban DISCOMs target: <10 interruptions/consumer/year
- Rural DISCOMs: <15–20 interruptions/consumer/year

**Customer Average Interruption Duration Index (CAIDI)**
- Formula: `CAIDI = SAIDI / SAIFI` (average duration per interruption)
- Target: <2 hours per interruption (urban); <4 hours (rural)

### SERC Performance Benchmarks (Selected States — from tariff orders)

| State | DISCOM | SAIDI Target | SAIFI Target | Source |
|-------|--------|-------------|-------------|--------|
| Maharashtra | MSEDCL | Urban: 4 hr/yr | Urban: 6 | MERC MYT order |
| UP | UPPCL/DISCOMs | Urban: 8 hr/yr | Urban: 10 | UPERC |
| Karnataka | BESCOM | Urban: 3 hr/yr | Urban: 5 | KERC |
| Delhi | BRPL/BYPL | <2 hr/yr | <5 | DERC |
| Telangana | TSSPDCL | Urban: 5 hr/yr | Urban: 8 | TSERC |
| Andhra Pradesh | APDISCOMs | Urban: 6 hr/yr | — | APERC |

**Note**: AT&C (Aggregate Technical and Commercial) loss targets set by SERC/MoP — typically mandated to reduce to 15% or below under RDSS scheme (2021–26)

---

## Energy Accounting at Substation Level

### Computation of T&D Losses

**At 33kV/11kV Substation level (DISCOM):**
```
Energy Input (kWh) = Σ energy imported on all incoming 33kV feeders (from energy meters)
Energy Output (kWh) = Σ energy exported on all outgoing 11kV feeders + auxiliary consumption
T&D Loss = Input − Output
T&D Loss % = (Input − Output) / Input × 100
```

**At 132kV/220kV/400kV Substation (TRANSCO):**
```
Energy Input = Σ energy on all incoming transmission lines
Energy Output = Σ energy on all outgoing lines + transformation losses
Transformation Loss ≈ 0.3–0.5% of throughput (standard transformer losses)
```

### Monthly Energy Account (Register 8 per UPPTCL)
- Readings at 8:00 AM on 1st of each month
- Each feeder: previous month reading, current reading, difference, multiplying factor (MF), net energy (kWh or MWh)
- Signed by JE(M)/AE(M)

### Energy Meter Types (CERC Metering Regulations 2006)
| Application | Meter Type | Accuracy Class |
|-------------|-----------|---------------|
| ABT boundary (inter-state) | Trivector / Multi-function ABT meter | Class 0.2S or better |
| 33kV interface (state boundary) | Trivector meter | Class 0.5 or better |
| 11kV feeder (DISCOM) | Static energy meter | Class 1.0 |
| Consumer LT connection | Static electronic meter | Class 1.0 or 2.0 |

**ABT Meter Data captured (15-minute blocks):**
- Block import MWh
- Block export MWh  
- Block import MVArh
- Block export MVArh
- Maximum demand (kW)
- Time-of-day recording (ToD)

---

## ABT (Availability Based Tariff) Framework

### Purpose
ABT is the frequency-responsive pricing mechanism for inter-state electricity dispatch in India. Implemented by CERC from 2002, extended to all state grids progressively.

### Three Components
1. **Capacity Charge (Fixed Charge)**: Paid based on declared availability (%) of generating unit; paid regardless of schedule; incentive to declare high availability
2. **Energy Charge (Variable Charge)**: Paid per unit scheduled; fuel cost recovery
3. **UI (Unscheduled Interchange) Charge**: Penalty/incentive for deviating from schedule; frequency-linked
   - Frequency > 50.05 Hz → UI rate near zero (stop generating / start consuming)
   - Frequency < 49.90 Hz → High UI rate (generate more / consume less)

### Substation's Role in ABT
- **ABT meters** at inter-state interconnection points record 15-minute block data
- Data transmitted to RLDC (Regional Load Despatch Centre) and SLDC (State LDC)
- SLDC prepares daily energy accounts from ABT meter data
- Substation must ensure ABT meters are functioning, calibrated, and time-synchronized (GPS clock synchronization to IST within 30 seconds)

### Deviations
- If actual generation deviates from schedule → charged at UI rate per CERC Deviation Settlement Mechanism (DSM) Regulations 2014 (replacing old UI mechanism)
- Limit: ±12% of scheduled drawal; beyond this: higher penalty rate

---

## Indian Electricity Grid Code (IEGC 2010, amended 2023)

### Frequency Standards
| Band | Status | Action Required |
|------|--------|----------------|
| 50.05–50.20 Hz | Over-frequency | Generating stations reduce output; loads increase |
| 49.95–50.05 Hz | Normal | No action required |
| 49.90–49.95 Hz | Under-frequency caution | Load shedding to be initiated |
| 49.50–49.90 Hz | Under-frequency emergency | UFLS (Under Frequency Load Shedding) auto-trip |
| Below 49.0 Hz | Severe emergency | All possible load shedding; grid separation risk |

### Voltage Standards (IEGC Schedule 6)
| Voltage Level | Minimum (kV) | Maximum (kV) |
|--------------|-------------|-------------|
| 400 kV | 380 | 420 |
| 220 kV | 200 | 245 |
| 132 kV | 121 | 145 |
| 66 kV | 63 | 72 |
| 33 kV | 30.25 | 36.3 |

### Outage Planning Requirements
- **Planned outages**: Notify SLDC/RLDC minimum **24 hours in advance** (132kV and below); **72 hours** for 400kV and above (IEGC)
- **Forced outages**: Notify SLDC within **15 minutes** of occurrence
- SLDC/RLDC maintains outage schedule to ensure N-1 security

### Reactive Power Management
- Each grid element must maintain power factor above 0.9 lag at bus
- Reactive power absorption/injection per SLDC instructions
- Over-fluxing protection relay settings per IEC 60255 / IEGC voltage standards

---

## SLDC Reporting (State Load Despatch Centre)

### Daily Reporting
- **Day-ahead schedule**: Submitted by generating stations by 10:00 AM for next day
- **Hourly drawal**: Reported in real time via SCADA/RTU; telephonic backup if SCADA fails
- **Outage notification**: Immediate for forced; 24 hrs advance for planned

### Monthly Reporting
- Energy account statement (by 5th of following month)
- Tripping and interruption summary
- Availability % per substation/element

### NRLDC / RLDC Reporting
- Regional LDCs (NRLDC / SRLDC / WRLDC / ERLDC / NERLDC) coordinate inter-state flows
- All 400kV and above substations communicate directly with RLDC via SCADA
- RLDC publishes daily real-time data, weekly logs, monthly reliability reports

---

## Availability and Performance Incentive Mechanism (Transmission)

Per CERC Transmission Tariff Regulations (2019):
- **Normative availability**: 98.5% (transmission lines and substations)
- If actual availability **≥ 98.5%**: Full transmission charge paid + incentive for each % above 98.5%
- If availability **< 98.5%**: Proportional deduction in transmission charge
- Availability computed as: `(8760 − Forced Outage Hours) / 8760 × 100` per year

**POWERGRID annual reports** show consistent 99.5%+ availability.
**State STU (e.g., UPTCL)** typically 95–98%, with improvement mandated by SERC.

---

## Reliability Improvement Schemes (MoP India)

### RDSS (Revamped Distribution Sector Scheme) 2021–2026
- AT&C loss target: ≤12–15% for eligible DISCOMs
- Substation automation and smart metering mandatory
- Feeder segregation (agricultural vs non-agricultural)
- Each DISCOM submits baseline loss data to MoP and implements improvement plan

### DDUGJY (Deen Dayal Upadhyaya Gram Jyoti Yojana)
- Rural electrification; data reporting on feeder-wise availability
- Substations must report rural feeder hours available per day

### UDAY (Ujwal DISCOM Assurance Yojana)
- AT&C loss reporting, financial improvement monitoring
- Loss data: Input at substation, billed units, collection → monthly to MoP portal
