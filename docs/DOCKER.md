# Running seAMLess with Docker

Everything the stack needs — R 4.4 with Bioconductor and seAMLess, two Python
runtimes for the molecular classifiers, the Node API service, and the web app —
is built into three images. The only thing you have to supply is the reference
data, which is too large for git.

## TL;DR

```bash
git clone --branch docker/seamless-stack git@github.com:eonurk/seamless-viz.git
cd seamless-viz
cp .env.example .env

# Downloads missing AML data from OSF and verifies every checksum.
./scripts/check-assets.sh

docker compose up
```

Then open <http://localhost:3000>. You are logged in automatically as
`dev@localhost` — no Firebase account needed.

The first build takes **20–40 minutes** (Bioconductor and torch are large).
Everything after that is cached.

---

## What runs where

| Service | Container | Host port | What it is |
|---|---|---|---|
| `frontend` | `seamless/frontend:local` | 3000 | Vite dev server, HMR against `vite-project/src` |
| `service` | `seamless/service:local` | 3001 | Express API: authenticates, then proxies to the compute API |
| `r-backend` | `seamless/r-backend:local` | 5555 | plumber API — all the actual analysis |

The browser talks to `service`; only `service` talks to `r-backend`.

Useful URLs:

- <http://localhost:3000> — the dashboard
- <http://localhost:3001/> — service liveness (`ok`)
- <http://localhost:5555/__docs__/> — plumber's Swagger UI, handy for poking at
  endpoints directly
- <http://localhost:5555/molecular-tools?disease=aml> — which classifiers found
  their model artifacts

### Inside the r-backend image

Three conda environments, because the tools disagree about their dependencies:

| Env | Python/R | Used by |
|---|---|---|
| `base` | R 4.4.3 | plumber, seAMLess, MuSiC, sva, ALLCatchR |
| `moltools` | Python 3.10 | ALLSorts, TALLSorts, parquet/STAR helpers |
| `bridge` | Python 3.11 + torch (CPU) | Bridge |

The plumber code finds them through `MOLECULAR_TOOLS_PYTHON`, `PARQUET_PYTHON`
and `BRIDGE_PYTHON`, all set in the image.

Set `WITH_BRIDGE=0` in `.env` to skip the torch environment: roughly 10 minutes
and 1.5 GB off the build, at the cost of `/bridge-predict`.

---

## Reference data

The required AML dataset is public on [OSF](https://osf.io/wq7gx/overview).
`./scripts/check-assets.sh` downloads any missing AML files from OSF and verifies
their published SHA-256 hashes. The large downloaded files remain `.gitignore`d;
the small hg38 support tables absent from OSF are versioned with this repository.

The resulting tree looks like this:

```
backend/
├── data/
│   ├── AML/            meta.csv, scores.csv, counts/, drug_response/, aberrations/
│   ├── B-ALL/          optional training data
│   └── T-ALL/          optional training data
├── tools/              vendored tool sources: AMLmapR, ALLCatchR_bcrabl1,
│                       ALLSorts, TALLSorts, Bridge
├── tools_runtime/      model artifacts, derived from tools/
└── cache/              local generated state; never distributed
```

`./scripts/check-assets.sh` separates the two cases that matter:

- **Required** — the AML reference data. Missing files are downloaded from OSF.
- **Optional** — B-ALL/T-ALL training data and molecular tools. Each degrades
  independently: the dashboard runs, and `GET /molecular-tools` reports missing
  tools as unavailable rather than erroring.

If `tools/` is present but `tools_runtime/` is empty, populate the latter:

```bash
./backend/prepare_tools_runtime.sh
```

`backend/cache/` is never downloaded or distributed. Reference matrices are
generated locally on first use, so the first t-SNE or harmonization request can
take several minutes; subsequent requests use the local cache.

---

## Authentication

Every `/v1` endpoint requires an authenticated caller. There are two modes.

### Development bypass (the default)

`SEAMLESS_DEV_AUTH=1` on the service and `VITE_DEV_AUTH=1` on the frontend. The
service accepts every request as `SEAMLESS_DEV_USER_EMAIL`, and the frontend
skips the login screen. No Firebase project, no service account, no test users.

Two guardrails:

- The service throws on startup if `SEAMLESS_DEV_AUTH` is set while
  `NODE_ENV=production`.
- Both flags must be set. The frontend sends a placeholder token that only the
  bypassed service accepts, so a half-configured stack fails closed.

The user's email is the cache partition key (`backend/cache/<email>/`), so
changing `SEAMLESS_DEV_USER_EMAIL` gives you a clean workspace.

### Real Firebase

```bash
# backend/service/firebase-credentials.json  <- service account key
# VITE_FIREBASE_* in .env                    <- web app config
docker compose -f docker-compose.yml -f docker-compose.firebase.yml up
```

The service account key comes from the Firebase console under
**Project Settings → Service accounts → Generate new private key**. With this
overlay you get the real login screen and need a user in that project.

---

## Everyday commands

```bash
make up                  # docker compose up
make up-d                # detached
make logs                # follow all three services
make down                # stop
make ps                  # status + health
make check-assets        # validate the bind-mounted data
make shell-r             # shell in the R container
make shell-service       # shell in the service container
make rebuild             # rebuild images from scratch
make docker-reset        # also drop volumes and the compiled R library
```

Talk to the R backend directly, bypassing auth entirely — the fastest way to
debug an endpoint:

```bash
curl 'http://localhost:5555/molecular-tools?disease=ball'
curl 'http://localhost:5555/sample-data-names?cachedir=cache/dev@localhost'
```

### What is live and what needs a restart

| Change | What to do |
|---|---|
| `vite-project/src/**` | nothing — HMR |
| `backend/service/src/**` | `docker compose restart service` (recompiles on start) |
| `backend/*.R`, `backend/*.py` | `docker compose restart r-backend` |
| `docker/**`, `env-*.yml`, `package.json` | `make rebuild` |

plumber parses `plumber.R` once at boot, so R changes always need the restart.

---

## Production-shaped images

The default compose targets development: Vite's dev server and `tsc` on service
start. For something closer to the deployed setup:

```bash
make prod-build
SERVICE_TARGET=prod NODE_ENV=production docker compose up
```

`SERVICE_TARGET=prod` runs the prebuilt `dist/` with no toolchain on the start
path. The frontend's `prod` stage builds the static bundle and serves it from
nginx with the SPA fallback and a local `/api` → service proxy. Note that Vite
inlines `VITE_*` at **build** time, so those values are build args, not runtime
environment.

This is not a hardened production deployment — no TLS, no secret management, and
`docker-compose.firebase.yml` mounts the service account key as a bind mount
rather than a real secret.

---

## Troubleshooting

**AML data is missing or corrupt** — run `./scripts/check-assets.sh`. It resumes
the public OSF downloads and verifies every file before Docker starts.

**A prediction endpoint reports the tool as unavailable** — that tool's model
artifacts are not mounted. Check `GET /molecular-tools?disease=<id>`; it lists
exactly which files it looked for.

**`ALLCatchRbcrabl1` install fails on first boot** — it is compiled from
`backend/tools/ALLCatchR_bcrabl1` into the `r-libs` volume on the first run.
Watch `docker compose logs r-backend` during startup. To retry from clean:
`docker volume rm seamless_r-libs`.

**Uploads fail with a missing-file error from the R backend** — the service
passes *absolute paths* to the compute backend, so both containers must see the
uploads directory at the same path. They share the `uploads` named volume at
`/shared/uploads`; don't change that path in only one service.

**The frontend loads but every API call 401s** — `SEAMLESS_DEV_AUTH` and
`VITE_DEV_AUTH` disagree. Both must be `1`, or both `0`. `VITE_DEV_AUTH` is read
by Vite at startup, so `docker compose up -d --force-recreate frontend` after
changing it.

**Slow first request** — batch correction and reference t-SNE are computed once
and cached under `backend/cache/.reference/`. Subsequent requests are fast.

**Port already taken** — change `FRONTEND_PORT` / `SERVICE_PORT` /
`R_BACKEND_PORT` in `.env`. If you move `SERVICE_PORT`, also set
`VITE_API_BASE_URL` to match, since the frontend defaults to port 3001.

**Linux: cache files are root-owned** — the R container runs as root so the
bind-mounted `backend/` tree works regardless of host UID. Use
`make docker-clean-cache` to remove cache files from inside the container.

**Apple Silicon** — images build natively for arm64; no emulation, no
`platform:` pin. All R, Bioconductor and Python dependencies resolve for both
`linux-aarch64` and `linux-64`.

---

## Running natively instead

The pre-Docker workflow still works and is documented in the top-level
[README](../README.md) and [DEVELOPMENT.md](../DEVELOPMENT.md): a micromamba
`seamless_env` for R, separate Python environments for the tools, and
`make dev`. Docker exists so nobody has to reproduce that by hand.
