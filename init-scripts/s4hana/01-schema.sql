-- ═══════════════════════════════════════════════════════════════════════════
-- Nodara BR-RAG · SAP S/4HANA (simulated) — transactional layer, purely relational
-- SAP tables kept with their original names and fields (lower case), client '100':
--   BUT000        Business Partner: general data
--   UKMBP_CMS_SGM FSCM Credit Management: credit segment data (limit, block)
--   DFKKBPTAXNUM  Business Partner tax numbers (Brazil: CNPJ, Inscrição Estadual)
--   MATDOC        Inventory management: material documents (S/4 single-table design)
--   ACDOCA        Universal Journal (FI/CO line items, incl. customer open items)
--   QMEL / AUFK   Plant Maintenance: notifications / orders (AFIH equipment flattened into AUFK)
--   RESB          Reservations / dependent requirements of maintenance orders
--   TCURR         Exchange rates (type M) used to post foreign-currency documents
-- Company code BR01 · plants BR10 flotation and BR20 leaching (Carajás, PA).
-- ═══════════════════════════════════════════════════════════════════════════
CREATE SCHEMA sap;
COMMENT ON SCHEMA sap IS 'SAP S/4HANA (simulated) - Nodara Mineracao Brasil, company code BR01';

-- BUT000 · Business Partner: general data ────────────────────────────────────
CREATE TABLE sap.but000 (
    mandt       char(3)     NOT NULL DEFAULT '100',
    partner     varchar(10) NOT NULL,                 -- business partner number
    type        char(1)     NOT NULL,                 -- BP category: 1 person, 2 organization
    bu_group    varchar(4)  NOT NULL,                 -- grouping: CLIE customer, FORN supplier
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
COMMENT ON TABLE sap.but000 IS 'BP: General data I (customers and suppliers)';

-- UKMBP_CMS_SGM · Credit Management: credit segment data ─────────────────────
CREATE TABLE sap.ukmbp_cms_sgm (
    client           char(3)       NOT NULL DEFAULT '100',
    partner          varchar(10)   NOT NULL,
    credit_sgmnt     varchar(10)   NOT NULL,            -- credit segment
    credit_limit     numeric(15,2) NOT NULL,
    currency         varchar(5)    NOT NULL,            -- credit segment currency
    xblocked         varchar(1)    NOT NULL DEFAULT '', -- 'X' = blocked in credit management
    block_reason     varchar(2)    NOT NULL DEFAULT '', -- 01 limit exceeded, 02 overdue items, 03 KYC pending
    limit_valid_date date,
    limit_chg_date   date,
    PRIMARY KEY (client, partner, credit_sgmnt)
);
COMMENT ON TABLE sap.ukmbp_cms_sgm IS 'FSCM Credit Management: credit limit and block per BP and credit segment';

-- DFKKBPTAXNUM · Business Partner tax numbers ────────────────────────────────
CREATE TABLE sap.dfkkbptaxnum (
    client  char(3)     NOT NULL DEFAULT '100',
    partner varchar(10) NOT NULL,
    taxtype varchar(4)  NOT NULL,                       -- BR1 CNPJ, BR2 CPF, BR3 Inscrição Estadual, BR4 Inscrição Municipal
    taxnum  varchar(20) NOT NULL,
    PRIMARY KEY (client, partner, taxtype)
);
COMMENT ON TABLE sap.dfkkbptaxnum IS 'BP tax numbers (Brazil: CNPJ and Inscricao Estadual are mandatory in XD01)';

-- MATDOC · Material documents (goods receipts, issues, transfers) ─────────────
CREATE TABLE sap.matdoc (
    mandt   char(3)       NOT NULL DEFAULT '100',
    mblnr   varchar(10)   NOT NULL,                   -- material document number
    mjahr   char(4)       NOT NULL,                   -- material document year
    zeile   varchar(4)    NOT NULL,                   -- item
    bwart   varchar(3)    NOT NULL,                   -- movement type: 101 GR, 201 GI to cost center, 261 GI to order
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
    tcode2  varchar(20)   NOT NULL DEFAULT 'MIGO',    -- transaction code of the posting
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
    koart   varchar(1)    NOT NULL,                   -- account type: D customer, K supplier, M material, S G/L
    drcrk   char(1)       NOT NULL,                   -- S debit / H credit
    rwcur   varchar(5)    NOT NULL DEFAULT 'BRL',     -- transaction currency
    wsl     numeric(23,2) NOT NULL,                   -- amount in transaction currency (signed)
    rhcur   varchar(5)    NOT NULL DEFAULT 'BRL',     -- local currency
    hsl     numeric(23,2) NOT NULL,                   -- amount in local currency (signed)
    budat   date          NOT NULL,
    netdt   date,                                     -- net due date (open items)
    blart   varchar(2)    NOT NULL,                   -- WE goods receipt, WA goods issue, RV billing, DZ incoming payment
    awtyp   varchar(5)    NOT NULL DEFAULT 'MKPF',    -- reference procedure
    awref   varchar(10)   NOT NULL,                   -- reference document
    aworg   varchar(10)   NOT NULL,                   -- reference org. units
    awitem  varchar(6),                               -- reference item
    kunnr   varchar(10),                              -- customer (BUT000.PARTNER)
    lifnr   varchar(10),                              -- supplier
    augbl   varchar(10),                              -- clearing document (NULL = open item)
    augdt   date,                                     -- clearing date
    matnr   varchar(40),
    werks   varchar(4),
    rcntr   varchar(10),                              -- cost center
    prctr   varchar(10),                              -- profit center
    aufnr   varchar(12),                              -- order
    sgtxt   varchar(50),
    usnam   varchar(12)   NOT NULL,
    PRIMARY KEY (rclnt, rldnr, rbukrs, gjahr, belnr, docln),
    CHECK (drcrk IN ('S', 'H'))
);
CREATE INDEX acdoca_material_idx ON sap.acdoca (matnr, budat);
CREATE INDEX acdoca_open_items_idx ON sap.acdoca (kunnr) WHERE augbl IS NULL;
COMMENT ON TABLE sap.acdoca IS 'Universal Journal - balanced per BELNR; customer open items = koart D and augbl NULL';

-- QMEL · Maintenance notifications ───────────────────────────────────────────
CREATE TABLE sap.qmel (
    mandt  char(3)     NOT NULL DEFAULT '100',
    qmnum  varchar(12) NOT NULL,                      -- notification number
    qmart  varchar(2)  NOT NULL,                      -- M1 maintenance request, M2 malfunction report
    qmtxt  varchar(40) NOT NULL,                      -- short text
    equnr  varchar(18),                               -- equipment
    iwerk  varchar(4)  NOT NULL,                      -- maintenance planning plant
    qmdat  date        NOT NULL,
    mzeit  time(0),
    priok  varchar(1),                                -- priority: 1 very high ... 4 low
    msaus  varchar(1)  NOT NULL DEFAULT '',           -- 'X' = breakdown
    ausvn  date,                                      -- malfunction start
    aufnr  varchar(12),                               -- maintenance order
    qmnam  varchar(12) NOT NULL,                      -- reported by
    PRIMARY KEY (mandt, qmnum)
);
COMMENT ON TABLE sap.qmel IS 'PM notifications (malfunction reports)';

-- AUFK · Order master data (maintenance orders) ──────────────────────────────
CREATE TABLE sap.aufk (
    mandt  char(3)     NOT NULL DEFAULT '100',
    aufnr  varchar(12) NOT NULL,
    auart  varchar(4)  NOT NULL,                      -- PM01 corrective, PM02 preventive
    autyp  varchar(2)  NOT NULL DEFAULT '30',         -- 30 = maintenance order
    ktext  varchar(40) NOT NULL,                      -- description
    werks  varchar(4)  NOT NULL,
    kostl  varchar(10) NOT NULL,                      -- responsible cost center (receives the costs)
    equnr  varchar(18),                               -- equipment (AFIH-EQUNR, flattened)
    erdat  date        NOT NULL,
    ernam  varchar(12) NOT NULL,
    phas0  varchar(1)  NOT NULL DEFAULT 'X',          -- created
    phas1  varchar(1)  NOT NULL DEFAULT '',           -- released
    phas2  varchar(1)  NOT NULL DEFAULT '',           -- technically completed
    phas3  varchar(1)  NOT NULL DEFAULT '',           -- closed
    PRIMARY KEY (mandt, aufnr)
);
COMMENT ON TABLE sap.aufk IS 'Maintenance orders (created with IW31); open = phas2 and phas3 empty';

-- RESB · Reservations / dependent requirements ───────────────────────────────
CREATE TABLE sap.resb (
    mandt char(3)       NOT NULL DEFAULT '100',
    rsnum varchar(10)   NOT NULL,
    rspos varchar(4)    NOT NULL,
    matnr varchar(40)   NOT NULL,
    werks varchar(4)    NOT NULL,
    lgort varchar(4)    NOT NULL,
    bdmng numeric(13,3) NOT NULL,                     -- requirement quantity
    enmng numeric(13,3) NOT NULL DEFAULT 0,           -- quantity withdrawn
    meins varchar(3)    NOT NULL,
    bdter date          NOT NULL,                     -- requirement date
    bwart varchar(3)    NOT NULL,
    aufnr varchar(12),
    kzear varchar(1)    NOT NULL DEFAULT '',          -- final issue
    xloek varchar(1)    NOT NULL DEFAULT '',          -- deleted
    PRIMARY KEY (mandt, rsnum, rspos)
);
COMMENT ON TABLE sap.resb IS 'Reservations of maintenance orders (open = bdmng > enmng)';

-- TCURR · Exchange rates ─────────────────────────────────────────────────────
CREATE TABLE sap.tcurr (
    mandt char(3)       NOT NULL DEFAULT '100',
    kurst varchar(4)    NOT NULL,                     -- exchange rate type: M = average rate
    fcurr varchar(5)    NOT NULL,                     -- from currency
    tcurr varchar(5)    NOT NULL,                     -- to currency
    gdatu date          NOT NULL,                     -- valid from (SAP stores it inverted; plain date here)
    ukurs numeric(9,5)  NOT NULL,                     -- exchange rate
    PRIMARY KEY (mandt, kurst, fcurr, tcurr, gdatu)
);
COMMENT ON TABLE sap.tcurr IS 'Exchange rates: foreign-currency postings use the rate valid on the posting date';

-- Rate valid on a date, as S/4 translates foreign-currency postings (no fixed rates).
CREATE FUNCTION sap.fx_rate(p_from varchar, p_to varchar, p_date date, p_type varchar DEFAULT 'M')
RETURNS numeric
LANGUAGE sql STABLE AS $$
    SELECT t.ukurs FROM sap.tcurr t
     WHERE t.kurst = p_type AND t.fcurr = p_from AND t.tcurr = p_to AND t.gdatu <= p_date
     ORDER BY t.gdatu DESC
     LIMIT 1
$$;

-- Number ranges (seed documents use 49000020xx / 49000030xx) ────────────────
CREATE SEQUENCE sap.matdoc_number_seq START 4900004001;
CREATE SEQUENCE sap.acdoca_number_seq START 5000000001;

-- Automatic account determination MM → FI, as S/4 posts it:
--   101 goods receipt          : Dr 0013100000 inventory          / Cr 0021100000 GR/IR clearing
--   201 goods issue cost center: Dr 0061200000 reagent consumption / Cr 0013100000 inventory
--   261 goods issue to order   : Dr 0061000000 maint. consumption  / Cr 0013100000 inventory
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
         WHERE m.mblnr = p_mblnr AND m.mjahr = p_mjahr AND m.bwart IN ('101', '201', '261')
         ORDER BY m.zeile
    LOOP
        v_belnr := coalesce(v_belnr, nextval('sap.acdoca_number_seq')::text);

        v_line := v_line + 1;  -- debit line
        INSERT INTO sap.acdoca (rbukrs, gjahr, belnr, docln, racct, koart, drcrk, wsl, hsl, budat, blart,
                                awref, aworg, awitem, matnr, werks, rcntr, prctr, aufnr, lifnr, sgtxt, usnam)
        VALUES ('BR01', r.mjahr, v_belnr, lpad(v_line::text, 6, '0'),
                CASE r.bwart WHEN '101' THEN '0013100000' WHEN '201' THEN '0061200000' ELSE '0061000000' END,
                CASE r.bwart WHEN '101' THEN 'M' ELSE 'S' END, 'S',
                r.dmbtr, r.dmbtr, r.budat, CASE r.bwart WHEN '101' THEN 'WE' ELSE 'WA' END,
                r.mblnr, r.mjahr, r.zeile, r.matnr, r.werks,
                CASE WHEN r.bwart <> '101' THEN r.kostl END, 'PC' || r.werks,
                CASE r.bwart WHEN '261' THEN r.aufnr END, NULL, r.sgtxt, r.usnam);

        v_line := v_line + 1;  -- credit line
        INSERT INTO sap.acdoca (rbukrs, gjahr, belnr, docln, racct, koart, drcrk, wsl, hsl, budat, blart,
                                awref, aworg, awitem, matnr, werks, rcntr, prctr, aufnr, lifnr, sgtxt, usnam)
        VALUES ('BR01', r.mjahr, v_belnr, lpad(v_line::text, 6, '0'),
                CASE r.bwart WHEN '101' THEN '0021100000' ELSE '0013100000' END,
                CASE r.bwart WHEN '101' THEN 'S' ELSE 'M' END, 'H',
                -r.dmbtr, -r.dmbtr, r.budat, CASE r.bwart WHEN '101' THEN 'WE' ELSE 'WA' END,
                r.mblnr, r.mjahr, r.zeile, r.matnr, r.werks,
                NULL, 'PC' || r.werks, NULL,
                CASE r.bwart WHEN '101' THEN r.lifnr END, r.sgtxt, r.usnam);
    END LOOP;
    RETURN v_belnr;
END $$;

-- Plant-floor simulator for CDC demos (case 3 only, so cases 1 and 2 stay intact):
-- one flotation shift consumes xanthate from Depósito 002 via MIGO (movement 201);
-- when the stock would fall below 3,000 kg, a 12,000 kg goods receipt (101) is posted first.
--   SELECT * FROM sap.simulate_activity(5);
CREATE FUNCTION sap.simulate_activity(p_events int DEFAULT 5)
RETURNS TABLE (mblnr varchar, bwart varchar, matnr varchar, werks varchar, lgort varchar,
               menge numeric, meins varchar, dmbtr numeric)
LANGUAGE plpgsql AS $$
#variable_conflict use_column
DECLARE
    c_matnr CONSTANT varchar := 'SKU-BR-REAG-4410';
    v_year  char(4) := to_char(current_date, 'YYYY');
    v_stock numeric;
    v_price numeric;
    v_lifnr varchar;
    v_qty   numeric(13,3);
    v_mblnr varchar(10);
BEGIN
    FOR i IN 1..p_events LOOP
        SELECT coalesce(sum(CASE m.shkzg WHEN 'S' THEN m.menge ELSE -m.menge END), 0)
          INTO v_stock
          FROM sap.matdoc m
         WHERE m.matnr = c_matnr AND m.werks = 'BR10' AND m.lgort = '0002';
        SELECT round(g.dmbtr / g.menge, 2), g.lifnr
          INTO v_price, v_lifnr
          FROM sap.matdoc g
         WHERE g.matnr = c_matnr AND g.bwart = '101'
         ORDER BY g.budat DESC, g.mblnr DESC
         LIMIT 1;

        v_qty := 120 + floor(random() * 41);
        v_mblnr := nextval('sap.matdoc_number_seq')::text;
        IF v_stock - v_qty < 3000 THEN
            INSERT INTO sap.matdoc (mblnr, mjahr, zeile, bwart, matnr, werks, lgort, shkzg, menge, meins,
                                    dmbtr, budat, usnam, lifnr, ebeln, sgtxt)
            VALUES (v_mblnr, v_year, '0001', '101', c_matnr, 'BR10', '0002', 'S', 12000, 'KG',
                    round(12000 * v_price, 2), current_date, 'SIMULATOR', v_lifnr,
                    '45000' || lpad(floor(random() * 99999)::text, 5, '0'),
                    'Reposicao xantato (simulador)');
        ELSE
            INSERT INTO sap.matdoc (mblnr, mjahr, zeile, bwart, matnr, werks, lgort, shkzg, menge, meins,
                                    dmbtr, budat, usnam, kostl, sgtxt)
            VALUES (v_mblnr, v_year, '0001', '201', c_matnr, 'BR10', '0002', 'H', v_qty, 'KG',
                    round(v_qty * v_price, 2), current_date, 'SIMULATOR', 'CC-FLO-01',
                    'Consumo turno flotacao (simulador)');
        END IF;

        PERFORM sap.post_material_document_to_fi(v_mblnr, v_year);

        RETURN QUERY
            SELECT d.mblnr, d.bwart, d.matnr, d.werks, d.lgort, d.menge, d.meins, d.dmbtr
              FROM sap.matdoc d
             WHERE d.mblnr = v_mblnr AND d.mjahr = v_year;
    END LOOP;
END $$;
