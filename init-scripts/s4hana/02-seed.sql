-- ═══════════════════════════════════════════════════════════════════════════
-- Seed data · SAP S/4HANA (simulated) — STRICTLY the three C-level business cases.
-- Synthetic: no real companies or people.
--   CASE 1 Compliance  : refiner customer blocked by its USD 5M credit limit (BUT000, UKMBP_CMS_SGM,
--                        ACDOCA open items translated with TCURR) with tax IDs CNPJ + IE (DFKKBPTAXNUM; XD01)
--   CASE 2 Leaching    : acid pump PB-LIX-02 down after a tropical storm; order already created (IW31)
--                        on cost center CC-LIX-01, spare SKU-BR-ACID-9902 reserved with ZERO stock
--   CASE 3 Flotation   : xanthate SKU-BR-REAG-4410 stock in Depósito 002 (BR10/0002), daily MIGO
--                        consumption at 10 g/t (~400 kg/day) before the dose change to 15 g/t
-- ═══════════════════════════════════════════════════════════════════════════

INSERT INTO sap.but000 (partner, type, bu_group, bu_sort1, name_org1, langu_corr, crdat) VALUES
    ('0005000001', '2', 'CLIE', 'REFATLANTICO', 'Refinaria Atlântico Sul S.A.',     'P', '2024-03-11'),  -- case 1
    ('0002000101', '2', 'FORN', 'BOMBASNORTE',  'Bombas Industriais do Norte Ltda', 'P', '2023-11-20'),  -- case 2
    ('0002000102', '2', 'FORN', 'QUIMFLOT',     'Química Flotação Brasil Ltda',     'P', '2024-01-08');  -- case 3

-- ── CASE 1 · Compliance ─────────────────────────────────────────────────────
INSERT INTO sap.ukmbp_cms_sgm (partner, credit_sgmnt, credit_limit, currency, xblocked, block_reason,
                               limit_valid_date, limit_chg_date) VALUES
    ('0005000001', '0000', 5000000.00, 'USD', 'X', '01', '2026-12-31', '2026-01-15');

INSERT INTO sap.dfkkbptaxnum (partner, taxtype, taxnum) VALUES
    ('0005000001', 'BR1', '11.222.333/0001-81'),   -- CNPJ
    ('0005000001', 'BR3', '123.456.789.110');      -- Inscrição Estadual

-- Monthly average USD/BRL rates (type M, synthetic history). Each foreign-currency posting is
-- translated at the rate valid on its posting date; the credit tool revalues at the LIVE rate.
INSERT INTO sap.tcurr (kurst, fcurr, tcurr, gdatu, ukurs) VALUES
    ('M', 'USD', 'BRL', '2026-07-01', 5.41200),
    ('M', 'USD', 'BRL', '2026-08-01', 5.36550),
    ('M', 'USD', 'BRL', '2026-09-01', 5.33100),
    ('M', 'USD', 'BRL', '2026-10-01', 5.38900);

-- Copper concentrate sales in USD. Exposure = open items (augbl NULL): USD 5,420,000 against a
-- USD 5,000,000 limit; USD 3,450,000 already overdue. HSL (BRL) comes from TCURR, never a constant.
INSERT INTO sap.acdoca (rbukrs, gjahr, belnr, docln, racct, koart, kunnr, drcrk, rwcur, wsl, rhcur, hsl,
                        budat, netdt, blart, awtyp, awref, aworg, augbl, augdt, prctr, sgtxt, usnam)
SELECT 'BR01', '2026', l.belnr, l.docln, l.racct, l.koart, l.kunnr, l.drcrk, 'USD', l.wsl, 'BRL',
       round(l.wsl * sap.fx_rate('USD', 'BRL', l.budat), 2),
       l.budat, l.netdt, l.blart, l.awtyp, l.belnr, '2026', l.augbl, l.augdt, 'PCBR10', l.sgtxt, l.usnam
  FROM (VALUES
    ('9000004101','000001','0011200000','D','0005000001','S', 1250000.00, date '2026-07-10', date '2026-08-09','RV','VBRK','1400000201', date '2026-08-08','Venda concentrado de cobre - NF 104511','FATURAMENTO'),
    ('9000004101','000002','0031100000','S',NULL,        'H',-1250000.00, date '2026-07-10', NULL,             'RV','VBRK',NULL,         NULL,             'Venda concentrado de cobre - NF 104511','FATURAMENTO'),
    ('1400000201','000001','0011100000','S',NULL,        'S', 1250000.00, date '2026-08-08', NULL,             'DZ','BKPF',NULL,         NULL,             'Recebimento NF 104511','TESOURARIA'),
    ('1400000201','000002','0011200000','D','0005000001','H',-1250000.00, date '2026-08-08', NULL,             'DZ','BKPF','1400000201', date '2026-08-08','Recebimento NF 104511','TESOURARIA'),
    ('9000004188','000001','0011200000','D','0005000001','S', 1800000.00, date '2026-08-21', date '2026-09-20','RV','VBRK',NULL,         NULL,             'Venda concentrado de cobre - NF 104598','FATURAMENTO'),
    ('9000004188','000002','0031100000','S',NULL,        'H',-1800000.00, date '2026-08-21', NULL,             'RV','VBRK',NULL,         NULL,             'Venda concentrado de cobre - NF 104598','FATURAMENTO'),
    ('9000004230','000001','0011200000','D','0005000001','S', 1650000.00, date '2026-09-18', date '2026-10-18','RV','VBRK',NULL,         NULL,             'Venda concentrado de cobre - NF 104655','FATURAMENTO'),
    ('9000004230','000002','0031100000','S',NULL,        'H',-1650000.00, date '2026-09-18', NULL,             'RV','VBRK',NULL,         NULL,             'Venda concentrado de cobre - NF 104655','FATURAMENTO'),
    ('9000004297','000001','0011200000','D','0005000001','S', 1970000.00, date '2026-10-16', date '2026-11-15','RV','VBRK',NULL,         NULL,             'Venda concentrado de cobre - NF 104731','FATURAMENTO'),
    ('9000004297','000002','0031100000','S',NULL,        'H',-1970000.00, date '2026-10-16', NULL,             'RV','VBRK',NULL,         NULL,             'Venda concentrado de cobre - NF 104731','FATURAMENTO')
  ) AS l(belnr, docln, racct, koart, kunnr, drcrk, wsl, budat, netdt, blart, awtyp, augbl, augdt, sgtxt, usnam);

-- ── CASE 2 · Leaching (PM) ──────────────────────────────────────────────────
INSERT INTO sap.aufk (aufnr, auart, ktext, werks, kostl, equnr, erdat, ernam, phas0, phas1, phas2, phas3) VALUES
    ('4000187730', 'PM01', 'Troca selo bomba PB-LIX-01',               'BR20', 'CC-LIX-01', 'PB-LIX-01', '2026-06-05', 'MPLANEJ', 'X', 'X', 'X', 'X'),
    ('4000194455', 'PM01', 'Troca selo bomba PB-LIX-03',               'BR20', 'CC-LIX-01', 'PB-LIX-03', '2026-09-10', 'MPLANEJ', 'X', 'X', 'X', 'X'),
    ('4000200101', 'PM01', 'Reparo bomba PB-LIX-02 (dano tempestade)', 'BR20', 'CC-LIX-01', 'PB-LIX-02', '2026-10-24', 'MPLANEJ', 'X', 'X', '',  '');

INSERT INTO sap.qmel (qmnum, qmart, qmtxt, equnr, iwerk, qmdat, mzeit, priok, msaus, ausvn, aufnr, qmnam) VALUES
    ('10004521', 'M2', 'Falha bomba ácido PB-LIX-02 (tempestade)', 'PB-LIX-02', 'BR20', '2026-10-24', '03:40:00', '1', 'X', '2026-10-24', '4000200101', 'OPERLIX');

INSERT INTO sap.resb (rsnum, rspos, matnr, werks, lgort, bdmng, enmng, meins, bdter, bwart, aufnr) VALUES
    ('0000501234', '0001', 'SKU-BR-ACID-9902', 'BR20', '0001', 1, 0, 'PC', '2026-10-25', '261', '4000200101');

-- Spare history: 2 kits received, both consumed by earlier pump repairs → stock 0 today.
INSERT INTO sap.matdoc (mblnr, mjahr, zeile, bwart, matnr, werks, lgort, shkzg, menge, meins, dmbtr, budat, cpudt, cputm, usnam, lifnr, ebeln, aufnr, kostl, sgtxt) VALUES
    ('4900002001','2026','0001','101','SKU-BR-ACID-9902','BR20','0001','S',2,'PC',77000.00,'2026-03-18','2026-03-18','10:12:40','RSANTOS','0002000101','4500020001',NULL,        NULL,       'Recebimento kit selo/impulsor bomba ácido'),
    ('4900002002','2026','0001','261','SKU-BR-ACID-9902','BR20','0001','H',1,'PC',38500.00,'2026-06-07','2026-06-07','14:05:12','RSANTOS',NULL,        NULL,        '4000187730','CC-LIX-01','Troca selo bomba PB-LIX-01'),
    ('4900002003','2026','0001','261','SKU-BR-ACID-9902','BR20','0001','H',1,'PC',38500.00,'2026-09-12','2026-09-12','09:47:55','RSANTOS',NULL,        NULL,        '4000194455','CC-LIX-01','Troca selo bomba PB-LIX-03');

-- ── CASE 3 · Flotation ──────────────────────────────────────────────────────
INSERT INTO sap.matdoc (mblnr, mjahr, zeile, bwart, matnr, werks, lgort, shkzg, menge, meins, dmbtr, budat, cpudt, cputm, usnam, lifnr, ebeln, sgtxt) VALUES
    ('4900003001','2026','0001','101','SKU-BR-REAG-4410','BR10','0002','S',12000,'KG',256800.00,'2026-10-14','2026-10-14','11:20:00','CSILVA','0002000102','4500030001','Recebimento xantato SIPX - Depósito 002');

-- Daily MIGO goods issues (201) to the flotation cost center at 10 g/t: 4,800 kg in 12 days.
INSERT INTO sap.matdoc (mblnr, mjahr, zeile, bwart, matnr, werks, lgort, shkzg, menge, meins, dmbtr, budat, cpudt, cputm, usnam, kostl, sgtxt)
SELECT (4900003001 + d.n)::text, '2026', '0001', '201', 'SKU-BR-REAG-4410', 'BR10', '0002', 'H', d.qty, 'KG',
       round(d.qty * 21.40, 2), date '2026-10-14' + d.n::int, date '2026-10-14' + d.n::int, time '23:40:00',
       'CSILVA', 'CC-FLO-01', 'Consumo diário xantato flotação (10 g/t)'
  FROM unnest(ARRAY[395, 410, 402, 388, 415, 398, 405, 392, 410, 400, 396, 389]) WITH ORDINALITY AS d(qty, n);

-- Universal Journal for every financially relevant material document (balanced per BELNR).
SELECT sap.post_material_document_to_fi(d.mblnr, d.mjahr)
  FROM (SELECT DISTINCT mblnr, mjahr FROM sap.matdoc) d
 ORDER BY d.mblnr;
