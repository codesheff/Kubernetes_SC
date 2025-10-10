#!/bin/bash

# ============================================
# NGINX Reverse Proxy Setup for Ingress
# ============================================
# This script sets up nginx on the master node to proxy
# HTTP traffic from port 80 to the ingress controller NodePort

echo "Installing nginx on master node..."

# Install nginx
sudo apt update
sudo apt install -y nginx

# Create nginx configuration for ingress proxy
sudo tee /etc/nginx/sites-available/ingress-proxy > /dev/null << 'EOF'
server {
    listen 80;
    server_name shield.mcu.com hydra.mcu.com mcu.com;
    
    # Proxy all requests to ingress controller
    location / {
        proxy_pass http://127.0.0.1:31877;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
EOF

# Enable the site
sudo ln -sf /etc/nginx/sites-available/ingress-proxy /etc/nginx/sites-enabled/
sudo rm -f /etc/nginx/sites-enabled/default

# Test nginx configuration
sudo nginx -t

# Restart nginx
sudo systemctl restart nginx
sudo systemctl enable nginx

echo "✅ Nginx reverse proxy configured!"
echo "You can now access:"
echo "  http://shield.mcu.com/"
echo "  http://hydra.mcu.com/"
echo "  http://mcu.com/shield"
echo "  http://mcu.com/hydra"