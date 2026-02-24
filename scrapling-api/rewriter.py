import itertools
import os
from dataclasses import dataclass

import httpx

NVIDIA_ENDPOINT = "https://integrate.api.nvidia.com/v1/chat/completions"


@dataclass
class RewriteResult:
    ai_title: str
    ai_summary: str


class NvidiaRewriter:
    def __init__(self) -> None:
        keys = [k.strip() for k in os.getenv("NVIDIA_API_KEYS", "").split(",") if k.strip()]
        if not keys:
            raise ValueError("NVIDIA_API_KEYS is required")
        self._keys = keys
        self._key_cycle = itertools.cycle(keys)
        self._model = os.getenv("NVIDIA_MODEL", "meta/llama-3.1-70b-instruct")

    def _next_key(self) -> str:
        return next(self._key_cycle)

    @staticmethod
    def _limit_words(text: str, max_words: int) -> str:
        words = text.split()
        return " ".join(words[:max_words]).strip()

    @staticmethod
    def _extract_json_payload(content: str) -> dict:
        import json

        cleaned = content.strip()
        if cleaned.startswith("```"):
            cleaned = cleaned.strip("`")
            cleaned = cleaned.replace("json\n", "", 1).strip()
        return json.loads(cleaned)

    async def rewrite(self, title: str, body_text: str, district: str) -> RewriteResult:
        api_key = self._next_key()
        system_prompt = (
            "You are a Tamil hyperlocal news rewriter. Return strict JSON with keys "
            "ai_title and ai_summary. ai_title max 10 Tamil words, no clickbait. "
            "ai_summary max 150 Tamil words. Keep factual accuracy and district context."
        )
        user_prompt = (
            f"District: {district}\n"
            f"Original title: {title}\n"
            f"Article text:\n{body_text[:6000]}\n\n"
            "Return JSON only."
        )

        async with httpx.AsyncClient(timeout=45.0) as client:
            response = await client.post(
                NVIDIA_ENDPOINT,
                headers={
                    "Authorization": f"Bearer {api_key}",
                    "Content-Type": "application/json",
                },
                json={
                    "model": self._model,
                    "temperature": 0.2,
                    "messages": [
                        {"role": "system", "content": system_prompt},
                        {"role": "user", "content": user_prompt},
                    ],
                },
            )
            response.raise_for_status()
            data = response.json()

        content = data["choices"][0]["message"]["content"]
        payload = self._extract_json_payload(content)
        title_out = str(payload.get("ai_title", "")).strip()
        summary_out = str(payload.get("ai_summary", "")).strip()

        # Enforce contract: title <=10 words, summary <=150 words.
        bounded_title = self._limit_words(title_out, 10)
        bounded_summary = self._limit_words(summary_out, 150)

        return RewriteResult(ai_title=bounded_title, ai_summary=bounded_summary)
