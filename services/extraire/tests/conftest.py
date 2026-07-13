import sys
import os
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

import pytest
from fpdf import FPDF


@pytest.fixture(scope="session")
def sample_pdf(tmp_path_factory):
    tmp = tmp_path_factory.mktemp("pdfs")
    path = tmp / "sample.pdf"

    pdf = FPDF()
    pdf.add_page()
    pdf.set_font("Helvetica", size=16)
    pdf.cell(200, 10, text="BANK STATEMENT", new_x="LMARGIN", new_y="NEXT", align="C")
    pdf.ln(10)
    pdf.set_font("Helvetica", size=10)
    pdf.cell(200, 10, text="Date | Amount | Description", new_x="LMARGIN", new_y="NEXT")
    pdf.cell(200, 10, text="2024-01-01 | 5000 | Salary", new_x="LMARGIN", new_y="NEXT")
    pdf.cell(200, 10, text="2024-01-05 | -200 | Groceries", new_x="LMARGIN", new_y="NEXT")
    pdf.output(str(path))

    return str(path)
