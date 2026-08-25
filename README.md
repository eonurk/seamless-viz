# seAMLess

AI-assisted molecular analysis of leukemia RNA-seq: deconvolution, harmonization
against reference cohorts, subtype classification, and drug-response views.

## Running it

**Use Docker** — one command, no environment to reproduce by hand:

```bash
cp .env.example .env
./scripts/check-assets.sh       # downloads missing AML data from OSF
docker compose up            # then open http://localhost:3000
```

See **[docs/DOCKER.md](docs/DOCKER.md)** for reference-data details,
authentication modes, and troubleshooting, and
[DEVELOPMENT.md](DEVELOPMENT.md) for the native workflow.

---

# Backend Installation

```bash
micromamba env create -f environment.yml
micromamba activate celvox_env
```

In the R console, you can then install the R packages using:

```R
install.packages("fst")

#install.packages("devtools")
devtools::install_github("eonurk/seAMLess")
devtools::install_github("eonurk/seAMLessData")

if (!require("BiocManager", quietly = TRUE))
    install.packages("BiocManager")

BiocManager::install("sva")

# Install MuSiC package
# TODO: This is an old version of the MuSiC package. We need to update it.
install.packages("MCMCpack")
install.packages("nnls")
install.packages("MuSiC", repos = "https://eonurk.github.io/drat/")
```

## Frontend Deployment (celvox.co)

Nginx serves the frontend from `/var/www/celvox` with SPA fallback to `index.html`. After pulling latest changes and building, deploy the contents of `vite-project/dist` to that web root.

### One-liner redeploy

```bash
cd /root/celvox.co/vite-project \
  && npm ci \
  && npm run build \
  && rsync -av --delete dist/ /var/www/celvox/ \
  && chown -R www-data:www-data /var/www/celvox \
  && find /var/www/celvox -type d -exec chmod 755 {} \; \
  && find /var/www/celvox -type f -exec chmod 644 {} \; \
  && nginx -t \
  && systemctl reload nginx
```

### Optional: backup current site before syncing

```bash
ts=$(date +%Y%m%d_%H%M%S); tar -C /var/www -czf /var/www/celvox_${ts}.tgz celvox
```

### Quick check

```bash
curl -I https://celvox.co
```

Notes:

- Update paths if project location or Nginx root changes.
- API requests are proxied under `/api` to `http://127.0.0.1:3001/` per `/etc/nginx/sites-available/celvox.co`.
