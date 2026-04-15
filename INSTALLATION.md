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

Edit [`docker/docker-compose.yml`](docker/docker-compose.yml) to change the host port or adjust CPU/memory limits:

```yaml
ports:
  - "3838:3838"   # change left side for a different host port

deploy:
  resources:
    limits:
      cpus: '4'
      memory: 8G
```

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
    --bind ./logs:/var/log/shiny-server \
    MicroarrAI.sif microarrai
```

Application available at `http://localhost:3838/MicroarrAI`.

### Persistent data

Mount a data directory so uploaded files survive restarts:

```bash
singularity instance start \
    --bind ./logs:/var/log/shiny-server \
    --bind ./data:/srv/shiny-server/MicroarrAI/data \
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

## Shiny Server configuration

| File | Used by |
|------|---------|
| `shiny-server.conf` | Docker (optional — uncomment the `COPY` line in `docker/Dockerfile`) |
| `singularity/shiny-server-singularity.conf` | Singularity (copied into the image during build) |

The Singularity variant omits `run_as shiny;` because Singularity runs processes as the invoking user.

---

## Troubleshooting

**Container starts but app does not load**  
Wait 60 seconds — Shiny Server initialises R packages on first request. Check `logs/` for errors.

**R package installation fails during build**  
Network issues during build are the most common cause. Retry the build. For air-gapped systems, pre-populate an R package cache and mount it during build.

**Singularity `%files` error during build**  
Always run the build command from the repository root, not from inside `singularity/`.

**Permission denied on `deploy.sh`**  
```bash
chmod +x deploy.sh docker/docker-deploy.sh singularity/singularity-deploy.sh
```
