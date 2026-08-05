import os
import sys
import tempfile
import numpy as np
import pandas as pd
import pytest
from unittest.mock import MagicMock, patch
from PIL import Image

# Ensure src is in python path
sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

from src.cli import batched, main
from src.postprocessing.structure_data import to_structured_table
from src.postprocessing.export import export_df
from src.extraction.table_handling import extract_tables_from_pdf, pdfplumber_table_to_dataframe
from src.extraction.layout_analysis import detect_layout_elements, _classify_block, _merge_nearby_blocks
from src.classification.document_classifier import DocumentClassifier, classify_pdf_text
from src.classification.pipelines import (
    run_pipeline,
    extract_bank_statement,
    extract_invoice,
    extract_contract,
    extract_article,
    extract_form,
    extract_receipt,
    extract_letter,
    extract_other,
)
from src.webapp import app, _find_results
from src.utils.config_loader import load_config, load_ocr_config
from src.preprocessing.image_enhancement import deskew, enhance_image, enhance_for_layout
from src.text_extraction import extract_text, extract_text_fallback, ocr_tesseract, ocr_easyocr
from src.postprocessing.text_cleaner import (
    clean_text,
    normalize_whitespace,
    extract_lines,
    merge_hyphenated,
    fix_sentence_spacing,
    is_table_row,
    extract_table_lines,
    full_clean,
)
from src.engine import extract_pdf, _is_scanned, extract_typed_pdf, extract_scanned_pdf


def test_cli_batched():
    items = list(range(25))
    batches = list(batched(items, batch_size=10))
    assert len(batches) == 3
    assert len(batches[0]) == 10
    assert len(batches[2]) == 5


def test_cli_main_no_pdf(monkeypatch):
    test_args = ["cli.py", "/nonexistent_path/empty.pdf"]
    monkeypatch.setattr(sys, "argv", test_args)
    with pytest.raises(SystemExit) as exc_info:
        main()
    assert exc_info.value.code == 1


def test_cli_main_valid_pdf(monkeypatch, tmp_path):
    pdf_file = tmp_path / "sample.pdf"
    pdf_file.write_bytes(b"%PDF-1.4 mock pdf content")
    test_args = ["cli.py", str(pdf_file), "--output", str(tmp_path), "--format", "json"]
    monkeypatch.setattr(sys, "argv", test_args)
    with patch("src.cli.process_batch") as mock_batch:
        main()
        assert mock_batch.called


def test_to_structured_table():
    elements = [
        {"type": "Title", "text": "Sample Title", "x": 10, "y": 20, "w": 100, "h": 30},
        {"type": "Text", "text": "Sample Body", "x": 10, "y": 60, "w": 200, "h": 40},
    ]
    df = to_structured_table(elements)
    assert isinstance(df, pd.DataFrame)
    assert len(df) == 2
    assert "type" in df.columns
    assert df.iloc[0]["content"] == "Sample Title"


def test_export_df_formats():
    df = pd.DataFrame([{"type": "Test", "content": "Val"}])
    with tempfile.TemporaryDirectory() as tmp_dir:
        res_json = export_df(df, tmp_dir, "base", fmt="json", doc_type="invoice")
        assert os.path.exists(res_json)

        res_xml = export_df(df, tmp_dir, "base", fmt="xml")
        assert os.path.exists(res_xml)

        res_txt = export_df(df, tmp_dir, "base", fmt="txt")
        assert os.path.exists(res_txt)

        res_xlsx = export_df(df, tmp_dir, "base", fmt="xlsx")
        assert os.path.exists(res_xlsx)


def test_document_classifier_extra():
    assert classify_pdf_text("Invoice Total $100 Tax 20%") == "invoice"
    cls = DocumentClassifier()
    doc_type, conf = cls.classify_with_confidence("   ")
    assert doc_type == "other"
    assert conf == 0.0
    doc_type2, conf2 = cls.classify_with_confidence("No matching pattern text")
    assert doc_type2 == "other"
    assert conf2 == 0.0


def test_extract_tables_from_pdf():
    with patch("src.extraction.table_handling.pdfplumber.open") as mock_open:
        mock_pdf = MagicMock()
        mock_page = MagicMock()
        mock_table = MagicMock()
        mock_table.extract.return_value = [["Header1", "Header2"], ["Val1", "Val2"]]
        mock_page.find_tables.return_value = [mock_table]
        mock_pdf.pages = [mock_page]
        mock_open.return_value.__enter__.return_value = mock_pdf

        tables = extract_tables_from_pdf("dummy.pdf")
        assert len(tables) == 1
        assert not tables[0].empty


def test_pdfplumber_table_to_dataframe_empty():
    mock_table = MagicMock()
    mock_table.extract.return_value = None
    df = pdfplumber_table_to_dataframe(mock_table)
    assert df.empty

    mock_table.extract.return_value = [["Col1", "Col2"], ["Val1", "Val2"]]
    df2 = pdfplumber_table_to_dataframe(mock_table)
    assert len(df2) == 1
    assert list(df2.columns) == ["Col1", "Col2"]


def test_classify_block():
    assert _classify_block(10, 10, 1, 0.01) == "Noise"
    assert _classify_block(100, 10, 20, 0.01) == "Header"
    assert _classify_block(100, 25, 10, 0.01) == "Title"
    assert _classify_block(250, 30, 50, 0.01) == "Title"
    assert _classify_block(100, 100, 50, 0.35) == "Figure"
    assert _classify_block(100, 100, 50, 0.01) == "Text"


def test_merge_nearby_blocks():
    assert _merge_nearby_blocks([]) == []
    b1 = {"type": "Text", "text": "Hello", "x": 10, "y": 10, "w": 50, "h": 20}
    b2 = {"type": "Text", "text": "World", "x": 65, "y": 12, "w": 50, "h": 20}
    merged = _merge_nearby_blocks([b1, b2])
    assert len(merged) == 1
    assert merged[0]["text"] == "Hello World"


def test_detect_layout_elements():
    img = np.zeros((300, 300, 3), dtype=np.uint8)
    img[50:100, 50:200] = 255
    with patch("src.extraction.layout_analysis.extract_text_fallback", return_value="Sample Text Here"):
        elements = detect_layout_elements(img)
        assert isinstance(elements, list)


def test_classification_pipelines():
    text_invoice = "INVOICE #12345\nDate: 2026-06-01\nDue date: 2026-07-01\nTotal: $500.00\nVAT: 20%"
    df_inv = run_pipeline("invoice", text_invoice)
    assert not df_inv.empty

    text_bank = "Account Statement\nAccount Number: 987654321\nOpening balance: $1200.50\nPeriod 2026-01-01 to 2026-01-31\n2026-01-15 100.00 1100.00 Salary Description"
    df_bank = run_pipeline("bank_statement", text_bank)
    assert not df_bank.empty

    text_contract = "AGREEMENT between Company A and Company B\nDated 2026-01-01"
    df_contract = run_pipeline("contract", text_contract)
    assert not df_contract.empty

    text_article = "# Research Title Test\nAbstract: This research studies AI.\nIntroduction: Hello"
    df_article = run_pipeline("article", text_article)
    assert not df_article.empty

    text_form = "Form 1040\nFull Name: _____\nAddress: _____"
    df_form = run_pipeline("form", text_form)
    assert not df_form.empty

    text_receipt = "SUPERMARKET\nTotal: $25.99"
    df_receipt = run_pipeline("receipt", text_receipt)
    assert not df_receipt.empty

    text_letter = "Dear Mr. Smith,\nHello,\nSincerely,\nJane Doe"
    df_letter = run_pipeline("letter", text_letter)
    assert not df_letter.empty

    df_other = run_pipeline("other", "Random text")
    assert not df_other.empty


def test_webapp_endpoints():
    client = app.test_client()
    assert client.get("/").status_code == 302
    assert client.get("/dashboard").status_code == 200
    assert client.get("/upload").status_code == 200
    assert client.get("/history").status_code == 200
    assert client.get("/settings").status_code == 200


def test_config_loader():
    assert load_config("nonexistent_file.yaml") == {}
    with tempfile.NamedTemporaryFile("w", suffix=".yaml", delete=False) as f:
        f.write("test_key: test_val\n")
        f_path = f.name
    try:
        data = load_config(f_path)
        assert data.get("test_key") == "test_val"
    finally:
        os.remove(f_path)

    ocr_cfg = load_ocr_config()
    assert isinstance(ocr_cfg, dict)


def test_image_enhancement():
    img = np.zeros((100, 100, 3), dtype=np.uint8)
    enhanced = enhance_image(img)
    assert enhanced is not None

    layout_img = enhance_for_layout(img)
    assert layout_img is not None

    deskewed = deskew(img[:, :, 0])
    assert deskewed is not None


def test_text_extraction_functions():
    img = np.zeros((50, 50, 3), dtype=np.uint8)
    with patch("src.text_extraction.ocr_tesseract", return_value="Tesseract Sample Text"):
        text = extract_text(img, engine="tesseract")
        assert text == "Tesseract Sample Text"

    with patch("src.text_extraction.ocr_easyocr", return_value="EasyOCR Sample Text"):
        text_easy = extract_text(img, engine="easyocr")
        assert text_easy == "EasyOCR Sample Text"

    with patch("src.text_extraction.ocr_tesseract", return_value="Hi"):
        with patch("src.text_extraction.ocr_easyocr", return_value="Longer Fallback Text"):
            fb = extract_text_fallback(img, min_chars=5)
            assert fb == "Longer Fallback Text"

    with patch("src.text_extraction._get_easyocr") as mock_reader:
        mock_easy = MagicMock()
        mock_easy.readtext.return_value = [(None, "Extracted EasyOCR Text", None)]
        mock_reader.return_value = mock_easy
        res = ocr_easyocr(img)
        assert "Extracted EasyOCR Text" in res


def test_text_cleaner_functions():
    cleaned = clean_text("Hello   World!\nTest @#$")
    assert "Hello World!" in cleaned

    assert normalize_whitespace("  A   B  ") == "A B"
    assert extract_lines("Line 1\n\nLine 2") == ["Line 1", "Line 2"]
    assert merge_hyphenated("extrac-\ntion") == "extraction"
    assert fix_sentence_spacing("End.Start") == "End. Start"

    assert is_table_row("Col1  Col2")
    assert is_table_row("A|B|C")
    assert not is_table_row("SingleWord")

    table_lines = extract_table_lines(["Header1  Header2", "Val1  Val2", "SingleLine"])
    assert len(table_lines) == 1

    cleaned_full = full_clean("This is a test-\nsentence.With spacing.")
    assert "testsentence" in cleaned_full


def test_engine_functions():
    dummy_img = Image.fromarray(np.zeros((100, 100, 3), dtype=np.uint8))
    with patch("src.engine.pdfplumber.open") as mock_open:
        mock_pdf = MagicMock()
        mock_page = MagicMock()
        mock_page.extract_text.return_value = "Sample text from PDF page with a long description that exceeds fifty characters to ensure typed PDF detection."
        mock_pdf.pages = [mock_page]
        mock_open.return_value.__enter__.return_value = mock_pdf

        assert _is_scanned("dummy.pdf") is False
        typed_df_list = extract_typed_pdf("dummy.pdf")
        assert len(typed_df_list) == 1

        with patch("src.engine.convert_pdf_to_images", return_value=[dummy_img]):
            with patch("src.engine.extract_text_fallback", return_value="Page 1 Content"):
                scanned_df_list = extract_scanned_pdf("dummy.pdf")
                assert len(scanned_df_list) == 1

                df_extracted = extract_pdf("dummy.pdf", force_ocr=False)
                assert not df_extracted.empty
