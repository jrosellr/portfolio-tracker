FROM alpine:3.23.2 AS base

RUN apk upgrade --no-cache

FROM base AS builder

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

WORKDIR /build

# Install python
RUN --mount=type=cache,target=/root/.cache/uv \
    --mount=type=bind,source=uv.lock,target=uv.lock \
    --mount=type=bind,source=pyproject.toml,target=pyproject.toml \
    --mount=type=bind,source=.python-version,target=.python-version \
    uv python install

# Install the project's dependencies
RUN --mount=type=cache,target=/root/.cache/uv \
    --mount=type=bind,source=uv.lock,target=uv.lock \
    --mount=type=bind,source=pyproject.toml,target=pyproject.toml \
    --mount=type=bind,source=.python-version,target=.python-version \
    uv sync --locked --no-install-project --no-editable

# Copy the project
COPY . .

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
COPY --from=builder /python /python
COPY --from=builder --chown=nonroot:nonroot /build/.venv /portfolio-tracker/.venv
ENV PATH="/portfolio-tracker/.venv/bin:$PATH"

# Use the non-root user to run our application
USER nonroot

WORKDIR /portfolio-tracker

ENTRYPOINT ["python", "/portfolio-tracker/.venv/bin/pt"]
