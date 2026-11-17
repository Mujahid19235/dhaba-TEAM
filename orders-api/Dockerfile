# syntax=docker/dockerfile:1
FROM golang:1.22-alpine AS builder

WORKDIR /src
COPY go.mod go.sum ./
RUN go mod download

COPY *.go ./
ARG VERSION=dev
RUN CGO_ENABLED=0 GOOS=linux go build -ldflags="-s -w -X main.Version=${VERSION}" -o /out/orders-api .

FROM alpine:3.20

RUN adduser -D -H -u 10001 appuser
WORKDIR /app
COPY --from=builder /out/orders-api /app/orders-api

USER 10001
EXPOSE 8080

HEALTHCHECK --interval=15s --timeout=3s --start-period=5s --retries=3 \
  CMD ["/app/orders-api", "-healthcheck"]

ENTRYPOINT ["/app/orders-api"]
