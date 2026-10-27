"""API contracts."""
from typing import Any, Literal

from pydantic import AliasChoices, BaseModel, Field, field_validator

from .messages import Language

Engine = Literal["nim", "ollama"]
_ENGINE_ALIASES = {"nim": "nim", "nvidia": "nim", "cloud": "nim", "ollama": "ollama", "local": "ollama"}


class AskRequest(BaseModel):
    question: str = Field(min_length=3, max_length=2000, validation_alias=AliasChoices("question", "query"),
                          description="User question in ES, EN or PT (also accepted as `query`)")
    language: Language = Field(default="pt", description="Answer language: ES | EN | PT (case-insensitive)")
    engine: Engine | None = Field(default=None, description="LLM engine: nim (NVIDIA NIM cloud) | ollama (local)")
    top_k: int | None = Field(default=None, ge=1, le=10)

    @field_validator("language", mode="before")
    @classmethod
    def normalize_language(cls, value: Any) -> Any:
        return str(value).strip().lower().split("-")[0] if value else "pt"

    @field_validator("engine", mode="before")
    @classmethod
    def normalize_engine(cls, value: Any) -> Any:
        return _ENGINE_ALIASES.get(str(value).strip().lower(), value) if value else None


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
    engine: Engine
    model_used: str
    attempts: list[dict[str, Any]]  # fallback chain as executed (model, task, status, ms, error)
    trace_id: str | None
    trace_url: str | None  # Langfuse v2 UI
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
