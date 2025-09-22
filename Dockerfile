# Multi-stage build for Swift application
FROM swift:6.1-noble AS builder

# Set working directory
WORKDIR /app

# Copy Package files
COPY Package.swift Package.resolved ./

# Copy source code
COPY Sources ./Sources
COPY Tests ./Tests

# Build the application
RUN swift build -c release --static-swift-stdlib

# Runtime image
FROM ubuntu:24.04

# Install runtime dependencies
RUN apt-get update && apt-get install -y \
    libsqlite3-0 \
    ca-certificates \
    tzdata \
    unzip \
    curl \
    file \
    xxd \
    binutils \
    && rm -rf /var/lib/apt/lists/* \
    && curl -L https://github.com/steventroughtonsmith/cartool/releases/download/1.0.0/cartool -o /usr/local/bin/cartool \
    && chmod +x /usr/local/bin/cartool

# Create app user
RUN useradd --user-group --create-home --system --skel /dev/null --home-dir /app app

# Set working directory
WORKDIR /app

# Copy built application
COPY --from=builder /app/.build/release/ipascanner ./
COPY --from=builder /app/.build/release/ipascanner-web ./

# Copy static files
COPY Public ./Public
COPY Views ./Views
COPY Resources ./Resources

# Create necessary directories
RUN mkdir -p temp uploads logs \
    && chown -R app:app /app

# Switch to app user
USER app

# Expose port
EXPOSE 8080

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:8080/health || exit 1

# Default command
CMD ["./ipascanner-web", "serve", "--hostname", "0.0.0.0", "--port", "8080"]