"""Live USD→BRL exchange rate for the credit evaluation (case 1).

fxratesapi.com first, Frankfurter (ECB reference rates) as fallback, both reached through the
egress gateway. Quotes are cached briefly. There is no fixed-rate fallback: if both providers
fail, the caller reports that live FX is unavailable.
"""
from __future__ import annotations

import threading
import time

import httpx

from .settings import get_settings


class FxUnavailable(RuntimeError):
    """Raised when no provider returned a live USD/BRL rate."""


_lock = threading.Lock()
_cached: tuple[float, dict] | None = None


def _fetch(provider: str, url: str) -> dict:
    response = httpx.get(url, timeout=8)  # honours HTTPS_PROXY → egress gateway
    response.raise_for_status()
    body = response.json()
    return {"pair": "USD/BRL", "rate": float(body["rates"]["BRL"]), "as_of": str(body.get("date")),
            "source": provider}


def usd_brl() -> dict:
    global _cached
    s = get_settings()
    with _lock:
        if _cached and time.monotonic() - _cached[0] < s.fx_cache_ttl_s:
            return _cached[1]
        errors = []
        for provider, url in (("fxratesapi.com", s.fx_primary_url), ("frankfurter.dev (ECB)", s.fx_fallback_url)):
            try:
                quote = _fetch(provider, url)
            except Exception as exc:  # try the next provider
                errors.append(f"{provider}: {exc}")
                continue
            _cached = (time.monotonic(), quote)
            return quote
        raise FxUnavailable("; ".join(errors))
