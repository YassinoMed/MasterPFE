import re
from pathlib import Path
from typing import Optional

DOCUMENT_TYPES = [
    "bank_statement",
    "invoice",
    "contract",
    "article",
    "form",
    "receipt",
    "letter",
    "other",
]

PATTERNS: dict[str, list[str]] = {
    "bank_statement": [
        r"bank\s+statement", r"account\s+(number|no|summary|statement)",
        r"transaction", r"withdrawal", r"deposit", r"balance",
        r"opening\s+balance", r"closing\s+balance", r"branch",
        r"iban", r"bic", r"sort\s+code", r"bank\s+of",
    ],
    "invoice": [
        r"invoice", r"facture", r"rechnung", r"fattura",
        r"bill\s+to", r"ship\s+to", r"tax\s+id", r"vat",
        r"total\s+due", r"amount\s+due", r"due\s+date",
        r"invoice\s+(number|no|#|date)", r"subtotal", r"tva",
    ],
    "contract": [
        r"contract", r"agreement", r"terms\s+and\s+conditions",
        r"hereby", r"whereas", r"party\s+(a|b|1|2)", r"indemnify",
        r"confidentiality", r"governing\s+law", r"termination",
        r"liability", r"witnesseth", r"executed",
    ],
    "article": [
        r"abstract", r"introduction", r"methodology", r"conclusion",
        r"references", r"doi", r"issn", r"vol(ume)?\s*\.?\s*\d+",
        r"proceedings", r"conference", r"journal",
    ],
    "form": [
        r"form", r"please\s+fill", r"section\s+\d+",
        r"applicant", r"signature", r"date:\s*_{2,}",
        r"checkbox", r"field", r"fill\s+out",
    ],
    "receipt": [
        r"receipt", r"reçu", r"quittan?ce", r"store\s+(name|#)",
        r"total", r"cash", r"change", r"thank\s+you",
        r"item", r"qty", r"price",
    ],
    "letter": [
        r"dear\s+(sir|madam|mr|ms|dr)", r"sincerely",
        r"yours\s+faithfully", r"yours\s+truly",
        r"to\s+whom\s+it\s+may\s+concern", r"re:",
        r"enclosure", r"cc:",
    ],
}

SCORES: dict[str, int] = {
    "bank_statement": 5,
    "invoice": 5,
    "contract": 4,
    "article": 3,
    "form": 3,
    "receipt": 4,
    "letter": 3,
}


class DocumentClassifier:
    def __init__(self, model_path: Optional[Path] = None):
        self.model_path = model_path

    def classify(self, text: str) -> str:
        if not text.strip():
            return "other"

        text_lower = text.lower()
        scores: dict[str, int] = {}

        for doc_type, patterns in PATTERNS.items():
            score = 0
            for pat in patterns:
                matches = re.findall(pat, text_lower)
                score += len(matches) * SCORES.get(doc_type, 1)
            if score > 0:
                scores[doc_type] = score

        if not scores:
            return "other"

        best = max(scores, key=scores.get)
        return best

    def classify_with_confidence(self, text: str) -> tuple[str, float]:
        if not text.strip():
            return "other", 0.0

        text_lower = text.lower()
        scores: dict[str, float] = {}

        for doc_type, patterns in PATTERNS.items():
            score = 0
            for pat in patterns:
                matches = re.findall(pat, text_lower)
                score += len(matches) * SCORES.get(doc_type, 1)
            if score > 0:
                scores[doc_type] = float(score)

        if not scores:
            return "other", 0.0

        total = sum(scores.values())
        best = max(scores, key=scores.get)
        confidence = scores[best] / total if total > 0 else 0.0
        return best, confidence


def classify_pdf_text(text: str) -> str:
    return DocumentClassifier().classify(text)
