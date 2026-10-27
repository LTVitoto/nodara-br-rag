-- ═══════════════════════════════════════════════════════════════════════════
-- Nodara BR-RAG · Knowledge base (isolated pgvector instance — manuals only)
-- English technical manuals from Australian operations, chunked for retrieval.
-- Embeddings are produced in-enclave by the backend (Ollama nomic-embed-text,
-- 768-d): no external embedding APIs (air-gap). No CDC, no Trino catalog.
-- ═══════════════════════════════════════════════════════════════════════════
CREATE EXTENSION IF NOT EXISTS vector;
CREATE SCHEMA kb;

CREATE TABLE kb.documents (
    doc_id         text PRIMARY KEY,
    title          text NOT NULL,
    equipment      text NOT NULL,
    doc_type       text NOT NULL CHECK (doc_type IN ('maintenance_procedure', 'inspection_standard', 'safety_standard')),
    issuing_site   text NOT NULL,
    revision       text NOT NULL,
    language       char(2) NOT NULL DEFAULT 'en',
    classification text NOT NULL,
    source_uri     text NOT NULL UNIQUE CHECK (source_uri LIKE 's3://raw-manuals/%'),  -- lineage → raw layer (MinIO)
    loaded_at      timestamptz NOT NULL DEFAULT now()
);

-- OEM part numbers quoted in the manuals ↔ SAP material numbers (bridge to S/4HANA).
CREATE TABLE kb.part_xref (
    oem_part_no    text PRIMARY KEY,
    matnr          varchar(40) NOT NULL UNIQUE,
    description_en text NOT NULL,
    description_pt text NOT NULL,
    base_uom       varchar(3) NOT NULL
);

CREATE TABLE kb.chunks (
    chunk_id        bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    doc_id          text NOT NULL REFERENCES kb.documents (doc_id),
    chunk_no        int NOT NULL,
    section         text NOT NULL,
    content         text NOT NULL,
    sap_materials   varchar(40)[] NOT NULL DEFAULT '{}',
    embedding       vector(768),
    embedding_model text,
    embedded_at     timestamptz,
    UNIQUE (doc_id, chunk_no)
);

CREATE INDEX chunks_embedding_hnsw ON kb.chunks USING hnsw (embedding vector_cosine_ops);
CREATE INDEX chunks_content_fts ON kb.chunks USING gin (to_tsvector('english', content));
