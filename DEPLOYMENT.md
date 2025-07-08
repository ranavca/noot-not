# Docker Deployment Guide

This guide covers the deployment of the noot-not application stack using Docker containers.

## Architecture Overview

The application is split into two deployment targets:

### Main Server (nootnot.rocks)
- **noot-not-api**: PHP/Laravel API backend
- **noot-not-front**: React frontend
- **MariaDB**: Database
- **Nginx**: Reverse proxy with SSL termination

### Image API Server (image-api.nootnot.rocks)
- **noot-not-image-api**: Python Flask image generation service
- **Nginx**: Reverse proxy with SSL termination (optional)

## Prerequisites

### Both Servers
- Docker Engine 20.10+
- Docker Compose 2.0+
- Minimum 2GB RAM, 20GB disk space
- Ubuntu 20.04+ or similar Linux distribution

### SSL Certificates
You'll need SSL certificates for:
- `nootnot.rocks` and `www.nootnot.rocks`
- `api.nootnot.rocks`
- `image-api.nootnot.rocks`

## Deployment Instructions

### 1. Main Server Deployment

#### Step 1: Prepare the Server
```bash
# Update system
sudo apt update && sudo apt upgrade -y

# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker $USER

# Install Docker Compose
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# Logout and login again for Docker permissions
```

#### Step 2: Clone and Setup
```bash
# Clone the repository
git clone <your-repo-url> noot-not
cd noot-not

# Make deployment scripts executable
chmod +x deploy-main.sh
chmod +x deploy-image-api.sh
```

#### Step 3: Configure SSL Certificates
```bash
# Create SSL directory and copy your certificates
mkdir -p nginx/ssl

# Copy your SSL certificates
# For nootnot.rocks:
cp /path/to/nootnot.rocks.crt nginx/ssl/
cp /path/to/nootnot.rocks.key nginx/ssl/

# For api.nootnot.rocks:
cp /path/to/api.nootnot.rocks.crt nginx/ssl/
cp /path/to/api.nootnot.rocks.key nginx/ssl/
```

#### Step 4: Configure Environment Variables
```bash
# Edit environment variables in docker-compose.yml if needed
# Default production settings should work, but you may want to customize:
# - Database passwords
# - CORS origins
# - Image API URL
```

#### Step 5: Deploy
```bash
# Run the deployment script
./deploy-main.sh production
```

#### Step 6: Verify Deployment
```bash
# Check running containers
docker ps

# Check logs
docker-compose logs -f

# Test endpoints
curl -f https://api.nootnot.rocks/api/health
curl -f https://nootnot.rocks
```

### 2. Image API Server Deployment

#### Step 1: Prepare the Server
```bash
# Same Docker installation as main server
# (Repeat Step 1 from main server deployment)
```

#### Step 2: Clone and Setup
```bash
# Clone the repository (or copy just the noot-not-image-api directory)
git clone <your-repo-url> noot-not
cd noot-not
```

#### Step 3: Upload Font Files
```bash
# Copy required font files to the image API
mkdir -p noot-not-image-api/assets/fonts

# Copy Noto fonts:
cp /path/to/NotoSans-Regular.ttf noot-not-image-api/assets/fonts/
cp /path/to/noto-emoji-bw.ttf noot-not-image-api/assets/fonts/
cp /path/to/NotoColorEmoji.ttf noot-not-image-api/assets/fonts/

# Copy background images (optional)
mkdir -p noot-not-image-api/assets/backgrounds
# Add any background images you want to use
```

#### Step 4: Configure SSL (if using Nginx)
```bash
# If using Nginx reverse proxy for SSL termination
mkdir -p noot-not-image-api/nginx/ssl
cp /path/to/image-api.nootnot.rocks.crt noot-not-image-api/nginx/ssl/
cp /path/to/image-api.nootnot.rocks.key noot-not-image-api/nginx/ssl/
```

#### Step 5: Deploy
```bash
# Run the image API deployment script
./deploy-image-api.sh production

# Or if you want to use Nginx reverse proxy:
cd noot-not-image-api
docker-compose --profile production up -d --build
```

#### Step 6: Verify Deployment
```bash
# Check running containers
docker ps

# Test the service
curl -f https://image-api.nootnot.rocks/health

# Test image generation
curl -X POST https://image-api.nootnot.rocks/generate-images \
  -H "Content-Type: application/json" \
  -d '{"text": "Test confession", "confession_id": "test-123"}'
```

## Configuration Details

### Environment Variables

#### Main Server (docker-compose.yml)
```yaml
# API Service
- DB_HOST=db
- DB_PORT=3306
- DB_NAME=noot_not
- DB_USER=noot_user
- DB_PASSWORD=noot_password
- IMAGE_API_URL=https://image-api.nootnot.rocks
- CORS_ORIGIN=https://nootnot.rocks

# Frontend Service
- VITE_API_BASE_URL=https://api.nootnot.rocks/api
```

#### Image API Server (.env file)
```bash
PORT=8001
HOST=0.0.0.0
DEBUG=False
PHP_API_BASE_URL=https://api.nootnot.rocks
ALLOWED_ORIGINS=https://api.nootnot.rocks,https://nootnot.rocks
```

### Port Configuration

#### Main Server
- **80/443**: Nginx reverse proxy (public)
- **8000**: API service (internal)
- **3000**: Frontend service (internal)
- **3306**: MariaDB (internal)

#### Image API Server
- **80/443**: Nginx reverse proxy (public, optional)
- **8001**: Image API service (public or internal)

## Monitoring and Maintenance

### Health Checks
All services include health checks:
```bash
# Check service health
docker ps --format "table {{.Names}}\t{{.Status}}"

# View health check logs
docker inspect <container-name> | grep -A 10 -B 10 Health
```

### Log Management
```bash
# View logs
docker-compose logs -f [service-name]

# Log rotation is configured automatically
# Logs are stored in volumes: api_logs, db_logs, nginx_logs, image_logs
```

### Database Backups
```bash
# Create database backup
docker exec noot-not-db mysqldump -u root -proot_password noot_not > backup_$(date +%Y%m%d_%H%M%S).sql

# Restore database backup
docker exec -i noot-not-db mysql -u root -proot_password noot_not < backup_file.sql
```

### Updates and Maintenance
```bash
# Pull latest images
docker-compose pull

# Rebuild and restart services
docker-compose up -d --build

# Remove unused images and containers
docker system prune -a
```

## Troubleshooting

### Common Issues

#### Service Won't Start
```bash
# Check logs for errors
docker-compose logs [service-name]

# Check disk space
df -h

# Check Docker daemon
sudo systemctl status docker
```

#### SSL Certificate Issues
```bash
# Verify certificate files
ls -la nginx/ssl/
openssl x509 -in nginx/ssl/nootnot.rocks.crt -text -noout

# Test SSL configuration
openssl s_client -connect nootnot.rocks:443
```

#### Database Connection Issues
```bash
# Check database container
docker exec -it noot-not-db mysql -u root -proot_password

# Check database logs
docker logs noot-not-db

# Reset database (CAUTION: This will delete all data)
docker-compose down -v
docker-compose up -d
```

#### Image Generation Issues
```bash
# Check font files
docker exec noot-not-image-api ls -la /app/assets/fonts/

# Test image generation manually
docker exec -it noot-not-image-api python3 -c "from image_generator import ImageGenerator; print('Fonts working')"

# Check Python service logs
docker logs noot-not-image-api
```

## Security Considerations

### Firewall Configuration
```bash
# Allow only necessary ports
sudo ufw allow 22/tcp    # SSH
sudo ufw allow 80/tcp    # HTTP
sudo ufw allow 443/tcp   # HTTPS
sudo ufw enable
```

### Regular Updates
```bash
# Update system packages monthly
sudo apt update && sudo apt upgrade -y

# Update Docker images
docker-compose pull
docker-compose up -d
```

### Monitoring
Consider setting up monitoring with:
- **Prometheus + Grafana** for metrics
- **ELK Stack** for log aggregation
- **Uptime monitoring** for availability

## Performance Optimization

### Database Optimization
- Configure MySQL/MariaDB settings in `docker-compose.yml`
- Set up read replicas for high traffic
- Implement database connection pooling

### Caching
- Add Redis for API caching
- Use CDN for static assets
- Configure Nginx caching for images

### Scaling
- Use Docker Swarm or Kubernetes for container orchestration
- Implement horizontal scaling for API services
- Use load balancers for multiple instances

## Support

For issues or questions:
1. Check the logs first
2. Review this documentation
3. Check GitHub issues
4. Contact the development team

---

**Last Updated**: $(date +%Y-%m-%d)
**Version**: 1.0.0
