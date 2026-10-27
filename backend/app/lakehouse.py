"""Federated SQL through Trino: live SAP S/4HANA tables (catalog `s4hana`) and the
CDC bronze layer on Delta Lake (catalog `lakehouse`)."""
from __future__ import annotations

from decimal import Decimal

import trino

from .settings import get_settings


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


def live_stock(matnrs: list[str]) -> list[dict]:
    """Current stock per plant / storage location, straight from MATDOC (real time)."""
    return query(f"""
        SELECT matnr, werks, lgort, meins,
               sum(CASE WHEN shkzg = 'S' THEN menge ELSE -menge END) AS stock_qty,
               max(budat) AS last_movement
          FROM s4hana.sap.matdoc
         WHERE matnr IN ({_placeholders(matnrs)})
         GROUP BY matnr, werks, lgort, meins
         ORDER BY matnr, werks, lgort""", matnrs)


def recent_consumption(matnrs: list[str], limit: int = 6) -> list[dict]:
    """Latest goods issues to maintenance orders (movement type 261)."""
    return query(f"""
        SELECT budat, mblnr, matnr, werks, lgort, menge, meins, aufnr, sgtxt
          FROM s4hana.sap.matdoc
         WHERE bwart = '261' AND matnr IN ({_placeholders(matnrs)})
         ORDER BY budat DESC, mblnr DESC
         LIMIT {int(limit)}""", matnrs)


def suppliers(matnrs: list[str]) -> list[dict]:
    """Suppliers of the last goods receipts, joined with Business Partner master data."""
    return query(f"""
        SELECT m.matnr, b.partner, b.name_org1 AS supplier, max(m.budat) AS last_receipt
          FROM s4hana.sap.matdoc m
          JOIN s4hana.sap.but000 b ON b.partner = m.lifnr
         WHERE m.bwart = '101' AND m.matnr IN ({_placeholders(matnrs)})
         GROUP BY m.matnr, b.partner, b.name_org1
         ORDER BY m.matnr, last_receipt DESC""", matnrs)


def s4_live_summary() -> dict:
    return query("""
        SELECT (SELECT count(*) FROM s4hana.sap.matdoc) AS matdoc_rows,
               (SELECT count(*) FROM s4hana.sap.acdoca) AS acdoca_rows,
               (SELECT count(*) FROM s4hana.sap.but000) AS but000_rows""")[0]


def cdc_freshness() -> dict:
    """How current the lakehouse is: CDC events landed in bronze and their latency."""
    return query("""
        SELECT count(*) AS events,
               max(_source_ts) AS last_source_commit,
               max(_ingested_at) AS last_ingested,
               max_by(date_diff('millisecond', _source_ts, _ingested_at), _ingested_at) AS last_lag_ms
          FROM lakehouse.bronze.matdoc""")[0]
