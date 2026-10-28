FROM python:3.12-slim

WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY log_worker ./log_worker
USER nobody
EXPOSE 8080
CMD ["python", "-m", "log_worker"]
