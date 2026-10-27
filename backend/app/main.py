"""Nodara BR-RAG · AI orchestrator API (FastAPI)."""
from __future__ import annotations

import logging
from contextlib import asynccontextmanager
from typing import Annotated

from fastapi import FastAPI, Query, Request
from fastapi.responses import JSONResponse

from . import knowledge, lakehouse, llm
from .orchestrator import KnowledgeBaseEmpty, answer_question
from .schemas import AskRequest, AskResponse, EmbedResponse
from .settings import get_settings

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s [backend] %(message)s")
log = logging.getLogger("backend")


@asynccontextmanager
async def lifespan(_: FastAPI):
    knowledge.open_pool()
    yield
    knowledge.close_pool()


app = FastAPI(title="Nodara BR-RAG Orchestrator", version="0.1.0", lifespan=lifespan)


@app.exception_handler(llm.ModelUnavailable)
async def model_unavailable(_: Request, exc: llm.ModelUnavailable) -> JSONResponse:
    return JSONResponse(status_code=503, content={"detail": str(exc)})


@app.exception_handler(KnowledgeBaseEmpty)
async def knowledge_base_empty(_: Request, exc: KnowledgeBaseEmpty) -> JSONResponse:
    return JSONResponse(status_code=409, content={"detail": str(exc)})


@app.get("/health")
def health() -> dict:
    return {"status": "ok"}


def _probe(check) -> dict:
    try:
        return {"ok": True, **check()}
    except Exception as exc:  # status page must degrade gracefully, never fail
        return {"ok": False, "error": str(exc)[:300]}


@app.get("/api/v1/status")
def status() -> dict:
    """Dependency map for the operator console: KB, live S/4, lakehouse CDC, local LLM."""
    return {"knowledge_base": _probe(knowledge.stats),
            "s4hana_live": _probe(lakehouse.s4_live_summary),
            "lakehouse_cdc": _probe(lakehouse.cdc_freshness),
            "llm": _probe(llm.model_status)}


@app.post("/api/v1/kb/embed", response_model=EmbedResponse)
def embed_knowledge_base() -> EmbedResponse:
    """Embeds pending manual chunks in-enclave (Ollama) and stores them in pgvector."""
    s = get_settings()
    llm.require_models(s.ollama_embed_model)
    pending = knowledge.pending_chunks()
    if pending:
        vectors = llm.embedder().embed_documents(
            [f"search_document: {c['section']}\n{c['content']}" for c in pending])
        knowledge.save_embeddings([(c["chunk_id"], v) for c, v in zip(pending, vectors)], s.ollama_embed_model)
        log.info("embedded %d chunks with %s", len(pending), s.ollama_embed_model)
    totals = knowledge.stats()
    return EmbedResponse(embedded_now=len(pending), model=s.ollama_embed_model,
                         total_embedded=totals["embedded"], total_chunks=totals["chunks"])


@app.post("/api/v1/ask", response_model=AskResponse)
def ask(request: AskRequest) -> dict:
    return answer_question(request.question, request.top_k)


@app.get("/api/v1/sap/stock")
def stock(matnr: Annotated[list[str], Query()]) -> dict:
    """Live stock for the given SAP materials (federated query, no copies)."""
    return {"stock": lakehouse.live_stock(matnr[:20])}
