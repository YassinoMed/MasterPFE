import json
import math
import xml.etree.ElementTree as ET
from pathlib import Path
from typing import Optional
import pandas as pd


def _sanitize(obj):
    if isinstance(obj, float) and math.isnan(obj):
        return None
    return obj


def to_excel(df: pd.DataFrame, path: str | Path) -> str:
    path = Path(path)
    df.to_excel(str(path), index=False)
    return str(path)


def _clean_json(obj):
    if isinstance(obj, dict):
        return {k: _clean_json(v) for k, v in obj.items()}
    if isinstance(obj, list):
        return [_clean_json(v) for v in obj]
    if isinstance(obj, float) and math.isnan(obj):
        return None
    return obj


def to_json(df: pd.DataFrame, path: str | Path, orient: str = "records") -> str:
    path = Path(path)
    data = _clean_json(df.to_dict(orient=orient))
    with open(path, "w", encoding="utf-8") as f:
        json.dump(data, f, indent=2, ensure_ascii=False)
    return str(path)


def to_txt(df: pd.DataFrame, path: str | Path, sep: str = " | ") -> str:
    path = Path(path)
    clean = df.where(pd.notna(df), None)
    lines = []
    lines.append(sep.join(str(c) for c in clean.columns))
    lines.append("-" * 60)
    for _, row in clean.iterrows():
        vals = [str(v) if v is not None else "" for v in row]
        lines.append(sep.join(vals))
    path.write_text("\n".join(lines), encoding="utf-8")
    return str(path)


def to_xml(df: pd.DataFrame, path: str | Path, root_name: str = "documents") -> str:
    path = Path(path)
    clean = df.where(pd.notna(df), None)
    root = ET.Element(root_name)
    for _, row in clean.iterrows():
        item = ET.SubElement(root, "item")
        for col in clean.columns:
            child = ET.SubElement(item, col.replace(" ", "_").lower())
            val = row[col]
            child.text = str(val) if val is not None else ""
    tree = ET.ElementTree(root)
    tree.write(str(path), encoding="utf-8", xml_declaration=True)
    return str(path)


EXPORTERS = {
    "xlsx": to_excel,
    "json": to_json,
    "txt": to_txt,
    "xml": to_xml,
}


def export_df(
    df: pd.DataFrame,
    output_dir: str | Path,
    base_name: str,
    fmt: str = "xlsx",
    doc_type: Optional[str] = None,
) -> str:
    output_dir = Path(output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)

    if doc_type:
        base_name = f"{base_name}_{doc_type}_output"
    else:
        base_name = f"{base_name}_output"

    ext = fmt if fmt != "xlsx" else "xlsx"
    path = output_dir / f"{base_name}.{ext}"

    exporter = EXPORTERS.get(fmt, to_excel)
    return exporter(df, str(path))
