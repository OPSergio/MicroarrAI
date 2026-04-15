# MicroarrAI - Referencia Rápida Docker

## 🚀 Comandos Esenciales

### Inicio Rápido

```bash
# Método más fácil (interactivo)
./deploy.sh

# Método directo
docker-compose up -d
```

Acceder: **http://localhost:3838/MicroarrAI**

---

## 📦 Gestión del Contenedor

### Construir e Iniciar

```bash
# Primera vez - construir imagen
docker-compose build

# Iniciar en segundo plano
docker-compose up -d

# Ver logs en tiempo real
docker-compose logs -f

# Iniciar y ver logs al mismo tiempo
docker-compose up
```

### Detener y Reiniciar

```bash
# Detener
docker-compose down

# Reiniciar
docker-compose restart

# Detener y eliminar volúmenes
docker-compose down -v
```

### Actualizar Aplicación

```bash
# Opción 1: Reconstruir todo
docker-compose down
docker-compose build --no-cache
docker-compose up -d

# Opción 2: Solo reconstruir
docker-compose up -d --build

# Opción 3: Usar script
./deploy.sh  # Opción 5
```

---

## 🔍 Monitoreo y Debug

### Ver Logs

```bash
# Todos los logs
docker-compose logs

# Logs en tiempo real
docker-compose logs -f

# Últimas 100 líneas
docker-compose logs --tail=100

# Logs de Docker específicos
docker logs microarrai-app

# Logs de Shiny Server (si montaste volumen)
tail -f logs/microarrai-shiny-*.log
```

### Estado del Sistema

```bash
# Ver contenedores activos
docker-compose ps

# Uso de recursos
docker stats microarrai-app

# Información detallada
docker inspect microarrai-app

# Ver procesos dentro del contenedor
docker-compose top
```

### Acceder al Contenedor

```bash
# Abrir shell interactiva
docker-compose exec microarrai /bin/bash

# Ejecutar comando R
docker-compose exec microarrai R --version

# Ver archivos de la app
docker-compose exec microarrai ls -la /srv/shiny-server/MicroarrAI
```

---

## ⚙️ Configuración

### Cambiar Puerto

Edita `docker-compose.yml`:
```yaml
ports:
  - "8080:3838"  # Cambia 8080 al puerto deseado
```

Luego:
```bash
docker-compose down
docker-compose up -d
```

### Ajustar Recursos

Edita `docker-compose.yml`:
```yaml
deploy:
  resources:
    limits:
      cpus: '8'
      memory: 16G
```

### Variables de Entorno

```bash
# Copia el archivo de ejemplo
cp .env.example .env

# Edita según necesites
nano .env

# Aplica cambios
docker-compose up -d
```

---

## 🗄️ Persistencia de Datos

### Montar Directorio de Datos

Edita `docker-compose.yml` - descomenta:
```yaml
volumes:
  - ./data:/srv/shiny-server/MicroarrAI/data
```

```bash
# Crear directorio
mkdir -p data

# Reiniciar
docker-compose down
docker-compose up -d
```

### Backup de Datos

```bash
# Copiar datos desde el contenedor
docker cp microarrai-app:/srv/shiny-server/MicroarrAI/data ./backup

# Restaurar datos
docker cp ./backup microarrai-app:/srv/shiny-server/MicroarrAI/data
```

---

## 🧹 Limpieza

### Limpieza Básica

```bash
# Detener y eliminar contenedor
docker-compose down

# Eliminar imagen
docker rmi microarrai:latest
```

### Limpieza Profunda

```bash
# Detener todo
docker-compose down -v

# Eliminar imagen
docker rmi microarrai:latest

# Limpiar recursos no usados de Docker
docker system prune -a

# Limpiar volúmenes huérfanos
docker volume prune
```

---

## 🔒 Producción

### Ejecutar con Nginx (Reverse Proxy)

```nginx
# /etc/nginx/sites-available/microarrai
server {
    listen 80;
    server_name tu-dominio.com;

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
# Activar configuración
sudo ln -s /etc/nginx/sites-available/microarrai /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl reload nginx
```

### HTTPS con Certbot

```bash
sudo certbot --nginx -d tu-dominio.com
```

### Configurar como Servicio Systemd

```bash
# Crear archivo de servicio
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
# Activar servicio
sudo systemctl enable microarrai
sudo systemctl start microarrai
sudo systemctl status microarrai
```

---

## 🐛 Troubleshooting

### Contenedor no inicia

```bash
# Ver logs de error
docker-compose logs

# Ver eventos de Docker
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
