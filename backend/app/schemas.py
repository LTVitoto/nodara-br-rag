"""API contracts."""
from typing import Any

from pydantic import AliasChoices, BaseModel, Field, field_validator

from .messages import Language


class AskRequest(BaseModel):
    question: str = Field(min_length=3, max_length=2000, validation_alias=AliasChoices("question", "query"),
                          description="User question in ES, EN or PT (also accepted as `query`)")
    language: Language = Field(default="pt", description="Answer language: ES | EN | PT (case-insensitive)")
    top_k: int | None = Field(default=None, ge=1, le=10)

    @field_validator("language", mode="before")
    @classmethod
    def normalize_language(cls, value: Any) -> Any:
        return str(value).strip().lower().split("-")[0] if value else "pt"


class Source(BaseModel):
    doc_id: str
    title: str
    applies_to: str
    source_uri: str  # lineage: original document in the raw layer (s3://raw-manuals/...)
    section: str
    similarity: float
    excerpt: str
    sap_refs: dict[str, list[str]]


class AskResponse(BaseModel):
    answer: str
    language: Language
    language_check: dict[str, str | None]
    grounding_check: dict[str, list[str]]  # SAP transactions: declared by the manuals / cited / removed
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
