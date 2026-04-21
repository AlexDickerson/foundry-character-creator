# foundry-character-creator

React 19 SPA that renders a Pathfinder 2e character creator/viewer, consuming the [foundry-mcp](https://github.com/AlexDickerson/foundry-mcp) REST API. Renders post-`prepareData()` actor state using PF2e's styling conventions.

## Architecture

```
Browser (Vite :5173) ──/api/* ──proxy──> foundry-mcp server (:8765)
                     ──/icons, /systems, /modules, /worlds, /assets──> Foundry VTT (:30000)
```

The SPA talks to foundry-mcp over REST (`/api/*`) for gameplay data and proxies asset paths straight to the running Foundry instance for images. No cross-dependency on the module or server code — contract is HTTP-only.

## Dev loop

```bash
# Start foundry-mcp server in a separate terminal
cd ../foundry-mcp && npm run dev

# Start Foundry (or point FOUNDRY_URL at a running one)
cd ../foundry-api-bridge && ./local.sh up

# Run the SPA
npm install
npm run dev                      # Vite on :5173, proxies /api → :8765
```

Override defaults via env:
- `FOUNDRY_URL=http://my-foundry:30000`
- `MCP_URL=http://my-server:8765`

Mock mode (no backend required):

```bash
npm run dev:mock                 # serves src/fixtures/*-prepared.json inline
```

## Scripts

- `npm run dev` — Vite dev server with HMR
- `npm run dev:mock` — dev server with in-process mock API
- `npm run build` — typecheck + production build to `dist/`
- `npm run preview` — serve the built dist
- `npm run lint` / `lint:fix`
- `npm run typecheck`
- `npm run test` / `test:watch` — Vitest

## Production

The [Dockerfile](Dockerfile) produces a small nginx image that serves the built SPA and reverse-proxies `/api/*` → the MCP server and Foundry asset prefixes → Foundry. Pushes to `main` publish `ghcr.io/alexdickerson/foundry-character-creator:latest` via [.github/workflows/docker.yml](.github/workflows/docker.yml); each PR validates the build with a `/healthz` + index smoke test.

Deployment target is a single Hetzner Cloud VM running `docker compose` — the stack config lives in [docker-compose.yml](docker-compose.yml) and pulls all three containers (`web`, `mcp`, `foundry`) from GHCR.

```bash
# On a fresh Ubuntu VM — one-time setup
curl -fsSL https://raw.githubusercontent.com/AlexDickerson/foundry-character-creator/main/scripts/bootstrap-host.sh | sudo bash
# then edit /opt/foundry-stack/.env (Foundry creds, OpenAI key) and:
cd /opt/foundry-stack && docker compose up -d
```

GitHub secrets for [.github/workflows/deploy.yml](.github/workflows/deploy.yml): `DEPLOY_HOST`, `DEPLOY_USER`, `DEPLOY_SSH_KEY` (optionally `DEPLOY_PORT`). The deploy job fires after each successful push build and restarts only the `web` service — sibling repos own their own services.

## Attribution

Derived files (PF2e SCSS, `en.json` i18n) are Apache-2.0 licensed upstream. See [NOTICE](NOTICE) for specifics.

## Links

- [foundry-mcp](https://github.com/AlexDickerson/foundry-mcp) — server providing the REST API this SPA consumes
- [foundry-api-bridge](https://github.com/AlexDickerson/foundry-api-bridge) — Foundry module that feeds the server
