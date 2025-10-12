#!/bin/bash

# Script to rebuild the NGINX reverse proxy configuration
# Usage: ./rebuild-reverse-proxy.sh [external]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INVENTORY="$SCRIPT_DIR/inventory/all-server.ini"

# Check if external access is requested
if [[ "$1" == "external" ]]; then
    PLAYBOOK="$SCRIPT_DIR/nginx-reverse-proxy-external.yml"
    ACCESS_TYPE="EXTERNAL INTERNET ACCESS"
    echo "🌍 Rebuilding NGINX Reverse Proxy for EXTERNAL INTERNET ACCESS"
else
    PLAYBOOK="$SCRIPT_DIR/nginx-reverse-proxy.yml"
    ACCESS_TYPE="LOCAL NETWORK ACCESS"
    echo "🏠 Rebuilding NGINX Reverse Proxy for LOCAL NETWORK ACCESS"
fi

echo "🔄 Rebuilding NGINX Configuration"
echo "Access Type: $ACCESS_TYPE"
echo "=================================================="

# Run the playbook directly without prompts
echo "🔧 Applying updated configuration..."
ansible-playbook -i "$INVENTORY" "$PLAYBOOK"

echo
echo "✅ NGINX Rebuild Complete!"
echo "🌐 Test direct IP access: http://192.168.1.114"
echo "📝 Test domain access after hosts file setup:"
echo "   - http://shield.mcu.com"
echo "   - http://hydra.mcu.com"
echo "   - http://mcu.com/shield"
echo "   - http://mcu.com/hydra"