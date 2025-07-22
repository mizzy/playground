# Multi-stage build for TypeScript application
FROM node:20-alpine AS builder

# Set working directory
WORKDIR /app

# Copy package files first for better layer caching
COPY typescript/package*.json ./

# Install dependencies
RUN npm ci

# Copy TypeScript config and source code
COPY typescript/tsconfig.json ./
COPY typescript/src ./src

# Build the application
RUN npm run build

# Final stage - minimal runtime image
FROM node:20-alpine

# Install ca-certificates for HTTPS requests
RUN apk add --no-cache ca-certificates tzdata

# Set working directory
WORKDIR /app

# Copy package files and install production dependencies only
COPY typescript/package*.json ./
RUN npm ci --only=production

# Copy the built application
COPY --from=builder /app/dist ./dist

# Set environment variables
ENV TZ=UTC

# Switch to non-root user (use existing node user)
USER node

# Expose port (if needed for health checks)
EXPOSE 8080

# Run the application
CMD ["node", "dist/index.js"]