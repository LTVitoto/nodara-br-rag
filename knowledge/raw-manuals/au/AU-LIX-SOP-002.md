---
doc_id: AU-LIX-SOP-002
title: SOP: PLS Flow Optimization & Acid Pump Maintenance
applies_to: Heap leach PLS circuit and acid dosing pumps
doc_type: standard_operating_procedure
issuing_site: Hydrometallurgy Operations, Pilbara (AU)
revision: Rev 7 2026-01
language: en
classification: SYNTHETIC-SIMULATION
---

# SOP: PLS Flow Optimization & Acid Pump Maintenance

> SYNTHETIC document for the Nodara BR-RAG simulation. Process limits and part numbers are fictional;
> do not use for real operation or maintenance.

## 2. PLS flow optimization

The pregnant leach solution (PLS) flow from the heap leach pads to the solvent extraction (SX) plant must be kept between 800 and 900 m³/h, with an irrigation rate of 10 to 12 L/h/m² on the active cells. Monitor PLS copper grade and pH every two hours: the target is 2.5 to 3.5 g/L Cu and pH 1.6 to 2.0. If the PLS grade falls below 2.5 g/L Cu for two consecutive readings, verify the irrigation distribution and the free acid concentration of the irrigation solution before increasing flow; increasing flow with low grade dilutes the SX feed and reduces copper transfer.

## 3. Acid concentration adjustment

Free sulfuric acid in the irrigation (raffinate) solution must be held at 10 to 12 g/L H2SO4. Adjust the acid dosing pump setpoint in steps of no more than 0.5 g/L every 8 hours and confirm each step by titration two hours after the change. Never exceed 15 g/L: excess acid increases gangue acid consumption and gypsum precipitation that blinds the pad. With one acid dosing pump out of service, the remaining pump must not run above 85 % of its rated flow; reduce the irrigated area instead and record the change in the shift log. Wear acid-resistant suits, gloves and face shields at the dosing station.

## 5. Centrifugal acid pump disassembly

1) Isolate the pump per the site lockout standard (electrical, hydraulic and chemical energy) and close and lock the suction and discharge valves. 2) Drain the casing, flush with water and neutralize with soda ash solution until the drain pH is between 6 and 8. 3) Remove the casing bolts and withdraw the back pull-out assembly with the lifting frame. 4) Inspect impeller, wear plates and shaft sleeve; replace the mechanical seal and impeller kit (P/N APX-450-SIK) whenever the seal has leaked acid. 5) Reassemble, torque the casing bolts to 180 N·m in a cross pattern and set the impeller front clearance to 0.5 mm. 6) Before handover, check the rotation direction and confirm vibration below 4.5 mm/s RMS during the first hour.

## 6. Post-storm inspection and restart

After a tropical storm, flooding or lightning activity, treat every acid pump motor as wet until proven dry. Measure insulation resistance with a 1000 V DC megger: the minimum is 100 MΩ; below that value, dry the motor and repeat the test. Inspect terminal boxes and cable glands for water ingress, check bunds and drains for acid overflow, and verify that the pump base and anchor bolts were not undermined. Do not energize a pump with a failed insulation test or water in the terminal box; report the failure as a breakdown and keep the standby pump in service.

## 7. Work order management in SAP

Report every failure as a malfunction notification and create the corrective maintenance order in SAP transaction IW31, assigning the equipment and the leaching cost center that receives the costs. Before creating a new order, check in transaction IW38 that no open order exists for the same equipment, to avoid duplicate orders and double reservations. Reserve the spare parts on the order; if a spare has no stock, the reservation stays open and a purchase requisition is generated, so escalate critical spares with long lead times to Supply Chain on the same day. Close the order only after the post-repair checks are recorded.
