# Substation Logsheet Parameters & Formats

**Sources**: UPPTCL O&M Manual (2020), CEA Metering Regulations, CERC Metering Regulations 2006, IEGC, Industry practice across Indian TRANSCOs/DISCOMs

---

## Daily Log Sheet (Register 19) — UPPTCL

The Daily Log Sheet is Register No. 19 in UPPTCL's essential registers. It is the primary hourly operational record.

---

## Recording Frequencies

### Hourly (every 1 hour) — EHV Substations (400kV/220kV/132kV)
Per SLDC/ALDC requirements, EHV substations record the following every hour or every 30 minutes per IEGC:

**For each Bay (Transformer/Feeder/Bus Coupler):**
| Parameter | Unit | Normal Range / Remarks |
|-----------|------|----------------------|
| Current (I) | Amperes (A) | Per phase for EHV; per CT ratio |
| Voltage (V) | kV (line-to-line) | ±5% of nominal (CEA voltage standard) |
| MW (Active Power) | MW | From energy meter / SCADA |
| MVAR (Reactive Power) | MVAR | Positive = lagging (absorbing MVAR from system) |
| MVA (Apparent Power) | MVA | √(MW²+MVAR²) |
| Power Factor (PF) | — | Minimum 0.90 lag at consumer buses; unity target at 33kV |
| Frequency | Hz | 49.9–50.05 Hz (IEGC normal band); 49.0–50.5 Hz (permissible) |
| Tap Position (OLTC) | Tap no. | Recorded per transformer |
| Winding Temperature | °C | Alarm: 90°C; Trip: 105°C |
| Oil Temperature | °C | Alarm: 85°C; Trip: 95°C |
| Breaker Status | O/C (Open/Closed) | For each bay breaker |
| Isolator Status | O/C | For each bay |
| Earth Switch Status | O/C | Safety record |

**For the Station overall:**
| Parameter | Unit | Remarks |
|-----------|------|---------|
| 33kV Bus Voltage | kV | EHV/MV secondary bus |
| 11kV Bus Voltage | kV | Distribution bus (DISCOM substations) |
| Station Auxiliary Load | MW | Colony + auxiliaries |
| Ambient Temperature | °C | Recorded twice per shift at minimum |
| Weather | Text | Clear/Cloudy/Rain/Fog — affects insulator performance |

### Every 4 Hours (Shift-based readings) — 33kV/11kV Substations (DISCOMs)
At 33kV/11kV grid substations, readings typically recorded at:
- 06:00 / 10:00 / 14:00 / 18:00 / 22:00 / 02:00 (every 4 hours)

Parameters:
- Voltage at 33kV and 11kV buses
- Feeder currents (A) — per feeder on 11kV
- Transformer load (A or % loading)
- Power factor
- Oil temperature
- Energy meter reading (cumulative kWh)

### 15-Minute Block (ABT Metering — Generating/Interchange Substations)
Per CERC Metering Regulations 2006 (as amended):
- ABT (Availability Based Tariff) meters capture **15-minute energy blocks**
- Each block: MWh (import and export), MVArh
- Data transmitted to SLDC/RLDC via optical fibre / SCADA / RTU
- Main meter + Check meter + Standby meter mandated at all inter-state exchange points

### Daily (at 8:00 AM — standard UPPTCL/UPPCL time)
- **Energy Account Register reading** (Register 8): All feeder/transformer energy meters read at 8:00 AM
- Transformer oil BDV result (if tested)
- Battery voltage and specific gravity (pilot cell)
- LA surge counter ammeter reading

### Monthly
- Monthly energy balance computation (Import − Export − Internal consumption = Losses)
- Loss % calculation
- Maximum/minimum load record for month
- Tripping/interruption summary (monthly abstract from Stoppage Register)
- Availability % for each feeder/transformer
- Submit monthly statement to ALDC/SLDC/SERC as required

---

## Logsheet Column Structure (Typical TRANSCO — 132kV/220kV/400kV)

### Header Block (per page)
- Substation name, Date, Month, Year
- Shift (Morning/Evening/Night)
- Name and designation of Shift In-Charge
- Relief time (handover time)

### Body (tabular, one row per hour)
| Column | Data |
|--------|------|
| Time | HH:MM (00:00 to 23:00) |
| Bus Voltage (kV) | Each bus separately: 400kV Bus-1, Bus-2, 220kV Bus etc. |
| Transformer-1 (Load) | MW, MVAR, MVA, PF, Tap, WTI (°C), OTI (°C) |
| Transformer-2 (Load) | Same as above |
| Line-1 (feeder) | Current (A), MW, MVAR, breaker status |
| Line-2, Line-3... | Same per bay |
| Frequency (Hz) | Typically recorded once per shift or as required by SLDC |
| Remarks | Any abnormality, operation performed, message received |

### Footer Block
- Shift summary: Total operations, Total abnormalities
- Signature of outgoing shift in-charge
- Signature of incoming shift in-charge (handover acknowledgment)
- Signature of AE/JE checking the log

---

## Tripping Entry in Logsheet vs Tripping Register

In the daily logsheet:
- Time of trip, feeder/bay name, cause (if known), restoration time → noted in Remarks column
- Full analysis: Flags (relay flags on control panel and relay panel), both-end flags, fault analysis → entered in **Tripping Register (Register 10)**
- Supply interruption details → entered in **Stoppage Register (Register 11)**

---

## DISCOM (11kV/33kV) Logsheet Parameters

At 11kV/33kV DISCOM substations (less sophisticated), recording is typically 4-hourly:

| Parameter | Unit | Remarks |
|-----------|------|---------|
| 33kV incoming voltage | kV | From 33kV bus PT |
| 11kV bus voltage | kV | Secondary side |
| Transformer current | A | Per phase (on HV or LV side) |
| Power factor | — | From trivector meter |
| Transformer temperature | °C | OTI reading |
| Energy import reading | kWh | From energy meter (cumulative) |
| Feeder current | A | Per 11kV feeder |
| Feeder ON/OFF status | — | Rostering schedule compliance |
| Frequency | Hz | If metered |
| Remarks | — | Any tripping, shutdown, complaint |

---

## ABT Metering Requirements (CERC / IEGC)

For inter-state generating stations and transmission licensees:
- **Trivector meter** (MD, kWh, kVArh) — Main + Check + Standby at each interface point
- Data logger captures **15-minute block** energy data
- Time synchronized to GPS/IST within **30 seconds** (CERC requirement)
- Data downloaded by RLDC/SLDC for **energy accounting and deviation settlement**
- Generating station must maintain **station-wise 15-minute scheduling data**

---

## SLDC Reporting Requirements

Per state SLDC instructions (UPSLDC, MSLDC, etc.):
- **Hourly generation/drawal data**: Transmitted via RTU/SCADA in real time
- **Daily generation schedule**: Submitted by 10:00 AM for next day (generating stations)
- **Outage notification**: Planned outage to be communicated **24 hours in advance**
- **Forced outage**: Immediate notification within 15 minutes
- **Monthly energy statement**: Submitted to SLDC by 5th of following month

---

## Normal Operating Bands (Per CEA / IEGC)

| Parameter | Normal Band | Note |
|-----------|-------------|------|
| Frequency | 49.9–50.05 Hz | IEGC normal; below 49.0 Hz = grid emergency |
| Voltage at 400kV | 380–420 kV | ±5% |
| Voltage at 220kV | 200–245 kV | −9% to +11% per CEA standards |
| Voltage at 132kV | 121–145 kV | |
| Voltage at 33kV | 30–36.3 kV | |
| Voltage at 11kV | 9.9–12.1 kV | ±10% |
| Power factor | ≥0.90 lagging | At consumer point; SERC penalty below this |
| Transformer loading | ≤100% rated | Emergency: 120% for <30 min per IEC 60076-7 |
