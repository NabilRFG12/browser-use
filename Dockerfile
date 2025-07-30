#
# A simplified, Railway-compatible Dockerfile for browser-use
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

# Copy dependency files
COPY pyproject.toml uv.lock* /app/

# Install Python dependencies using uv
RUN uv sync --all-extras --no-dev

# Install Playwright and Chromium browser
# This is a critical step that also installs necessary system dependencies
RUN playwright install --with-deps chromium

# Copy the rest of the application code
COPY . /app/

# Re-run uv sync to install the browser-use package itself from the copied code
RUN uv sync --all-extras --locked --no-dev

# Change ownership of the app and data directories to the non-root user
RUN chown -R $BROWSERUSE_USER:$BROWSERUSE_USER /app $DATA_DIR

# Switch to the non-root user
USER $BROWSERUSE_USER

# Expose the application port
EXPOSE 3000

# Set the default command to run when the container starts
ENTRYPOINT ["browser-use"]
