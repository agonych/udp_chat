# Multi-stage build for React client
FROM node:18-alpine AS builder

# Set working directory
WORKDIR /app

# Copy package files
COPY package*.json ./

# Install dependencies
RUN npm ci

# Copy source code
COPY . .

# Accept build arguments for environment variables
ARG VITE_WS_HOST
ARG VITE_WS_PORT
ARG VITE_WS_PATH
ARG VITE_WS_URL

# Set environment variables for build
ENV VITE_WS_HOST=$VITE_WS_HOST
ENV VITE_WS_PORT=$VITE_WS_PORT
ENV VITE_WS_PATH=$VITE_WS_PATH
ENV VITE_WS_URL=$VITE_WS_URL

# Build the application
RUN npm run build

# Production stage
FROM nginx:alpine

# Copy built assets from builder stage
COPY --from=builder /app/dist /usr/share/nginx/html

# Copy custom nginx configuration
COPY nginx-main.conf /etc/nginx/nginx.conf

# Create non-root user (nginx group already exists in nginx:alpine)
RUN adduser -S client -u 1001 -G nginx

# Change ownership
RUN chown -R client:nginx /usr/share/nginx/html && \
    chown -R client:nginx /var/cache/nginx && \
    chown -R client:nginx /var/log/nginx && \
    chown -R client:nginx /etc/nginx/conf.d

# Create nginx pid directory and fix permissions
RUN mkdir -p /var/run/nginx /run && \
    chown -R client:nginx /var/run/nginx /run && \
    chmod 755 /run

USER client

# Expose port
EXPOSE 80

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD wget --no-verbose --tries=1 --spider http://localhost/ || exit 1

# Start nginx
CMD ["nginx", "-g", "daemon off;"]
