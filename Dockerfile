# =============================================================================
# foundry-character-creator  —  static SPA served by nginx
# Builds the React/Vite bundle, then serves it from nginx with reverse
# proxies to the foundry-mcp REST surface and Foundry VTT's asset tree.
# =============================================================================

# -- Build: React SPA (Vite) --
FROM node:20-alpine AS build
WORKDIR /app

# Install deps first so the layer caches on package.json churn only.
COPY package.json package-lock.json ./
RUN npm ci

# Build inputs.
COPY tsconfig.json tsconfig.node.json vite.config.ts postcss.config.js index.html ./
COPY src ./src
# vite.config.ts imports from ./mock, so the build needs it present even
# though the mock plugin is only enabled via `vite --mode mock`.
COPY mock ./mock
RUN npm run build

# -- Runtime: nginx --
FROM nginx:1.27-alpine

# Stock nginx:alpine entrypoint renders /etc/nginx/templates/*.template
# through envsubst into /etc/nginx/conf.d/, so dropping our template there
# overwrites the base image's default.conf at container start.
COPY nginx/default.conf.template /etc/nginx/templates/default.conf.template
COPY --from=build /app/dist /usr/share/nginx/html

# Upstreams default to the service names used by the bundled
# docker-compose (mcp for /api, foundry for asset prefixes). Override in
# other environments.
ENV MCP_UPSTREAM=mcp:8765 \
    FOUNDRY_UPSTREAM=foundry:30000 \
    SERVER_PORT=8080 \
    NGINX_ENVSUBST_FILTER=^(MCP_UPSTREAM|FOUNDRY_UPSTREAM|SERVER_PORT)$

EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD wget -q --spider http://127.0.0.1:${SERVER_PORT}/healthz || exit 1
