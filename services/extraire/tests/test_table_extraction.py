import pandas as pd
import numpy as np
from src.engine import extract_pdf, _is_scanned
from src.text_extraction import ocr_tesseract
from src.postprocessing.text_cleaner import full_clean, merge_hyphenated, is_table_row
from src.preprocessing.image_enhancement import deskew


def test_is_scanned(sample_pdf):
    assert _is_scanned(sample_pdf) is False


def test_extract_typed_pdf(sample_pdf):
    df = extract_pdf(sample_pdf)
    assert isinstance(df, pd.DataFrame)
    assert not df.empty
    assert "type" in df.columns
    assert "content" in df.columns


def test_text_cleaner():
    assert full_clean("Hello   world") == "Hello world"
    assert merge_hyphenated("Hel-\nlo") == "Hello"
    assert is_table_row("a  b  c") is True
    assert is_table_row("hello world") is False


def test_deskew_identity():
    img = np.zeros((100, 200), dtype=np.uint8)
    img[10:90, 10:190] = 255
    result = deskew(img)
    assert result.shape == img.shape


def test_tesseract_empty():
    img = np.zeros((50, 100, 3), dtype=np.uint8)
    text = ocr_tesseract(img)
    assert isinstance(text, str)
