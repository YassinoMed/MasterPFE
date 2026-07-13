import pytest
from src.preprocessing.pdf_to_image import convert_pdf_to_images


def test_pdf_conversion(sample_pdf):
    images = convert_pdf_to_images(sample_pdf, dpi=150)
    assert len(images) > 0
    assert images[0].size[0] > 0
    assert images[0].size[1] > 0
