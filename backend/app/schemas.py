"""API contracts."""
from typing import Any

from pydantic import BaseModel, Field


class AskRequest(BaseModel):
    question: str = Field(min_length=3, max_length=2000, description="Pergunta do operador (pt-BR)")
    top_k: int | None = Field(default=None, ge=1, le=10)


class Source(BaseModel):
    doc_id: str
    title: str
    equipment: str
    section: str
    similarity: float
    excerpt: str
    sap_materials: list[str]


class AskResponse(BaseModel):
    answer: str
    question_en: str
    sources: list[Source]
    sap: dict[str, Any]
    models: dict[str, str]
    timings_ms: dict[str, int]


class EmbedResponse(BaseModel):
    embedded_now: int
    model: str
    total_embedded: int
    total_chunks: int
