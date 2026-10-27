"""User-facing backend messages in the three supported languages (ES / EN / PT)."""
from __future__ import annotations

from typing import Literal

Language = Literal["es", "en", "pt"]

LANGUAGE_NAMES: dict[str, str] = {"es": "español", "en": "English", "pt": "português do Brasil"}

_MESSAGES: dict[str, dict[str, str]] = {
    "model_unavailable": {
        "es": "Modelo(s) {models} no disponible(s) en el Ollama local (entorno air-gapped). Impórtalos con: make models",
        "en": "Model(s) {models} not available in the local Ollama (air-gapped environment). Import them with: make models",
        "pt": "Modelo(s) {models} indisponível(is) no Ollama local (ambiente air-gapped). Importe com: make models",
    },
    "kb_empty": {
        "es": "La base de conocimiento no tiene embeddings. Ejecuta: make embed",
        "en": "The knowledge base has no embeddings. Run: make embed",
        "pt": "Base de conhecimento sem embeddings. Execute: make embed",
    },
}


def message(key: str, language: str, **values: str) -> str:
    texts = _MESSAGES[key]
    return texts.get(language, texts["en"]).format(**values)
