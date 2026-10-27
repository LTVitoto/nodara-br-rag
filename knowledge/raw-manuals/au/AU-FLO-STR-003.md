---
doc_id: AU-FLO-STR-003
title: Global Reagent Dosage Strategy for Variable Grade Ore
applies_to: Copper sulfide flotation circuits (collector dosing)
doc_type: technical_strategy
issuing_site: Group Metallurgy, Perth (AU)
revision: Rev 3 2025-12
language: en
classification: SYNTHETIC-SIMULATION
---

# Global Reagent Dosage Strategy for Variable Grade Ore

> SYNTHETIC document for the Nodara BR-RAG simulation. Dosages and thresholds are illustrative;
> do not use for real plant operation.

## 1. Principle

Collector dosage must follow the head grade and mineralogy of the ore actually fed to flotation, not a fixed setpoint. Under-dosing a lower grade feed loses fine and composite sulfide particles to the tailings; over-dosing reduces selectivity, raises reagent cost and can depress concentrate grade. The reference collector is sodium isopropyl xanthate (SIPX), dosed to the conditioning tank ahead of the rougher bank.

## 2. Dosage matrix by head grade

Apply the following xanthate (SIPX) dosage by head grade: 10 g/t when the head grade is 0.8 % Cu or higher; 12 g/t between 0.6 % and 0.8 % Cu; 15 g/t when the head grade drops below 0.6 % Cu. Never exceed 18 g/t without approval from the Group Metallurgist. A grade band change is confirmed only after two consecutive shift assays fall inside the new band; then adjust the dosage at the start of the next shift.

## 3. Dose change procedure

1) Raise a management of change (MOC) record signed by the plant metallurgist with the assay evidence. 2) Change the dosing pump setpoint and verify the actual flow with a calibration cylinder (drawdown test) within 30 minutes. 3) Monitor rougher tailings grade, froth color and mass pull every two hours for the next 24 hours. 4) If the tailings grade does not improve after 24 hours, return to the previous dosage and escalate to the Group Metallurgist. Record every change in the shift log.

## 4. Reagent inventory and consumption

Daily xanthate consumption (kg/day) = dosage (g/t) × throughput (t/day) / 1000. Example for a 40,000 t/day concentrator: 400 kg/day at 10 g/t and 600 kg/day at 15 g/t, a 50 % increase. Keep a minimum of 14 days of consumption on site at the current dosage and trigger replenishment as soon as coverage falls below that level, considering the supplier lead time. Store xanthate dry, ventilated and away from heat sources: wet or hot xanthate decomposes and releases flammable carbon disulfide (CS2).

## 5. SAP posting of reagent consumption

Post the daily reagent consumption from the reagent depot to the flotation cost center with SAP transaction MIGO (goods issue, movement type 201), using the quantity measured by the dosing system. Reconcile physical and book stock weekly; differences above 2 % must be investigated before posting adjustments. After a dosage change, update the consumption forecast so that purchasing receives the new daily rate.
