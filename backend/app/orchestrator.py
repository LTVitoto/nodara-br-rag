"""RAG orchestration: PT-BR operator question → EN retrieval over AU manuals →
live SAP S/4HANA cross-check (Trino) → PT-BR answer from the local LLM."""
from __future__ import annotations

import time

from langchain_core.output_parsers import StrOutputParser
from langchain_core.prompts import ChatPromptTemplate

from . import knowledge, lakehouse, llm
from .settings import get_settings

# Organizational master data (T001W / T001L are outside the simulated table scope).
PLANTS = {"BR10": "Carajás (PA)", "BR20": "Itabira (MG)"}
STORAGE_LOCATIONS = {"0001": "Almoxarifado central", "0002": "Oficina de manutenção"}
RELEVANCE_WINDOW = 0.10  # SAP lookups only for chunks close to the best match


class KnowledgeBaseEmpty(RuntimeError):
    """Raised when the manuals have not been embedded yet."""


QUERY_TRANSLATION = ChatPromptTemplate.from_messages([
    ("system",
     "You translate questions from mining maintenance operators (Brazilian Portuguese) into concise "
     "technical English for semantic search over equipment manuals. Keep part numbers, equipment codes "
     "and units unchanged. Reply with the English translation only."),
    ("human", "{question}"),
])

ANSWER = ChatPromptTemplate.from_messages([
    ("system",
     "Você é o assistente de inteligência operacional da Nodara para a manutenção de mina no Brasil.\n"
     "Regras obrigatórias:\n"
     "1. Responda sempre em português do Brasil, de forma objetiva; procedimentos em passos numerados.\n"
     "2. Use SOMENTE os trechos de manuais técnicos (em inglês, origem Austrália) e os dados SAP fornecidos.\n"
     "3. Traduza fielmente procedimentos, torques, pressões, intervalos e alertas de segurança; preserve "
     "unidades, números de peça e códigos de equipamento.\n"
     "4. Cruze o procedimento com o SAP S/4HANA: informe o estoque por planta/depósito e sinalize falta "
     "ou estoque crítico.\n"
     "5. Cite as fontes no formato [DOC-ID §seção].\n"
     "6. Se algo não estiver no contexto, diga que não está disponível. Nunca invente."),
    ("human",
     "Pergunta do operador:\n{question}\n\n"
     "=== TRECHOS DOS MANUAIS (EN) ===\n{manuals}\n\n"
     "=== DADOS SAP S/4HANA (tempo real, via Trino) ===\n{sap}"),
])


def _elapsed_ms(start: float) -> int:
    return int((time.perf_counter() - start) * 1000)


def _format_manuals(chunks: list[dict]) -> str:
    return "\n\n".join(f"[{c['doc_id']} §{c['section']}] (equipamento: {c['equipment']})\n{c['content']}"
                       for c in chunks)


def _stock_flag(qty: float) -> str:
    # Deterministic business rule: the LLM reports it, it does not infer it.
    return " → SEM ESTOQUE" if qty <= 0 else " → ESTOQUE CRÍTICO" if qty <= 1 else ""


def _format_sap(sap: dict) -> str:
    if not sap["materials"]:
        return "Nenhum material SAP relacionado aos trechos recuperados."
    lines = ["Materiais (SAP MATNR ↔ número de peça OEM) e estoque total:"]
    for m in sap["materials"].values():
        total = sum(s["stock_qty"] for s in sap["stock"] if s["matnr"] == m["matnr"])
        lines.append(f"- {m['matnr']} | {m['oem_part_no']} | {m['description_pt']} | "
                     f"total {total:g} {m['base_uom']}{_stock_flag(total)}")
    lines.append("Estoque por planta / depósito (MATDOC):")
    lines += [f"- {s['matnr']} @ {s['werks']} {PLANTS.get(s['werks'], '')} / {s['lgort']} "
              f"{STORAGE_LOCATIONS.get(s['lgort'], '')}: {s['stock_qty']:g} {s['meins']}{_stock_flag(s['stock_qty'])} "
              f"(último movimento {s['last_movement']})" for s in sap["stock"]] or ["- sem posições de estoque"]
    lines.append("Consumo recente em ordens de manutenção (261):")
    lines += [f"- {c['budat']} doc {c['mblnr']}: {c['menge']:g} {c['meins']} de {c['matnr']} em "
              f"{c['werks']}/{c['lgort']} → ordem {c['aufnr']} ({c['sgtxt']})"
              for c in sap["recent_consumption"]] or ["- sem consumo recente"]
    lines.append("Fornecedores (últimos recebimentos, BUT000):")
    lines += [f"- {s['matnr']}: {s['supplier']} (BP {s['partner']}), último recebimento {s['last_receipt']}"
              for s in sap["suppliers"]] or ["- sem fornecedores registrados"]
    return "\n".join(lines)


def answer_question(question: str, top_k: int | None = None) -> dict:
    s = get_settings()
    llm.require_models(s.ollama_chat_model, s.ollama_embed_model)
    chat = llm.chat()
    timings: dict[str, int] = {}

    start = time.perf_counter()
    question_en = (QUERY_TRANSLATION | chat | StrOutputParser()).invoke({"question": question}).strip()
    timings["translate_ms"] = _elapsed_ms(start)

    start = time.perf_counter()
    query_vector = llm.embedder().embed_query(f"search_query: {question_en}")
    chunks = knowledge.search(query_vector, top_k or s.rag_top_k)
    if not chunks:
        raise KnowledgeBaseEmpty("Base de conhecimento sem embeddings. Execute: make embed")
    timings["retrieve_ms"] = _elapsed_ms(start)

    start = time.perf_counter()
    best = chunks[0]["similarity"]
    matnrs = sorted({m for c in chunks if c["similarity"] >= best - RELEVANCE_WINDOW for m in c["sap_materials"]})
    sap = {"materials": knowledge.part_descriptions(matnrs) if matnrs else {},
           "stock": lakehouse.live_stock(matnrs) if matnrs else [],
           "recent_consumption": lakehouse.recent_consumption(matnrs) if matnrs else [],
           "suppliers": lakehouse.suppliers(matnrs) if matnrs else []}
    timings["sap_ms"] = _elapsed_ms(start)

    start = time.perf_counter()
    answer = (ANSWER | chat | StrOutputParser()).invoke(
        {"question": question, "manuals": _format_manuals(chunks), "sap": _format_sap(sap)})
    timings["generate_ms"] = _elapsed_ms(start)

    return {
        "answer": answer.strip(),
        "question_en": question_en,
        "sources": [{"doc_id": c["doc_id"], "title": c["title"], "equipment": c["equipment"],
                     "section": c["section"], "similarity": round(float(c["similarity"]), 4),
                     "excerpt": c["content"][:280], "sap_materials": c["sap_materials"]} for c in chunks],
        "sap": sap,
        "models": {"chat": s.ollama_chat_model, "embeddings": s.ollama_embed_model},
        "timings_ms": timings,
    }
