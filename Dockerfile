#
# Final Railway-compatible Dockerfile for browser-use
#
# syntax=docker/dockerfile:1

FROM python:3.12-slim

# Set environment variables
ENV TZ=UTC \
    LANGUAGE=en_US:en \
    LC_ALL=C.UTF-8 \
    LANG=C.UTF-8 \
    DEBIAN_FRONTEND=noninteractive \
    PYTHONUNBUFFERED=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    BROWSERUSE_USER="browseruse" \
    DATA_DIR=/data \
    PATH="/app/.venv/bin:$PATH"

# Install essential system packages
RUN apt-get update -qq && apt-get install -qq -y --no-install-recommends \
    curl \
    wget \
    gnupg2 \
    unzip \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Create the non-privileged user
RUN groupadd --system $BROWSERUSE_USER \
    && useradd --system --create-home --gid $BROWSERUSE_USER --groups audio,video $BROWSERUSE_USER \
    && mkdir -p $DATA_DIR \
    && chown -R $BROWSERUSE_USER:$BROWSERUSE_USER /home/$BROWSERUSE_USER $DATA_DIR

# Install uv (the python package manager)
COPY --from=ghcr.io/astral-sh/uv:latest /uv /usr/local/bin/

# Set the working directory
WORKDIR /app

# Copy ALL application code BEFORE installing dependencies
COPY . /app/

# Install Python dependencies AND the browser-use package itself
RUN uv sync --all-extras --no-dev

# Install Playwright and Chromium browser (and its system dependencies)
RUN playwright install --with-deps chromium

# Change ownership of the app and data directories to the non-root user
RUN chown -R $BROWSERUSE_USER:$BROWSERUSE_USER /app $DATA_DIR

# Switch to the non-root user
USER $BROWSERUSE_USER

# Expose the application port
EXPOSE 3000

# ---- THE FIX: Run the application in server mode ----
ENTRYPOINT ["browser-use", "--mcp"]```

### What to Do Now

1.  **Update the `Dockerfile`** on your GitHub repository with the complete code block above.
2.  **Commit the change.** Railway will automatically start a new deployment.
3.  **Watch the new logs.** This time, you should not see the `Enter your task...` loop. The logs will likely show some startup messages and then go quiet, which is a sign that the server is successfully running and waiting for connections.
4.  Once the deployment is `ACTIVE`, **run your local command again**:

    ```bash
    websocat "wss://browser-use-production-ccc0.up.railway.app?token=bu_-WzxJx_LfbRyiLLVND2-sVb14r2GHS--SE4eMOLxxos" | browser-use --mcp -p "go to wikipedia.org and tell me the main headline"
    ```

This aligns the server's startup command with its role as a backend service. The 502 error will be resolved, and your connection will finally succeed.
