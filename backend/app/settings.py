"""Runtime configuration — 12-factor: everything comes from environment variables."""
from functools import lru_cache

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(extra="ignore")

    # Knowledge base: isolated pgvector instance (manuals only)
    vector_db_host: str = "vector-db"
    vector_db_port: int = 5432
    vector_db_name: str = "knowledge"
    vector_db_user: str
    vector_db_password: str

    # Federated SQL: Trino → S/4HANA live (catalog s4hana) + Delta bronze (catalog lakehouse)
    trino_host: str = "trino"
    trino_port: int = 8080
    trino_user: str = "nodara-backend"

    # Local LLM runtime (air-gapped Ollama)
    ollama_base_url: str = "http://ollama:11434"
    ollama_chat_model: str = "llama3.1:8b"
    ollama_embed_model: str = "nomic-embed-text"
    ollama_timeout_s: float = 300.0

    rag_top_k: int = 4


@lru_cache
def get_settings() -> Settings:
    return Settings()
