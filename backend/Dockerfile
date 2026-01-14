FROM golang:1.24-alpine AS builder

WORKDIR /src

RUN apk add --no-cache ca-certificates git

COPY go.mod go.sum ./
RUN go mod download

COPY . .

RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 \
    go build -trimpath -ldflags="-s -w" -o /out/app .

FROM gcr.io/distroless/static:nonroot

WORKDIR /
ENV COSMOS_URL=${COSMOS_URL}
ENV REDIS_URL={REDIS_URL}

COPY --from=builder /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/
COPY --from=builder /out/app /app

EXPOSE 80
USER nonroot:nonroot
ENTRYPOINT ["/app"]
