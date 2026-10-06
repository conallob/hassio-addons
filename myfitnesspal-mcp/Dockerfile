ARG BUILD_FROM
ARG MYFITNESSPAL_MCP_VERSION=v1.3.0

# Stage 1: Install myfitnesspal-mcp and its dependencies into a venv. Upstream
# publishes a container image built on python:3.13-slim, which can't be used
# as the add-on base, and it's a Python package rather than a single binary,
# so instead it's pip-installed from its release tag here. This stage uses the
# same HA base as the final stage, so the venv's interpreter path
# (/usr/bin/python3, Debian bookworm's Python 3.11 — upstream requires >=3.11)
# is identical in both and the venv can be copied across as-is.
FROM ${BUILD_FROM} AS builder

ARG MYFITNESSPAL_MCP_VERSION

RUN apt-get update \
    && apt-get install -y --no-install-recommends git python3 python3-venv \
    && rm -rf /var/lib/apt/lists/*

RUN python3 -m venv /opt/myfitnesspal-mcp/venv \
    && /opt/myfitnesspal-mcp/venv/bin/pip install --no-cache-dir --upgrade pip \
    && /opt/myfitnesspal-mcp/venv/bin/pip install --no-cache-dir \
        "git+https://github.com/delize/myfitness-mcp.git@${MYFITNESSPAL_MCP_VERSION}"

# Stage 2: Build the add-on image on the HA Debian base (includes s6-overlay)
FROM ${BUILD_FROM}

# Labels
LABEL \
    io.hass.name="MyFitnessPal MCP" \
    io.hass.description="Model Context Protocol server for MyFitnessPal" \
    io.hass.type="addon" \
    io.hass.version="${BUILD_VERSION}" \
    maintainer="Conall O'Brien <conall@conall.net>"

# Only the Python runtime is needed here; the venv brings everything else.
RUN apt-get update \
    && apt-get install -y --no-install-recommends python3 \
    && rm -rf /var/lib/apt/lists/*

COPY --from=builder /opt/myfitnesspal-mcp/venv /opt/myfitnesspal-mcp/venv

# Copy add-on rootfs (s6 services)
COPY rootfs /

# Set script permissions
RUN chmod a+x /etc/s6-overlay/s6-rc.d/*/run

EXPOSE 8000
