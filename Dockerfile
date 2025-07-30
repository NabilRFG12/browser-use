# syntax=docker/dockerfile:1

FROM python:3.12-slim

LABEL name="browseruse" \
    maintainer="Nick Sweeting <dockerfile@browser-use.com>" \
    description="Make websites accessible for AI agents. Automate tasks online with ease." \
    homepage="https://github.com/browser-use/browser-use" \
    documentation="https://docs.browser-use.com"

ARG TARGETPLATFORM
ARG TARGETOS
ARG TARGETARCH
ARG TARGETVARIANT

ENV TZ=UTC \
    LANGUAGE=en_US:en \
    LC_ALL=C.UTF-8 \
    LANG=C.UTF-8 \
    DEBIAN_FRONTEND=noninteractive \
    APT_KEY_DONT_WARN_ON_DANGEROUS_USAGE=1 \
    PYTHONIOENCODING=UTF-8 \
    PYTHONUNBUFFERED=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    UV_CACHE_DIR=/root/.cache/uv \
    UV_LINK_MODE=copy \
    UV_COMPILE_BYTECODE=1 \
    UV_PYTHON_PREFERENCE=only-system \
    npm_config_loglevel=error \
    IN_DOCKER=True \
    BROWSERUSE_USER="browseruse" \
    DEFAULT_PUID=911 \
    DEFAULT_PGID=911 \
    CODE_DIR=/app \
    DATA_DIR=/data \
    VENV_DIR=/app/.venv \
    PATH="/app/.venv/bin:$PATH"

SHELL ["/bin/bash", "-o", "pipefail", "-o", "errexit", "-o", "errtrace", "-o", "nounset", "-c"] 

RUN echo 'Binary::apt::APT::Keep-Downloaded-Packages "1";' > /etc/apt/apt.conf.d/99keep-cache \
    && echo 'APT::Install-Recommends "0";' > /etc/apt/apt.conf.d/99no-intall-recommends \
    && echo 'APT::Install-Suggests "0";' > /etc/apt/apt.conf.d/99no-intall-suggests \
    && rm -f /etc/apt/apt.conf.d/docker-clean

RUN (echo "[i] Docker build starting..." && uname -a)

RUN echo "[*] Setting up $BROWSERUSE_USER user..." \
    && groupadd --system $BROWSERUSE_USER \
    && useradd --system --create-home --gid $BROWSERUSE_USER --groups audio,video $BROWSERUSE_USER \
    && usermod -u "$DEFAULT_PUID" "$BROWSERUSE_USER" \
    && groupmod -g "$DEFAULT_PGID" "$BROWSERUSE_USER" \
    && mkdir -p /data \
    && mkdir -p /home/$BROWSERUSE_USER/.config \
    && chown -R $BROWSERUSE_USER:$BROWSERUSE_USER /home/$BROWSERUSE_USER \
    && ln -s $DATA_DIR /home/$BROWSERUSE_USER/.config/browseruse

# Install base apt dependencies
RUN --mount=type=cache,target=/var/cache/apt,id=railway-apt-cache \
    echo "[+] Installing APT base system dependencies..." \
    && mkdir -p /etc/apt/keyrings \
    && apt-get update -qq \
    && apt-get install -qq -y --no-install-recommends \
        apt-transport-https ca-certificates apt-utils gnupg2 unzip curl wget grep \
        nano iputils-ping dnsutils jq \
     && rm -rf /var/lib/apt/lists/*

COPY --from=ghcr.io/astral-sh/uv:latest /uv /uvx /bin/

WORKDIR /app
COPY pyproject.toml uv.lock* /app/

# Setup venv
RUN --mount=type=cache,target=/root/.cache,id=railway-venv-cache \
    echo "[+] Setting up venv using uv..." \
    && uv venv

# Install playwright
RUN --mount=type=cache,target=/root/.cache,id=railway-playwright-pip-cache \
     echo "[+] Installing playwright via pip..." \
     && PLAYWRIGHT_VERSION=$(grep -E "playwright>=" pyproject.toml | grep -o "[0-9]\+\.[0-9]\+\.[0-9]\+" | head -1) \
     && PATCHRIGHT_VERSION=$(grep -E "patchright>=" pyproject.toml | grep -o "[0-9]\+\.[0-9]\+\.[0-9]\+" | head -1) \
     && uv pip install playwright==$PLAYWRIGHT_VERSION patchright==$PATCHRIGHT_VERSION

# Install Chromium using playwright
RUN --mount=type=cache,target=/var/cache/apt,id=railway-chromium-apt-cache \
    --mount=type=cache,target=/root/.cache,id=railway-chromium-playwright-cache \
    echo "[+] Installing chromium..." \
    && apt-get update -qq \
    && playwright install --with-deps --no-shell chromium \
    && rm -rf /var/lib/apt/lists/* \
    && export CHROME_BINARY="$(python -c 'from playwright.sync_api import sync_playwright; print(sync_playwright().start().chromium.executable_path)')" \
    && ln -s "$CHROME_BINARY" /usr/bin/chromium-browser

# Install browser-use sub-dependencies
RUN --mount=type=cache,target=/root/.cache,id=railway-subdep-cache \
     echo "[+] Installing browser-use pip sub-dependencies..." \
     && uv sync --all-extras --no-dev --no-install-project

# Copy the rest of the browser-use codebase
COPY . /app

# Install the browser-use package itself
RUN --mount=type=cache,target=/root/.cache,id=railway-main-install-cache \
     echo "[+] Installing browser-use pip library from source..." \
     && uv sync --all-extras --locked --no-dev

RUN mkdir -p "$DATA_DIR/profiles/default" \
    && chown -R $BROWSERUSE_USER:$BROWSERUSE_USER "$DATA_DIR"

USER "$BROWSERUSE_USER"
EXPOSE 9242
EXPOSE 9222

ENTRYPOINT ["browser-use"]
