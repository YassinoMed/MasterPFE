import re


def clean_text(text: str) -> str:
    text = re.sub(r"\s+", " ", text)
    text = re.sub(r"[^\w\s.,:;!?()\-/\d%€$£@#+=*]", "", text)
    return text.strip()


def normalize_whitespace(text: str) -> str:
    return re.sub(r"\s+", " ", text).strip()


def extract_lines(text: str) -> list[str]:
    return [normalize_whitespace(l) for l in text.split("\n") if l.strip()]


def merge_hyphenated(text: str) -> str:
    return re.sub(r"(\w)-\s*\n\s*(\w)", r"\1\2", text)


def fix_sentence_spacing(text: str) -> str:
    return re.sub(r"(?<=[.!?])(?=[A-Z])", " ", text)


def is_table_row(line: str) -> bool:
    return bool(re.search(r"\s{2,}", line)) or line.count("|") >= 2


def extract_table_lines(lines: list[str]) -> list[list[str]]:
    tables, current = [], []
    for line in lines:
        if is_table_row(line):
            cols = re.split(r"\s{2,}|\|", line)
            current.append([c.strip() for c in cols if c.strip()])
        else:
            if len(current) >= 2:
                tables.append(current)
            current = []
    if len(current) >= 2:
        tables.append(current)
    return tables


def full_clean(text: str) -> str:
    text = merge_hyphenated(text)
    text = normalize_whitespace(text)
    text = clean_text(text)
    text = fix_sentence_spacing(text)
    return text
