#!/bin/bash

# Script to deploy NGINX reverse proxy for Kubernetes ingress
# Usage: ./setup-reverse-proxy.sh [external]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INVENTORY="$SCRIPT_DIR/inventory/all-server.ini"

# Check if external access is requested
if [[ "$1" == "external" ]]; then
    PLAYBOOK="$SCRIPT_DIR/nginx-reverse-proxy-external.yml"
    ACCESS_TYPE="EXTERNAL INTERNET ACCESS"
    echo "🌍 Setting up NGINX Reverse Proxy for EXTERNAL INTERNET ACCESS"
else
    PLAYBOOK="$SCRIPT_DIR/nginx-reverse-proxy.yml"
    ACCESS_TYPE="LOCAL NETWORK ACCESS"
    echo "🏠 Setting up NGINX Reverse Proxy for LOCAL NETWORK ACCESS"
fi

echo "🚀 Setting up NGINX Reverse Proxy for Kubernetes Ingress"
echo "Access Type: $ACCESS_TYPE"
echo "=================================================="

# Check if ansible is installed
if ! command -v ansible-playbook &> /dev/null; then
    echo "❌ Ansible is not installed. Please install ansible first:"
    echo "   sudo apt update && sudo apt install ansible"
    exit 1
fi

# Check if inventory file exists
if [[ ! -f "$INVENTORY" ]]; then
    echo "❌ Inventory file not found: $INVENTORY"
    exit 1
fi

# Check if playbook exists
if [[ ! -f "$PLAYBOOK" ]]; then
    echo "❌ Playbook not found: $PLAYBOOK"
    exit 1
fi

echo "📋 Using inventory: $INVENTORY"
echo "📋 Using playbook: $PLAYBOOK"
echo

# Test connectivity to the Pi
echo "🔍 Testing connectivity to Raspberry Pi..."
if ansible masters -i "$INVENTORY" -m ping; then
    echo "✅ Connection successful!"
else
    echo "❌ Cannot connect to Raspberry Pi. Check:"
    echo "   - SSH key authentication"
    echo "   - Pi is powered on and accessible"
    echo "   - IP address in inventory file"
    exit 1
fi

echo
echo "🔧 Running NGINX reverse proxy setup..."
if [[ "$1" == "external" ]]; then
    echo "This will:"
    echo "   - Install NGINX on your Raspberry Pi"
    echo "   - Configure reverse proxy to your K8s ingress"
    echo "   - Set up failover from LoadBalancer IP to NodePort"
    echo "   - Enable health monitoring"
    echo "   - Configure UFW firewall for external access"
    echo "   - Install and configure fail2ban for security"
    echo "   - Add rate limiting and security headers"
    echo "   - Block common attack patterns"
    echo ""
    echo "⚠️  IMPORTANT: You must configure port forwarding on your router!"
    echo "   Port 80 → 192.168.1.114:80"
    echo "   Port 443 → 192.168.1.114:443"
else
    echo "This will:"
    echo "   - Install NGINX on your Raspberry Pi"
    echo "   - Configure reverse proxy to your K8s ingress"
    echo "   - Set up failover from LoadBalancer IP to NodePort"
    echo "   - Enable health monitoring"
fi
echo

read -p "Continue? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "❌ Aborted"
    exit 1
fi

# Run the playbook (pi user has passwordless sudo)
ansible-playbook -i "$INVENTORY" "$PLAYBOOK"

echo
echo "🎉 NGINX Reverse Proxy setup complete!"
echo

if [[ "$1" == "external" ]]; then
    echo "🌐 EXTERNAL ACCESS CONFIGURED!"
    echo ""
    echo "📋 NEXT STEPS FOR INTERNET ACCESS:"
    echo "1. Configure router port forwarding:"
    echo "   Port 80 → 192.168.1.114:80"
    echo "   Port 443 → 192.168.1.114:443"
    echo ""
    echo "2. Set up domain names (choose one):"
    echo "   - Free DDNS: duckdns.org, no-ip.com"
    echo "   - Buy domain: cloudflare.com, namecheap.com"
    echo "   - Use public IP directly (testing only)"
    echo ""
    echo "3. Find your public IP: curl ipinfo.io/ip"
    echo ""
    echo "📖 See EXTERNAL-ACCESS-GUIDE.md for detailed instructions"
else
    echo "🏠 LOCAL ACCESS CONFIGURED!"
    echo ""
    echo "🌐 Your services should now be accessible at:"
    echo "   - http://shield.mcu.com (via Pi IP)"
    echo "   - http://hydra.mcu.com (via Pi IP)"  
    echo "   - http://mcu.com/shield (via Pi IP)"
    echo "   - http://mcu.com/hydra (via Pi IP)"
    echo ""
    echo "📝 Next steps:"
    echo "   1. Update your laptop's hosts file to point domains to Pi IP (192.168.1.114)"
    echo "   2. Test the endpoints from your browser"
fi
echo
echo "📊 Monitor logs with:"
echo "   - sudo tail -f /var/log/nginx/access.log"
echo "   - sudo tail -f /var/log/nginx/error.log"
echo "   - sudo tail -f /var/log/nginx/k8s-ingress-health.log"