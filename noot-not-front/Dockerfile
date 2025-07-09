# Build stage
FROM node:18-alpine as build

# Set working directory
WORKDIR /app

# Install curl for health checks
RUN apk add --no-cache curl

# Accept build argument for API URL
ARG VITE_API_BASE_URL
ENV VITE_API_BASE_URL=$VITE_API_BASE_URL

# Copy package files first for better caching
COPY package*.json ./

# Install all dependencies (including dev dependencies needed for build)
RUN npm ci --frozen-lockfile

# Copy source code
COPY . .

# Build the app with error handling
RUN npm run build

# Verify build output exists
RUN ls -la dist/

# Production stage
FROM nginx:alpine

# Install curl for health checks
RUN apk add --no-cache curl

# Copy built files from build stage
COPY --from=build /app/dist /usr/share/nginx/html

# Copy nginx configuration
COPY nginx.conf /etc/nginx/nginx.conf

# Create a simple health check script
RUN echo '#!/bin/sh' > /healthcheck.sh && \
    echo 'curl -f http://localhost/ || exit 1' >> /healthcheck.sh && \
    chmod +x /healthcheck.sh

# Expose port 80
EXPOSE 80

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD /healthcheck.sh

# Start nginx
CMD ["nginx", "-g", "daemon off;"]

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD /healthcheck.sh

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
