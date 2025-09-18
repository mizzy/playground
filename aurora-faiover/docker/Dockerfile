FROM node:22.19.0-bookworm-slim

# Install TypeScript globally and ts-node for direct execution
RUN npm install -g typescript ts-node

# Set working directory
WORKDIR /app

# Copy source code
COPY . .

# Install dependencies if package.json exists, otherwise create minimal one
RUN if [ -f package.json ]; then \
        echo "Found package.json, installing dependencies..."; \
        if [ -f package-lock.json ]; then \
            npm ci --omit=dev; \
        else \
            npm install --only=production; \
        fi; \
    else \
        echo "No package.json found, creating minimal one..."; \
        echo '{"name":"aurora-failover-app","version":"1.0.0","main":"index.ts","scripts":{"start":"ts-node index.ts"},"dependencies":{}}' > package.json; \
    fi

# Default command
CMD ["ts-node", "index.ts"]
