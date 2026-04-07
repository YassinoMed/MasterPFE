from importlib.util import module_from_spec, spec_from_file_location
from pathlib import Path

from fastapi.testclient import TestClient


MODULE_PATH = Path(__file__).resolve().parents[1] / "src" / "main.py"
MODULE_SPEC = spec_from_file_location("security_auditor_main", MODULE_PATH)
assert MODULE_SPEC and MODULE_SPEC.loader
MODULE = module_from_spec(MODULE_SPEC)
MODULE_SPEC.loader.exec_module(MODULE)

client = TestClient(MODULE.app)


def test_healthz() -> None:
    response = client.get("/healthz")

    assert response.status_code == 200
    assert response.json() == {"status": "ok", "service": "security-auditor"}


def test_root() -> None:
    response = client.get("/")

    assert response.status_code == 200
    assert response.json() == {"service": "security-auditor", "status": "ready"}
