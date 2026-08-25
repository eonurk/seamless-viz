# seAMLess

Standalone molecular analysis and visualization for leukemia RNA-seq data.
The local stack includes the React dashboard, Node API service, R/plumber
compute backend, and isolated Python classifier runtimes.

## Run locally

Docker is the recommended path. No Firebase account or application user is
required in the default development configuration.

```bash
cp .env.example .env
./scripts/check-assets.sh
docker compose up
```

`check-assets.sh` downloads the public AML reference data from
[OSF](https://osf.io/wq7gx/overview), installs pinned molecular classifiers from
their upstream repositories, and verifies downloaded archives with SHA-256.
It does not download or distribute cache files. Bridge additionally requires
an authorized private model bundle; see [docs/DOCKER.md](docs/DOCKER.md).

Open <http://localhost:3000> after the services start. The initial image build
can take 20–40 minutes.

See [docs/DOCKER.md](docs/DOCKER.md) for build options, authentication modes,
asset availability, and troubleshooting. See [DEVELOPMENT.md](DEVELOPMENT.md)
for the native three-process workflow.

## Native R environment

```bash
micromamba env create -f environment.yml
micromamba activate seamless_env
```

The molecular classifiers need additional Python environments described in
`docker/r-backend/env-moltools.yml` and `docker/r-backend/env-bridge.yml`.
Docker builds and configures these automatically.
