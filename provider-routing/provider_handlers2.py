"""Secondary provider handlers (provider_handlers2.py)

Delegates to backend provider adapters when available. Falls back to the
minimal placeholders if backend classes are unavailable in the environment.
This prevents import-time failures while preserving full backend logic for
server-side execution.
"""

from __future__ import annotations

import time
from typing import Any, AsyncGenerator, Dict


async def _stream_single_chunk(message: str) -> AsyncGenerator[Dict[str, Any], None]:
    yield {"delta": {"content": message}}


async def handle_ollama(
    pid: str,
    model: str,
    payload: Dict[str, Any],
    timeout,
    stream: bool,
    endpoint: str,
    invoke_path: str,
    client,
    start_time: float,
) -> Dict[str, Any]:
    latency_ms = (time.time() - start_time) * 1000.0
    try:
        from backend.providers.base import InferenceRequest
        from backend.providers.ollama import OllamaProvider

        messages = payload.get("messages") or (
            [{"role": "user", "content": payload.get("prompt", "")}]
        )
        req = InferenceRequest(messages=messages, model=model, stream=bool(stream))
        provider = OllamaProvider(base_url=endpoint) if endpoint else OllamaProvider()
        result = await __import__("asyncio").to_thread(lambda: provider.infer(req))

        if stream:

            async def _agen():
                yield {"delta": {"content": result.content}}

            return {"ok": True, "stream": _agen()}

        return {
            "ok": True,
            "result": {"content": result.content, "usage": result.usage},
            "latency_ms": result.latency_ms,
        }

    except Exception:
        if stream:
            return {
                "ok": True,
                "stream": _stream_single_chunk("ollama-not-implemented"),
            }
        return {
            "ok": False,
            "error": "ollama-not-implemented",
            "latency_ms": latency_ms,
        }


async def handle_anthropic(
    pid: str,
    model: str,
    payload: Dict[str, Any],
    timeout,
    stream: bool,
    endpoint: str,
    invoke_path: str,
    api_key: str | None,
    client,
    start_time: float,
) -> Dict[str, Any]:
    latency_ms = (time.time() - start_time) * 1000.0
    try:
        from backend.providers.base import InferenceRequest
        from backend.providers.anthropic import AnthropicProvider

        messages = payload.get("messages") or (
            [{"role": "user", "content": payload.get("prompt", "")}]
        )
        req = InferenceRequest(messages=messages, model=model, stream=bool(stream))
        if not api_key:
            raise RuntimeError("missing-api-key")
        provider = AnthropicProvider(
            api_key=api_key, base_url=endpoint if endpoint else None
        )
        result = await __import__("asyncio").to_thread(lambda: provider.infer(req))

        if stream:

            async def _agen():
                yield {"delta": {"content": result.content}}

            return {"ok": True, "stream": _agen()}

        return {
            "ok": True,
            "result": {"content": result.content, "usage": result.usage},
            "latency_ms": result.latency_ms,
        }

    except Exception as exc:
        if stream:
            return {
                "ok": True,
                "stream": _stream_single_chunk("anthropic-not-implemented"),
            }
        return {
            "ok": False,
            "error": str(exc) or "anthropic-not-implemented",
            "latency_ms": latency_ms,
        }


async def handle_grok(
    pid: str,
    model: str,
    payload: Dict[str, Any],
    timeout,
    stream: bool,
    endpoint: str,
    invoke_path: str,
    api_key: str | None,
    client,
    start_time: float,
) -> Dict[str, Any]:
    latency_ms = (time.time() - start_time) * 1000.0
    try:
        # Grok has an async adapter (GrokAdapter) — use it when available
        from backend.providers.grok_adapter import GrokAdapter

        messages = payload.get("messages") or (
            [{"role": "user", "content": payload.get("prompt", "")}]
        )
        adapter = GrokAdapter(api_key=api_key, base_url=endpoint if endpoint else None)
        res = await adapter.generate(messages, model=model, stream=bool(stream))

        if stream:

            async def _agen():
                yield {"delta": {"content": res.get("content", "")}}

            return {"ok": True, "stream": _agen()}

        return {
            "ok": True,
            "result": {"content": res.get("content"), "usage": res.get("usage")},
            "latency_ms": 0,
        }

    except Exception:
        if stream:
            return {"ok": True, "stream": _stream_single_chunk("grok-not-implemented")}
        return {"ok": False, "error": "grok-not-implemented", "latency_ms": latency_ms}


async def handle_gemini(
    pid: str,
    model: str,
    payload: Dict[str, Any],
    timeout,
    stream: bool,
    endpoint: str,
    invoke_path: str,
    api_key: str | None,
    client,
    start_time: float,
) -> Dict[str, Any]:
    latency_ms = (time.time() - start_time) * 1000.0
    try:
        from backend.providers.gemini_adapter import GeminiAdapter

        messages = payload.get("messages") or (
            [{"role": "user", "content": payload.get("prompt", "")}]
        )
        adapter = GeminiAdapter(
            api_key=api_key, base_url=endpoint if endpoint else None
        )
        res = await adapter.generate(messages, model=model, stream=bool(stream))

        if stream:

            async def _agen():
                yield {"delta": {"content": res.get("content", "")}}

            return {"ok": True, "stream": _agen()}

        return {
            "ok": True,
            "result": {"content": res.get("content"), "usage": res.get("usage")},
            "latency_ms": 0,
        }

    except Exception:
        if stream:
            return {
                "ok": True,
                "stream": _stream_single_chunk("gemini-not-implemented"),
            }
        return {
            "ok": False,
            "error": "gemini-not-implemented",
            "latency_ms": latency_ms,
        }


async def handle_generic(
    pid: str,
    model: str,
    payload: Dict[str, Any],
    timeout: int,
    stream: bool,
    endpoint: str,
    invoke_path: str,
    api_key: str | None,
    client,
    start_time: float,
) -> Dict[str, Any]:
    """Generic fallback used when a provider-specific handler isn't available.

    Returns a predictable response so upper layers can handle failures
    gracefully instead of crashing on ImportError.
    """
    latency_ms = (time.time() - start_time) * 1000.0
    try:
        # Reuse backend.providers.generic.test_connection if available
        from backend.providers import generic as generic_backend

        if api_key is None:
            raise RuntimeError("missing-api-key")
        res = generic_backend.test_connection(api_key)
        if not res.get("success"):
            return {
                "ok": False,
                "error": res.get("error", "generic-failure"),
                "latency_ms": latency_ms,
            }
        return {
            "ok": True,
            "result": {"message": res.get("message")},
            "latency_ms": res.get("latency_ms", latency_ms),
        }
    except Exception as exc:
        if stream:
            return {
                "ok": True,
                "stream": _stream_single_chunk("generic-not-implemented"),
            }
        return {
            "ok": False,
            "error": str(exc) or f"provider-{pid}-not-implemented",
            "latency_ms": latency_ms,
        }


__all__ = [
    "handle_ollama",
    "handle_anthropic",
    "handle_grok",
    "handle_gemini",
    "handle_generic",
]
