import re
import pandas as pd
from typing import Any


def extract_bank_statement(text: str) -> list[dict[str, Any]]:
    rows = []
    rows.append({"field": "document_type", "value": "bank_statement"})

    account = re.search(r"account\s+(?:number|no|#)[:\s]*([\w\d]+)", text, re.I)
    if account:
        rows.append({"field": "account_number", "value": account.group(1)})

    balance = re.search(r"(?:opening|closing|current)\s+balance[:\s]*([\d\s,.]+)", text, re.I)
    if balance:
        rows.append({"field": "balance", "value": balance.group(1).strip()})

    period = re.search(r"(?:period|statement\s+period|from\s+)\s*([\d/.-]+)\s*(?:to|–|-)\s*([\d/.-]+)", text, re.I)
    if period:
        rows.append({"field": "period_from", "value": period.group(1)})
        rows.append({"field": "period_to", "value": period.group(2)})

    for line in text.split("\n"):
        line = line.strip()
        match = re.match(
            r"(\d{2,4}[/-]\d{1,2}[/-]\d{1,4})\s+([\d\s,.]+)\s+([\d\s,.-]+)\s*(.*)",
            line,
        )
        if match:
            rows.append({
                "field": "transaction",
                "date": match.group(1),
                "amount": match.group(3).strip(),
                "description": match.group(4).strip(),
            })

    return rows


def extract_invoice(text: str) -> list[dict[str, Any]]:
    rows = []
    rows.append({"field": "document_type", "value": "invoice"})

    inv_num = re.search(r"(?:invoice|facture)\s*(?:number|no|#)[:\s]*([\w\d-]+)", text, re.I)
    if inv_num:
        rows.append({"field": "invoice_number", "value": inv_num.group(1)})

    date = re.search(r"(?:invoice|date)\s*date[:\s]*([\d{2,4}[/-]\d{1,2}[/-]\d{1,4})", text, re.I)
    if date:
        rows.append({"field": "date", "value": date.group(1)})

    due = re.search(r"due\s*date[:\s]*([\d{2,4}[/-]\d{1,2}[/-]\d{1,4})", text, re.I)
    if due:
        rows.append({"field": "due_date", "value": due.group(1)})

    total = re.search(r"(?:total|amount\s+due)[:\s]*([\d\s,.]+)", text, re.I)
    if total:
        rows.append({"field": "total", "value": total.group(1).strip()})

    vat = re.search(r"(?:vat|tva|tax)[:\s]*([\d\s,.]+%?)", text, re.I)
    if vat:
        rows.append({"field": "vat", "value": vat.group(1).strip()})

    return rows


def extract_contract(text: str) -> list[dict[str, Any]]:
    rows = []
    rows.append({"field": "document_type", "value": "contract"})

    parties = re.findall(r"(?:between|party\s*a|party\s*b|hereinafter)[:\s]*([\w\s]+?)(?=and|hereinafter|\d)", text, re.I)
    for i, p in enumerate(parties[:2]):
        rows.append({"field": f"party_{i+1}", "value": p.strip()})

    date = re.search(r"(?:dated|date|executed)[:\s]*(\d{1,2}[/-]\d{1,2}[/-]\d{2,4})", text, re.I)
    if date:
        rows.append({"field": "date", "value": date.group(1)})

    return rows


def extract_article(text: str) -> list[dict[str, Any]]:
    rows = []
    rows.append({"field": "document_type", "value": "article"})

    title_match = re.search(r"^(?:#\s*)?(.{10,100})$", text[:200], re.M)
    if title_match:
        rows.append({"field": "title", "value": title_match.group(1).strip()})

    abstract = re.search(r"(?:abstract|summary)[:\s]*([\w\s]{20,500}?)(?=introduction|\n\n)", text, re.I | re.S)
    if abstract:
        rows.append({"field": "abstract", "value": abstract.group(1).strip()})

    return rows


def extract_form(text: str) -> list[dict[str, Any]]:
    rows = []
    rows.append({"field": "document_type", "value": "form"})
    fields = re.findall(r"^([\w\s]{2,50}?)[:\s]*_+\s*$", text, re.M)
    for f in fields:
        rows.append({"field": "field", "value": f.strip()})
    return rows


def extract_receipt(text: str) -> list[dict[str, Any]]:
    rows = []
    rows.append({"field": "document_type", "value": "receipt"})

    total = re.search(r"(?:total|amount)[:\s]*([\d\s,.]+)", text, re.I)
    if total:
        rows.append({"field": "total", "value": total.group(1).strip()})

    store = re.search(r"^(.[\w\s]+)$", text[:100], re.M)
    if store:
        rows.append({"field": "store", "value": store.group(1).strip()})

    return rows


def extract_letter(text: str) -> list[dict[str, Any]]:
    rows = []
    rows.append({"field": "document_type", "value": "letter"})

    recipient = re.search(r"(?:dear|to)[:\s]*([\w\s]+)[,]", text, re.I)
    if recipient:
        rows.append({"field": "recipient", "value": recipient.group(1).strip()})

    sender = re.search(r"(?:sincerely|yours\s+(faithfully|truly))[,]?\s*\n+([\w\s]+)", text, re.I)
    if sender:
        rows.append({"field": "sender", "value": sender.group(2).strip()})

    return rows


def extract_other(text: str) -> list[dict[str, Any]]:
    return [{"field": "document_type", "value": "other"}]


PIPELINES = {
    "bank_statement": extract_bank_statement,
    "invoice": extract_invoice,
    "contract": extract_contract,
    "article": extract_article,
    "form": extract_form,
    "receipt": extract_receipt,
    "letter": extract_letter,
    "other": extract_other,
}


def run_pipeline(doc_type: str, text: str) -> pd.DataFrame:
    extractor = PIPELINES.get(doc_type, extract_other)
    data = extractor(text)
    return pd.DataFrame(data)
