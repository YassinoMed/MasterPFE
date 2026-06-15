from fastapi import FastAPI

app = FastAPI(title="security-auditor", version="0.1.0")

@app.get("/health")
def health():
    return {"status": "ok", "service": "security-auditor"}

@app.get("/ready")
def ready():
    return {"status": "ready"}
