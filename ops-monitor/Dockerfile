# syntax=docker/dockerfile:1
FROM alpine:3.20

RUN apk add --no-cache bash curl jq \
    && curl -sLO "https://dl.k8s.io/release/$(curl -sL https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl" \
    && install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl \
    && rm -f kubectl \
    && adduser -D -H -u 10001 monitor

WORKDIR /opt/monitor
COPY scripts/monitor/ /opt/monitor/

USER 10001
ENTRYPOINT ["/opt/monitor/run-all.sh"]
