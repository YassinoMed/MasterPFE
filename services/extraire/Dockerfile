FROM python:3.11-slim

RUN apt-get update && apt-get install -y \
    tesseract-ocr \
    tesseract-ocr-eng \
    tesseract-ocr-fra \
    poppler-utils \
    build-essential \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY services/extraire/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY services/extraire .

CMD ["python", "-m", "src.cli", "--input", "/data", "--output", "/output"]
