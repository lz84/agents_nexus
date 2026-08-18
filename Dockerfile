# ============================================================
# Grever Production Dockerfile
# Multi-stage: frontend build → Python runtime
# ============================================================

# ---------- Stage 1: Build Frontend ----------
FROM node:20-slim AS frontend-builder

WORKDIR /app/packages/ui
COPY packages/ui/package*.json ./
RUN npm ci
COPY packages/ui/ .
RUN npm run build

# ---------- Stage 2: Python Runtime ----------
FROM python:3.11-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    GREVER_ENV=production

WORKDIR /app

# System deps
RUN apt-get update && \
    apt-get install -y --no-install-recommends curl && \
    rm -rf /var/lib/apt/lists/*

# Python deps
COPY config/requirements.txt /tmp/requirements.txt
RUN pip install --upgrade pip && \
    pip install --no-cache-dir -r /tmp/requirements.txt && \
    rm /tmp/requirements.txt

# Application code
COPY packages/server/src packages/server/src
COPY config/ config/
COPY migrations/ migrations/

# Frontend build artifacts
COPY --from=frontend-builder /app/packages/ui/dist packages/ui/dist

# Data & logs dirs
RUN mkdir -p /app/data /app/logs

EXPOSE 8097

HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
    CMD curl -f http://localhost:8097/health || exit 1

CMD ["python", "-m", "uvicorn", "packages.server.src.reins.api.server:app", "--host", "0.0.0.0", "--port", "8097"]
