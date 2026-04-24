FROM python:3.11-slim

WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    git \
    && rm -rf /var/lib/apt/lists/*

# Copy project
COPY . .

# Install core + streamlit UI deps
RUN pip install --no-cache-dir -e ".[ui]" && \
    pip install --no-cache-dir gunicorn

# Default: streamlit on 8501
EXPOSE 8501

CMD ["streamlit", "run", "frontends/stapp.py", \
     "--server.port", "8501", \
     "--server.address", "0.0.0.0", \
     "--server.headless", "true", \
     "--server.enableCORS", "false", \
     "--server.enableXsrfProtection", "false"]
