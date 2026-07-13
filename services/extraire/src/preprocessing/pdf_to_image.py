from pathlib import Path
from pdf2image import convert_from_path
from PIL import Image


def convert_pdf_to_images(pdf_path: str | Path, dpi: int = 300) -> list[Image.Image]:
    return convert_from_path(str(pdf_path), dpi=dpi)
