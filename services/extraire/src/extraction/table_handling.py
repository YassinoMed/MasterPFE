import pdfplumber
import pandas as pd


def extract_tables_from_pdf(pdf_path: str) -> list[pd.DataFrame]:
    tables = []
    with pdfplumber.open(pdf_path) as pdf:
        for page in pdf.pages:
            for table in page.find_tables():
                data = table.extract()
                if not data or len(data) < 2:
                    continue
                df = pd.DataFrame(data[1:], columns=data[0])
                tables.append(df)
    return tables


def pdfplumber_table_to_dataframe(table) -> pd.DataFrame:
    data = table.extract()
    if not data:
        return pd.DataFrame()
    return pd.DataFrame(data[1:], columns=data[0])
