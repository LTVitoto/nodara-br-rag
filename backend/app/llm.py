"""Local LLM runtime (Ollama inside the air-gapped enclave) through LangChain."""
from __future__ import annotations

import httpx
from langchain_ollama import ChatOllama, OllamaEmbeddings

from .settings import get_settings


class ModelUnavailable(RuntimeError):
    """Raised when a required model has not been imported into the enclave."""


def _canonical(name: str) -> str:
    return name if ":" in name else f"{name}:latest"


def installed_models() -> set[str]:
    response = httpx.get(f"{get_settings().ollama_base_url}/api/tags", timeout=5)
    response.raise_for_status()
    return {_canonical(m["name"]) for m in response.json().get("models", [])}


def require_models(*names: str) -> None:
    missing = [n for n in names if _canonical(n) not in installed_models()]
    if missing:
        raise ModelUnavailable(
            f"Modelo(s) {', '.join(missing)} indisponível(is) no Ollama local (ambiente air-gapped). "
            "Importe com: make models")


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
