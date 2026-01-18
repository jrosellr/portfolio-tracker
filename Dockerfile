FROM alpine:3.23.2 AS base

RUN apk upgrade --no-cache

FROM base AS builder

# Install required tools
RUN apk --no-cache add \
    curl \
    ca-certificates

# Install uv
ADD 'https://astral.sh/uv/0.9.26/install.sh' /uv-installer.sh
RUN sh /uv-installer.sh && rm /uv-installer.sh
ENV PATH="/root/.local/bin/:$PATH"

# uv settings
ENV UV_COMPILE_BYTECODE=1
ENV UV_LINK_MODE=copy
ENV UV_NO_DEV=1
ENV UV_TOOL_BIN_DIR=/usr/local/bin
ENV UV_PYTHON_INSTALL_DIR=/python
ENV UV_PYTHON_PREFERENCE=only-managed

WORKDIR /app

# Copy lockfile and settings
COPY pyproject.toml uv.lock .python-version ./

# Install python
RUN --mount=type=cache,target=/root/.cache/uv \
    uv python install

# Install the project's dependencies
RUN --mount=type=cache,target=/root/.cache/uv \
    uv sync --locked --no-install-project --no-editable

# Copy the project
COPY src /app

# Build the project
RUN --mount=type=cache,target=/root/.cache/uv \
    uv sync --locked --no-editable

FROM base AS runtime

# Python settings
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

# Setup a non-root user
RUN addgroup nonroot \
    && adduser --disabled-password --ingroup nonroot --no-create-home nonroot

# Copy the python installation and the project
COPY --from=builder --chown=python:python /python /python
COPY --from=builder --chown=nonroot:nonroot /app/.venv /app/.venv
ENV PATH="/app/.venv/bin:$PATH"

# Use the non-root user to run our application
USER nonroot

WORKDIR /app

ENTRYPOINT ["/app/.venv/bin/main"]
