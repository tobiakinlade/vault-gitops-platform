# Multi-stage build for security and minimal image size
FROM golang:1.21-alpine AS builder
# Install security updates and CA certificates
RUN apk update && \
    apk upgrade && \
    apk add --no-cache ca-certificates git tzdata && \
    update-ca-certificates
# Set working directory
WORKDIR /build
# Copy go mod files first (for caching)
COPY go.mod go.sum ./
RUN go mod download && go mod verify
# Copy source code
COPY . .
# Build with security flags
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 \
    go build -a -installsuffix cgo \
    -ldflags="-w -s -X main.version=$(git describe --tags --always --dirty 2>/dev/null || echo 'dev')" \
    -o backend .
# Run tests during build
RUN go test -v ./...
# Final stage - use scratch for minimal attack surface
FROM scratch
# Copy CA certificates from builder
COPY --from=builder /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/
COPY --from=builder /usr/share/zoneinfo /usr/share/zoneinfo
# Copy binary
COPY --from=builder /build/backend /backend
# Use non-root user
USER 65534:65534
# Expose port
EXPOSE 8080
# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD ["/backend", "health"] || exit 1
# Run application
ENTRYPOINT ["/backend"]
