FROM python:3.12-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY app.py .

# Ensure /log exists so the PVC mount point is available from first boot
RUN mkdir -p /log

EXPOSE 8080

CMD ["python", "app.py"]
