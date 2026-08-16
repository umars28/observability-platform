# syntax=docker/dockerfile:1.7
FROM golang:1.24-alpine AS builder
WORKDIR /src
COPY go.mod go.sum* ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -trimpath -ldflags="-s -w" -o /out/demo-shop-api ./cmd

FROM gcr.io/distroless/static-debian12:nonroot
COPY --from=builder /out/demo-shop-api /demo-shop-api
EXPOSE 8080 6060
USER nonroot:nonroot
ENTRYPOINT ["/demo-shop-api"]
