from __future__ import annotations

import json
import logging
from dataclasses import dataclass, field
from typing import Any, Dict, Iterable

import httpx
from django.conf import settings

__all__ = [
    "OpenRouterClient",
    "OpenRouterError",
    "OpenRouterConfigurationError",
]

logger = logging.getLogger(__name__)


class OpenRouterError(RuntimeError):
    """Raised when OpenRouter returns an unexpected response."""


class OpenRouterConfigurationError(OpenRouterError):
    """Raised when OpenRouter configuration is missing or invalid."""


@dataclass
class OpenRouterClient:
    api_key: str | None = None
    base_url: str | None = None
    model: str | None = None
    app_url: str | None = None
    timeout: float | None = None
    default_headers: Dict[str, str] = field(default_factory=dict)

    def __post_init__(self) -> None:
        config = getattr(settings, "OPENROUTER", {})
        self.api_key = (self.api_key or config.get("api_key") or "").strip()
        self.base_url = (self.base_url or config.get("base_url") or "https://openrouter.ai/api/v1").rstrip("/")
        self.model = (self.model or config.get("model") or "").strip()
        self.app_url = (self.app_url or config.get("app_url") or "").strip()
        self.timeout = float(self.timeout or config.get("timeout") or 45)

        if not self.api_key:
            raise OpenRouterConfigurationError("OpenRouter API key is not configured.")
        if not self.model:
            raise OpenRouterConfigurationError("OpenRouter model is not configured.")

        headers = {
            "Authorization": f"Bearer {self.api_key}",
            "Content-Type": "application/json",
        }
        if self.app_url:
            headers.setdefault("HTTP-Referer", self.app_url)
            headers.setdefault("X-Title", "Sodamrok Backend")
        if self.default_headers:
            headers.update(self.default_headers)
        self.default_headers = headers

    def chat(self, messages: Iterable[dict[str, Any]], *, response_format: str | None = None, **extra: Any) -> dict[str, Any]:
        payload: dict[str, Any] = {
            "model": self.model,
            "messages": list(messages),
        }
        if response_format:
            payload["response_format"] = {"type": response_format}
        if extra:
            payload.update(extra)

        logger.debug("Sending chat request to OpenRouter: model=%s", self.model)
        try:
            with httpx.Client(base_url=self.base_url, timeout=self.timeout) as client:
                response = client.post("/chat/completions", headers=self.default_headers, json=payload)
                response.raise_for_status()
        except httpx.HTTPStatusError as exc:  # pragma: no cover - thin wrapper
            logger.exception("OpenRouter returned status error: %s", exc)
            raise OpenRouterError(f"openrouter_http_{exc.response.status_code}") from exc
        except httpx.HTTPError as exc:  # pragma: no cover - thin wrapper
            logger.exception("Failed to reach OpenRouter: %s", exc)
            raise OpenRouterError("openrouter_request_failed") from exc

        data = response.json()
        if not data.get("choices"):
            logger.error("OpenRouter response missing choices: %s", data)
            raise OpenRouterError("openrouter_empty_response")
        return data

    def complete(self, messages: Iterable[dict[str, Any]], *, response_format: str | None = None, **extra: Any) -> str:
        data = self.chat(messages, response_format=response_format, **extra)
        try:
            content = data["choices"][0]["message"]["content"]
        except (KeyError, IndexError, TypeError) as exc:
            logger.exception("OpenRouter payload structure unexpected: %s", data)
            raise OpenRouterError("openrouter_invalid_payload") from exc
        return content

    def complete_json(self, messages: Iterable[dict[str, Any]], **extra: Any) -> dict[str, Any]:
        content = self.complete(messages, response_format="json_object", **extra)
        try:
            return json.loads(content)
        except json.JSONDecodeError as exc:
            logger.exception("OpenRouter returned invalid JSON: %s", content)
            raise OpenRouterError("openrouter_invalid_json") from exc

