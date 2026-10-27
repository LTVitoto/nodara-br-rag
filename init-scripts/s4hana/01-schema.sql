-- ═══════════════════════════════════════════════════════════════════════════
-- Nodara BR-RAG · SAP S/4HANA (simulated) — transactional layer, purely relational
--   BUT000  Business Partner: general data
--   MATDOC  Inventory management: material documents (S/4 single-table design)
--   ACDOCA  Universal Journal (FI/CO line items)
-- SAP field names kept as-is (lower case). Client (MANDT/RCLNT) = '100'.
-- Company code BR01 · plants BR10 Carajás (PA), BR20 Itabira (MG).
-- ═══════════════════════════════════════════════════════════════════════════
CREATE SCHEMA sap;
COMMENT ON SCHEMA sap IS 'SAP S/4HANA (simulated) - Nodara Mineracao Brasil, company code BR01';

-- BUT000 · Business Partner: general data ────────────────────────────────────
CREATE TABLE sap.but000 (
    mandt       char(3)     NOT NULL DEFAULT '100',
    partner     varchar(10) NOT NULL,                 -- business partner number
    type        char(1)     NOT NULL,                 -- BP category: 1 person, 2 organization
    bu_group    varchar(4)  NOT NULL,                 -- grouping: FORN supplier, FUNC employee, EMPR company
    bu_sort1    varchar(20) NOT NULL,                 -- search term 1
    name_org1   varchar(40),                          -- organization name
    name_first  varchar(40),                          -- first name (persons)
    name_last   varchar(40),                          -- last name (persons)
    langu_corr  char(1)     NOT NULL DEFAULT 'P',     -- correspondence language: P pt, E en
    xblck       varchar(1)  NOT NULL DEFAULT '',      -- central block ('X' = blocked)
    crusr       varchar(12) NOT NULL DEFAULT 'MIGRATION',
    crdat       date        NOT NULL DEFAULT current_date,
    PRIMARY KEY (mandt, partner),
    CHECK (type IN ('1', '2', '3'))
);
COMMENT ON TABLE sap.but000 IS 'BP: General data I (suppliers, employees, company)';

-- MATDOC · Material documents (goods receipts, issues, transfers) ─────────────
CREATE TABLE sap.matdoc (
    mandt   char(3)       NOT NULL DEFAULT '100',
    mblnr   varchar(10)   NOT NULL,                   -- material document number
    mjahr   char(4)       NOT NULL,                   -- material document year
    zeile   varchar(4)    NOT NULL,                   -- item
    bwart   varchar(3)    NOT NULL,                   -- movement type: 101 GR, 261 GI to order, 311 transfer
    matnr   varchar(40)   NOT NULL,                   -- material number
    werks   varchar(4)    NOT NULL,                   -- plant
    lgort   varchar(4)    NOT NULL,                   -- storage location
    shkzg   char(1)       NOT NULL,                   -- S = receipt (+), H = issue (-)
    menge   numeric(13,3) NOT NULL,                   -- quantity in base unit
    meins   varchar(3)    NOT NULL,                   -- base unit of measure
    dmbtr   numeric(23,2) NOT NULL,                   -- amount in local currency
    waers   varchar(5)    NOT NULL DEFAULT 'BRL',
    budat   date          NOT NULL,                   -- posting date
    cpudt   date          NOT NULL DEFAULT current_date,
    cputm   time(0)       NOT NULL DEFAULT localtime(0),
    usnam   varchar(12)   NOT NULL,                   -- user
    lifnr   varchar(10),                              -- supplier (BUT000.PARTNER)
    ebeln   varchar(10),                              -- purchase order
    aufnr   varchar(12),                              -- maintenance order
    kostl   varchar(10),                              -- cost center
    sgtxt   varchar(50),                              -- item text
    PRIMARY KEY (mandt, mblnr, mjahr, zeile),
    CHECK (shkzg IN ('S', 'H')),
    CHECK (menge > 0)
);
CREATE INDEX matdoc_stock_idx ON sap.matdoc (matnr, werks, lgort);
COMMENT ON TABLE sap.matdoc IS 'Material documents - stock = sum(S) - sum(H) per matnr/werks/lgort';

-- ACDOCA · Universal Journal ─────────────────────────────────────────────────
CREATE TABLE sap.acdoca (
    rclnt   char(3)       NOT NULL DEFAULT '100',
    rldnr   varchar(2)    NOT NULL DEFAULT '0L',      -- ledger
    rbukrs  varchar(4)    NOT NULL,                   -- company code
    gjahr   char(4)       NOT NULL,                   -- fiscal year
    belnr   varchar(10)   NOT NULL,                   -- accounting document
    docln   varchar(6)    NOT NULL,                   -- line item
    racct   varchar(10)   NOT NULL,                   -- G/L account
    drcrk   char(1)       NOT NULL,                   -- S debit / H credit
    rwcur   varchar(5)    NOT NULL DEFAULT 'BRL',     -- transaction currency
    wsl     numeric(23,2) NOT NULL,                   -- amount in transaction currency (signed)
    rhcur   varchar(5)    NOT NULL DEFAULT 'BRL',     -- local currency
    hsl     numeric(23,2) NOT NULL,                   -- amount in local currency (signed)
    budat   date          NOT NULL,
    blart   varchar(2)    NOT NULL,                   -- document type: WE goods receipt, WA goods issue
    awtyp   varchar(5)    NOT NULL DEFAULT 'MKPF',    -- reference procedure
    awref   varchar(10)   NOT NULL,                   -- reference document (MATDOC.MBLNR)
    aworg   varchar(10)   NOT NULL,                   -- reference org. units (MATDOC.MJAHR)
    awitem  varchar(6),                               -- reference item (MATDOC.ZEILE)
    matnr   varchar(40),
    werks   varchar(4),
    rcntr   varchar(10),                              -- cost center
    prctr   varchar(10),                              -- profit center
    aufnr   varchar(12),                              -- order
    lifnr   varchar(10),                              -- supplier
    sgtxt   varchar(50),
    usnam   varchar(12)   NOT NULL,
    PRIMARY KEY (rclnt, rldnr, rbukrs, gjahr, belnr, docln),
    CHECK (drcrk IN ('S', 'H'))
);
CREATE INDEX acdoca_material_idx ON sap.acdoca (matnr, budat);
CREATE INDEX acdoca_reference_idx ON sap.acdoca (awref, aworg);
COMMENT ON TABLE sap.acdoca IS 'Universal Journal - MM postings derived from MATDOC (balanced per BELNR)';

-- Number ranges (seed data uses MBLNR 49000010xx) ─────────────────────────────
CREATE SEQUENCE sap.matdoc_number_seq START 4900001100;
CREATE SEQUENCE sap.acdoca_number_seq START 5000000001;

-- Automatic account determination MM → FI, as S/4 posts it:
--   101 goods receipt  : Dr 0013100000 inventory    / Cr 0021100000 GR/IR clearing
--   261 goods issue    : Dr 0061000000 consumption  / Cr 0013100000 inventory
--   311 transfer (same plant): no financial impact
CREATE FUNCTION sap.post_material_document_to_fi(p_mblnr varchar, p_mjahr char(4))
RETURNS varchar
LANGUAGE plpgsql AS $$
#variable_conflict use_column
DECLARE
    v_belnr varchar(10);
    v_line  int := 0;
    r       record;
BEGIN
    FOR r IN
        SELECT * FROM sap.matdoc m
         WHERE m.mblnr = p_mblnr AND m.mjahr = p_mjahr AND m.bwart IN ('101', '261')
         ORDER BY m.zeile
    LOOP
        v_belnr := coalesce(v_belnr, nextval('sap.acdoca_number_seq')::text);

        v_line := v_line + 1;  -- debit line
        INSERT INTO sap.acdoca (rbukrs, gjahr, belnr, docln, racct, drcrk, wsl, hsl, budat, blart,
                                awref, aworg, awitem, matnr, werks, rcntr, prctr, aufnr, lifnr, sgtxt, usnam)
        VALUES ('BR01', r.mjahr, v_belnr, lpad(v_line::text, 6, '0'),
                CASE r.bwart WHEN '101' THEN '0013100000' ELSE '0061000000' END, 'S',
                r.dmbtr, r.dmbtr, r.budat, CASE r.bwart WHEN '101' THEN 'WE' ELSE 'WA' END,
                r.mblnr, r.mjahr, r.zeile, r.matnr, r.werks,
                CASE r.bwart WHEN '261' THEN r.kostl END, 'PC' || r.werks,
                CASE r.bwart WHEN '261' THEN r.aufnr END, NULL, r.sgtxt, r.usnam);

        v_line := v_line + 1;  -- credit line
        INSERT INTO sap.acdoca (rbukrs, gjahr, belnr, docln, racct, drcrk, wsl, hsl, budat, blart,
                                awref, aworg, awitem, matnr, werks, rcntr, prctr, aufnr, lifnr, sgtxt, usnam)
        VALUES ('BR01', r.mjahr, v_belnr, lpad(v_line::text, 6, '0'),
                CASE r.bwart WHEN '101' THEN '0021100000' ELSE '0013100000' END, 'H',
                -r.dmbtr, -r.dmbtr, r.budat, CASE r.bwart WHEN '101' THEN 'WE' ELSE 'WA' END,
                r.mblnr, r.mjahr, r.zeile, r.matnr, r.werks,
                NULL, 'PC' || r.werks, NULL,
                CASE r.bwart WHEN '101' THEN r.lifnr END, r.sgtxt, r.usnam);
    END LOOP;
    RETURN v_belnr;
END $$;

-- Plant-floor simulator for CDC demos: goods issues to maintenance orders and automatic
-- replenishment when a stock position runs low. Each event = MATDOC + ACDOCA in one txn.
--   SELECT * FROM sap.simulate_activity(5);
CREATE FUNCTION sap.simulate_activity(p_events int DEFAULT 5)
RETURNS TABLE (mblnr varchar, bwart varchar, matnr varchar, werks varchar, lgort varchar,
               menge numeric, meins varchar, dmbtr numeric)
LANGUAGE plpgsql AS $$
#variable_conflict use_column
DECLARE
    s       record;
    v_mblnr varchar(10);
    v_year  char(4) := to_char(current_date, 'YYYY');
    v_qty   numeric(13,3);
BEGIN
    FOR i IN 1..p_events LOOP
        SELECT st.matnr, st.werks, st.lgort, st.meins, st.qty, gr.price, gr.lifnr
          INTO s
          FROM (SELECT m.matnr, m.werks, m.lgort, m.meins,
                       sum(CASE m.shkzg WHEN 'S' THEN m.menge ELSE -m.menge END) AS qty
                  FROM sap.matdoc m
                 GROUP BY m.matnr, m.werks, m.lgort, m.meins) st
          CROSS JOIN LATERAL (
                SELECT round(g.dmbtr / g.menge, 2) AS price, g.lifnr
                  FROM sap.matdoc g
                 WHERE g.matnr = st.matnr AND g.bwart = '101'
                 ORDER BY g.budat DESC, g.mblnr DESC
                 LIMIT 1) gr
         ORDER BY random()
         LIMIT 1;

        v_mblnr := nextval('sap.matdoc_number_seq')::text;

        IF s.qty <= 1 THEN
            -- replenishment: goods receipt for purchase order (101)
            v_qty := CASE WHEN s.meins = 'L' THEN 1000 ELSE 4 END;
            INSERT INTO sap.matdoc (mblnr, mjahr, zeile, bwart, matnr, werks, lgort, shkzg, menge, meins,
                                    dmbtr, budat, usnam, lifnr, ebeln, sgtxt)
            VALUES (v_mblnr, v_year, '0001', '101', s.matnr, s.werks, s.lgort, 'S', v_qty, s.meins,
                    round(v_qty * s.price, 2), current_date, 'SIMULATOR', s.lifnr,
                    '45000' || lpad(floor(random() * 99999)::text, 5, '0'),
                    'Reposicao automatica (simulador)');
        ELSE
            -- consumption: goods issue to a maintenance order (261)
            v_qty := CASE WHEN s.meins = 'L' THEN least(s.qty, 20 + floor(random() * 80))
                          ELSE least(s.qty, 1 + floor(random() * 2)) END;
            INSERT INTO sap.matdoc (mblnr, mjahr, zeile, bwart, matnr, werks, lgort, shkzg, menge, meins,
                                    dmbtr, budat, usnam, aufnr, kostl, sgtxt)
            VALUES (v_mblnr, v_year, '0001', '261', s.matnr, s.werks, s.lgort, 'H', v_qty, s.meins,
                    round(v_qty * s.price, 2), current_date, 'SIMULATOR',
                    '40001' || lpad(floor(random() * 99999)::text, 5, '0'),
                    CASE s.werks WHEN 'BR10' THEN 'BR10MNT001' ELSE 'BR20MNT001' END,
                    'Consumo ordem de manutencao (simulador)');
        END IF;

        PERFORM sap.post_material_document_to_fi(v_mblnr, v_year);

        RETURN QUERY
            SELECT d.mblnr, d.bwart, d.matnr, d.werks, d.lgort, d.menge, d.meins, d.dmbtr
              FROM sap.matdoc d
             WHERE d.mblnr = v_mblnr AND d.mjahr = v_year;
    END LOOP;
END $$;
