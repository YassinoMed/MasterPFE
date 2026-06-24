FROM python:3.11-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY main.py collector.py scorer.py ./

# Run as non-root user for better security (SOC2 requirement)
RUN useradd -m soc2user
USER soc2user

EXPOSE 8080

CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8080"]
