"""Chargeurs de documents pour PDF, TXT, DOCX, Markdown."""
from __future__ import annotations

import os
from datetime import datetime, timezone
from pathlib import Path
from typing import Tuple

import structlog
from docx import Document as DocxDocument
from pypdf import PdfReader

logger = structlog.get_logger(__name__)


class UnsupportedFileTypeError(Exception):
    """Levée pour un format de fichier non géré."""


class DocumentReadError(Exception):
    """Levée quand le fichier ne peut pas être lu."""


SUPPORTED_EXTENSIONS = {".pdf", ".txt", ".md", ".markdown", ".docx"}


def _read_pdf(path: Path) -> str:
    try:
        reader = PdfReader(str(path))
    except Exception as exc:
        raise DocumentReadError(f"Failed to open PDF {path}: {exc}") from exc
    pages = []
    for i, page in enumerate(reader.pages):
        try:
            pages.append(page.extract_text() or "")
        except Exception as exc:
            logger.warning("pdf_page_read_failed", page=i, error=str(exc))
    return "\n\n".join(pages)


def _read_docx(path: Path) -> str:
    try:
        doc = DocxDocument(str(path))
    except Exception as exc:
        raise DocumentReadError(f"Failed to open DOCX {path}: {exc}") from exc
    return "\n".join(p.text for p in doc.paragraphs if p.text)


def _read_text(path: Path) -> str:
    try:
        return path.read_text(encoding="utf-8", errors="ignore")
    except Exception as exc:
        raise DocumentReadError(f"Failed to read text file {path}: {exc}") from exc


def load_document(file_path: str) -> Tuple[str, dict]:
    """Charge un document et renvoie (texte, métadonnées de base).

    Métadonnées : name, extension, size_bytes, modified_at, loaded_at.
    Lève UnsupportedFileTypeError / DocumentReadError / FileNotFoundError.
    """
    path = Path(file_path)
    if not path.exists():
        raise FileNotFoundError(f"Document not found: {file_path}")
    if not path.is_file():
        raise DocumentReadError(f"Not a regular file: {file_path}")

    ext = path.suffix.lower()
    if ext not in SUPPORTED_EXTENSIONS:
        raise UnsupportedFileTypeError(
            f"Unsupported extension '{ext}'. Supported: {sorted(SUPPORTED_EXTENSIONS)}"
        )

    logger.info("loading_document", path=str(path), ext=ext)

    if ext == ".pdf":
        text = _read_pdf(path)
    elif ext == ".docx":
        text = _read_docx(path)
    else:
        text = _read_text(path)

    if not text.strip():
        raise DocumentReadError(f"Document {file_path} is empty after extraction")

    stat = path.stat()
    metadata = {
        "name": path.name,
        "extension": ext,
        "size_bytes": stat.st_size,
        "modified_at": datetime.fromtimestamp(stat.st_mtime, tz=timezone.utc).isoformat(),
        "loaded_at": datetime.now(timezone.utc).isoformat(),
        "absolute_path": os.path.abspath(str(path)),
    }
    logger.info("document_loaded", name=path.name, chars=len(text))
    return text, metadata
