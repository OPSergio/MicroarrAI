# MicroarrAI - Docker Quick Reference

## Essential Commands

### Quick Start

```bash
# Easiest method (interactive)
./deploy.sh

# Direct method
docker-compose up -d
```

Access: **http://localhost:3838/MicroarrAI**

---

## Container Management

### Build and Start

```bash
# First time - build image
docker-compose build

# Start in background
docker-compose up -d

# View logs in real-time
docker-compose logs -f

# Start and view logs at the same time
docker-compose up
```

### Stop and Restart

```bash
# Stop
docker-compose down

# Restart
docker-compose restart

# Stop and remove volumes
docker-compose down -v
```

### Update Application

```bash
# Option 1: Rebuild everything
docker-compose down
docker-compose build --no-cache
docker-compose up -d

# Option 2: Only rebuild
docker-compose up -d --build

# Option 3: Use script
./deploy.sh  # Option 5
```

---

## Monitoring and Debugging

### View Logs

```bash
# All logs
docker-compose logs

# Real-time logs
docker-compose logs -f

# Last 100 lines
docker-compose logs --tail=100

# Specific Docker logs
docker logs microarrai-app

# Shiny Server logs (if volume mounted)
tail -f logs/microarrai-shiny-*.log
```

### System Status

```bash
# View active containers
docker-compose ps

# Resource usage
docker stats microarrai-app

# Detailed information
docker inspect microarrai-app

# View processes inside the container
docker-compose top
```

### Access Container

```bash
# Open interactive shell
docker-compose exec microarrai /bin/bash

# Execute R command
docker-compose exec microarrai R --version

# View app files
docker-compose exec microarrai ls -la /srv/shiny-server/MicroarrAI
```

---

## Configuration

### Change Port

Edit `docker-compose.yml`:
```yaml
ports:
  - "8080:3838"  # Change 8080 to the desired port
```

Then:
```bash
docker-compose down
docker-compose up -d
```

### Adjust Resources

Edit `docker-compose.yml`:
```yaml
deploy:
  resources:
    limits:
      cpus: '8'
      memory: 16G
```

### Environment Variables

```bash
# Copy the example file
cp .env.example .env

# Edit as needed
nano .env

# Apply changes
docker-compose up -d
```

---

## Data Persistence

### Mount Data Directory

Edit `docker-compose.yml` - uncomment:
```yaml
volumes:
  - ./data:/srv/shiny-server/MicroarrAI/data
```

```bash
# Create directory
mkdir -p data

# Restart
docker-compose down
docker-compose up -d
```

### Data Backup

```bash
# Copy data from the container
docker cp microarrai-app:/srv/shiny-server/MicroarrAI/data ./backup

# Restore data
docker cp ./backup microarrai-app:/srv/shiny-server/MicroarrAI/data
```

---

## Cleanup

### Basic Cleanup

```bash
# Stop and remove container
docker-compose down

# Remove image
docker rmi microarrai:latest
```

### Deep Cleanup

```bash
# Stop everything
docker-compose down -v

# Remove image
docker rmi microarrai:latest

# Clean unused Docker resources
docker system prune -a

# Clean orphan volumes
docker volume prune
```

---

## Production

### Run with Nginx (Reverse Proxy)

```nginx
# /etc/nginx/sites-available/microarrai
server {
    listen 80;
    server_name your-domain.com;

    location / {
        proxy_pass http://localhost:3838/MicroarrAI/;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_read_timeout 20d;
        proxy_buffering off;
    }
}
```

```bash
# Activate configuration
sudo ln -s /etc/nginx/sites-available/microarrai /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl reload nginx
```

### HTTPS with Certbot

```bash
sudo certbot --nginx -d your-domain.com
```

### Configure as Systemd Service

```bash
# Create service file
sudo nano /etc/systemd/system/microarrai.service
```

```ini
[Unit]
Description=MicroarrAI Docker Container
Requires=docker.service
After=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=/path/to/MicroarrAI
ExecStart=/usr/bin/docker-compose up -d
ExecStop=/usr/bin/docker-compose down
TimeoutStartSec=0

[Install]
WantedBy=multi-user.target
```

```bash
# Activate service
sudo systemctl enable microarrai
sudo systemctl start microarrai
sudo systemctl status microarrai
```

---

## Troubleshooting

### Container does not start

```bash
# View error logs
docker-compose logs

# View Docker events
docker events

# Verificar configuración
docker-compose config
```

### Error de puerto en uso

```bash
# Encontrar qué usa el puerto 3838
sudo lsof -i :3838

# Matar proceso
sudo kill -9 <PID>

# O cambiar puerto en docker-compose.yml
```

### Problemas de memoria

```bash
# Ver uso actual
docker stats microarrai-app

# Aumentar límite en docker-compose.yml
# Reiniciar Docker daemon
sudo systemctl restart docker
```

### Problemas de permisos

```bash
# Arreglar permisos de logs
sudo chown -R $USER:$USER logs/

# Dentro del contenedor
docker-compose exec microarrai chown -R shiny:shiny /srv/shiny-server/MicroarrAI
```

---

## 📊 Health Check

```bash
# Check HTTP
curl -f http://localhost:3838/MicroarrAI || echo "App no responde"

# Check desde otro servidor
curl -f http://<server-ip>:3838/MicroarrAI

# Ping al contenedor
docker-compose exec microarrai ping -c 3 google.com
```

---

## 🔗 Enlaces Útiles

- **Documentación completa**: [DOCKER_DEPLOYMENT.md](DOCKER_DEPLOYMENT.md)
- **Configuración**: [.env.example](.env.example)
- **Docker Hub**: https://hub.docker.com/
- **Shiny Server**: https://shiny.rstudio.com/

---

**Última actualización**: Marzo 2026
