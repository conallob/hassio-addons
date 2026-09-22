ARG BUILD_FROM
ARG OMNIFOCUS_SYNC_MCP_REF=main

# Stage 1: Build omnifocus-sync-mcp from source (TypeScript -> dist/, prod-only
# node_modules). Upstream ships no Dockerfile and no tagged releases, so this
# clones the source and builds it with npm rather than copying a binary.
FROM node:20-bookworm-slim AS builder

ARG OMNIFOCUS_SYNC_MCP_REF

RUN apt-get update \
    && apt-get install -y --no-install-recommends git ca-certificates \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /build
RUN git clone https://github.com/rosskukulinski/omnifocus-sync-mcp.git . \
    && git checkout "${OMNIFOCUS_SYNC_MCP_REF}"

RUN npm ci \
    && npm run build \
    && npm prune --omit=dev

# Stage 2: Build the add-on image on the HA Debian base (includes s6-overlay)
FROM ${BUILD_FROM}

# Labels
LABEL \
    io.hass.name="OmniFocus Sync MCP" \
    io.hass.description="HTTP interface to an OmniFocus MCP server, synced via Omni Sync Server" \
    io.hass.type="addon" \
    io.hass.version="${BUILD_VERSION}" \
    maintainer="Conall O'Brien <conall@conall.net>"

# omnifocus-sync-mcp only speaks MCP over stdio, so `supergateway` bridges it
# to streamable HTTP for ingress / network clients. Node.js isn't in the HA
# base image, so install the NodeSource 20.x runtime alongside it.
RUN apt-get update \
    && apt-get install -y --no-install-recommends curl ca-certificates gnupg \
    && curl -fsSL https://deb.nodesource.com/setup_20.x | bash - \
    && apt-get install -y --no-install-recommends nodejs \
    && npm install -g supergateway@latest \
    && apt-get purge -y --auto-remove curl gnupg \
    && rm -rf /var/lib/apt/lists/* /tmp/* /root/.npm

# Copy the built MCP server from the builder stage
COPY --from=builder /build/dist /opt/omnifocus-sync-mcp/dist
COPY --from=builder /build/node_modules /opt/omnifocus-sync-mcp/node_modules
COPY --from=builder /build/package.json /opt/omnifocus-sync-mcp/package.json

# Copy add-on rootfs (s6 services)
COPY rootfs /

# Persistent Omni Sync Server client state (database cache, sync cursor)
RUN mkdir -p /data/omnifocus-sync-mcp

# Set script permissions
RUN chmod a+x /etc/s6-overlay/s6-rc.d/*/run

EXPOSE 8642
