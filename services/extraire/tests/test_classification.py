from src.classification.document_classifier import DocumentClassifier, classify_pdf_text
from src.classification.pipelines import run_pipeline, extract_bank_statement, extract_invoice

classifier = DocumentClassifier()


def test_classify_bank_statement():
    text = "BANK STATEMENT\nAccount Number: 12345678\nOpening Balance: 5000\nTransactions:\nDeposit 1000"
    assert classifier.classify(text) == "bank_statement"


def test_classify_invoice():
    text = "INVOICE\nInvoice Number: INV-2024-001\nDate: 2024-01-15\nTotal Due: 1500.00"
    assert classifier.classify(text) == "invoice"


def test_classify_contract():
    text = "CONTRACT\nThis agreement is made between Party A and Party B\nGoverning law"
    assert classifier.classify(text) == "contract"


def test_classify_article():
    text = "Abstract\nThis paper presents a novel method\nIntroduction\nMethodology\nConclusion\nReferences"
    assert classifier.classify(text) == "article"


def test_classify_receipt():
    text = "RECEIPT\nStore: Supermarket\nItem1 10.00\nItem2 5.00\nTotal: 15.00\nThank you"
    assert classifier.classify(text) == "receipt"


def test_classify_letter():
    text = "Dear Sir,\nI am writing to apply for the position\nSincerely,\nJohn Doe"
    assert classifier.classify(text) == "letter"


def test_classify_form():
    text = "APPLICATION FORM\nSection 1: Personal Information\nName: ______________\nSignature: ______________"
    assert classifier.classify(text) == "form"


def test_classify_other():
    assert classifier.classify("") == "other"
    assert classifier.classify("abc123 random text with no patterns") == "other"


def test_classify_with_confidence():
    doc_type, conf = classifier.classify_with_confidence("BANK STATEMENT\nAccount: 12345\nTransaction: 500")
    assert doc_type == "bank_statement"
    assert conf > 0.0


def test_bank_pipeline():
    text = "BANK STATEMENT\nAccount Number: 12345678\nPeriod: 01/01/2024 to 31/01/2024\nOpening Balance: 5000\n2024-01-05 500 Deposit\n2024-01-10 -200 Withdrawal"
    df = run_pipeline("bank_statement", text)
    assert not df.empty
    assert "field" in df.columns
    assert "value" in df.columns


def test_invoice_pipeline():
    text = "INVOICE\nInvoice Number: INV-001\nInvoice Date: 15/01/2024\nDue Date: 15/02/2024\nTotal: 1500.00\nVAT: 20%"
    df = run_pipeline("invoice", text)
    assert not df.empty
    fields = df["field"].tolist()
    assert "invoice_number" in fields
    assert "total" in fields
