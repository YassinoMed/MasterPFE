FROM python:3.12-slim


# Install system dependencies
RUN apt-get update && apt-get upgrade -y && apt-get install -y --no-install-recommends \
    curl \
    git \
    make \
    build-essential \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copy requirements and install
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy source code
COPY app.py .

# Create models directory for caching or config
RUN mkdir -p /app/models && chown -m 755 /app/models

# Expose port
EXPOSE 8000

# Set environment variables
ENV MOCK_INFERENCE=true
ENV PYTHONUNBUFFERED=1

# Expose non-root user for security standards
USER 65534:65534

# Health check
HEALTHCHECK --interval=30s --timeout=10s --retries=3 \
  CMD curl -fsS http://localhost:8000/health || exit 1

# Start the application
CMD ["uvicorn", "app:app", "--host", "0.0.0.0", "--port", "8000"]
