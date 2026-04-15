# Docker Installation Guide - MicroarrAI

Docker is **free** for most users. This guide will help you install it on your system.

## Is Docker Paid?

**Not for most cases:**

- **Docker Engine (Linux)**: 100% free and open source
- **Docker Desktop (Windows/Mac)**: 
  - **FREE** for:
    - Personal use
    - Education and research
    - Small organizations (<250 employees AND <$10M annual revenue)
    - Open source projects
  - Paid for large enterprises (but you can use Docker Engine without Docker Desktop)

**For on-premise servers (your case): Docker Engine is completely free.**

---

## Linux Installation (Recommended for Servers)

### Ubuntu/Debian

```bash
# Update system
sudo apt update
sudo apt upgrade -y

# Install dependencies
sudo apt install -y apt-transport-https ca-certificates curl software-properties-common

# Add Docker's official GPG key
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

# Add Docker repository
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Install Docker Engine
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

# Verify installation
docker --version
docker compose version

# Start Docker
sudo systemctl start docker
sudo systemctl enable docker

# Allow using Docker without sudo (optional)
sudo usermod -aG docker $USER
newgrp docker

# Test installation
docker run hello-world
```

### CentOS/RHEL/Rocky Linux

```bash
# Install dependencies
sudo yum install -y yum-utils

# Add Docker repository
sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo

# Install Docker Engine
sudo yum install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

# Start Docker
sudo systemctl start docker
sudo systemctl enable docker

# Allow current user to use Docker
sudo usermod -aG docker $USER
newgrp docker

# Verify
docker --version
docker run hello-world
```

### Fedora

```bash
# Add repository
sudo dnf -y install dnf-plugins-core
sudo dnf config-manager --add-repo https://download.docker.com/linux/fedora/docker-ce.repo

# Install
sudo dnf install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

# Start
sudo systemctl start docker
sudo systemctl enable docker

# Configure user
sudo usermod -aG docker $USER
newgrp docker
```

---

## Windows Installation

### Option 1: Docker Desktop (Easy but with license restrictions)

1. **Download**:
   - Go to https://www.docker.com/products/docker-desktop
   - Download Docker Desktop for Windows

2. **Requirements**:
   - Windows 10/11 Pro, Enterprise or Education
   - WSL 2 enabled
   - Virtualization enabled in BIOS

3. **Install**:
   - Run installer
   - Follow the wizard
   - Restart when prompted

4. **Configure WSL 2**:
   ```powershell
   # In PowerShell as Administrator
   wsl --install
   wsl --set-default-version 2
   ```

### Option 2: Docker in WSL 2 (Completely Free)

If you don't want Docker Desktop:

```bash
# 1. Install WSL 2 with Ubuntu
wsl --install -d Ubuntu

# 2. Inside WSL Ubuntu, install Docker Engine (see Linux section above)

# 3. Use from WSL or Windows Terminal
```

---

## macOS Installation

### Docker Desktop (Easiest)

1. **Download**:
   - https://www.docker.com/products/docker-desktop
   - Choose Intel or Apple Silicon version

2. **Install**:
   - Open downloaded .dmg
   - Drag Docker to Applications
   - Start Docker Desktop

3. **Verify**:
   ```bash
   docker --version
   docker compose version
   ```

### Alternative: Homebrew

```bash
# Install Homebrew if you don't have it
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Install Docker
brew install docker docker-compose
```

---

## Verify Installation

After installing, verify it works:

```bash
# View version
docker --version

# View system info
docker info

# Test with hello-world container
docker run hello-world

# Verify Docker Compose
docker compose version
```

**Expected output of `docker --version`:**
```
Docker version 24.0.0 or higher
```

---

## Deploy MicroarrAI After Installing Docker

Once Docker is installed:

```bash
# Go to project directory
cd /path/to/MicroarrAI

# Option 1: Automatic script (easiest)
./deploy.sh

# Option 2: Manual Docker Compose
docker compose up -d

# View logs
docker compose logs -f

# Access
# http://localhost:3838/MicroarrAI
```

---

## Post-Installation Configuration (Linux)

### Use Docker without sudo

```bash
# Add user to docker group
sudo usermod -aG docker $USER

# Apply changes (or log out and log back in)
newgrp docker

# Test
docker run hello-world
```

### Configure automatic start

```bash
# Enable Docker on boot
sudo systemctl enable docker

# Check status
sudo systemctl status docker
```

### Increase resource limits (optional)

Edit `/etc/docker/daemon.json`:
```json
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  },
  "default-ulimits": {
    "nofile": {
      "Name": "nofile",
      "Hard": 64000,
      "Soft": 64000
    }
  }
}
```

Restart Docker:
```bash
sudo systemctl restart docker
```

---

## Docker Alternatives

If you cannot or do not want to use Docker:

### 1. Podman (Compatible with Docker, 100% Open Source)

```bash
# Ubuntu/Debian
sudo apt install -y podman

# CentOS/RHEL
sudo yum install -y podman

# Use same as Docker
podman build -t microarrai .
podman run -p 3838:3838 microarrai

# Create alias for compatibility
alias docker=podman
```

### 2. Run Directly with R/Shiny Server

If you don't want containers:

```bash
# Install Shiny Server
# Ubuntu/Debian
wget https://download3.rstudio.org/ubuntu-18.04/x86_64/shiny-server-1.5.20.1002-amd64.deb
sudo gdebi shiny-server-1.5.20.1002-amd64.deb

# Install R and dependencies (see README.md)
# Copy app to /srv/shiny-server/
sudo cp -r /path/to/MicroarrAI /srv/shiny-server/

# Access
# http://localhost:3838/MicroarrAI
```

### 3. Run in RStudio

```r
# Open project in RStudio
# Install dependencies (see README.md "Local Installation" section)
# Run:
shiny::runApp()
```

---

## Troubleshooting

### Error: "Cannot connect to Docker daemon"

```bash
# Check if Docker is running
sudo systemctl status docker

# Start Docker
sudo systemctl start docker

# Check permissions
sudo usermod -aG docker $USER
newgrp docker
```

### Error: "permission denied" on /var/run/docker.sock

```bash
# Option 1: Add user to docker group
sudo usermod -aG docker $USER
newgrp docker

# Option 2: Change permissions (not recommended in production)
sudo chmod 666 /var/run/docker.sock
```

### Docker Desktop does not start on Windows

1. Verify WSL 2 is installed: `wsl --list`
2. Update WSL: `wsl --update`
3. Enable virtualization in BIOS
4. Restart Windows

### Insufficient disk space

```bash
# View disk usage
docker system df

# Clean unused resources
docker system prune -a

# Clean volumes
docker volume prune
```

---

## System Requirements

### Minimum for MicroarrAI:
- **CPU**: 2 cores
- **RAM**: 4 GB
- **Disk**: 15 GB (10 GB for Docker image + 5 GB data)
- **OS**: Linux, Windows 10/11, macOS 10.15+

### Recommended for MicroarrAI:
- **CPU**: 4+ cores
- **RAM**: 8-16 GB
- **Disk**: 25 GB
- **OS**: Linux (better performance)

---

## Additional Resources

- **Official Docker documentation**: https://docs.docker.com/
- **Docker Hub**: https://hub.docker.com/
- **Docker Compose**: https://docs.docker.com/compose/
- **Podman**: https://podman.io/
- **WSL 2**: https://learn.microsoft.com/en-us/windows/wsl/

---

## Quick Summary

```bash
# 1. Install Docker (Ubuntu/Debian)
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker $USER
newgrp docker

# 2. Verify
docker --version

# 3. Deploy MicroarrAI
cd MicroarrAI
./deploy.sh

# 4. Access
# http://localhost:3838/MicroarrAI
```

---

## Tip for On-Premise Servers

For a **production on-premise server**, we recommend:

1. **Linux** (Ubuntu Server 22.04 LTS or Rocky Linux 9)
2. **Docker Engine** (free)
3. **Docker Compose** (free)
4. **Nginx** as reverse proxy (free)
5. **Let's Encrypt** for SSL (free)

**Everything is 100% free and open source.**

---

**Last update**: March 2026
