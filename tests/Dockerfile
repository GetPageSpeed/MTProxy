FROM python:3.11-slim
WORKDIR /app
COPY requirements.txt .
RUN pip install -r requirements.txt
ENV PYTHONUNBUFFERED=1
COPY test_proxy.py test_tls_e2e.py test_multi_secret_tls.py test_ip_acl.py test_direct_e2e.py test_secret_limit.py test_drs_delays_e2e.py ./
CMD ["python", "test_proxy.py"]

