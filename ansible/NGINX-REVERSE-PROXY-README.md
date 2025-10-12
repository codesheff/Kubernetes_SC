# NGINX Reverse Proxy for Kubernetes Ingress

This Ansible playbook sets up an NGINX reverse proxy on your Raspberry Pi to forward requests to your Kubernetes ingress controller.

## Overview

The reverse proxy solves the network connectivity issue between your laptop (WSL) and the Kubernetes LoadBalancer IP by:

1. **Installing NGINX** on your Raspberry Pi
2. **Configuring upstream servers** with automatic failover:
   - Primary: LoadBalancer IP (192.168.1.75:80)
   - Backup: NodePort (192.168.1.114:31763)
3. **Setting up domain routing** for Marvel services
4. **Enabling health monitoring** and logging

## Architecture

```
Your Laptop → Pi NGINX (192.168.1.114:80) → K8s Ingress → Marvel Apps
```

### Domain Mapping

| Domain | Service | Backend |
|--------|---------|---------|
| `shield.mcu.com` | Shield App | Host-based routing |
| `hydra.mcu.com` | Hydra App | Host-based routing |
| `mcu.com/shield` | Shield App | Path-based routing |
| `mcu.com/hydra` | Hydra App | Path-based routing |

## Quick Start

### 1. Run the Setup

```bash
cd /mnt/c/git/SC_Kubernetes/ansible
./setup-reverse-proxy.sh
```

### 2. Configure Your Laptop's Hosts File

**Windows** (C:\\Windows\\System32\\drivers\\etc\\hosts):
```
192.168.1.114 shield.mcu.com
192.168.1.114 hydra.mcu.com
192.168.1.114 mcu.com
```

**Linux/Mac** (/etc/hosts):
```
192.168.1.114 shield.mcu.com
192.168.1.114 hydra.mcu.com
192.168.1.114 mcu.com
```

### 3. Test Access

Open in your browser:
- http://shield.mcu.com
- http://hydra.mcu.com
- http://mcu.com/shield
- http://mcu.com/hydra

Or test with curl:
```bash
curl http://shield.mcu.com
curl http://hydra.mcu.com
curl http://mcu.com/shield
curl http://mcu.com/hydra
```

## Features

### ✅ Automatic Failover
- Primary: LoadBalancer IP (192.168.1.75)
- Backup: NodePort (192.168.1.114:31763)
- Automatic switching on failure

### ✅ Health Monitoring
- Health check endpoint: http://192.168.1.114:8080/health
- Automated upstream monitoring every 5 minutes
- Detailed logging for troubleshooting

### ✅ Optimized Configuration
- Gzip compression
- Connection pooling
- Proper timeout settings
- Request forwarding headers

### ✅ Logging & Monitoring
- Access logs: `/var/log/nginx/access.log`
- Error logs: `/var/log/nginx/error.log`
- Health logs: `/var/log/nginx/k8s-ingress-health.log`

## Manual Setup (Alternative)

If you prefer manual setup instead of Ansible:

### 1. Install NGINX
```bash
ssh pi@192.168.1.114
sudo apt update && sudo apt install nginx
```

### 2. Configure NGINX
```bash
sudo cp /etc/nginx/nginx.conf /etc/nginx/nginx.conf.backup
# Copy the configuration from the playbook
```

### 3. Test and Start
```bash
sudo nginx -t
sudo systemctl restart nginx
sudo systemctl enable nginx
```

## Troubleshooting

### Check NGINX Status
```bash
ssh pi@192.168.1.114
sudo systemctl status nginx
```

### View Logs
```bash
# Real-time access logs
sudo tail -f /var/log/nginx/access.log

# Real-time error logs
sudo tail -f /var/log/nginx/error.log

# Health check logs
sudo tail -f /var/log/nginx/k8s-ingress-health.log
```

### Test Upstream Connectivity
```bash
# Test LoadBalancer IP
curl -H "Host: shield.mcu.com" http://192.168.1.75

# Test NodePort
curl -H "Host: shield.mcu.com" http://192.168.1.114:31763
```

### Restart Services
```bash
# Restart NGINX
sudo systemctl restart nginx

# Reload configuration (no downtime)
sudo nginx -s reload
```

## Configuration Details

### Upstream Configuration
```nginx
upstream k8s_ingress {
    server 192.168.1.75:80 max_fails=3 fail_timeout=30s;
    server 192.168.1.114:31763 backup;
}
```

### Load Balancing Strategy
- **Primary server**: LoadBalancer IP with health checks
- **Backup server**: NodePort (only used if primary fails)
- **Health checks**: 3 failures trigger failover
- **Timeout**: 30-second failure detection

### Headers Forwarded
- `Host`: Original domain name
- `X-Real-IP`: Client's real IP address
- `X-Forwarded-For`: Proxy chain information
- `X-Forwarded-Proto`: Original protocol (http/https)

## Benefits

1. **Network Compatibility**: Bridges WSL/laptop to K8s network
2. **High Availability**: Automatic failover between LoadBalancer and NodePort
3. **Performance**: Connection pooling and compression
4. **Monitoring**: Comprehensive logging and health checks
5. **Scalability**: Easy to add more upstream servers
6. **Security**: Centralized access point with detailed logging

## Files Created

- `/etc/nginx/nginx.conf` - Main NGINX configuration
- `/etc/nginx/sites-available/marvel-ingress` - Marvel domains configuration
- `/etc/nginx/sites-enabled/marvel-ingress` - Enabled site symlink
- `/usr/local/bin/check-k8s-ingress.sh` - Health monitoring script
- `/etc/logrotate.d/nginx-reverse-proxy` - Log rotation configuration

## Next Steps

1. **SSL/TLS**: Add HTTPS support with Let's Encrypt
2. **Caching**: Enable response caching for better performance
3. **Rate Limiting**: Add request rate limiting for security
4. **Monitoring**: Integrate with Prometheus/Grafana
5. **Authentication**: Add basic auth for security if needed