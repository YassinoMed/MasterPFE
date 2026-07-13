from pathlib import Path
import numpy as np
import pandas as pd
import pdfplumber
from src.text_extraction import extract_text_fallback
from src.preprocessing.pdf_to_image import convert_pdf_to_images
from src.preprocessing.image_enhancement import enhance_image
from src.postprocessing.text_cleaner import full_clean, extract_lines, is_table_row
from src.classification.document_classifier import DocumentClassifier
from src.classification.pipelines import run_pipeline
from src.utils.logger import setup_logger

logger = setup_logger("engine")
classifier = DocumentClassifier()


def _is_scanned(pdf_path: str) -> bool:
    try:
        with pdfplumber.open(pdf_path) as pdf:
            for page in pdf.pages:
                text = page.extract_text() or ""
                if len(text.strip()) > 50:
                    return False
        return True
    except Exception:
        return True


def _extract_full_text(pdf_path: str) -> str:
    try:
        with pdfplumber.open(pdf_path) as pdf:
            return "\n".join(
                (page.extract_text() or "") for page in pdf.pages
            )
    except Exception:
        return ""


def extract_typed_pdf(pdf_path: str) -> list[pd.DataFrame]:
    pages_data = []
    with pdfplumber.open(pdf_path) as pdf:
        for i, page in enumerate(pdf.pages):
            rows = []
            text = page.extract_text() or ""
            if text.strip():
                rows.append({"type": "paragraph", "content": full_clean(text), "page": i})
            tables = page.find_tables()
            for table in tables:
                data = table.extract()
                if data and len(data) >= 2:
                    df = pd.DataFrame(data[1:], columns=data[0])
                    rows.append({"type": "table", "content": df.to_dict(orient="records"), "page": i})
            pages_data.append(pd.DataFrame(rows) if rows else pd.DataFrame())
    return pages_data


def extract_scanned_pdf(pdf_path: str, dpi: int = 300) -> list[pd.DataFrame]:
    images = convert_pdf_to_images(pdf_path, dpi=dpi)
    pages_data = []
    for page_idx, img in enumerate(images):
        img_np = np.array(img.convert("RGB"))
        enhanced = enhance_image(img_np)
        text = extract_text_fallback(enhanced)
        cleaned = full_clean(text)
        lines = extract_lines(cleaned)
        rows = []
        for line in lines:
            rows.append({
                "type": "table_row" if is_table_row(line) else "paragraph",
                "content": line,
            })
        if not rows and cleaned.strip():
            rows.append({"type": "paragraph", "content": cleaned.strip()})
        pages_data.append(pd.DataFrame(rows) if rows else pd.DataFrame())
    return pages_data


def extract_pdf(
    pdf_path: str,
    force_ocr: bool = False,
    dpi: int = 300,
    classify: bool = True,
    use_pipeline: bool = True,
) -> pd.DataFrame:
    pdf_path = str(pdf_path)

    if not force_ocr and not _is_scanned(pdf_path):
        logger.info(f"pdfplumber — {Path(pdf_path).name}")
        raw_pages = extract_typed_pdf(pdf_path)
        full_text = _extract_full_text(pdf_path)
    else:
        logger.info(f"OCR — {Path(pdf_path).name}")
        raw_pages = extract_scanned_pdf(pdf_path, dpi=dpi)
        full_text = "\n".join(
            row.get("content", "")
            for page_df in raw_pages
            for _, row in page_df.iterrows()
        )

    if not raw_pages:
        return pd.DataFrame()

    raw_df = pd.concat(raw_pages, ignore_index=True)

    doc_type = "other"
    if classify and full_text.strip():
        doc_type, confidence = classifier.classify_with_confidence(full_text)
        logger.info(f"Classified as {doc_type} (confidence: {confidence:.2f})")

        if use_pipeline:
            struct_df = run_pipeline(doc_type, full_text)
            struct_df = struct_df.rename(columns={"field": "type", "value": "content"})
            raw_df = pd.concat([raw_df, struct_df], ignore_index=True)

    raw_df.attrs["doc_type"] = doc_type
    return raw_df
