# Guía de Instalación de Docker - MicroarrAI

Docker es **gratuito** para la mayoría de usuarios. Esta guía te ayudará a instalarlo en tu sistema.

## 💰 ¿Es Docker de Pago?

**No para la mayoría de casos:**

- **Docker Engine (Linux)**: 100% gratuito y open source
- **Docker Desktop (Windows/Mac)**: 
  - ✅ **GRATIS** para:
    - Uso personal
    - Educación e investigación
    - Organizaciones pequeñas (<250 empleados Y <$10M ingresos anuales)
    - Proyectos open source
  - 💳 De pago para empresas grandes (pero puedes usar Docker Engine sin Docker Desktop)

**Para servidores on-premise (tu caso): Docker Engine es completamente gratuito.**

---

## 🐧 Instalación en Linux (Recomendado para Servidores)

### Ubuntu/Debian

```bash
# Actualizar sistema
sudo apt update
sudo apt upgrade -y

# Instalar dependencias
sudo apt install -y apt-transport-https ca-certificates curl software-properties-common

# Agregar clave GPG de Docker
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

# Agregar repositorio de Docker
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Instalar Docker Engine
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

# Verificar instalación
docker --version
docker compose version

# Iniciar Docker
sudo systemctl start docker
sudo systemctl enable docker

# Permitir usar Docker sin sudo (opcional)
sudo usermod -aG docker $USER
newgrp docker

# Probar instalación
docker run hello-world
```

### CentOS/RHEL/Rocky Linux

```bash
# Instalar dependencias
sudo yum install -y yum-utils

# Agregar repositorio de Docker
sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo

# Instalar Docker Engine
sudo yum install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

# Iniciar Docker
sudo systemctl start docker
sudo systemctl enable docker

# Permitir usuario actual usar Docker
sudo usermod -aG docker $USER
newgrp docker

# Verificar
docker --version
docker run hello-world
```

### Fedora

```bash
# Agregar repositorio
sudo dnf -y install dnf-plugins-core
sudo dnf config-manager --add-repo https://download.docker.com/linux/fedora/docker-ce.repo

# Instalar
sudo dnf install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

# Iniciar
sudo systemctl start docker
sudo systemctl enable docker

# Configurar usuario
sudo usermod -aG docker $USER
newgrp docker
```

---

## 🪟 Instalación en Windows

### Opción 1: Docker Desktop (Fácil pero con restricciones de licencia)

1. **Descargar**:
   - Ir a https://www.docker.com/products/docker-desktop
   - Descargar Docker Desktop para Windows

2. **Requisitos**:
   - Windows 10/11 Pro, Enterprise o Education
   - WSL 2 habilitado
   - Virtualización habilitada en BIOS

3. **Instalar**:
   - Ejecutar instalador
   - Seguir el asistente
   - Reiniciar cuando se solicite

4. **Configurar WSL 2**:
   ```powershell
   # En PowerShell como Administrador
   wsl --install
   wsl --set-default-version 2
   ```

### Opción 2: Docker en WSL 2 (Totalmente Gratis)

Si no quieres Docker Desktop:

```bash
# 1. Instalar WSL 2 con Ubuntu
wsl --install -d Ubuntu

# 2. Dentro de WSL Ubuntu, instalar Docker Engine (ver sección Linux arriba)

# 3. Usar desde WSL o Windows Terminal
```

---

## 🍎 Instalación en macOS

### Docker Desktop (más fácil)

1. **Descargar**:
   - https://www.docker.com/products/docker-desktop
   - Elegir versión Intel o Apple Silicon

2. **Instalar**:
   - Abrir .dmg descargado
   - Arrastrar Docker a Applications
   - Iniciar Docker Desktop

3. **Verificar**:
   ```bash
   docker --version
   docker compose version
   ```

### Alternativa: Homebrew

```bash
# Instalar Homebrew si no lo tienes
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Instalar Docker
brew install docker docker-compose
```

---

## ✅ Verificar Instalación

Después de instalar, verifica que funciona:

```bash
# Ver versión
docker --version

# Ver info del sistema
docker info

# Probar con contenedor de prueba
docker run hello-world

# Verificar Docker Compose
docker compose version
```

**Salida esperada de `docker --version`:**
```
Docker version 24.0.0 o superior
```

---

## 🚀 Desplegar MicroarrAI Después de Instalar Docker

Una vez Docker esté instalado:

```bash
# Ir al directorio del proyecto
cd /ruta/a/MicroarrAI

# Opción 1: Script automático (más fácil)
./deploy.sh

# Opción 2: Docker Compose manual
docker compose up -d

# Ver logs
docker compose logs -f

# Acceder
# http://localhost:3838/MicroarrAI
```

---

## 🔧 Configuración Post-Instalación (Linux)

### Usar Docker sin sudo

```bash
# Agregar usuario al grupo docker
sudo usermod -aG docker $USER

# Aplicar cambios (o cerrar sesión y volver a entrar)
newgrp docker

# Probar
docker run hello-world
```

### Configurar inicio automático

```bash
# Habilitar Docker al arranque
sudo systemctl enable docker

# Ver estado
sudo systemctl status docker
```

### Aumentar límites de recursos (opcional)

Edita `/etc/docker/daemon.json`:
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

Reiniciar Docker:
```bash
sudo systemctl restart docker
```

---

## 🐋 Alternativas a Docker

Si no puedes o no quieres usar Docker:

### 1. Podman (Compatible con Docker, 100% Open Source)

```bash
# Ubuntu/Debian
sudo apt install -y podman

# CentOS/RHEL
sudo yum install -y podman

# Usar igual que Docker
podman build -t microarrai .
podman run -p 3838:3838 microarrai

# Crear alias para compatibilidad
alias docker=podman
```

### 2. Ejecutar Directamente con R/Shiny Server

Si no quieres contenedores:

```bash
# Instalar Shiny Server
# Ubuntu/Debian
wget https://download3.rstudio.org/ubuntu-18.04/x86_64/shiny-server-1.5.20.1002-amd64.deb
sudo gdebi shiny-server-1.5.20.1002-amd64.deb

# Instalar R y dependencias (ver README.md)
# Copiar app a /srv/shiny-server/
sudo cp -r /ruta/a/MicroarrAI /srv/shiny-server/

# Acceder
# http://localhost:3838/MicroarrAI
```

### 3. Ejecutar en RStudio

```r
# Abrir proyecto en RStudio
# Instalar dependencias (ver README.md sección "Local Installation")
# Ejecutar:
shiny::runApp()
```

---

## 🆘 Troubleshooting

### Error: "Cannot connect to Docker daemon"

```bash
# Verificar que Docker está corriendo
sudo systemctl status docker

# Iniciar Docker
sudo systemctl start docker

# Verificar permisos
sudo usermod -aG docker $USER
newgrp docker
```

### Error: "permission denied" en /var/run/docker.sock

```bash
# Opción 1: Agregar usuario a grupo docker
sudo usermod -aG docker $USER
newgrp docker

# Opción 2: Cambiar permisos (no recomendado en producción)
sudo chmod 666 /var/run/docker.sock
```

### Docker Desktop no inicia en Windows

1. Verificar que WSL 2 está instalado: `wsl --list`
2. Actualizar WSL: `wsl --update`
3. Habilitar virtualización en BIOS
4. Reiniciar Windows

### Espacio en disco insuficiente

```bash
# Ver uso de espacio
docker system df

# Limpiar recursos no usados
docker system prune -a

# Limpiar volúmenes
docker volume prune
```

---

## 📊 Requisitos de Sistema

### Mínimo para MicroarrAI:
- **CPU**: 2 cores
- **RAM**: 4 GB
- **Disco**: 15 GB (10 GB para imagen Docker + 5 GB datos)
- **OS**: Linux, Windows 10/11, macOS 10.15+

### Recomendado para MicroarrAI:
- **CPU**: 4+ cores
- **RAM**: 8-16 GB
- **Disco**: 25 GB
- **OS**: Linux (mejor rendimiento)

---

## 📚 Recursos Adicionales

- **Documentación oficial de Docker**: https://docs.docker.com/
- **Docker Hub**: https://hub.docker.com/
- **Docker Compose**: https://docs.docker.com/compose/
- **Podman**: https://podman.io/
- **WSL 2**: https://learn.microsoft.com/en-us/windows/wsl/

---

## 🎯 Resumen Rápido

```bash
# 1. Instalar Docker (Ubuntu/Debian)
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker $USER
newgrp docker

# 2. Verificar
docker --version

# 3. Desplegar MicroarrAI
cd MicroarrAI
./deploy.sh

# 4. Acceder
# http://localhost:3838/MicroarrAI
```

---

## 💡 Consejo para Servidores On-Premise

Para un **servidor on-premise en producción**, recomendamos:

1. ✅ **Linux** (Ubuntu Server 22.04 LTS o Rocky Linux 9)
2. ✅ **Docker Engine** (gratis)
3. ✅ **Docker Compose** (gratis)
4. ✅ **Nginx** como reverse proxy (gratis)
5. ✅ **Let's Encrypt** para SSL (gratis)

**Todo es 100% gratuito y open source.**

---

**Última actualización**: Marzo 2026
