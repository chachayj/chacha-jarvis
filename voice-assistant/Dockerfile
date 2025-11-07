FROM python:3.11-slim

RUN apt-get update && apt-get install -y --no-install-recommends     ffmpeg curl ca-certificates git  && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

RUN mkdir -p /app/models
COPY download_models.py /app/download_models.py
RUN python /app/download_models.py

COPY app.py .
COPY static ./static
RUN mkdir -p /app/data/tts

EXPOSE 8080
CMD ["uvicorn", "app:app", "--host", "0.0.0.0", "--port", "8080"]
