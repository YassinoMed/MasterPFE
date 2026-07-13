import json
import xml.etree.ElementTree as ET
from pathlib import Path
import pandas as pd
from src.postprocessing.export import to_excel, to_json, to_txt, to_xml, export_df


def _sample_df() -> pd.DataFrame:
    return pd.DataFrame({
        "type": ["paragraph", "field"],
        "content": ["Hello world", "test_value"],
    })


def test_to_excel(tmp_path):
    df = _sample_df()
    path = tmp_path / "out.xlsx"
    result = to_excel(df, path)
    assert Path(result).exists()
    reloaded = pd.read_excel(result)
    assert len(reloaded) == 2


def test_to_json(tmp_path):
    df = _sample_df()
    path = tmp_path / "out.json"
    result = to_json(df, path)
    assert Path(result).exists()
    with open(result) as f:
        data = json.load(f)
    assert len(data) == 2
    assert data[0]["content"] == "Hello world"


def test_to_txt(tmp_path):
    df = _sample_df()
    path = tmp_path / "out.txt"
    result = to_txt(df, path)
    assert Path(result).exists()
    content = Path(result).read_text()
    assert "Hello world" in content
    assert "type | content" in content


def test_to_xml(tmp_path):
    df = _sample_df()
    path = tmp_path / "out.xml"
    result = to_xml(df, path)
    assert Path(result).exists()
    tree = ET.parse(result)
    root = tree.getroot()
    assert root.tag == "documents"
    assert len(root) == 2
    assert root[0].find("content").text == "Hello world"


def test_export_df_default_xlsx(tmp_path):
    df = _sample_df()
    path = export_df(df, str(tmp_path), "test_file", fmt="xlsx")
    assert path.endswith(".xlsx")
    assert Path(path).exists()


def test_export_df_json(tmp_path):
    df = _sample_df()
    path = export_df(df, str(tmp_path), "test_file", fmt="json")
    assert path.endswith(".json")
    assert Path(path).exists()


def test_export_df_with_doc_type(tmp_path):
    df = _sample_df()
    path = export_df(df, str(tmp_path), "report", fmt="json", doc_type="bank")
    assert "report_bank_output.json" in path
