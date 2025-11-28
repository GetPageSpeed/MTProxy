FROM python:3.9-slim
WORKDIR /app
COPY requirements.txt .
RUN pip install -r requirements.txt
ENV PYTHONUNBUFFERED=1
COPY test_proxy.py .
CMD ["python", "test_proxy.py"]

