FROM debian:12-slim

ENV DEBIAN_FRONTEND=noninteractive \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        bash curl ca-certificates iproute2 iptables iputils-ping net-tools unzip \
        python3 python3-pip python-is-python3 \
        git wget \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# 复制应用
COPY requirements.txt /app/requirements.txt
RUN pip3 install --no-cache-dir -r /app/requirements.txt

COPY app /app/app
COPY ssr_simplified.sh /app/ssr_simplified.sh
RUN chmod +x /app/ssr_simplified.sh

EXPOSE 8080
CMD ["python3", "-m", "app.main"]
