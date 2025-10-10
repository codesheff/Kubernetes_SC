#!/bin/bash

# Deploy and test the MCU ingress application
# This script deploys the apps and ingress, then tests the endpoints

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check prerequisites
check_prerequisites() {
    print_status "Checking prerequisites..."
    
    # Check kubectl
    if ! command -v kubectl &> /dev/null; then
        print_error "kubectl not found"
        exit 1
    fi
    
    # Check cluster connection
    if ! kubectl cluster-info &> /dev/null; then
        print_error "Cannot connect to cluster"
        exit 1
    fi
    
    # Check NGINX ingress controller
    if ! kubectl get namespace ingress-nginx &> /dev/null; then
        print_error "NGINX Ingress Controller not found"
        print_status "Please run: ./setup-ingress-prerequisites.sh"
        exit 1
    fi
    
    print_success "Prerequisites check passed"
}

# Function to deploy applications
deploy_applications() {
    print_status "Deploying MCU applications..."
    
    if [ ! -f "app.yml" ]; then
        print_error "app.yml not found in current directory"
        exit 1
    fi
    
    kubectl apply -f app.yml
    print_success "Applications deployed"
    
    # Wait for pods to be ready
    print_status "Waiting for pods to be ready..."
    kubectl wait --for=condition=ready pod/shield --timeout=120s
    kubectl wait --for=condition=ready pod/hydra --timeout=120s
    
    print_success "All pods are ready"
}

# Function to deploy ingress
deploy_ingress() {
    print_status "Deploying ingress configuration..."
    
    if [ ! -f "ig-all.yml" ]; then
        print_error "ig-all.yml not found in current directory"
        exit 1
    fi
    
    kubectl apply -f ig-all.yml
    print_success "Ingress deployed"
    
    # Wait a moment for ingress to be processed
    sleep 5
}

# Function to check deployment status
check_status() {
    print_status "Checking deployment status..."
    
    echo
    print_status "Pods:"
    kubectl get pods -o wide
    
    echo
    print_status "Services:"
    kubectl get svc
    
    echo
    print_status "Ingress:"
    kubectl get ingress
    
    echo
    print_status "Ingress details:"
    kubectl describe ingress mcu-all
}

# Function to get ingress IP
get_ingress_ip() {
    print_status "Getting ingress IP address..."
    
    INGRESS_IP=$(kubectl get svc ingress-nginx-controller -n ingress-nginx -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "")
    
    if [ -z "$INGRESS_IP" ] || [ "$INGRESS_IP" = "null" ]; then
        print_warning "No external IP found, checking for pending assignment..."
        kubectl get svc -n ingress-nginx
        INGRESS_IP="<PENDING>"
    else
        print_success "Ingress IP: $INGRESS_IP"
    fi
}

# Function to test endpoints
test_endpoints() {
    if [ "$INGRESS_IP" = "<PENDING>" ]; then
        print_warning "Cannot test endpoints without ingress IP"
        print_status "Please wait for MetalLB to assign an IP and test manually"
        return
    fi
    
    print_status "Testing ingress endpoints..."
    
    # Test endpoints
    ENDPOINTS=(
        "shield.mcu.com"
        "hydra.mcu.com"
        "mcu.com/shield"
        "mcu.com/hydra"
    )
    
    for endpoint in "${ENDPOINTS[@]}"; do
        print_status "Testing: http://$endpoint"
        
        if [[ "$endpoint" == *"/"* ]]; then
            # Path-based routing
            HOST=$(echo "$endpoint" | cut -d'/' -f1)
            PATH="/$(echo "$endpoint" | cut -d'/' -f2-)"
            RESPONSE=$(curl -s -w "%{http_code}" -H "Host: $HOST" "http://$INGRESS_IP$PATH" || echo "000")
        else
            # Host-based routing
            RESPONSE=$(curl -s -w "%{http_code}" -H "Host: $endpoint" "http://$INGRESS_IP/" || echo "000")
        fi
        
        HTTP_CODE="${RESPONSE: -3}"
        BODY="${RESPONSE%???}"
        
        if [ "$HTTP_CODE" = "200" ]; then
            print_success "✅ $endpoint: OK"
            if [ ${#BODY} -lt 100 ]; then
                echo "   Response: $BODY"
            else
                echo "   Response: ${BODY:0:100}..."
            fi
        else
            print_error "❌ $endpoint: HTTP $HTTP_CODE"
            if [ -n "$BODY" ]; then
                echo "   Error: $BODY"
            fi
        fi
        echo
    done
}

# Function to display manual test commands
display_manual_tests() {
    print_status "Manual test commands:"
    echo
    if [ "$INGRESS_IP" != "<PENDING>" ]; then
        echo "# Host-based routing:"
        echo "curl -H 'Host: shield.mcu.com' http://$INGRESS_IP"
        echo "curl -H 'Host: hydra.mcu.com' http://$INGRESS_IP"
        echo
        echo "# Path-based routing:"
        echo "curl -H 'Host: mcu.com' http://$INGRESS_IP/shield"
        echo "curl -H 'Host: mcu.com' http://$INGRESS_IP/hydra"
        echo
        echo "# If you configured /etc/hosts entries:"
        echo "curl http://shield.mcu.com"
        echo "curl http://hydra.mcu.com"
        echo "curl http://mcu.com/shield"
        echo "curl http://mcu.com/hydra"
    else
        print_warning "Wait for MetalLB to assign IP, then use these commands:"
        echo "INGRESS_IP=\$(kubectl get svc ingress-nginx-controller -n ingress-nginx -o jsonpath='{.status.loadBalancer.ingress[0].ip}')"
        echo "curl -H 'Host: shield.mcu.com' http://\$INGRESS_IP"
        echo "curl -H 'Host: hydra.mcu.com' http://\$INGRESS_IP"
    fi
}

# Function to cleanup
cleanup() {
    read -p "Do you want to clean up the deployed resources? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        print_status "Cleaning up resources..."
        kubectl delete -f ig-all.yml --ignore-not-found=true
        kubectl delete -f app.yml --ignore-not-found=true
        print_success "Resources cleaned up"
    fi
}

# Main execution
main() {
    echo "=============================================="
    echo "       MCU Ingress Application Deployment"
    echo "=============================================="
    echo
    
    check_prerequisites
    deploy_applications
    deploy_ingress
    check_status
    get_ingress_ip
    
    echo
    echo "=============================================="
    echo "                  Testing"
    echo "=============================================="
    
    test_endpoints
    display_manual_tests
    
    echo
    echo "=============================================="
    echo "                 Cleanup"
    echo "=============================================="
    
    cleanup
}

# Check if running from correct directory
if [ ! -f "app.yml" ] || [ ! -f "ig-all.yml" ]; then
    print_error "Please run this script from the ingress-test directory"
    print_status "Expected files: app.yml, ig-all.yml"
    exit 1
fi

# Run main function
main "$@"