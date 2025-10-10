#!/bin/bash

# ============================================
# External Access Test Script
# ============================================

PUBLIC_IP="146.198.242.247"  # Your current public IP
METALLB_IP="192.168.1.75"    # MetalLB assigned IP

echo "============================================"
echo "EXTERNAL ACCESS CONFIGURATION TEST"
echo "============================================"
echo ""

echo "🌐 Network Configuration:"
echo "Public IP: $PUBLIC_IP"
echo "MetalLB IP: $METALLB_IP"
echo "Router: 192.168.1.254"
echo ""

echo "📋 Required Router Port Forwarding:"
echo "External Port 80  → $METALLB_IP:80  (HTTP)"
echo "External Port 443 → $METALLB_IP:443 (HTTPS)"
echo ""

echo "🔧 Testing Internal Access (should work now):"
echo ""

# Test from master node
echo "Testing from master node..."
if ssh master "curl -s -H 'Host: shield.mcu.com' http://$METALLB_IP | grep -q 'S.H.I.E.L.D'"; then
    echo "✅ Internal shield routing: SUCCESS"
else
    echo "❌ Internal shield routing: FAILED"
fi

if ssh master "curl -s -H 'Host: hydra.mcu.com' http://$METALLB_IP | grep -q 'Hydra'"; then
    echo "✅ Internal hydra routing: SUCCESS"
else
    echo "❌ Internal hydra routing: FAILED"
fi

echo ""
echo "🌍 External Access Test Commands:"
echo ""
echo "After configuring router port forwarding, test with:"
echo ""
echo "# Test from external network:"
echo "curl -H 'Host: shield.mcu.com' http://$PUBLIC_IP"
echo "curl -H 'Host: hydra.mcu.com' http://$PUBLIC_IP"
echo "curl -H 'Host: mcu.com' http://$PUBLIC_IP/shield"
echo ""

echo "🏠 Browser Access Setup:"
echo ""
echo "1. Configure router port forwarding (see EXTERNAL-ACCESS-GUIDE.md)"
echo "2. Set up DNS or use hosts file:"
echo ""
echo "   # Option A: Real domain DNS records"
echo "   shield.yourdomain.com  → $PUBLIC_IP"
echo "   hydra.yourdomain.com   → $PUBLIC_IP"
echo ""
echo "   # Option B: Local hosts file for testing"
echo "   # Add to /etc/hosts (Linux/Mac) or C:\\Windows\\System32\\drivers\\etc\\hosts (Windows):"
echo "   $PUBLIC_IP shield.mcu.com"
echo "   $PUBLIC_IP hydra.mcu.com"
echo "   $PUBLIC_IP mcu.com"
echo ""

echo "🎯 Access URLs (after DNS setup):"
echo "http://shield.mcu.com/"
echo "http://hydra.mcu.com/"
echo "http://mcu.com/shield"
echo "http://mcu.com/hydra"
echo ""

echo "============================================"
echo "ROUTER CONFIGURATION CHECKLIST"
echo "============================================"
echo ""
echo "□ Access router admin (usually http://192.168.1.1 or http://192.168.1.254)"
echo "□ Navigate to Port Forwarding section"
echo "□ Add rule: External 80 → $METALLB_IP:80"
echo "□ Add rule: External 443 → $METALLB_IP:443"
echo "□ Save configuration"
echo "□ Restart router (if required)"
echo "□ Test external access"
echo ""

echo "✅ Your MetalLB LoadBalancer is ready for external traffic!"
echo "The setup provides production-grade external access on standard ports."