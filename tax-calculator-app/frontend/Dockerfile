# Multi-stage build for security and minimal image size
FROM node:18-alpine AS builder
# Install security updates
RUN apk update && \
    apk upgrade && \
    apk add --no-cache ca-certificates && \
    update-ca-certificates
WORKDIR /build
# Copy package files first (for caching)
COPY package*.json ./
RUN npm ci --only=production && \
    npm cache clean --force
# Copy source code
COPY . .
# Build application
RUN npm run build
# Run tests during build
RUN npm test -- --watchAll=false --coverage
# Production stage - minimal nginx
FROM nginx:1.25-alpine
# Install security updates
RUN apk update && \
    apk upgrade && \
    apk add --no-cache ca-certificates && \
    rm -rf /var/cache/apk/*
# Remove default nginx content
RUN rm -rf /usr/share/nginx/html/*
# Copy built application
COPY --from=builder /build/build /usr/share/nginx/html
# Copy nginx configuration
COPY nginx.conf /etc/nginx/nginx.conf
# Use non-root user
RUN chown -R nginx:nginx /usr/share/nginx/html && \
    chown -R nginx:nginx /var/cache/nginx && \
    chown -R nginx:nginx /var/log/nginx && \
    chown -R nginx:nginx /etc/nginx/conf.d && \
    touch /var/run/nginx.pid && \
    chown -R nginx:nginx /var/run/nginx.pid
USER nginx
# Expose port
EXPOSE 8080
# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD wget --quiet --tries=1 --spider http://localhost:8080/ || exit 1
# Start nginx
CMD ["nginx", "-g", "daemon off;"]
