"""Local LLM runtime (Ollama inside the air-gapped enclave) through LangChain."""
from __future__ import annotations

import logging

import httpx
from langchain_ollama import ChatOllama, OllamaEmbeddings

from .messages import message
from .settings import get_settings


log = logging.getLogger("backend")


class ModelUnavailable(RuntimeError):
    """Raised when a required model has not been imported into the enclave."""


def _canonical(name: str) -> str:
    return name if ":" in name else f"{name}:latest"


def installed_models() -> set[str]:
    response = httpx.get(f"{get_settings().ollama_base_url}/api/tags", timeout=5)
    response.raise_for_status()
    return {_canonical(m["name"]) for m in response.json().get("models", [])}


def require_models(*names: str, language: str = "en") -> None:
    missing = [n for n in names if _canonical(n) not in installed_models()]
    if missing:
        raise ModelUnavailable(message("model_unavailable", language, models=", ".join(missing)))


def model_status() -> dict:
    s = get_settings()
    installed = installed_models()
    return {"chat_model": s.ollama_chat_model, "chat_ready": _canonical(s.ollama_chat_model) in installed,
            "embed_model": s.ollama_embed_model, "embed_ready": _canonical(s.ollama_embed_model) in installed,
            "installed": sorted(installed)}


def chat() -> ChatOllama:
    s = get_settings()
    return ChatOllama(model=s.ollama_chat_model, base_url=s.ollama_base_url, temperature=0.1,
                      num_ctx=8192, keep_alive="30m", client_kwargs={"timeout": s.ollama_timeout_s})


def embedder() -> OllamaEmbeddings:
    s = get_settings()
    return OllamaEmbeddings(model=s.ollama_embed_model, base_url=s.ollama_base_url,
                            client_kwargs={"timeout": s.ollama_timeout_s})


def warm_up() -> None:
    """Loads both models into memory so the first operator question skips the cold start."""
    s = get_settings()
    try:
        if {_canonical(s.ollama_chat_model), _canonical(s.ollama_embed_model)} <= installed_models():
            embedder().embed_query("warm-up")
            chat().invoke("Reply with OK.")
            log.info("models warmed up: %s, %s", s.ollama_chat_model, s.ollama_embed_model)
    except Exception as exc:  # warm-up is best effort; requests still work without it
        log.info("model warm-up skipped: %s", exc)
