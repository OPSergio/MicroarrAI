# MicroarrAI — Installation

Two deployment options are available: **Docker** (recommended for workstations and servers) and **Singularity/Apptainer** (recommended for HPC clusters where Docker is unavailable).

Both produce identical environments: R 4.4.0 + Shiny Server + all required packages.

---

## Quick start

```bash
git clone https://github.com/OPSergio/MicroarrAI.git
cd MicroarrAI
chmod +x deploy.sh docker/docker-deploy.sh singularity/singularity-deploy.sh
./deploy.sh
```

`deploy.sh` asks which runtime to use and delegates to the appropriate script.

---

## Docker

### Requirements

- Docker Engine ≥ 20.10
- Docker Compose (plugin or standalone)
- ~10 GB free disk space
- 4 GB RAM minimum (8 GB recommended)

If Docker is not installed, use the bundled script:

```bash
sudo sh docker/get-docker.sh
sudo usermod -aG docker $USER   # then re-login
```

### First-time build

```bash
./deploy.sh   # choose option 1 → Docker, then option 1 → Build and start
```

The image build installs all R packages and takes 15–30 minutes. Subsequent starts are immediate.

The application is available at `http://localhost:3838/MicroarrAI`.

Logs are written to `logs/` in the repository root.

### Manual commands

All commands accept the compose file explicitly so they can be run from the repo root:

```bash
docker compose -f docker/docker-compose.yml up -d        # start
docker compose -f docker/docker-compose.yml down         # stop
docker compose -f docker/docker-compose.yml logs -f      # tail logs
docker compose -f docker/docker-compose.yml build        # rebuild image
```

### Port and resource limits

Copy the example environment file and edit it. Compose reads `.env` from the
directory holding the compose file, so it must live in `docker/`:

```bash
cp docker/.env.example docker/.env
```

```ini
SHINY_PORT=3838                 # host port (container always listens on 3838)
CPU_LIMIT=4
MEMORY_LIMIT=8G
MICROARRAI_MAX_UPLOAD_MB=1024   # ceiling for one RAW upload (a whole scan set)
```

Apply with `docker compose -f docker/docker-compose.yml up -d` — no rebuild needed.

---

## Singularity / Apptainer

Intended for HPC environments. No root required for running the image once built.

### Requirements

- Singularity CE ≥ 3.8 or Apptainer ≥ 1.0
- Root or fakeroot privileges for the build step
- ~10 GB free disk space

Install Apptainer (recommended):  
https://apptainer.org/docs/admin/main/installation.html

### Build

The build must run from the **repository root**:

```bash
# With fakeroot (user must be in /etc/subuid and /etc/subgid):
singularity build --fakeroot MicroarrAI.sif singularity/MicroarrAI.def

# Or as root:
sudo singularity build MicroarrAI.sif singularity/MicroarrAI.def
```

The `.sif` image is created in the repo root. Build takes 15–30 minutes.

### Run

```bash
./deploy.sh   # choose option 2 → Singularity, then option 2 → Start
```

Or manually:

```bash
mkdir -p logs
singularity instance start \
    --containall --no-home --writable-tmpfs \
    --bind ./logs:/var/log/shiny-server \
    MicroarrAI.sif microarrai
```

Application available at `http://localhost:3838/MicroarrAI`.

### User data

There is no data directory to mount. Users upload their scan files through the
browser; each session stages them in its own temporary directory, which is
deleted when the session ends. Nothing user-supplied is written into the image
or onto the host, so the same instance can serve several users safely.

To raise the upload ceiling (RAW mode sends a whole scan set in one request):

```bash
SINGULARITYENV_MICROARRAI_MAX_UPLOAD_MB=2048 \
singularity instance start \
    --containall --no-home --writable-tmpfs \
    --bind ./logs:/var/log/shiny-server \
    MicroarrAI.sif microarrai
```

### Stop

```bash
singularity instance stop microarrai
```

### Verify the image

```bash
singularity test MicroarrAI.sif
```

Checks that all R packages and application files are present inside the image.

---

## R dependencies

Both images install the exact same package set from [`dependencies.R`](dependencies.R),
the single source of truth. To add or remove a package, edit that file only —
the Dockerfile and the Singularity definition both call it:

```bash
Rscript dependencies.R install   # install everything missing
Rscript dependencies.R check     # exit 1 if anything is missing
```

The build runs `check` after `install`, so a package that silently fails to
compile fails the build instead of producing a broken image.

No CRAN repository is pinned in the recipes on purpose: the `rocker` base image
already points at a dated Posit Package Manager snapshot, which gives
reproducible versions and prebuilt Linux binaries. Overriding it would force
every package to compile from source.

---

## Shiny Server configuration

| File | Used by |
|------|---------|
| `docker/shiny-server.conf` | Docker (copied into the image during build) |
| `singularity/shiny-server-singularity.conf` | Singularity (copied into the image during build) |

The Singularity variant omits `run_as shiny;` because Singularity runs processes as the invoking user.

Both set `app_init_timeout 300`: loading mixOmics, caret and the rest of
`R/global.R` takes well over the 60 s default on a cold start, which would
otherwise surface to the user as "an error has occurred".

---

## Troubleshooting

**Container starts but app does not load**  
Wait up to a minute — Shiny Server initialises R packages on the first request. Check `logs/` for errors.

**"Maximum upload size exceeded" when uploading scan files**  
RAW mode sends the whole scan set in one request. Raise `MICROARRAI_MAX_UPLOAD_MB`
(default 1024) in `docker/.env`, or via `SINGULARITYENV_MICROARRAI_MAX_UPLOAD_MB`.

**R package installation fails during build**  
Network issues during build are the most common cause. Retry the build. For air-gapped systems, pre-populate an R package cache and mount it during build.

**Singularity `%files` error during build**  
Always run the build command from the repository root, not from inside `singularity/`.

**Permission denied on `deploy.sh`**  
```bash
chmod +x deploy.sh docker/docker-deploy.sh singularity/singularity-deploy.sh
```
