-- ═══════════════════════════════════════════════════════════════════════════
-- Seed data · SAP S/4HANA (simulated). Synthetic — no real companies or people.
-- Materials (MATNR) are cross-referenced by the knowledge base (kb.part_xref):
--   100000101 hydraulic return filter HF-7720   100000102 hydraulic oil ISO VG 46 (L)
--   100000201 OTR tyre 59/80R63                 100000301 SAG mill lifter bar
--   100000401 conveyor belt splice kit ST-2000  100000501 slurry pump mechanical seal
--   100000601 shovel hoist rope 70 mm           100000701 fire suppression cartridge
--   100000801 personal LOTO kit
-- ═══════════════════════════════════════════════════════════════════════════

INSERT INTO sap.but000 (partner, type, bu_group, bu_sort1, name_org1, name_first, name_last, langu_corr, crdat) VALUES
    ('0001000001', '1', 'FUNC', 'PEREIRA',     NULL, 'João',    'Pereira', 'P', '2024-02-01'),
    ('0001000002', '1', 'FUNC', 'SOUZA',       NULL, 'Ana',     'Souza',   'P', '2024-03-15'),
    ('0001000003', '1', 'FUNC', 'LIMA',        NULL, 'Carlos',  'Lima',    'P', '2024-05-20'),
    ('0001000004', '1', 'FUNC', 'COSTA',       NULL, 'Mariana', 'Costa',   'P', '2025-01-10'),
    ('0002000001', '2', 'FORN', 'HIDRCARAJAS', 'Hidráulica Carajás Com. de Peças Ltda',     NULL, NULL, 'P', '2023-08-01'),
    ('0002000002', '2', 'FORN', 'PNEUSNORTE',  'Pneus Norte Mineração S.A.',                NULL, NULL, 'P', '2023-08-01'),
    ('0002000003', '2', 'FORN', 'PILBARAHE',   'Pilbara Heavy Equipment Pty Ltd',           NULL, NULL, 'E', '2023-09-12'),
    ('0002000004', '2', 'FORN', 'CORREIASMG',  'Correias Minas Gerais Ltda',                NULL, NULL, 'P', '2024-01-22'),
    ('0002000005', '2', 'FORN', 'LUBSERRAAZUL','Lubrificantes Serra Azul Ltda',             NULL, NULL, 'P', '2024-01-22'),
    ('0002000006', '2', 'FORN', 'SEGINDBR',    'Segurança Industrial Brasil Ltda',          NULL, NULL, 'P', '2024-06-03'),
    ('0003000001', '2', 'EMPR', 'NODARABR',    'Nodara Mineração Brasil Ltda',              NULL, NULL, 'P', '2023-01-02');

-- Goods receipts (101), transfers to the workshop (311) and goods issues to
-- maintenance orders (261). Resulting stock is intentionally tight for some items.
INSERT INTO sap.matdoc (mblnr, mjahr, zeile, bwart, matnr, werks, lgort, shkzg, menge, meins, dmbtr, budat, cpudt, cputm, usnam, lifnr, ebeln, aufnr, kostl, sgtxt) VALUES
    ('4900001001','2026','0001','101','100000101','BR10','0001','S',   12,'PC',   22200.00,'2026-09-02','2026-09-02','08:14:05','ASOUZA','0002000001','4500010001',NULL,NULL,'Recebimento filtros hidráulicos HF-7720'),
    ('4900001002','2026','0001','101','100000102','BR10','0001','S', 2000,'L',    57000.00,'2026-09-03','2026-09-03','09:02:41','ASOUZA','0002000005','4500010002',NULL,NULL,'Recebimento óleo hidráulico ISO VG 46'),
    ('4900001003','2026','0001','101','100000201','BR10','0001','S',    4,'PC', 1140000.00,'2026-09-05','2026-09-05','10:30:12','ASOUZA','0002000002','4500010003',NULL,NULL,'Recebimento pneus OTR 59/80R63'),
    ('4900001004','2026','0001','101','100000301','BR10','0001','S',   24,'PC', 1008000.00,'2026-09-08','2026-09-08','14:45:30','ASOUZA','0002000003','4500010004',NULL,NULL,'Importação lifter bars moinho SAG (AU)'),
    ('4900001005','2026','0001','101','100000401','BR20','0001','S',    3,'PC',   55500.00,'2026-09-10','2026-09-10','11:20:00','MCOSTA','0002000004','4500010005',NULL,NULL,'Kits emenda correia ST-2000'),
    ('4900001006','2026','0001','101','100000501','BR20','0001','S',    4,'PC',   93600.00,'2026-09-12','2026-09-12','15:05:44','MCOSTA','0002000001','4500010006',NULL,NULL,'Selos mecânicos bomba de polpa SP-250'),
    ('4900001007','2026','0001','101','100000601','BR10','0001','S',    1,'PC',  310000.00,'2026-09-15','2026-09-15','09:40:18','ASOUZA','0002000003','4500010007',NULL,NULL,'Importação cabo de elevação ES-4100 (AU)'),
    ('4900001008','2026','0001','101','100000701','BR10','0001','S',   10,'PC',   32000.00,'2026-09-16','2026-09-16','13:12:09','ASOUZA','0002000006','4500010008',NULL,NULL,'Cartuchos supressão de incêndio FS-30'),
    ('4900001008','2026','0002','101','100000801','BR10','0001','S',   20,'PC',   19000.00,'2026-09-16','2026-09-16','13:12:09','ASOUZA','0002000006','4500010008',NULL,NULL,'Kits pessoais de bloqueio LOTO'),
    ('4900001009','2026','0001','101','100000101','BR20','0001','S',    6,'PC',   11100.00,'2026-09-18','2026-09-18','10:01:55','MCOSTA','0002000001','4500010009',NULL,NULL,'Filtros hidráulicos HF-7720 - Itabira'),
    ('4900001010','2026','0001','311','100000101','BR10','0001','H',    6,'PC',   11100.00,'2026-09-20','2026-09-20','07:30:00','JPEREIRA',NULL,NULL,NULL,NULL,'Transferência para oficina'),
    ('4900001010','2026','0002','311','100000101','BR10','0002','S',    6,'PC',   11100.00,'2026-09-20','2026-09-20','07:30:00','JPEREIRA',NULL,NULL,NULL,NULL,'Transferência para oficina'),
    ('4900001011','2026','0001','311','100000102','BR10','0001','H',  400,'L',    11400.00,'2026-09-20','2026-09-20','07:35:00','JPEREIRA',NULL,NULL,NULL,NULL,'Transferência para oficina'),
    ('4900001011','2026','0002','311','100000102','BR10','0002','S',  400,'L',    11400.00,'2026-09-20','2026-09-20','07:35:00','JPEREIRA',NULL,NULL,NULL,NULL,'Transferência para oficina'),
    ('4900001012','2026','0001','261','100000101','BR10','0002','H',    2,'PC',    3700.00,'2026-09-28','2026-09-28','16:22:10','JPEREIRA',NULL,NULL,'4000123401','BR10MNT001','Troca filtro hidráulico HT-400 #07'),
    ('4900001012','2026','0002','261','100000102','BR10','0002','H',  180,'L',     5130.00,'2026-09-28','2026-09-28','16:22:10','JPEREIRA',NULL,NULL,'4000123401','BR10MNT001','Reposição óleo hidráulico HT-400 #07'),
    ('4900001013','2026','0001','261','100000201','BR10','0001','H',    2,'PC',  570000.00,'2026-10-02','2026-10-02','11:48:31','CLIMA',   NULL,NULL,'4000123470','BR10MNT001','Substituição pneus traseiros HT-400 #03'),
    ('4900001014','2026','0001','261','100000301','BR10','0001','H',   16,'PC',  672000.00,'2026-10-05','2026-10-05','06:15:00','JPEREIRA',NULL,NULL,'4000123480','BR10MNT002','Troca revestimento moinho SAG SM-40'),
    ('4900001015','2026','0001','261','100000101','BR10','0002','H',    2,'PC',    3700.00,'2026-10-09','2026-10-09','17:03:27','JPEREIRA',NULL,NULL,'4000123455','BR10MNT001','Troca filtro hidráulico HT-400 #12'),
    ('4900001015','2026','0002','261','100000102','BR10','0002','H',  160,'L',     4560.00,'2026-10-09','2026-10-09','17:03:27','JPEREIRA',NULL,NULL,'4000123455','BR10MNT001','Reposição óleo hidráulico HT-400 #12'),
    ('4900001016','2026','0001','261','100000401','BR20','0001','H',    1,'PC',   18500.00,'2026-10-11','2026-10-11','09:55:12','MCOSTA',  NULL,NULL,'4000124001','BR20MNT001','Emenda vulcanizada correia CV-12'),
    ('4900001017','2026','0001','261','100000501','BR20','0001','H',    3,'PC',   70200.00,'2026-10-14','2026-10-14','14:30:48','MCOSTA',  NULL,NULL,'4000124010','BR20MNT001','Troca selo mecânico bomba SP-250'),
    ('4900001018','2026','0001','261','100000101','BR10','0002','H',    1,'PC',    1850.00,'2026-10-20','2026-10-20','08:41:06','JPEREIRA',NULL,NULL,'4000123499','BR10MNT001','Troca filtro hidráulico HT-400 #05'),
    ('4900001019','2026','0001','261','100000101','BR20','0001','H',    5,'PC',    9250.00,'2026-10-21','2026-10-21','10:17:39','MCOSTA',  NULL,NULL,'4000124020','BR20MNT001','Troca filtros frota Itabira'),
    ('4900001020','2026','0001','261','100000701','BR10','0001','H',    2,'PC',    6400.00,'2026-10-22','2026-10-22','15:50:21','CLIMA',   NULL,NULL,'4000123510','BR10MNT001','Recarga supressão de incêndio HT-400 #07');

-- Universal Journal for every financially relevant material document (balanced per BELNR).
SELECT sap.post_material_document_to_fi(d.mblnr, d.mjahr)
  FROM (SELECT DISTINCT mblnr, mjahr FROM sap.matdoc) d
 ORDER BY d.mblnr;
