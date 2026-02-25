import asyncio
import io
import os
import uuid
from typing import Optional

import boto3
from botocore.config import Config
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel, HttpUrl
from PIL import Image

from rewriter import NvidiaRewriter

# Scrapling import path may vary by version; this import matches current package layout.
from scrapling.fetchers import AsyncFetcher


class ScrapeRequest(BaseModel):
    url: HttpUrl
    district: str


class ScrapeResponse(BaseModel):
    title: str
    body_text: str
    image_url: Optional[str]
    publisher: str
    ai_title: str
    ai_summary: str


app = FastAPI(title="Namma Ooru Scrapling API", version="1.0.0")
rewriter = NvidiaRewriter()
fetcher = AsyncFetcher()

MAX_CONCURRENCY = int(os.getenv("SCRAPLING_CONCURRENCY", "5"))
MAX_WIDTH = int(os.getenv("SCRAPLING_IMAGE_MAX_WIDTH", "800"))
REQUEST_TIMEOUT = int(os.getenv("SCRAPLING_TIMEOUT_SECONDS", "25"))
SCRAPE_SEMAPHORE = asyncio.Semaphore(MAX_CONCURRENCY)


def _r2_client():
    return boto3.client(
        "s3",
        endpoint_url=os.getenv("CLOUDFLARE_R2_ENDPOINT"),
        aws_access_key_id=os.getenv("R2_ACCESS_KEY_ID"),
        aws_secret_access_key=os.getenv("R2_SECRET_ACCESS_KEY"),
        config=Config(signature_version="s3v4"),
        region_name="auto",
    )


async def _upload_image_to_r2(image_bytes: bytes) -> str:
    bucket = os.getenv("CLOUDFLARE_R2_BUCKET")
    if not bucket:
        raise ValueError("CLOUDFLARE_R2_BUCKET is required")

    image = Image.open(io.BytesIO(image_bytes)).convert("RGB")
    if image.width > MAX_WIDTH:
        ratio = MAX_WIDTH / float(image.width)
        image = image.resize((MAX_WIDTH, int(image.height * ratio)), Image.Resampling.LANCZOS)

    output = io.BytesIO()
    image.save(output, format="JPEG", quality=86, optimize=True)
    output.seek(0)

    key = f"articles/{uuid.uuid4()}.jpg"
    client = _r2_client()
    client.put_object(
        Bucket=bucket,
        Key=key,
        Body=output.getvalue(),
        ContentType="image/jpeg",
        CacheControl="public, max-age=31536000, immutable",
    )

    base_url = os.getenv("R2_PUBLIC_BASE_URL", "https://cdn.quoteviral.online")
    return f"{base_url.rstrip('/')}/{key}"


@app.get("/health")
async def health():
    return {"ok": True}


@app.post("/scrape", response_model=ScrapeResponse)
async def scrape(payload: ScrapeRequest):
    async with SCRAPE_SEMAPHORE:
        try:
            page = await fetcher.fetch(str(payload.url), timeout=REQUEST_TIMEOUT)
        except Exception as exc:
            raise HTTPException(status_code=502, detail=f"Scrape fetch failed: {exc}") from exc

        title = (page.meta.get("title") or "").strip()[:300]
        publisher = (page.meta.get("site_name") or payload.url.host).strip()[:120]
        body_text = (page.text or "").strip()
        if not body_text:
            raise HTTPException(status_code=422, detail="No article text extracted")

        image_url = page.meta.get("image")
        cdn_image_url: Optional[str] = None

        if image_url:
            import httpx

            async with httpx.AsyncClient(timeout=REQUEST_TIMEOUT) as client:
                img_res = await client.get(image_url)
                if img_res.status_code == 200:
                    cdn_image_url = await _upload_image_to_r2(img_res.content)

        rewrite = await rewriter.rewrite(title=title, body_text=body_text, district=payload.district)

        return ScrapeResponse(
            title=title,
            body_text=body_text[:12000],
            image_url=cdn_image_url,
            publisher=publisher,
            ai_title=rewrite.ai_title,
            ai_summary=rewrite.ai_summary,
        )
