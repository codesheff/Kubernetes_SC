#!/bin/bash

# ============================================
# Ingress Testing Script
# ============================================

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Get the ingress controller service details
echo -e "${BLUE}============================================${NC}"
echo -e "${BLUE}INGRESS CONTROLLER STATUS${NC}"
echo -e "${BLUE}============================================${NC}"

# Get NodePort details
INGRESS_HTTP_PORT=$(kubectl get svc ingress-nginx-controller -n ingress-nginx -o jsonpath='{.spec.ports[?(@.port==80)].nodePort}')
INGRESS_HTTPS_PORT=$(kubectl get svc ingress-nginx-controller -n ingress-nginx -o jsonpath='{.spec.ports[?(@.port==443)].nodePort}')
NODE_IP="192.168.1.114"  # Your master node IP

echo "Node IP: $NODE_IP"
echo "HTTP Port: $INGRESS_HTTP_PORT"
echo "HTTPS Port: $INGRESS_HTTPS_PORT"
echo ""

# Function to test URL
test_url() {
    local url=$1
    local description=$2
    echo -e "${YELLOW}Testing: $description${NC}"
    echo "URL: $url"
    
    response=$(curl -s -w "HTTP_CODE:%{http_code}" "$url" 2>/dev/null)
    http_code=$(echo "$response" | grep -o "HTTP_CODE:[0-9]*" | cut -d: -f2)
    content=$(echo "$response" | sed 's/HTTP_CODE:[0-9]*$//')
    
    if [ "$http_code" = "200" ]; then
        echo -e "${GREEN}✅ SUCCESS (HTTP $http_code)${NC}"
        echo "Response: $content"
    elif [ "$http_code" = "404" ]; then
        echo -e "${YELLOW}⚠️  NOT FOUND (HTTP $http_code)${NC}"
        echo "This is expected if no ingress rules match"
    else
        echo -e "${RED}❌ FAILED (HTTP $http_code)${NC}"
        echo "Response: $content"
    fi
    echo ""
}

# Test basic ingress controller
echo -e "${BLUE}============================================${NC}"
echo -e "${BLUE}BASIC INGRESS CONTROLLER TEST${NC}"
echo -e "${BLUE}============================================${NC}"
test_url "http://$NODE_IP:$INGRESS_HTTP_PORT" "Basic ingress controller (should return 404)"

# Test with Host headers (once you deploy the applications)
echo -e "${BLUE}============================================${NC}"
echo -e "${BLUE}HOST-BASED ROUTING TESTS${NC}"
echo -e "${BLUE}============================================${NC}"
echo "Note: These will only work after deploying applications and setting up DNS/hosts file"

test_url "http://$NODE_IP:$INGRESS_HTTP_PORT" "shield.mcu.local (with Host header)" 
echo "To test with host header, use:"
echo "curl -H 'Host: shield.mcu.local' http://$NODE_IP:$INGRESS_HTTP_PORT"
echo ""

test_url "http://$NODE_IP:$INGRESS_HTTP_PORT" "hydra.mcu.local (with Host header)"
echo "To test with host header, use:"
echo "curl -H 'Host: hydra.mcu.local' http://$NODE_IP:$INGRESS_HTTP_PORT"
echo ""

# Test path-based routing
echo -e "${BLUE}============================================${NC}"
echo -e "${BLUE}PATH-BASED ROUTING TESTS${NC}"
echo -e "${BLUE}============================================${NC}"
echo "To test path-based routing after deployment:"
echo "curl -H 'Host: mcu.local' http://$NODE_IP:$INGRESS_HTTP_PORT/shield"
echo "curl -H 'Host: mcu.local' http://$NODE_IP:$INGRESS_HTTP_PORT/hydra"
echo ""

# Show how to set up local DNS
echo -e "${BLUE}============================================${NC}"
echo -e "${BLUE}DNS SETUP INSTRUCTIONS${NC}"
echo -e "${BLUE}============================================${NC}"
echo "Add these entries to your hosts file for testing:"
echo ""
echo "# On Linux/Mac: /etc/hosts"
echo "# On Windows: C:\\Windows\\System32\\drivers\\etc\\hosts"
echo "$NODE_IP shield.mcu.local"
echo "$NODE_IP hydra.mcu.local" 
echo "$NODE_IP mcu.local"
echo ""

# Show deployment commands
echo -e "${BLUE}============================================${NC}"
echo -e "${BLUE}DEPLOYMENT COMMANDS${NC}"
echo -e "${BLUE}============================================${NC}"
echo "1. Deploy applications:"
echo "   kubectl apply -f app.yml"
echo ""
echo "2. Deploy ingress rules:"
echo "   kubectl apply -f ig-all.yml"
echo ""
echo "3. Check deployments:"
echo "   kubectl get pods,svc,ingress"
echo ""
echo "4. Check ingress details:"
echo "   kubectl describe ingress mcu-all"
echo ""

# Show useful debugging commands
echo -e "${BLUE}============================================${NC}"
echo -e "${BLUE}DEBUGGING COMMANDS${NC}"
echo -e "${BLUE}============================================${NC}"
echo "# Check ingress controller logs"
echo "kubectl logs -n ingress-nginx -l app.kubernetes.io/name=ingress-nginx"
echo ""
echo "# Check ingress status"
echo "kubectl get ingress -o wide"
echo ""
echo "# Test internal connectivity"
echo "kubectl run test-pod --image=busybox --rm -it -- sh"
echo "# Inside the pod:"
echo "# wget -qO- http://svc-shield:8080"
echo "# wget -qO- http://svc-hydra:8080"