## How to run seAMLess locally

### With Docker (recommended)

```bash
cp .env.example .env
./scripts/check-assets.sh    # downloads/verifies the public AML data from OSF
docker compose up
```

Open <http://localhost:3000>. You are signed in automatically as `dev@localhost`;
no Firebase project is required.

Full details — reference data, per-tool availability, real Firebase auth,
production-shaped images, troubleshooting — are in **[docs/DOCKER.md](docs/DOCKER.md)**.

### Natively

seAMLess is three processes:

**1. Compute backend (R plumber, :5555)**

Set up the R environment as described in the [README](README.md), then:

```bash
make r-backend
```

**2. API service (Node, :3001)**

See [backend/service/README.md](backend/service/README.md).

```bash
make service
```

**3. Web app (Vite, :3000)**

```bash
make frontend
```

Or all three at once with `make dev`.

The native path also needs two Python environments for the molecular
classifiers (ALLSorts/TALLSorts, and Bridge). Docker builds these for you; doing
it by hand means reproducing what `docker/r-backend/env-moltools.yml` and
`env-bridge.yml` describe.
