"""Minimal provider handlers (provider_handlers.py)

These are lightweight, well-documented fallbacks intended to fix import-time
failures during deployment. They implement the async signatures expected by
`invoke_provider_impl.py` and return safe, testable responses.

They intentionally do NOT call external provider APIs — that belongs in the
full implementations. These stubs preserve runtime behavior and provide
clear error messages so Vercel doesn't crash on import errors.
"""

from __future__ import annotations

import time
from typing import Any, AsyncGenerator, Dict


async def _stream_single_chunk(message: str) -> AsyncGenerator[Dict[str, Any], None]:
    """A tiny async generator that yields one chunk then completes.
    Used when a streaming response is requested but not implemented.
    """
    yield {"delta": {"content": message}}


async def handle_llamacpp(
    pid: str,
    model: str,
    payload: Dict[str, Any],
    timeout,  # httpx.Timeout or numeric
    stream: bool,
    endpoint: str,
    invoke_path: str,
    client,
    start_time: float,
) -> Dict[str, Any]:
    """Handler for local Llama/C++ runtimes — delegates to backend implementation

    Falls back to a minimal response if the backend provider class isn't
    importable in the current environment.
    """
    latency_ms = (time.time() - start_time) * 1000.0

    # Build standardized InferenceRequest if possible
    try:
        from backend.providers.base import InferenceRequest
        from backend.providers.llamacpp import LlamaCppProvider

        messages = payload.get("messages") or (
            [{"role": "user", "content": payload.get("prompt", "")}]
        )
        req = InferenceRequest(messages=messages, model=model, stream=bool(stream))

        # Instantiate provider with endpoint if provided
        provider = (
            LlamaCppProvider(base_url=endpoint) if endpoint else LlamaCppProvider()
        )

        result = await __import__("asyncio").to_thread(lambda: provider.infer(req))

        if stream:
            # Convert returned InferenceResult.content into a single-chunk async stream
            async def _agen():
                yield {"delta": {"content": result.content}}

            return {"ok": True, "stream": _agen()}

        return {
            "ok": True,
            "result": {"content": result.content, "usage": result.usage},
            "latency_ms": result.latency_ms,
        }

    except Exception:
        # Fallback safe behaviour
        if stream:
            return {
                "ok": True,
                "stream": _stream_single_chunk("llamacpp-not-implemented"),
            }
        return {
            "ok": False,
            "error": "llamacpp-not-implemented",
            "latency_ms": latency_ms,
        }


async def handle_openai(
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
    """OpenAI handler that delegates to backend.providers.OpenAIProvider when available.

    Keeps backward-compatible return shape expected by the router.
    """
    latency_ms = (time.time() - start_time) * 1000.0
    try:
        from backend.providers.base import InferenceRequest
        from backend.providers.openai import OpenAIProvider

        messages = payload.get("messages") or (
            [{"role": "user", "content": payload.get("prompt", "")}]
        )
        req = InferenceRequest(messages=messages, model=model, stream=bool(stream))

        if not api_key:
            raise RuntimeError("missing-api-key")

        provider = OpenAIProvider(
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
        # Preserve earlier safe stub behaviour on errors
        if stream:
            return {
                "ok": True,
                "stream": _stream_single_chunk("openai-not-implemented"),
            }
        return {
            "ok": False,
            "error": str(exc) or "openai-not-implemented",
            "latency_ms": latency_ms,
        }


__all__ = ["handle_llamacpp", "handle_openai"]
