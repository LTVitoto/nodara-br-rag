-- ═══════════════════════════════════════════════════════════════════════════
-- Seed corpus · SYNTHETIC technical manuals (English) — simulation only.
-- Equipment, part numbers and limits are fictional; do not use for real maintenance.
-- Embeddings stay NULL until the backend runs POST /api/v1/kb/embed (make embed).
-- ═══════════════════════════════════════════════════════════════════════════

INSERT INTO kb.documents (doc_id, title, equipment, doc_type, issuing_site, revision, classification) VALUES
    ('AU-HT400-HYD-001',  'HT-400 Ultra-Class Haul Truck - Hydraulic System Service',            'HT-400 haul truck',        'maintenance_procedure', 'Pilbara Operations, WA (AU)', 'Rev C 2025-11', 'SYNTHETIC-SIMULATION'),
    ('AU-HT400-TYR-002',  'HT-400 OTR Tyre Inspection and Change-out Standard',                   'HT-400 haul truck',        'inspection_standard',   'Pilbara Operations, WA (AU)', 'Rev B 2025-06', 'SYNTHETIC-SIMULATION'),
    ('AU-SM40-LIN-003',   'SAG Mill SM-40 - Shell Liner Change-out Procedure',                    'SM-40 SAG mill',           'maintenance_procedure', 'Pilbara Processing Plant (AU)', 'Rev D 2025-09', 'SYNTHETIC-SIMULATION'),
    ('AU-CV12-BLT-004',   'Overland Conveyor CV-12 - Belt Splice Inspection and Repair',          'CV-12 overland conveyor',  'inspection_standard',   'Pilbara Processing Plant (AU)', 'Rev A 2025-03', 'SYNTHETIC-SIMULATION'),
    ('AU-SP250-SEAL-005', 'Slurry Pump SP-250 - Mechanical Seal Replacement',                     'SP-250 slurry pump',       'maintenance_procedure', 'Pilbara Processing Plant (AU)', 'Rev B 2025-08', 'SYNTHETIC-SIMULATION'),
    ('AU-ES4100-RPE-006', 'Electric Rope Shovel ES-4100 - Hoist Rope Inspection and Discard Criteria', 'ES-4100 rope shovel', 'inspection_standard',   'Pilbara Operations, WA (AU)', 'Rev C 2025-10', 'SYNTHETIC-SIMULATION'),
    ('AU-SAFE-LOTO-007',  'Site Standard - Energy Isolation, Lock-Out/Tag-Out and Verification',  'All equipment',            'safety_standard',       'Pilbara Operations, WA (AU)', 'Rev F 2025-12', 'SYNTHETIC-SIMULATION'),
    ('AU-HT400-FSS-008',  'HT-400 Fire Suppression System - Inspection and Cartridge Replacement', 'HT-400 haul truck',       'maintenance_procedure', 'Pilbara Operations, WA (AU)', 'Rev A 2025-07', 'SYNTHETIC-SIMULATION');

INSERT INTO kb.part_xref (oem_part_no, matnr, description_en, description_pt, base_uom) VALUES
    ('HF-7720',        '100000101', 'Hydraulic return filter element, HT-400',     'Filtro hidráulico de retorno HT-400',            'PC'),
    ('ISO-VG46-HYD',   '100000102', 'Anti-wear hydraulic oil ISO VG 46',           'Óleo hidráulico antidesgaste ISO VG 46',         'L'),
    ('OTR-5980R63',    '100000201', 'OTR tyre 59/80R63',                           'Pneu OTR 59/80R63',                              'PC'),
    ('SM40-LB-220',    '100000301', 'SAG mill shell lifter bar SM-40',             'Barra elevadora (lifter) do moinho SAG SM-40',   'PC'),
    ('CV-ST2000-SPK',  '100000401', 'Steel-cord belt splice kit ST-2000',          'Kit de emenda vulcanizada para correia ST-2000', 'PC'),
    ('SP250-MS-01',    '100000501', 'Slurry pump mechanical seal cartridge SP-250','Selo mecânico tipo cartucho da bomba SP-250',    'PC'),
    ('ES4100-HR-70',   '100000601', 'Hoist rope 70 mm, ES-4100',                   'Cabo de aço de elevação 70 mm ES-4100',          'PC'),
    ('FS30-CART',      '100000701', 'Fire suppression actuator cartridge FS-30',   'Cartucho atuador de supressão de incêndio FS-30','PC'),
    ('LOTO-KIT-P',     '100000801', 'Personal lockout kit',                        'Kit pessoal de bloqueio (LOTO)',                 'PC');

INSERT INTO kb.chunks (doc_id, chunk_no, section, sap_materials, content) VALUES
('AU-HT400-HYD-001', 1, '3.1 Hydraulic return filter element replacement (P/N HF-7720)', '{100000101,100000102}',
$$Interval: every 500 SMU hours, or immediately when the filter bypass indicator shows red. Required parts: one return filter element P/N HF-7720 per filter housing (the HT-400 has two housings: hoist and steering), the O-ring supplied with the element, and ISO VG 46 hydraulic oil for top-up. Procedure: 1) Park the truck on level ground with the body fully lowered, park brake applied and wheels chocked. 2) Apply personal isolation per site standard AU-SAFE-LOTO-007 and verify zero energy. 3) Bleed the steering accumulators through the bleed-down valve and confirm 0 kPa on the accumulator gauge; wait at least 5 minutes before opening any hydraulic circuit. 4) Clean the housing exterior, remove the cover and drain the housing into an approved container. 5) Remove the element and inspect it for metallic debris; if brass or steel particles are visible, retain a sample and raise a defect notification. 6) Fit the new element with a new lubricated O-ring and torque the cover bolts to 95 N·m in a cross pattern.$$),

('AU-HT400-HYD-001', 2, '3.1 (cont.) Post-replacement checks', '{100000101,100000102}',
$$7) Top up the hydraulic tank with ISO VG 46 oil to the FULL mark of the sight glass with the body lowered; a single housing change typically needs 15 to 25 L. 8) Remove isolation, start the engine and run at low idle for 5 minutes, cycling hoist and steering three times to purge air. 9) Check the housing cover for leaks and re-check the oil level. 10) Reset the bypass indicator and record the filter change, the oil added and the SMU hours in the work order. Never re-use a filter element and never operate the truck for more than one shift with the bypass indicator red: unfiltered oil accelerates hydraulic pump wear.$$),

('AU-HT400-HYD-001', 3, '3.2 Hydraulic oil sampling and condition limits', '{100000102}',
$$Take an oil sample every 250 SMU hours from the sampling valve on the return manifold with the system at operating temperature (50 to 70 °C). Target cleanliness is ISO 4406 18/16/13; results worse than 20/18/15 require a filter change and a second sample within 50 hours. Water content above 0.1 % (1,000 ppm) or iron (Fe) above 50 ppm must be escalated to the reliability engineer. Hydraulic tank capacity is 1,250 L; use only ISO VG 46 anti-wear hydraulic oil.$$),

('AU-HT400-HYD-001', 4, '4.3 Troubleshooting - high hydraulic oil temperature', '{100000101,100000102}',
$$If hydraulic oil temperature exceeds 85 °C, stop the truck in a safe location and let the system cool at low idle. Common causes: clogged return filter (check the bypass indicator), low oil level, oil cooler fins blocked by dust, or a stuck relief valve. Do not open the tank filler cap while the oil is hot: the tank is pressurised and hot oil causes severe burns. Every 10 °C above 85 °C roughly halves the service life of the oil.$$),

('AU-HT400-TYR-002', 1, '2.1 Daily inspection and cold inflation pressure', '{100000201}',
$$Inspect tyres at the start of every shift. Cuts deeper than 25 mm, exposed cords, bulges or sidewall separation require the truck to be parked and the tyre assessed by a qualified tyre technician. Cold inflation pressure for the 59/80R63 tyre (P/N OTR-5980R63) is 700 kPa (102 psi) using nitrogen; check pressure only when the tyres are cold. Never approach a hot or damaged tyre: if a tyre has been exposed to fire, lightning or a hot-brake event, establish a 300 m exclusion zone and keep it for at least 24 hours.$$),

('AU-HT400-TYR-002', 2, '3.4 Tyre change-out', '{100000201}',
$$Tyre change-outs are performed only in the designated tyre bay using an OTR tyre handler. Deflate the tyre completely by removing the valve core before loosening any wheel nut. Torque wheel nuts to 2,700 N·m in a star pattern in three stages and re-torque after the first 10 operating hours. Rear dual assemblies are changed as matched pairs: the tread depth difference between duals must not exceed 10 mm.$$),

('AU-SM40-LIN-003', 1, '5.2 Shell lifter bar replacement', '{100000301}',
$$Liner change-outs are planned shutdown activities. Replace shell lifter bars (P/N SM40-LB-220) when lifter height is worn below 90 mm or when cracking is observed. A full shell reline uses 48 lifter bars; partial relines must replace complete rows. Before entry, isolate the mill main motor and the inching drive, engage the mechanical mill lock, and complete a confined-space entry permit with gas testing. Use the relining machine only: manual handling of liners (up to 1,200 kg) is prohibited. Torque liner bolts to 2,000 N·m and re-check after 24 hours of operation.$$),

('AU-CV12-BLT-004', 1, '2.3 Splice inspection and vulcanised repair', '{100000401}',
$$Inspect all steel-cord (ST-2000) belt splices monthly with the magnetic belt scanner. Repair is required when splice elongation exceeds 1 % of splice length or more than 5 % of the cords show damage. A vulcanised splice repair consumes one splice kit (P/N CV-ST2000-SPK) and needs a 12-hour window including curing at 145 °C. Before any work on the belt, isolate the drive motors AND release or mechanically secure the gravity take-up: the take-up stores enough energy to move the belt even with the drives isolated.$$),

('AU-SP250-SEAL-005', 1, '4.1 Mechanical seal cartridge replacement', '{100000501}',
$$Replace the mechanical seal cartridge (P/N SP250-MS-01) when gland leakage exceeds 1 L/min or when flush water pressure cannot be held at 70 kPa above pump discharge pressure. Isolate the pump motor, close and lock the suction and discharge knife-gate valves, and drain the casing: slurry may be under pressure and up to 60 °C. After installation, set the impeller front clearance to 1.0 mm and confirm flush water flow before restarting the pump.$$),

('AU-ES4100-RPE-006', 1, '3.1 Hoist rope inspection and discard criteria', '{100000601}',
$$Inspect the 70 mm hoist rope (P/N ES4100-HR-70) every 24 operating hours. Discard the rope if any of the following is found: 6 or more broken wires within one lay length, 3 broken wires in one strand within one lay, diameter reduction greater than 7 % of nominal (below 65.1 mm), kinking, bird-caging or heat damage. A rope change requires the dipper lowered to the ground, hoist brakes set and the hoist drive isolated; it typically takes 8 to 10 hours with two crews.$$),

('AU-SAFE-LOTO-007', 1, '4. Isolation and verification steps', '{100000801}',
$$Every person working on equipment applies their own personal lock (personal lockout kit P/N LOTO-KIT-P) to every isolation point. Steps: 1) Identify all energy sources: electrical, hydraulic, pneumatic, stored mechanical energy (springs, accumulators, gravity, belt take-ups) and thermal. 2) Notify the operator and shut the equipment down. 3) Isolate each energy source and apply personal locks and danger tags. 4) Dissipate or restrain stored energy. 5) Verify zero energy with a try-start test and test instruments before work begins. Never remove another person's lock.$$),

('AU-HT400-FSS-008', 1, '2.2 Monthly inspection and cartridge replacement', '{100000701}',
$$Inspect the fire suppression system monthly: the agent tank gauge must read in the green band, nozzles must be capped and free of dust, and hoses must not be chafed. Replace the actuator cartridge (P/N FS30-CART) after any discharge, every 12 months, or when its weight is more than 10 % below the stamped weight. Disarm the system with the safety pin before removing the cartridge and re-arm it only after the work order is closed. A discharged system must be recharged before the truck returns to operation.$$);
