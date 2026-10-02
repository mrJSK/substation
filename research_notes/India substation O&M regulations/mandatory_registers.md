# Mandatory Registers at Indian EHV Substations

**Primary Source**: UPPTCL "Best O&M Practices for EHV Sub-stations and Lines" — First Edition, October 2020 (Official TRANSCO manual, U.P. Power Transmission Corporation Ltd, 765kV/400kV/220kV/132kV)

---

## PART-I: Essential Operational Registers (Section 10.0)

UPPTCL mandates 19 numbered registers at every substation. All registers must be machine-numbered and maintained formally.

| Reg No. | Register Name | What It Contains |
|---------|--------------|------------------|
| 1 | Index Register | Serial nos. of all registers maintained at the substation with subject and remarks |
| 2 | Plant History Register | Full technical specs + commissioning data for each equipment. All major replacements, overhauls, and events logged. Min 5 blank pages per equipment for future events. |
| 3 | O&M Manual | Manufacturer/authority recommendations for each equipment; kept with AE/JE (Maintenance) |
| 4 | Shift Arrangement Register | Monthly chart of shift duties for all operating personnel. Maintained yearly. Shift codes: E=Evening, N=Night, M=Morning, G=General, R=Rest |
| 5 | Attendance Register | Proper watch on general shift and maintenance staff attendance |
| 6 | Testing Register | Records of all tests performed, test results, settings. Filled by T&C organisation. Columns: Date / Name of equipment / Details of test / Result / Signature of JE/AE |
| 7 | Defect Register | ALL defects noted in plant/equipment entered by shift staff so maintenance can attend. Date, time, defect details, compliance date, signature of JE/AE |
| 8 | Energy Account Register | Energy balance at substation and feeders with energy loss. Meter readings at 8:00 AM daily. Import/Export per feeder/transformer. Loss % = (A−B)/A × 100 |
| 9(a) | Shutdown Form Register | Records of all planned shutdowns with authorization chain |
| 9(b) | Work Permit Form Register | Records of all Work Permits issued (PTW system) |
| 10 | Tripping Register – Primary System | All trippings at 132kV and above for which system analysis is done. Columns: SI.No / Date & Time / Breaker & Feeder / Tripping time / Closing time / Flags at this end (Control Panel, Relay Panel) / Flags at other end / Any other breaker tripped / Fault analysis & remarks |
| 11 | Stoppage Register | ALL interruptions of supply due to tripping, breakdown, shutdown, and rostering for ALL feeders/transformers of ALL voltages. Monthly abstract at month-end. Columns: Feeder name / Tripping (From-To-Duration-Flags) / Breakdown (From-To-Duration-Reason) / Shutdown (From-To-Duration-Reason) / Rostering / Total effective duration / Availability % (including/excluding rostering) |
| 12 | Authorization Register | Persons authorized to perform different operations. Columns: Name / Work authorized / Dated signature of authorised person / Dated signature of authorising authority |
| 13 | Instruction Register | All instructions issued to shift/maintenance staff by officers. Date / Details / By whom / Noted by / Compliance |
| 14 | Inspection Register | Remarks of inspecting officers and their compliance. Date / Inspecting Officer / Observation / Signature / Noted by / Compliance |
| 15 | Rostering Register | Load shedding instructions and their implementation. Programme / Received from / Code No. / Communicated to / Remark |
| 16(a) | Message Register – Control | All incoming/outgoing messages at ALDC/Control. Date & Time / Receiving End / Sending End / From / To / Details / Action taken / JE/SSO signature |
| 16(b) | Message Register – Local | Same as above for local substation messages |
| 17 | Maximum/Minimum Load Register | Max & min loads per transformer/feeder with date and time. Graph to be plotted for important lines/transformers. DISPLAYED in control room as permanent record. |
| 18 | LA Surge Counter Reading Register | Daily reading of Lightning Arrestor surge counter ammeter for each LA (R, Y, B phases per feeder/transformer) |
| 19 | Daily Log Sheet | Hourly operational log (see logsheet section) |

---

## PART-II: Maintenance Registers

| Equipment | Register Type | Frequency |
|-----------|--------------|-----------|
| Transformers | Transformer Maintenance Register | Quarterly / Half-Yearly / Yearly |
| Circuit Breakers | Breaker Maintenance Register | Quarterly / Yearly / Trip-based (3/5/10 Yearly) |
| Batteries & Chargers | Battery Maintenance Register | Daily, Monthly, Yearly |
| Compressors | Compressor Maintenance Register | Daily, Quarterly, Yearly |
| Isolators | Isolator Maintenance Register | Yearly |
| CT/CVT/PT | CT/CVT/PT Maintenance Register | Yearly |
| Lightning Arrestors | LA Maintenance Register | Half-Yearly and Yearly |
| Fire Fighting Equipment | FF Equipment Register | Daily Maintenance Card + Monthly/Quarterly/Yearly |
| Bus bar, Structure, Jumpers, Lighting, Earthing, Hotspots | Busbar/Earthing Register | Monthly, Yearly |
| Relay Panels, Control Panels | Panel Maintenance Register | Monthly, Yearly |
| Operation Daily | Daily Log Sheets + Daily Maintenance Card | Daily |

---

## Drawings That Must Be Maintained at Each Substation

1. G.A. Diagrams of all equipment including structures
2. Schematic diagrams of all equipment including control/relay panels
3. Manufacturer's Erection, Commissioning and Maintenance Manuals
4. Cable schedules and interconnection diagrams for all bays
5. Electrical layout
6. Foundation plan and earthmat drawing
7. Layout plan
8. Maintenance Manual

**Storage requirement**: All drawings pasted with cloth, kept in folders bay-wise with index on first page, in separate almirah in control room, under charge of JE/AE (Maintenance).

---

## Additional Registers (from Industry Practice / CEA Safety Regulations 2010)

Beyond UPPTCL's 19 primary registers, CEA Safety Regulations 2010 and industry practice require:

| Register | Statutory Basis | Purpose |
|---------|-----------------|---------|
| Accident Register / Dangerous Occurrence Book | CEA Safety Regulations 2010 / Indian Electricity Rules | Record all electrical accidents, dangerous occurrences; report to CEA/CEIG within prescribed time |
| Oil Testing Register (BDV Register) | IS 335 / IEC 60156 | Transformer oil Breakdown Voltage test results per equipment |
| Earth Resistance Register | IS 3043 / CEA Safety Regs | Earth resistance readings per earth electrode, tower footing; annual minimum |
| Relay Test Register | CEA Tech Standards | Secondary injection test results, settings, dates per protection relay |
| DGA (Dissolved Gas Analysis) Register | IEC 60599 | Gas analysis results per transformer – H2, CH4, C2H2, C2H4, C2H6, CO, CO2 (ppm) |
| IR/Megger Test Register | IEC 60076 / IS 2026 | Insulation resistance readings per winding, cable, equipment |
| SF6 Gas Analysis Register | IEC 60480 | Dew point and purity analysis per CB pole |
| OLTC Maintenance Register | Manufacturer / CBIP guide | Tap change counter, oil change record, contact resistance |
| Key Register | Safety / PTW | Keys issued/returned for equipment rooms, cable trench covers |
| Visitor Register | Security | All visitors to substation premises |
| Fuel/Generator Log | Operational | DG set operation, fuel consumption, start/stop log |

---

## Energy Account Register – Detailed Format (Reg 8)

Readings taken at **8:00 AM daily** per UPPTCL standard.

**Import section per feeder/transformer:**
- Last month reading at 8:00 AM
- Present month reading at 8:00 AM  
- Difference
- Multiplying Factor (MF)
- Net Energy in MWh

**Export section per feeder:**
- Same columns as import

**Loss computation at month end:**
1. Energy generated
2. Energy imported from other sources → Total (A)
3. Energy consumed in colony and local accessories
4. Energy supplied direct to consumers
5. Energy exported to Transmission Organisation → Total (B)
6. Difference (A−B)
7. Percentage Loss = (A−B)/A × 100

Signature of JE(M)/AE(M) required.

---

## Stoppage Register – Monthly Availability Calculation

This register feeds into the reliability indices (availability %, number of trippings). Monthly abstract computes:
- Total effective duration of failure
- Total availability (hours/month)
- Availability including rostering
- Availability excluding rostering

These figures are reported to ALDC/SLDC and form the basis of SERC regulatory reporting.
