import os

from fastapi import FastAPI


SERVICE_NAME = os.getenv("SERVICE_NAME", "chatbot-manager")

app = FastAPI(title=f"SecureRAG Hub - {SERVICE_NAME}")


@app.get("/healthz", tags=["health"])
def healthz() -> dict[str, str]:
    return {"status": "ok", "service": SERVICE_NAME}


@app.get("/", tags=["meta"])
def root() -> dict[str, str]:
    return {"service": SERVICE_NAME, "status": "ready"}
