from pathlib import Path
from typing import Any
import yaml


def load_config(file_path: str | Path) -> dict[str, Any]:
    path = Path(file_path)
    if not path.exists():
        return {}
    with path.open("r") as f:
        return yaml.safe_load(f) or {}


def load_ocr_config() -> dict[str, Any]:
    config_path = Path(__file__).resolve().parents[2] / "configs" / "ocr_config.yaml"
    cfg = load_config(str(config_path))
    return cfg.get("tesseract", {"languages": ["eng"], "psm": 6, "oem": 1})
