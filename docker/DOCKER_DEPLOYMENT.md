# Docker Deployment Guide - MicroarrAI

This guide explains how to deploy the MicroarrAI application on an on-premise server using Docker.

## Prerequisites

- Docker Engine 20.10+
- Docker Compose 2.0+ (optional but recommended)
- 8GB RAM minimum (16GB recommended)
- 4 CPU cores minimum
- 10GB disk space

## Method 1: Simple Docker Build

### Building the Image

```bash
# Clone the repository (if necessary)
git clone <repository-url>
cd MicroarrAI

# Build the Docker image
docker build -t microarrai:latest .
```

The build may take 15-30 minutes depending on your connection and server resources.

### Running the Container

```bash
# Basic run
docker run --rm -p 3838:3838 microarrai:latest

# Run with logs persistence
docker run --rm -p 3838:3838 \
  -v $(pwd)/logs:/var/log/shiny-server \
  microarrai:latest

# Run in background (production)
docker run -d \
  --name microarrai-app \
  --restart unless-stopped \
  -p 3838:3838 \
  -v $(pwd)/logs:/var/log/shiny-server \
  microarrai:latest
```

### Accessing the Application

Open your browser at:
```
http://localhost:3838/MicroarrAI
```

Or from another machine:
```
http://<server-ip>:3838/MicroarrAI
```

## Method 2: Docker Compose (Recommended)

### Start the Application

```bash
# Start in the background
docker-compose up -d

# View logs in real-time
docker-compose logs -f
```

### Container Management

```bash
# Stop the application
docker-compose down

# Restart the application
docker-compose restart

# Rebuild and restart
docker-compose up -d --build

# View status
docker-compose ps
```

## Advanced Configuration

### Customize Port

Edit `docker-compose.yml`:
```yaml
ports:
  - "8080:3838"  # Change 8080 to desired port
```

### Resource Limits

Edit `docker-compose.yml`:
```yaml
deploy:
  resources:
    limits:
      cpus: '8'      # Adjust according to server
      memory: 16G    # Adjust according to server
```

### Custom Shiny Server Configuration

1. Uncomment this line in `Dockerfile`:
```dockerfile
COPY shiny-server.conf /etc/shiny-server/shiny-server.conf
```

2. Edit `shiny-server.conf` as needed

3. Rebuild the image:
```bash
docker build -t microarrai:latest .
```

### Data Persistence

To persist data uploaded by users, uncomment in `docker-compose.yml`:
```yaml
volumes:
  - ./data:/srv/shiny-server/MicroarrAI/data
```

## Security and Production

### Use with Reverse Proxy (Nginx)

Example Nginx configuration:

```nginx
server {
    listen 80;
    server_name microarrai.your-domain.com;

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

### HTTPS with Let's Encrypt

```bash
# Install certbot
sudo apt-get install certbot python3-certbot-nginx

# Get certificate
sudo certbot --nginx -d microarrai.your-domain.com
```

### Firewall

```bash
# Allow only port 3838 locally (if using nginx)
sudo ufw allow from 127.0.0.1 to any port 3838

# Or allow direct access from any IP
sudo ufw allow 3838/tcp
```

## Monitoring

### View Logs

```bash
# Docker Compose
docker-compose logs -f

# Direct Docker
docker logs -f microarrai-app

# Shiny Server logs (if volume is mounted)
tail -f logs/*.log
```

### Check Resources

```bash
# View container resource usage
docker stats microarrai-app
```

### Health Check

```bash
# Verify app is responding
curl http://localhost:3838/MicroarrAI
```

## Troubleshooting

### Image takes a long time to build
- This is normal, R packages installation can take 15-30 mins
- The image uses cached layers, subsequent builds are faster

### Error: "Cannot allocate memory"
- Increase RAM available to Docker
- Reduce limits in docker-compose.yml

### Container stops unexpectedly
```bash
# View error logs
docker logs microarrai-app

# Check resources
docker stats microarrai-app
```

### Missing R package
1. Edit `Dockerfile` and add the package
2. Rebuild:
```bash
docker build -t microarrai:latest .
docker-compose up -d
```

## Application Update

```bash
# 1. Stop container
docker-compose down

# 2. Update code
git pull

# 3. Rebuild and restart
docker-compose up -d --build
```

## Cleanup

```bash
# Stop and remove container
docker-compose down

# Remove image
docker rmi microarrai:latest

# Clean unused Docker resources
docker system prune -a
```

## Additional Notes

- **First start**: May take 1-2 minutes while R loads all packages
- **Image size**: ~4-5 GB due to all ML and visualization packages
- **Memory**: App can use 2-4GB RAM with large datasets
- **CPU**: Intensive ML analyses benefit from multiple cores

## Support

If you encounter problems:
1. Check logs: `docker-compose logs -f`
2. Check resources: `docker stats`
3. Consult documentation in `/docs`

---

**Last update**: March 2026
