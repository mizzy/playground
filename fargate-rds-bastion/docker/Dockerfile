FROM postgres:15

RUN apt-get update && apt-get install -y --no-install-recommends \
    procps \
    && rm -rf /var/lib/apt/lists/*

COPY idle-timeout.sh /usr/local/bin/idle-timeout.sh
RUN chmod +x /usr/local/bin/idle-timeout.sh

CMD ["/usr/local/bin/idle-timeout.sh"]
