# SSL Setup Deployment Guide

## Overview

This guide explains how to deploy and run the SSL setup script on your Linux server.

## Prerequisites on Linux Server

1. **Docker and Docker Compose installed**
2. **Domain DNS properly configured** pointing to your server IP
3. **Ports 80 and 443 open** in firewall
4. **Project files deployed** to the server

## Step-by-Step Deployment

### 1. Transfer Files to Server

```bash
# From your local machine, copy the project to the server
scp -r /Users/raymond/Desktop/noot-not user@your-server-ip:/path/to/deployment/

# Or if using git:
# git clone your-repo
# git pull latest changes
```

### 2. Connect to Your Linux Server

```bash
ssh user@your-server-ip
cd /path/to/deployment/noot-not
```

### 3. Verify Prerequisites on Server

```bash
# Check Docker is installed and running
docker --version
docker-compose --version
sudo systemctl status docker

# Start Docker if not running
sudo systemctl start docker
sudo systemctl enable docker

# Add your user to docker group (optional, to avoid sudo)
sudo usermod -aG docker $USER
# Then logout and login again
```

### 4. Verify Domain DNS Configuration

```bash
# Check if domains point to your server
nslookup nootnot.rocks
nslookup www.nootnot.rocks
nslookup api.nootnot.rocks

# Or use dig
dig nootnot.rocks
dig www.nootnot.rocks
dig api.nootnot.rocks
```

### 5. Configure Firewall (if needed)

```bash
# For Ubuntu/Debian with ufw
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw reload

# For CentOS/RHEL with firewalld
sudo firewall-cmd --permanent --add-port=80/tcp
sudo firewall-cmd --permanent --add-port=443/tcp
sudo firewall-cmd --reload

# For iptables
sudo iptables -A INPUT -p tcp --dport 80 -j ACCEPT
sudo iptables -A INPUT -p tcp --dport 443 -j ACCEPT
```

### 6. Run the SSL Setup Script

```bash
# Make sure you're in the project directory
cd /path/to/deployment/noot-not

# Make the script executable (if not already)
chmod +x setup-ssl.sh

# Run the script (NOT as root!)
./setup-ssl.sh
```

### 7. Follow the Interactive Prompts

The script will ask for:

- **Email address** for Let's Encrypt notifications
- **Confirmation** to proceed with domain configuration

### 8. Verify SSL Setup

After successful completion:

```bash
# Check certificate status
./check-ssl.sh

# Test HTTPS access
curl -I https://nootnot.rocks
curl -I https://www.nootnot.rocks
curl -I https://api.nootnot.rocks

# Check SSL rating
curl -s "https://api.ssllabs.com/api/v3/analyze?host=nootnot.rocks" | jq
```

## Troubleshooting

### Common Issues

1. **DNS not propagated**

   ```bash
   # Wait for DNS propagation (can take up to 48 hours)
   # Verify with: dig nootnot.rocks
   ```

2. **Firewall blocking ports**

   ```bash
   # Check if ports are open
   sudo netstat -tlnp | grep :80
   sudo netstat -tlnp | grep :443
   ```

3. **Docker permission issues**

   ```bash
   # Add user to docker group
   sudo usermod -aG docker $USER
   # Logout and login again
   ```

4. **Certificate generation fails**

   ```bash
   # Check nginx logs
   docker-compose logs nginx

   # Check certbot logs
   docker-compose -f docker-compose.yml -f docker-compose.ssl.yml logs certbot
   ```

### Manual Certificate Renewal

```bash
# Run the renewal script
./renew-ssl.sh

# Or manually
docker-compose -f docker-compose.yml -f docker-compose.ssl.yml run --rm certbot \
    certbot renew --quiet
```

## Automatic Renewal

The script sets up a cron job for automatic renewal. To verify:

```bash
# Check if cron job was added
crontab -l | grep renew-ssl

# Check cron service is running
sudo systemctl status cron     # Ubuntu/Debian
sudo systemctl status crond    # CentOS/RHEL
```

## Security Notes

- ✅ Never run the script as root
- ✅ Keep your server updated
- ✅ Monitor certificate expiration
- ✅ Regularly check SSL configuration
- ✅ Use strong passwords for admin accounts

## Post-Setup Checklist

- [ ] All domains accessible via HTTPS
- [ ] HTTP redirects to HTTPS working
- [ ] SSL certificates valid and trusted
- [ ] Automatic renewal configured
- [ ] Firewall properly configured
- [ ] DNS records properly set
- [ ] Application functionality verified

## Support

If you encounter issues:

1. Check the logs: `docker-compose logs`
2. Verify DNS propagation
3. Ensure firewall ports are open
4. Check domain ownership
5. Verify Docker is running properly
