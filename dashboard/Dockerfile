FROM python:3.11-slim

WORKDIR /app

COPY app/requirements.txt /app/requirements.txt
RUN pip install --no-cache-dir -r requirements.txt

COPY app /app
COPY static /app/static
COPY templates /app/templates

EXPOSE 8080

CMD ["python", "app.py"]
