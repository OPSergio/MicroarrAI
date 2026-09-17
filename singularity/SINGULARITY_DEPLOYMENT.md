# MicroarrAI - Deployment with Singularity/Apptainer

Complete guide to deploying MicroarrAI using **Singularity** or **Apptainer** as an alternative to Docker. The deployment is functionally identical: same base image, same R packages, same port, and same application.

> **When to use Singularity instead of Docker?**
> Singularity/Apptainer is the de facto standard in HPC clusters (SLURM, PBS) where Docker is not available for security reasons. También es útil en entornos donde no se tienen permisos de root pero sí acceso a `fakeroot` o Apptainer sin privilegios.

---

## Prerequisites

| Component | Minimum | Recommended |
|---|---|---|
| CPU | 2 cores | 4+ cores |
| RAM | 4 GB | 8–16 GB |
| Disk | 15 GB | 25 GB |
| OS | Linux (kernel ≥ 3.10) | Ubuntu 22.04 LTS |
| Singularity/Apptainer | Singularity CE 3.8+ | Apptainer 1.0+ |

### Install Apptainer (recommended)

```bash
# Ubuntu/Debian
sudo apt-get update && sudo apt-get install -y software-properties-common
sudo add-apt-repository -y ppa:apptainer/ppa
sudo apt-get update && sudo apt-get install -y apptainer

# Verify
apptainer --version
```

### Install Singularity CE

```bash
# Dependencies
sudo apt-get install -y build-essential libssl-dev uuid-dev libgpgme11-dev \
    squashfs-tools libseccomp-dev wget pkg-config git cryptsetup

# Download and install (adjust version)
export SINGULARITY_VERSION=3.11.4
wget https://github.com/sylabs/singularity/releases/download/v${SINGULARITY_VERSION}/singularity-ce-${SINGULARITY_VERSION}.tar.gz
tar xvf singularity-ce-${SINGULARITY_VERSION}.tar.gz
cd singularity-ce-${SINGULARITY_VERSION}
./mconfig && make -C builddir && sudo make -C builddir install
```

---

## Quick Start

```bash
# 1. Build the image (requires root or fakeroot, ~15-30 min)
sudo singularity build MicroarrAI.sif singularity/MicroarrAI.def
# or with fakeroot:
singularity build --fakeroot MicroarrAI.sif singularity/MicroarrAI.def

# 2. Create logs directory
mkdir -p logs

# 3. Start the application in the background
singularity instance start \
    --containall --no-home --writable-tmpfs \
    --bind ./logs:/var/log/shiny-server \
    MicroarrAI.sif microarrai

# 4. Access in the browser
#    http://localhost:3838/MicroarrAI

# 5. Stop
singularity instance stop microarrai
```

Or using the interactive script:

```bash
chmod +x singularity-deploy.sh
./singularity-deploy.sh
```

---

## Image Build

### Method 1: As root (most compatible)

```bash
sudo singularity build MicroarrAI.sif singularity/MicroarrAI.def
```

### Method 2: With fakeroot (no root, recommended on systems with /etc/subuid configured)

```bash
singularity build --fakeroot MicroarrAI.sif singularity/MicroarrAI.def
```

To enable fakeroot for your user (requires system root once):

```bash
sudo singularity config fakeroot --add $USER
```

### Method 3: Unprivileged Apptainer (on modern HPCs)

Apptainer 1.0+ allows unprivileged builds in some HPC environments:

```bash
apptainer build MicroarrAI.sif singularity/MicroarrAI.def
```

> The build downloads the base image from Docker Hub and compiles all R packages. The first time takes **15–30 minutes**. The resulting image takes up ~4–5 GB.

---

## Application Management

### Start (equivalent to `docker-compose up -d`)

```bash
mkdir -p logs
singularity instance start \
    --containall --no-home --writable-tmpfs \
    --bind ./logs:/var/log/shiny-server \
    MicroarrAI.sif microarrai
```

With persistent data:

```bash
mkdir -p logs data
singularity instance start \
    --containall --no-home --writable-tmpfs \
    --bind ./logs:/var/log/shiny-server \
    --bind ./data:/srv/shiny-server/MicroarrAI/data \
    MicroarrAI.sif microarrai
```

With custom Shiny Server configuration:

```bash
singularity instance start \
    --containall --no-home --writable-tmpfs \
    --bind ./logs:/var/log/shiny-server \
    --bind ./shiny-server.conf:/etc/shiny-server/shiny-server.conf:ro \
    MicroarrAI.sif microarrai
```

### Stop (equivalent to `docker-compose down`)

```bash
singularity instance stop microarrai
```

Stop all instances:

```bash
singularity instance stop --all
```

### List active instances (equivalent to `docker ps`)

```bash
singularity instance list
```

### View logs in real-time (equivalent to `docker-compose logs -f`)

```bash
tail -f logs/*.log
```

### Open interactive shell (equivalent to `docker exec -it ... bash`)

```bash
singularity shell \
    --bind ./logs:/var/log/shiny-server \
    MicroarrAI.sif
```

### Run a specific command

```bash
singularity exec MicroarrAI.sif R --no-save -e "sessionInfo()"
```

---

## Change Port

The image listens on port **3838** by default. Singularity does not remap ports like Docker (`-p 8080:3838`). To change the port you have two options:

**Option A — Use a reverse proxy** (recommended in production):

```bash
# Nginx: redirects port 80 to internal 3838
# See "Production" section below
```

**Option B — Modify Shiny Server configuration**:

Edit `shiny-server-singularity.conf`, change `listen 3838;` to the desired port, and mount the file in the container:

```bash
singularity instance start \
    --containall --no-home --writable-tmpfs \
    --bind ./logs:/var/log/shiny-server \
    --bind ./shiny-server-singularity.conf:/etc/shiny-server/shiny-server.conf:ro \
    MicroarrAI.sif microarrai
```

---

## Use as a System Service (systemd)

To start automatically with the system:

```bash
# /etc/systemd/system/microarrai.service
sudo tee /etc/systemd/system/microarrai.service > /dev/null <<EOF
[Unit]
Description=MicroarrAI Shiny Application (Singularity)
After=network.target

[Service]
Type=forking
User=$USER
WorkingDirectory=$(pwd)
ExecStartPre=/bin/mkdir -p $(pwd)/logs
ExecStart=$(which singularity) instance start \
    --containall --no-home --writable-tmpfs \
    --bind $(pwd)/logs:/var/log/shiny-server \
    $(pwd)/MicroarrAI.sif microarrai
ExecStop=$(which singularity) instance stop microarrai
Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable microarrai
sudo systemctl start microarrai
sudo systemctl status microarrai
```

---

## Deployment in HPC Cluster (SLURM)

```bash
#!/bin/bash
#SBATCH --job-name=microarrai
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=4
#SBATCH --mem=8G
#SBATCH --time=24:00:00

cd $SLURM_SUBMIT_DIR
mkdir -p logs

# Start the application as a Singularity instance
singularity instance start \
    --containall --no-home --writable-tmpfs \
    --bind ./logs:/var/log/shiny-server \
    MicroarrAI.sif microarrai

echo "MicroarrAI available at: http://$(hostname):3838/MicroarrAI"

# Keep job active while instance is running
while singularity instance list | grep -q "^microarrai "; do
    sleep 60
done
```

---

## Reverse Proxy with Nginx (production)

```nginx
# /etc/nginx/sites-available/microarrai
server {
    listen 80;
    server_name tu-servidor.ejemplo.com;

    location /MicroarrAI/ {
        proxy_pass         http://localhost:3838/MicroarrAI/;
        proxy_http_version 1.1;
        proxy_set_header   Upgrade $http_upgrade;
        proxy_set_header   Connection "upgrade";
        proxy_set_header   Host $host;
        proxy_read_timeout 3600s;
        proxy_send_timeout 3600s;

        # Maximum upload size (100 MB)
        client_max_body_size 100M;
    }
}
```

```bash
sudo ln -s /etc/nginx/sites-available/microarrai /etc/nginx/sites-enabled/
sudo nginx -t && sudo systemctl reload nginx
```

---

## Verificación post-build

```bash
# Ejecutar los tests integrados en la imagen
singularity test MicroarrAI.sif

# Comprobar que los paquetes R están instalados
singularity exec MicroarrAI.sif \
    R --no-save -e "library(shiny); library(randomForest); library(mixOmics); cat('OK\n')"

# Comprobar que los archivos de la app están presentes
singularity exec MicroarrAI.sif \
    ls /srv/shiny-server/MicroarrAI/
```

---

## Solución de problemas

### La instancia no arranca

```bash
# Ver mensajes de error de Shiny Server
tail -50 logs/*.log

# Arrancar en primer plano para ver errores directamente
singularity run \
    --bind ./logs:/var/log/shiny-server \
    MicroarrAI.sif
```

### Error de permisos en los logs

```bash
# Asegúrate de que el directorio de logs tiene permisos de escritura
mkdir -p logs && chmod 777 logs
```

### Puerto 3838 ya en uso

```bash
# Identificar el proceso que usa el puerto
ss -tlnp | grep 3838
# o
lsof -i :3838

# Detener posibles instancias previas
singularity instance stop --all
```

### Error al construir: "fakeroot not configured"

```bash
# Opción 1: configurar fakeroot (requiere sudo una vez)
sudo singularity config fakeroot --add $USER
# Verify: cat /etc/subuid | grep $USER

# Opción 2: construir como root
sudo singularity build MicroarrAI.sif MicroarrAI.def
```

### La app carga pero da error de R

```bash
# Ver logs de Shiny con detalle
tail -f logs/shiny-*.log

# Abrir shell y probar manualmente
singularity shell --bind ./logs:/var/log/shiny-server MicroarrAI.sif
# Dentro del contenedor:
R --no-save -e "source('/srv/shiny-server/MicroarrAI/global.R')"
```

---

## Diferencias respecto al despliegue Docker

| Aspecto | Docker | Singularity |
|---|---|---|
| Archivo de definición | `Dockerfile` + `docker-compose.yml` | `MicroarrAI.def` |
| Script de gestión | `deploy.sh` | `singularity-deploy.sh` |
| Imagen generada | capa de imágenes en `/var/lib/docker` | fichero `MicroarrAI.sif` (portátil) |
| Ejecución en segundo plano | `docker-compose up -d` | `singularity instance start` |
| Ver logs | `docker-compose logs -f` | `tail -f logs/*.log` |
| Usuario del proceso | root → shiny (via `run_as shiny;`) | usuario actual del host |
| Config shiny-server | `shiny-server.conf` (con `run_as shiny;`) | `shiny-server-singularity.conf` (sin `run_as`) |
| Reasignación de puertos | `-p 8080:3838` | proxy inverso (Nginx) |
| Disponible en HPC | No (sin root) | Sí (con fakeroot o Apptainer) |
| Imagen portátil | No (acoplada al daemon Docker) | Sí (fichero `.sif` copiable) |

---

## Archivos Singularity en este proyecto

| Fichero | Descripción |
|---|---|
| [`MicroarrAI.def`](MicroarrAI.def) | Definición de la imagen Singularity (equivale al `Dockerfile`) |
| [`shiny-server-singularity.conf`](shiny-server-singularity.conf) | Config de Shiny Server sin `run_as` (para ejecución sin root) |
| [`singularity-deploy.sh`](singularity-deploy.sh) | Script de gestión interactivo (equivale a `deploy.sh`) |
| [`SINGULARITY_DEPLOYMENT.md`](SINGULARITY_DEPLOYMENT.md) | Esta guía |
