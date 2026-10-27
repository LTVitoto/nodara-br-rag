"""Knowledge base access: English technical manuals (AU) chunked in pgvector."""
from __future__ import annotations

from psycopg.rows import dict_row
from psycopg_pool import ConnectionPool

from .settings import get_settings

_pool: ConnectionPool | None = None

SEARCH_SQL = """
    SELECT c.chunk_id, c.doc_id, d.title, d.equipment, d.source_uri, c.section, c.content, c.sap_materials,
           1 - (c.embedding <=> %(q)s::vector) AS similarity
      FROM kb.chunks c
      JOIN kb.documents d ON d.doc_id = c.doc_id
     WHERE c.embedding IS NOT NULL
     ORDER BY c.embedding <=> %(q)s::vector
     LIMIT %(k)s
"""


def open_pool() -> None:
    global _pool
    s = get_settings()
    _pool = ConnectionPool(
        kwargs={"host": s.vector_db_host, "port": s.vector_db_port, "dbname": s.vector_db_name,
                "user": s.vector_db_user, "password": s.vector_db_password,
                "application_name": "nodara-backend", "row_factory": dict_row},
        min_size=1, max_size=5, open=False, name="knowledge-base")
    _pool.open(wait=False)


def close_pool() -> None:
    if _pool is not None:
        _pool.close()


def _vector(values: list[float]) -> str:
    return "[" + ",".join(f"{v:.7g}" for v in values) + "]"


def search(embedding: list[float], k: int) -> list[dict]:
    with _pool.connection() as conn:
        return conn.execute(SEARCH_SQL, {"q": _vector(embedding), "k": k}).fetchall()


def pending_chunks() -> list[dict]:
    with _pool.connection() as conn:
        return conn.execute(
            "SELECT chunk_id, section, content FROM kb.chunks WHERE embedding IS NULL ORDER BY chunk_id"
        ).fetchall()


def save_embeddings(rows: list[tuple[int, list[float]]], model: str) -> None:
    with _pool.connection() as conn, conn.cursor() as cur:
        cur.executemany(
            "UPDATE kb.chunks SET embedding = %s::vector, embedding_model = %s, embedded_at = now() "
            "WHERE chunk_id = %s",
            [(_vector(vector), model, chunk_id) for chunk_id, vector in rows])


def part_descriptions(matnrs: list[str]) -> dict[str, dict]:
    with _pool.connection() as conn:
        rows = conn.execute(
            "SELECT matnr, oem_part_no, description_en, description_pt, base_uom "
            "FROM kb.part_xref WHERE matnr = ANY(%s)", (matnrs,)).fetchall()
    return {row["matnr"]: row for row in rows}


def stats() -> dict:
    with _pool.connection() as conn:
        return conn.execute(
            "SELECT count(DISTINCT doc_id) AS documents, count(*) AS chunks, count(embedding) AS embedded "
            "FROM kb.chunks").fetchone()
