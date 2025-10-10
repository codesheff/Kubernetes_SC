#!/bin/bash

# ============================================
# SSH Tunnel Setup for MetalLB Access
# ============================================
# This script creates SSH tunnels to access the MetalLB 
# ingress from remote/WSL environments

echo "============================================"
echo "SSH TUNNEL SETUP FOR METALLB ACCESS"
echo "============================================"
echo ""

# Get the MetalLB external IP
METALLB_IP=$(kubectl get svc ingress-nginx-controller -n ingress-nginx -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

echo "🔧 Current MetalLB Configuration:"
echo "External IP: $METALLB_IP"
echo "Raspberry Pi: master (192.168.1.112)"
echo ""

echo "📋 SSH Tunnel Options:"
echo ""

echo "Option 1: HTTP Tunnel (Port 8080)"
echo "Command: ssh -L 8080:$METALLB_IP:80 master"
echo "Access: http://localhost:8080"
echo "Note: Add Host headers for routing"
echo ""

echo "Option 2: Multiple Domain Tunnels"
echo "ssh -L 8081:$METALLB_IP:80 -L 8082:$METALLB_IP:80 -L 8083:$METALLB_IP:80 master"
echo ""

echo "Option 3: HTTPS Tunnel (Port 8443)"
echo "Command: ssh -L 8443:$METALLB_IP:443 master"
echo "Access: https://localhost:8443"
echo ""

echo "============================================"
echo "TESTING COMMANDS"
echo "============================================"
echo ""

echo "Once tunnel is established, test with:"
echo ""
echo "# Test Shield app"
echo "curl -H 'Host: shield.mcu.com' http://localhost:8080"
echo ""
echo "# Test Hydra app"
echo "curl -H 'Host: hydra.mcu.com' http://localhost:8080"
echo ""
echo "# Test path-based routing"
echo "curl -H 'Host: mcu.com' http://localhost:8080/shield"
echo "curl -H 'Host: mcu.com' http://localhost:8080/hydra"
echo ""

echo "============================================"
echo "BROWSER ACCESS"
echo "============================================"
echo ""

echo "🌐 For browser access, you have two options:"
echo ""

echo "Option A: Use localhost with browser extensions"
echo "- Install a browser extension to modify Host headers"
echo "- Access http://localhost:8080"
echo "- Set Host header to: shield.mcu.com, hydra.mcu.com, etc."
echo ""

echo "Option B: Update Windows hosts file (if using WSL)"
echo "- File location: C:\\Windows\\System32\\drivers\\etc\\hosts"
echo "- Add: 127.0.0.1 shield.mcu.com hydra.mcu.com mcu.com"
echo "- Create tunnel: ssh -L 80:$METALLB_IP:80 master"
echo "- Access: http://shield.mcu.com/, http://hydra.mcu.com/"
echo ""

echo "============================================"
echo "QUICK START"
echo "============================================"
echo ""

echo "🚀 To start SSH tunnel now:"
echo "ssh -L 8080:$METALLB_IP:80 master"
echo ""
echo "Then test:"
echo "curl -H 'Host: shield.mcu.com' http://localhost:8080"
echo ""

# Offer to create the tunnel
read -p "📞 Would you like to create the SSH tunnel now? (y/n): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "Creating SSH tunnel to $METALLB_IP..."
    echo "Access your ingress at: http://localhost:8080"
    echo "Use Ctrl+C to stop the tunnel"
    ssh -L 8080:$METALLB_IP:80 master
fi