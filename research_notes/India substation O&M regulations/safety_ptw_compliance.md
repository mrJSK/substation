# Safety, Permit to Work, and Statutory Compliance

**Sources**: UPPTCL O&M Manual Section 6, CEA (Measures Relating to Safety and Electric Supply) Regulations 2010, Indian Electricity Rules 1956, Electricity Act 2003

---

## Statutory Framework

### Electricity Act 2003
- **Section 53**: Central Government shall prepare a National Electricity Policy and Plan; CEA to specify safety requirements
- **Section 161**: Inspection by CEA and Electrical Inspectors
- **Section 163**: Power to inspect

### CEA (Measures Relating to Safety and Electric Supply) Regulations 2010
These regulations are the PRIMARY statutory document governing substation safety in India. Key provisions:
- **Regulation 3**: All electrical installations shall be maintained in a safe condition
- **Regulation 30**: Safe working procedures and PTW system mandated for EHV installations
- **Regulation 31**: Personal Protective Equipment (PPE) requirements
- **Regulation 46**: Dangerous occurrence and accident reporting
- All persons working on HV/EHV equipment must hold competency certificate

### Indian Electricity Rules 1956 (as amended)
- **Rule 44**: Requirements for operation of EHV systems; qualified persons only
- **Rule 46**: All EHV lines and substations must have an approved Safety Manual
- **Rule 67**: Protection against electrical shocks; earthing requirements
- **Rule 68**: Warning notices, caution boards, safety signs

---

## Permit to Work (PTW) System

### UPPTCL Section 6 — Safety Documents Defined

Before ANY work on electrical equipment, a PTW (Work Permit) must be issued. UPPTCL defines these safety document types:

#### 1. Permit to Work (PTW)
- Issued for: work on isolated and earthed electrical equipment
- Issued by: Shift Engineer (Shift In-Charge)
- Pre-conditions: Equipment fully isolated, earthed, discharged, and locked
- Contents:
  - Equipment to be worked on (specific identification)
  - Points of isolation (both sides)
  - Earthing points applied
  - Safety precautions to be observed
  - Name of person in charge of work
  - Validity period

#### 2. Permit to Test
- Issued for: testing that may involve application of test voltages
- Same structure as PTW but specifies test voltages and procedures

#### 3. Caution Notice
- For work near (but not on) live equipment
- Warning signs fixed to live equipment in vicinity

---

## PTW Workflow — UPPTCL Standard (Section 6.5 Shutdown Procedure)

```
Step 1: Outage Request
  └─ Work requesting authority fills Shutdown Request
  └─ Submitted to ALDC/SLDC minimum 24 hrs in advance (planned)
  └─ ALDC/SLDC approves and schedules the shutdown window

Step 2: System Isolation
  └─ Shift In-Charge gets shutdown permission from ALDC/SLDC
  └─ Trip the breaker (CB) of the equipment to be maintained
  └─ Open all isolators on both sides of the equipment
  └─ Close Earth Switches on both sides
  └─ Physically lock isolators in OPEN position (padlock and tag)
  └─ Confirm: Busbar voltage gone, no back-feed path

Step 3: Earthing
  └─ Apply temporary earths (earthing rods) at the work site
  └─ Earthing on BOTH sides of work location
  └─ Three earth rods minimum: one each side + one at work location
  └─ Record all earthing points in PTW

Step 4: Issue PTW
  └─ Shift Engineer fills PTW form (Register 9b)
  └─ Specifies: equipment, isolation points, earthing points, safety precautions
  └─ Hands original to person in charge of work
  └─ Retains duplicate in PTW register

Step 5: Work Execution
  └─ Work carried out only within demarcated area
  └─ Caution notices placed on adjacent live equipment
  └─ No other PTWs on same equipment while one is live

Step 6: PTW Return / Cancellation
  └─ Person in charge of work: confirms work complete, all staff clear
  └─ Returns PTW to Shift Engineer signed and dated
  └─ PTW cancelled in register

Step 7: Re-energization
  └─ Remove all temporary earths (verify all removed)
  └─ Remove all tools and persons from work area
  └─ Open Earth Switches (if applicable)
  └─ Close isolators (in sequence: nearest first)
  └─ Get ALDC/SLDC permission to charge
  └─ Close CB
  └─ Notify ALDC/SLDC: equipment returned to service
```

### Key PTW Safety Rules (UPPTCL)
1. The operation of any equipment to achieve safety shall NEVER involve pre-arranged signals or use of time intervals — confirmation before PTW issue is mandatory
2. Isolation and earthing shall be CONFIRMED before issue of PTW (not assumed)
3. Work areas shall be clearly demarcated with physical barriers
4. No other PTW shall be issued on the same equipment while one is active
5. When danger from induced voltages exists, additional earths shall be applied

---

## Pre-PTW Checks (UPPCTL Section 6 / Industry Standard)

Before issuing a PTW, Shift Engineer must verify:
- [ ] ALDC/SLDC permission obtained and reference number recorded
- [ ] CB tripped (trip indication verified on mimic board)
- [ ] All isolators on both sides OPEN (physical check; position indication verified)
- [ ] Earth switches CLOSED on both sides
- [ ] No voltage present (using voltage indicator / kV meter)
- [ ] Discharge applied (for capacitive equipment)
- [ ] Locking and tagging complete
- [ ] Temporary earths applied at work location
- [ ] Identification: correct equipment confirmed (name plate, bay number)

---

## Safety in Specific Situations (UPPTCL Sections 6.6–6.8)

### EHV Equipment (Section 6.6)
- No work on EHV equipment without PTW
- When danger from induced voltages: additional earths
- Physical barriers around work area

### Medium/LV Equipment (Section 6.7)
- Work on MV/LV equipment with equipment in DEAD condition wherever practicable
- When live work unavoidable: Safety Instructions 04 to be followed
- MV/LV: Safety Document or Personal Supervision as appropriate

### Mechanical Equipment (Section 6.8)
- Include in PTW: drainage, venting, purging, removal of stored energy
- For equipment with internal access: purge and dispose of residue safely
- Vents shall be locked open with caution notices
- If motive power restored during PTW: no other PTW on same equipment

---

## Accident and Dangerous Occurrence Reporting

### Mandatory Reporting per CEA Safety Regulations 2010
When an **electrical accident** occurs:
- Notify Chief Electrical Inspector (CEIG) of the state **within 24 hours**
- Written report within **48 hours**
- Preserve evidence (do not restore supply until Inspector permits, except life safety)

### What Must Be Reported
- Any fatal accident involving electrical equipment
- Any electrical injury requiring hospitalization
- Any dangerous occurrence (major equipment failure, fire, near-miss causing risk to life)
- Any supply failure affecting large area (>10 MW or >1 lakh consumers per state norms)

### Accident Register
- All accidents and dangerous occurrences logged in Accident Register
- Minimum contents: Date/time, location, equipment involved, persons involved, nature of injury, sequence of events, immediate cause, root cause (after investigation), corrective action

---

## Staff Qualification Requirements (CEA / IER)

| Role | Minimum Qualification |
|------|-----------------------|
| Shift Engineer (Shift In-Charge) | Degree in Electrical Engineering + Competency Certificate for EHV (CEA) |
| Assistant Engineer (Maintenance) | Degree/Diploma in Electrical Engineering |
| Junior Engineer (Operation) | Diploma in Electrical Engineering |
| Sub-Station Operator (SSO) | ITI Electrician + State Licensed Electrician |
| Lineman | ITI Electrician / Wireman License (under IER) |

---

## CEA Safety Requirements for Substation Premises

- **Safety signs**: Danger boards, "HIGH VOLTAGE — KEEP AWAY" signs at all equipment
- **Rubber mats**: Must be laid in front of all LT panels, control panels, battery chargers
- **Rubber gloves and boots**: Mandatory PPE for anyone entering live switchyard
- **First aid kit**: Available in control room; trained first-aider on every shift
- **Fire extinguishers**: CO2 type near transformer, electrical panels; sand buckets in switchyard
- **Emergency contact numbers**: ALDC/SLDC, AE, EE, CE, Fire Brigade displayed in control room
- **Safety distances from live conductors**: Per IE Rules 1956 (e.g., 400kV: 3.70 m approach distance)

---

## Permit System Registers

Two dedicated registers per UPPTCL essential register list:
- **Register 9(a): Shutdown Form Register** — records all planned/unplanned shutdowns with ALDC/SLDC references
- **Register 9(b): Work Permit Form Register** — records all PTWs issued; original handed to workman, copy retained

PTW Register format per standard practice:
| Field | Contents |
|-------|----------|
| PTW Number | Sequential machine-numbered |
| Date and Time of Issue | — |
| Equipment Description | Bay name, voltage level, equipment type |
| Points of Isolation | List all CBs/isolators opened |
| Earthing Points | List all earth switches and temporary earths |
| Safety Precautions | Specific instructions |
| Person in Charge of Work | Name, designation |
| Valid From / Valid To | Expiry time (PTW must not be extended beyond original duration without re-issue) |
| Signature (Issuing Officer) | Shift Engineer |
| Time of PTW Return | — |
| Signature (Person returning PTW) | Workman in charge |
| Signature (Shift Engineer acknowledging return) | — |
| Equipment restored at | Date and time |
| ALDC/SLDC Permission Reference | Shutdown request / ALDC sanction reference number |
