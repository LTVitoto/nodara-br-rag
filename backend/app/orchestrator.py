"""RAG orchestration with dynamic language routing (ES / EN / PT):
question → English for retrieval over the AU manuals (pgvector) → live SAP S/4HANA context via
Trino (materials, maintenance orders, counterparty credit) → answer written EXACTLY in the
requested language: system prompt per language plus a language guard that re-translates on drift."""
from __future__ import annotations

import re
import time

from langchain_core.output_parsers import StrOutputParser
from langchain_core.prompts import ChatPromptTemplate
from langdetect import DetectorFactory, LangDetectException, detect_langs

from . import knowledge, lakehouse, llm
from .messages import LANGUAGE_NAMES, message
from .settings import get_settings

DetectorFactory.seed = 0  # deterministic language detection

# Organizational master data and customizing (T001W / T001L / credit block reasons are outside the
# simulated table scope).
PLANTS = {"BR10": "flotation plant, Carajás (PA)", "BR20": "leaching plant, Carajás (PA)"}
STORAGE_LOCATIONS = {("BR10", "0002"): "Depot 002, flotation reagents",
                     ("BR20", "0001"): "central warehouse, leaching spares"}
CREDIT_BLOCK_REASONS = {"01": "credit limit exceeded", "02": "overdue items", "03": "KYC pending"}
RELEVANCE_WINDOW = 0.10  # SAP lookups only for chunks close to the best match


class KnowledgeBaseEmpty(RuntimeError):
    """Raised when the manuals have not been embedded yet."""


QUERY_TRANSLATION = ChatPromptTemplate.from_messages([
    ("system",
     "You translate questions from users of a multinational mining company (Spanish, Portuguese or English) "
     "into concise technical English for semantic search over corporate manuals (compliance, leaching, "
     "flotation, maintenance). Keep SAP codes, transaction codes, material numbers, cost centers, part numbers "
     "and units unchanged. If the question is already in English, return it unchanged. "
     "Reply with the English text only."),
    ("human", "{question}"),
])

SYSTEM_PROMPTS = {
    "es": ("Eres el asistente de inteligencia operacional de Nodara, minera multinacional con operaciones en Brasil. "
           "Escribe para el operador, de forma objetiva y ejecutiva.\n"
           "Reglas obligatorias:\n"
           "1. Responde EXCLUSIVAMENTE en español: traduce también el contenido de los manuales (en inglés) y los "
           "textos de SAP (en portugués); deja sin traducir solo códigos, unidades y nombres propios.\n"
           "2. Usa SOLO los extractos de los manuales corporativos (Australia) y los datos de SAP S/4HANA "
           "proporcionados.\n"
           "3. Traduce fielmente procedimientos, valores, límites, plazos y alertas; conserva cifras y códigos SAP "
           "(materiales, centros de costo, órdenes, documentos).\n"
           "4. Cruza el manual con SAP: describe la situación actual y los próximos pasos. Cuando el manual traiga "
           "fórmulas o umbrales (días mínimos de cobertura, cambios de dosis, límites de crédito), aplícalos a las "
           "cifras de SAP y muestra el resultado calculado.\n"
           "5. Menciona SOLO códigos de transacción SAP que aparezcan literalmente en los extractos de los manuales "
           "o en los datos SAP; incluye en los próximos pasos las transacciones prescritas que apliquen; nunca "
           "inventes transacciones ni presentes nombres de tablas o campos como transacciones.\n"
           "6. Cita las fuentes con el formato [DOC-ID §sección].\n"
           "7. Incluye siempre los requisitos específicos de Brasil (anexos BR) y no afirmes validaciones que no "
           "estén en los datos.\n"
           "8. Si algo no está en el contexto, di que no está disponible. Nunca inventes.\n"
           "Formato: 1) Situación actual en SAP (con cifras). 2) Qué exige el manual. 3) Próximos pasos numerados, "
           "con la transacción SAP cuando aplique. 4) Fuentes."),
    "en": ("You are the operational intelligence assistant of Nodara, a multinational mining company operating "
           "in Brazil. Write for the operator, in a concise executive style.\n"
           "Mandatory rules:\n"
           "1. Answer EXCLUSIVELY in English: also translate the SAP texts (in Portuguese); keep only codes, units "
           "and proper names untranslated.\n"
           "2. Use ONLY the corporate manual excerpts (Australia) and the SAP S/4HANA data provided.\n"
           "3. Reproduce procedures, values, limits, deadlines and warnings faithfully; keep figures and SAP codes "
           "(materials, cost centers, orders, documents) unchanged.\n"
           "4. Cross-check the manual with SAP: describe the current situation and the next steps. When the manual "
           "gives formulas or thresholds (minimum coverage days, dosage changes, credit limits), apply them to the "
           "SAP figures and show the calculated result.\n"
           "5. Mention ONLY SAP transaction codes that appear literally in the manual excerpts or in the SAP data; "
           "include the prescribed transactions that apply in the next steps; never invent transactions and never "
           "present table or field names as transactions.\n"
           "6. Cite sources as [DOC-ID §section].\n"
           "7. Always include Brazil-specific requirements (BR annexes) and never claim validations that are not in "
           "the data.\n"
           "8. If something is not in the context, say it is not available. Never invent.\n"
           "Format: 1) Current situation in SAP (with figures). 2) What the manual requires. 3) Numbered next "
           "steps, with the SAP transaction where applicable. 4) Sources."),
    "pt": ("Você é o assistente de inteligência operacional da Nodara, mineradora multinacional com operações no "
           "Brasil. Escreva para o operador, de forma objetiva e executiva.\n"
           "Regras obrigatórias:\n"
           "1. Responda EXCLUSIVAMENTE em português do Brasil: traduza também o conteúdo dos manuais (em inglês); "
           "mantenha sem tradução apenas códigos, unidades e nomes próprios.\n"
           "2. Use SOMENTE os trechos dos manuais corporativos (Austrália) e os dados do SAP S/4HANA fornecidos.\n"
           "3. Traduza fielmente procedimentos, valores, limites, prazos e alertas; preserve números e códigos SAP "
           "(materiais, centros de custo, ordens, documentos).\n"
           "4. Cruze o manual com o SAP: descreva a situação atual e os próximos passos. Quando o manual trouxer "
           "fórmulas ou limites (dias mínimos de cobertura, mudanças de dosagem, limites de crédito), aplique-os aos "
           "números do SAP e mostre o resultado calculado.\n"
           "5. Cite SOMENTE códigos de transação SAP que aparecem literalmente nos trechos dos manuais ou nos dados "
           "SAP; inclua nos próximos passos as transações prescritas que se aplicam; nunca invente transações nem "
           "apresente nomes de tabelas ou campos como transações.\n"
           "6. Cite as fontes no formato [DOC-ID §seção].\n"
           "7. Inclua sempre os requisitos específicos do Brasil (anexos BR) e não afirme validações que não estejam "
           "nos dados.\n"
           "8. Se algo não estiver no contexto, diga que não está disponível. Nunca invente.\n"
           "Formato: 1) Situação atual no SAP (com números). 2) O que o manual exige. 3) Próximos passos "
           "numerados, com a transação SAP quando aplicável. 4) Fontes."),
}

HUMAN_PROMPTS = {
    "es": ("Pregunta del usuario:\n{question}\n\n=== EXTRACTOS DE MANUALES (EN) ===\n{manuals}\n\n"
           "=== DATOS SAP S/4HANA (tiempo real, vía Trino) ===\n{sap}\n\n"
           "=== TRANSACCIONES SAP PRESCRITAS POR LOS MANUALES ===\n{transactions}\n\nResponde ahora en español."),
    "en": ("User question:\n{question}\n\n=== MANUAL EXCERPTS (EN) ===\n{manuals}\n\n"
           "=== SAP S/4HANA DATA (real time, via Trino) ===\n{sap}\n\n"
           "=== SAP TRANSACTIONS PRESCRIBED BY THE MANUALS ===\n{transactions}\n\nAnswer now in English."),
    "pt": ("Pergunta do usuário:\n{question}\n\n=== TRECHOS DOS MANUAIS (EN) ===\n{manuals}\n\n"
           "=== DADOS SAP S/4HANA (tempo real, via Trino) ===\n{sap}\n\n"
           "=== TRANSAÇÕES SAP PRESCRITAS PELOS MANUAIS ===\n{transactions}\n\nResponda agora em português do Brasil."),
}

ANSWER_PROMPTS = {language: ChatPromptTemplate.from_messages([("system", SYSTEM_PROMPTS[language]),
                                                             ("human", HUMAN_PROMPTS[language])])
                  for language in LANGUAGE_NAMES}

ANSWER_TRANSLATION = ChatPromptTemplate.from_messages([
    ("system",
     "You are a professional translator for a mining company. Translate the user's text into {language}. "
     "Keep the structure, numbering, figures, units, SAP codes, transaction codes and citations "
     "[DOC-ID §section] unchanged. Output only the translation."),
    ("human", "{text}"),
])


# "transacción SAP: XD01", "**Transação SAP:**\n* MIGO", "transaction IW31"… → the cited code.
TRANSACTION_MENTION = re.compile(
    r"(?i:\b(?:transacci[oó]n(?:es)?|transactions?|transaç(?:ão|ões)|transacao|tcode)\b(?:\s+SAP)?)"
    r"[\s:*•_-]*(?!SAP\b)([A-Z][A-Z0-9_-]{2,15})\b")
# Anything shaped like an SAP transaction code (XD01, IW31, ME23N, FICO-CF01…), wherever it appears.
TRANSACTION_LIKE = re.compile(r"\b(?:[A-Z]{2,5}-)?[A-Z]{1,4}\d{2,3}[A-Z]?\b")
UNGROUNDED_TRANSACTION = {"es": "«no especificada en el manual»", "en": "«not specified in the manual»",
                          "pt": "«não especificada no manual»"}


def ground_transactions(answer: str, context: str, declared: list[str], language: str) -> tuple[str, list[str], list[str]]:
    """Keeps only SAP transaction codes that appear literally in the context (manuals, SAP data or the
    question); invented ones are replaced by a localized placeholder and reported."""
    removed: set[str] = set()
    placeholder = UNGROUNDED_TRANSACTION[language]

    def grounded(code: str) -> bool:
        return re.search(rf"(?<![\w-]){re.escape(code)}(?![\w-])", context) is not None

    def anchored(match: re.Match) -> str:
        code = match.group(1)
        if grounded(code):
            return match.group(0)
        removed.add(code)
        return match.group(0)[: match.start(1) - match.start(0)] + placeholder

    def loose(match: re.Match) -> str:
        if grounded(match.group(0)):
            return match.group(0)
        removed.add(match.group(0))
        return placeholder

    answer = TRANSACTION_LIKE.sub(loose, TRANSACTION_MENTION.sub(anchored, answer))
    cited = sorted(code for code in declared if re.search(rf"(?<![\w-]){re.escape(code)}(?![\w-])", answer))
    return answer, cited, sorted(removed)


def prescribed_transactions(chunks: list[dict]) -> dict[str, str]:
    """SAP transactions the matched manuals prescribe, each with the sentence that prescribes it."""
    found: dict[str, str] = {}
    for chunk in chunks:
        for sentence in re.split(r"(?<=[.;])\s+", chunk["content"]):
            for code in TRANSACTION_MENTION.findall(sentence):
                found.setdefault(code, f"[{chunk['doc_id']} §{chunk['section']}] {sentence.strip()}")
    return dict(sorted(found.items()))


def detect_language(text: str) -> str | None:
    """Most probable supported language of a text (statistical detector with a fixed seed)."""
    try:
        candidates = [c for c in detect_langs(text) if c.lang in LANGUAGE_NAMES]
    except LangDetectException:
        return None
    return max(candidates, key=lambda c: c.prob).lang if candidates else None


def _elapsed_ms(start: float) -> int:
    return int((time.perf_counter() - start) * 1000)


def _relevant_documents(hits: list[dict]) -> list[str]:
    """Manuals whose best section is close to the overall best match, most relevant first."""
    best = hits[0]["similarity"]
    return list(dict.fromkeys(h["doc_id"] for h in hits if h["similarity"] >= best - RELEVANCE_WINDOW))


def _collect_refs(chunks: list[dict]) -> dict[str, list[str]]:
    refs: dict[str, set[str]] = {"materials": set(), "cost_centers": set(), "scopes": set()}
    for chunk in chunks:
        for key, values in refs.items():
            values.update(chunk["sap_refs"].get(key, []))
    return {key: sorted(values) for key, values in refs.items()}


def _sap_context(refs: dict[str, list[str]]) -> dict:
    materials, cost_centers = refs["materials"], refs["cost_centers"]
    return {
        "materials": knowledge.part_descriptions(materials) if materials else {},
        "stock": lakehouse.material_stock(materials) if materials else [],
        "reservations": lakehouse.open_reservations(materials) if materials else [],
        "movements": lakehouse.material_movements(materials) if materials else [],
        "suppliers": lakehouse.suppliers(materials) if materials else [],
        "orders": lakehouse.maintenance_orders(cost_centers) if cost_centers else [],
        "counterparties": lakehouse.counterparty_credit() if "counterparty_credit" in refs["scopes"] else [],
    }


def _format_manuals(chunks: list[dict]) -> str:
    return "\n\n".join(f"[{c['doc_id']} §{c['section']}] (applies to: {c['applies_to']})\n{c['content']}"
                       for c in chunks)


def _stock_flag(quantity: float, uom: str) -> str:
    # Deterministic business rules: the LLM reports them, it does not infer them.
    if quantity <= 0:
        return " → OUT OF STOCK"
    return " → CRITICAL STOCK" if uom == "PC" and quantity <= 1 else ""


def _format_sap(sap: dict) -> str:
    lines: list[str] = []
    if sap["materials"]:
        lines.append("Materials (SAP material | OEM part number | description):")
        lines += [f"- {m['matnr']} | {m['oem_part_no']} | {m['description_en']}" for m in sap["materials"].values()]
    if sap["stock"]:
        lines.append("Stock by plant / storage location (live; consumption = average daily issue on "
                     f"posting days of the last {lakehouse.CONSUMPTION_WINDOW_DAYS} days):")
        for s in sap["stock"]:
            usage = (f"; consumption {s['avg_daily_issue']:.0f} {s['meins']}/day → coverage {s['coverage_days']:.1f} days"
                     if s["avg_daily_issue"] else "")
            lines.append(f"- {s['matnr']} @ plant {s['werks']} ({PLANTS.get(s['werks'], 'n/a')}) / storage location "
                         f"{s['lgort']} ({STORAGE_LOCATIONS.get((s['werks'], s['lgort']), 'n/a')}): "
                         f"{s['stock_qty']:g} {s['meins']}{_stock_flag(s['stock_qty'], s['meins'])}{usage}; "
                         f"last movement {s['last_movement']}")
    if sap["reservations"]:
        lines.append("Open reservations for maintenance orders:")
        lines += [f"- reservation {r['rsnum']}/{r['rspos']}: {r['open_qty']:g} {r['meins']} of {r['matnr']} still to be "
                  f"issued for order {r['aufnr']} \"{r['ktext']}\" (cost center {r['kostl']}), required on {r['bdter']}"
                  for r in sap["reservations"]]
    if sap["orders"]:
        lines.append("Open maintenance orders with their malfunction notifications:")
        for o in sap["orders"]:
            line = (f"- order {o['aufnr']} ({o['auart']}, {'released' if o['status'] == 'REL' else 'created'}, "
                    f"created on {o['erdat']} by {o['ernam']}): \"{o['ktext']}\" | plant {o['werks']} | "
                    f"cost center {o['kostl']} | equipment {o['equnr']}")
            if o["qmnum"]:
                line += (f"; notification {o['qmnum']} ({o['qmart']}, priority {o['priok']}"
                         f"{', breakdown' if o['msaus'] == 'X' else ''}, since {o['ausvn']}): \"{o['qmtxt']}\"")
            lines.append(line)
    if sap["movements"]:
        lines.append("Latest goods movements (with the SAP transaction that posted them):")
        for m in sap["movements"]:
            target = f" → order {m['aufnr']}" if m["aufnr"] else f" → cost center {m['kostl']}" if m["kostl"] else ""
            lines.append(f"- {m['budat']} {m['tcode2']} movement type {m['bwart']} document {m['mblnr']}: "
                         f"{m['menge']:g} {m['meins']} {m['matnr']} @ {m['werks']}/{m['lgort']}{target} ({m['sgtxt']})")
    if sap["suppliers"]:
        lines.append("Suppliers of the last goods receipts:")
        lines += [f"- {s['matnr']}: {s['supplier']} (BP {s['partner']}), last receipt {s['last_receipt']}"
                  for s in sap["suppliers"]]
    if sap["counterparties"]:
        lines.append("Counterparties in SAP credit management (exposure = open receivables):")
        for c in sap["counterparties"]:
            usage = c["exposure"] / c["credit_limit"] * 100 if c["credit_limit"] else 0
            status = (f"BLOCKED (reason {c['block_reason']}: {CREDIT_BLOCK_REASONS.get(c['block_reason'], 'n/a')})"
                      if c["xblocked"] == "X" else "not blocked")
            overdue_age = f" (oldest item {c['max_days_overdue']} days past due)" if c["max_days_overdue"] else ""
            lines.append(f"- BP {c['partner']} {c['name']}: credit limit {c['currency']} {c['credit_limit']:,.2f}; "
                         f"exposure (open receivables) {c['currency']} {c['exposure']:,.2f} = {usage:.1f}% of the limit"
                         f"{' → OVER LIMIT' if c['exposure'] > c['credit_limit'] else ''}; overdue {c['currency']} "
                         f"{c['overdue']:,.2f}{overdue_age}; credit status {status}; limit valid until "
                         f"{c['limit_valid_date']}; CNPJ {c['cnpj'] or 'MISSING'}; "
                         f"Inscrição Estadual {c['inscricao_estadual'] or 'MISSING'}")
    return "\n".join(lines) or "No SAP data is linked to the retrieved manual excerpts."


def answer_question(question: str, language: str = "pt", top_k: int | None = None) -> dict:
    s = get_settings()
    llm.require_models(s.ollama_chat_model, s.ollama_embed_model, language=language)
    chat = llm.chat()
    timings: dict[str, int] = {}

    start = time.perf_counter()
    question_en = (QUERY_TRANSLATION | chat | StrOutputParser()).invoke({"question": question}).strip()
    timings["translate_ms"] = _elapsed_ms(start)

    start = time.perf_counter()
    query_vector = llm.embedder().embed_query(f"search_query: {question_en}")
    hits = knowledge.search(query_vector, top_k or s.rag_top_k)
    if not hits:
        raise KnowledgeBaseEmpty(message("kb_empty", language))
    # Small-to-big: the matched manuals go in full, so SAP steps (XD01, IW31, MIGO…) are never cut off.
    chunks = knowledge.document_chunks(_relevant_documents(hits), query_vector)
    timings["retrieve_ms"] = _elapsed_ms(start)

    start = time.perf_counter()
    sap = _sap_context(_collect_refs(chunks))
    timings["sap_ms"] = _elapsed_ms(start)

    start = time.perf_counter()
    manuals, sap_text, prescribed = _format_manuals(chunks), _format_sap(sap), prescribed_transactions(chunks)
    answer = (ANSWER_PROMPTS[language] | chat | StrOutputParser()).invoke(
        {"question": question, "manuals": manuals, "sap": sap_text,
         "transactions": "\n".join(f"- {code}: {sentence}" for code, sentence in prescribed.items()) or "-"}).strip()
    timings["generate_ms"] = _elapsed_ms(start)

    detected, status = detect_language(answer), "ok"
    if detected != language:  # language guard: one corrective translation pass
        start = time.perf_counter()
        answer = (ANSWER_TRANSLATION | chat | StrOutputParser()).invoke(
            {"language": LANGUAGE_NAMES[language], "text": answer}).strip()
        timings["language_fix_ms"] = _elapsed_ms(start)
        detected, status = detect_language(answer), "corrected"
    answer, cited, removed = ground_transactions(answer, f"{question}\n{manuals}\n{sap_text}", list(prescribed), language)

    return {
        "answer": answer,
        "language": language,
        "language_check": {"requested": language, "detected": detected, "status": status},
        "grounding_check": {"declared": list(prescribed), "cited": cited, "removed": removed},
        "question_en": question_en,
        "sources": [{"doc_id": c["doc_id"], "title": c["title"], "applies_to": c["applies_to"],
                     "source_uri": c["source_uri"], "section": c["section"],
                     "similarity": round(float(c["similarity"]), 4), "excerpt": c["content"][:280],
                     "sap_refs": c["sap_refs"]} for c in chunks],
        "sap": sap,
        "models": {"chat": s.ollama_chat_model, "embeddings": s.ollama_embed_model},
        "timings_ms": timings,
    }
