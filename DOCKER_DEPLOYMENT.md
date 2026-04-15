# Guía de Despliegue con Docker - MicroarrAI

Esta guía explica cómo desplegar la aplicación MicroarrAI en un servidor on-premise usando Docker.

## 📋 Requisitos Previos

- Docker Engine 20.10+
- Docker Compose 2.0+ (opcional pero recomendado)
- 8GB RAM mínimo (16GB recomendado)
- 4 CPU cores mínimo
- 10GB espacio en disco

## 🚀 Método 1: Docker Build Simple

### Construcción de la Imagen

```bash
# Clonar el repositorio (si es necesario)
git clone <repository-url>
cd MicroarrAI

# Construir la imagen Docker
docker build -t microarrai:latest .
```

La construcción puede tardar 15-30 minutos dependiendo de tu conexión y recursos del servidor.

### Ejecución del Contenedor

```bash
# Ejecución básica
docker run --rm -p 3838:3838 microarrai:latest

# Ejecución con persistencia de logs
docker run --rm -p 3838:3838 \
  -v $(pwd)/logs:/var/log/shiny-server \
  microarrai:latest

# Ejecución en segundo plano (producción)
docker run -d \
  --name microarrai-app \
  --restart unless-stopped \
  -p 3838:3838 \
  -v $(pwd)/logs:/var/log/shiny-server \
  microarrai:latest
```

### Acceso a la Aplicación

Abre tu navegador en:
```
http://localhost:3838/MicroarrAI
```

O desde otra máquina:
```
http://<ip-del-servidor>:3838/MicroarrAI
```

## 🐳 Método 2: Docker Compose (Recomendado)

### Iniciar la Aplicación

```bash
# Iniciar en segundo plano
docker-compose up -d

# Ver logs en tiempo real
docker-compose logs -f
```

### Gestión del Contenedor

```bash
# Detener la aplicación
docker-compose down

# Reiniciar la aplicación
docker-compose restart

# Re-construir y reiniciar
docker-compose up -d --build

# Ver estado
docker-compose ps
```

## 🔧 Configuración Avanzada

### Personalizar Puerto

Edita `docker-compose.yml`:
```yaml
ports:
  - "8080:3838"  # Cambiar 8080 al puerto deseado
```

### Limites de Recursos

Edita `docker-compose.yml`:
```yaml
deploy:
  resources:
    limits:
      cpus: '8'      # Ajustar según servidor
      memory: 16G    # Ajustar según servidor
```

### Configuración Personalizada de Shiny Server

1. Descomenta esta línea en `Dockerfile`:
```dockerfile
COPY shiny-server.conf /etc/shiny-server/shiny-server.conf
```

2. Edita `shiny-server.conf` según necesites

3. Reconstruye la imagen:
```bash
docker build -t microarrai:latest .
```

### Persistencia de Datos

Para persistir datos cargados por usuarios, descomenta en `docker-compose.yml`:
```yaml
volumes:
  - ./data:/srv/shiny-server/MicroarrAI/data
```

## 🔒 Seguridad y Producción

### Uso con Reverse Proxy (Nginx)

Configuración Nginx de ejemplo:

```nginx
server {
    listen 80;
    server_name microarrai.tu-dominio.com;

    location / {
        proxy_pass http://localhost:3838/MicroarrAI/;
        proxy_redirect http://localhost:3838/ $scheme://$host/;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_read_timeout 20d;
        proxy_buffering off;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

### HTTPS con Let's Encrypt

```bash
# Instalar certbot
sudo apt-get install certbot python3-certbot-nginx

# Obtener certificado
sudo certbot --nginx -d microarrai.tu-dominio.com
```

### Firewall

```bash
# Permitir solo puerto 3838 localmente (si usas nginx)
sudo ufw allow from 127.0.0.1 to any port 3838

# O permitir acceso directo desde cualquier IP
sudo ufw allow 3838/tcp
```

## 📊 Monitoreo

### Ver Logs

```bash
# Docker Compose
docker-compose logs -f

# Docker directo
docker logs -f microarrai-app

# Logs de Shiny Server (si montas el volumen)
tail -f logs/*.log
```

### Verificar Recursos

```bash
# Ver uso de recursos del contenedor
docker stats microarrai-app
```

### Health Check

```bash
# Verificar que la app responde
curl http://localhost:3838/MicroarrAI
```

## 🛠️ Troubleshooting

### La imagen tarda mucho en construirse
- Es normal, la instalación de paquetes R puede tardar 15-30 min
- La imagen usa capas cacheadas, reconstrucciones posteriores son más rápidas

### Error: "Cannot allocate memory"
- Aumenta la RAM disponible para Docker
- Reduce los límites en docker-compose.yml

### El contenedor se detiene inesperadamente
```bash
# Ver logs de error
docker logs microarrai-app

# Verificar recursos
docker stats microarrai-app
```

### Paquete R falta
1. Edita `Dockerfile` y añade el paquete
2. Reconstruye:
```bash
docker build -t microarrai:latest .
docker-compose up -d
```

## 🔄 Actualización de la Aplicación

```bash
# 1. Detener contenedor
docker-compose down

# 2. Actualizar código
git pull

# 3. Reconstruir y reiniciar
docker-compose up -d --build
```

## 🗑️ Limpieza

```bash
# Detener y eliminar contenedor
docker-compose down

# Eliminar imagen
docker rmi microarrai:latest

# Limpiar recursos no usados de Docker
docker system prune -a
```

## 📝 Notas Adicionales

- **Primer inicio**: Puede tardar 1-2 minutos mientras R carga todos los paquetes
- **Tamaño de imagen**: ~4-5 GB debido a todos los paquetes de ML y visualización
- **Memoria**: La app puede usar 2-4GB RAM con datasets grandes
- **CPU**: Análisis ML intensivos se benefician de múltiples cores

## 📞 Soporte

Si encuentras problemas:
1. Revisa los logs: `docker-compose logs -f`
2. Verifica recursos: `docker stats`
3. Consulta la documentación en `/docs`

---

**Última actualización**: Marzo 2026
