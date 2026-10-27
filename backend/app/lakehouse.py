"""Federated SQL through Trino: live SAP S/4HANA tables (catalog `s4hana`) and the CDC bronze
layer on Delta Lake (catalog `lakehouse`). Each resolver turns the SAP references curated on the
knowledge base (materials, cost centers, scopes) into live business context."""
from __future__ import annotations

from decimal import Decimal

import trino

from .settings import get_settings

CONSUMPTION_WINDOW_DAYS = 14


def query(sql: str, params: list | None = None) -> list[dict]:
    s = get_settings()
    with trino.dbapi.connect(host=s.trino_host, port=s.trino_port, user=s.trino_user,
                             source="nodara-backend") as conn:
        cur = conn.cursor()
        cur.execute(sql, params)
        rows = cur.fetchall()
        columns = [c[0] for c in cur.description]
    return [{col: float(v) if isinstance(v, Decimal) else v for col, v in zip(columns, row)} for row in rows]


def _placeholders(values: list) -> str:
    return ", ".join("?" for _ in values)


def material_stock(matnrs: list[str]) -> list[dict]:
    """Stock per plant / storage location (MATDOC), average daily issue and days of coverage."""
    ph = _placeholders(matnrs)
    return query(f"""
        WITH stock AS (
            SELECT matnr, werks, lgort, meins,
                   sum(CASE WHEN shkzg = 'S' THEN menge ELSE -menge END) AS stock_qty,
                   max(budat) AS last_movement
              FROM s4hana.sap.matdoc
             WHERE matnr IN ({ph})
             GROUP BY matnr, werks, lgort, meins),
        usage AS (
            SELECT matnr, werks, lgort, sum(menge) / count(DISTINCT budat) AS avg_daily_issue
              FROM s4hana.sap.matdoc
             WHERE matnr IN ({ph}) AND bwart IN ('201', '261')
               AND budat >= current_date - INTERVAL '{CONSUMPTION_WINDOW_DAYS}' DAY
             GROUP BY matnr, werks, lgort)
        SELECT s.matnr, s.werks, s.lgort, s.meins, s.stock_qty, s.last_movement, u.avg_daily_issue,
               CASE WHEN u.avg_daily_issue > 0 THEN s.stock_qty / u.avg_daily_issue END AS coverage_days
          FROM stock s
          LEFT JOIN usage u ON u.matnr = s.matnr AND u.werks = s.werks AND u.lgort = s.lgort
         ORDER BY s.matnr, s.werks, s.lgort""", matnrs + matnrs)


def material_movements(matnrs: list[str], limit: int = 6) -> list[dict]:
    """Latest goods movements with the SAP transaction that posted them (MATDOC-TCODE2)."""
    return query(f"""
        SELECT budat, mblnr, bwart, tcode2, matnr, werks, lgort, shkzg, menge, meins, kostl, aufnr, sgtxt
          FROM s4hana.sap.matdoc
         WHERE matnr IN ({_placeholders(matnrs)})
         ORDER BY budat DESC, mblnr DESC
         LIMIT {int(limit)}""", matnrs)


def open_reservations(matnrs: list[str]) -> list[dict]:
    """Open reservations of maintenance orders for the materials (RESB + AUFK)."""
    return query(f"""
        SELECT r.rsnum, r.rspos, r.matnr, r.werks, r.lgort, r.bdmng, r.enmng,
               r.bdmng - r.enmng AS open_qty, r.meins, r.bdter, r.aufnr, a.ktext, a.kostl
          FROM s4hana.sap.resb r
          LEFT JOIN s4hana.sap.aufk a ON a.aufnr = r.aufnr
         WHERE r.matnr IN ({_placeholders(matnrs)}) AND r.xloek = '' AND r.kzear = '' AND r.bdmng > r.enmng
         ORDER BY r.bdter""", matnrs)


def suppliers(matnrs: list[str]) -> list[dict]:
    """Suppliers of the last goods receipts, joined with Business Partner master data."""
    return query(f"""
        SELECT m.matnr, b.partner, b.name_org1 AS supplier, max(m.budat) AS last_receipt
          FROM s4hana.sap.matdoc m
          JOIN s4hana.sap.but000 b ON b.partner = m.lifnr
         WHERE m.bwart = '101' AND m.matnr IN ({_placeholders(matnrs)})
         GROUP BY m.matnr, b.partner, b.name_org1
         ORDER BY m.matnr, last_receipt DESC""", matnrs)


def maintenance_orders(cost_centers: list[str]) -> list[dict]:
    """Open maintenance orders (AUFK) of the cost centers with their notification (QMEL)."""
    return query(f"""
        SELECT a.aufnr, a.auart, a.ktext, a.werks, a.kostl, a.equnr, a.erdat, a.ernam,
               CASE WHEN a.phas1 = 'X' THEN 'REL' ELSE 'CRTD' END AS status,
               q.qmnum, q.qmart, q.qmtxt, q.priok, q.msaus, q.ausvn
          FROM s4hana.sap.aufk a
          LEFT JOIN s4hana.sap.qmel q ON q.aufnr = a.aufnr
         WHERE a.kostl IN ({_placeholders(cost_centers)}) AND a.phas2 = '' AND a.phas3 = ''
         ORDER BY a.erdat DESC""", cost_centers)


def counterparty_credit(limit: int = 5) -> list[dict]:
    """Counterparties under credit management: limit and block (UKMBP_CMS_SGM), open-item exposure
    and overdue amounts (ACDOCA, koart D), Brazilian tax IDs (DFKKBPTAXNUM)."""
    return query(f"""
        WITH exposure AS (
            SELECT kunnr, rwcur,
                   sum(wsl) AS open_amount,
                   sum(CASE WHEN netdt < current_date THEN wsl ELSE 0 END) AS overdue_amount,
                   max(CASE WHEN netdt < current_date THEN date_diff('day', netdt, current_date) END) AS max_days_overdue
              FROM s4hana.sap.acdoca
             WHERE koart = 'D' AND augbl IS NULL
             GROUP BY kunnr, rwcur),
        tax AS (
            SELECT partner,
                   max(CASE WHEN taxtype = 'BR1' THEN taxnum END) AS cnpj,
                   max(CASE WHEN taxtype = 'BR3' THEN taxnum END) AS inscricao_estadual
              FROM s4hana.sap.dfkkbptaxnum
             GROUP BY partner)
        SELECT b.partner, b.name_org1 AS name, c.credit_sgmnt, c.credit_limit, c.currency, c.xblocked,
               c.block_reason, c.limit_valid_date, coalesce(e.open_amount, 0) AS exposure,
               coalesce(e.overdue_amount, 0) AS overdue, e.max_days_overdue, t.cnpj, t.inscricao_estadual
          FROM s4hana.sap.ukmbp_cms_sgm c
          JOIN s4hana.sap.but000 b ON b.partner = c.partner
          LEFT JOIN exposure e ON e.kunnr = c.partner AND e.rwcur = c.currency
          LEFT JOIN tax t ON t.partner = c.partner
         ORDER BY c.xblocked DESC, exposure DESC
         LIMIT {int(limit)}""")


def s4_live_summary() -> dict:
    return query("""
        SELECT (SELECT count(*) FROM s4hana.sap.matdoc) AS matdoc_rows,
               (SELECT count(*) FROM s4hana.sap.acdoca) AS acdoca_rows,
               (SELECT count(*) FROM s4hana.sap.but000) AS but000_rows,
               (SELECT count(*) FROM s4hana.sap.aufk WHERE phas2 = '' AND phas3 = '') AS open_orders,
               (SELECT count(*) FROM s4hana.sap.ukmbp_cms_sgm WHERE xblocked = 'X') AS credit_blocked""")[0]


def cdc_freshness() -> dict:
    """How current the lakehouse is: CDC events landed in bronze and their latency."""
    return query("""
        SELECT count(*) AS events,
               max(_source_ts) AS last_source_commit,
               max(_ingested_at) AS last_ingested,
               max_by(date_diff('millisecond', _source_ts, _ingested_at), _ingested_at) AS last_lag_ms
          FROM lakehouse.bronze.matdoc""")[0]
