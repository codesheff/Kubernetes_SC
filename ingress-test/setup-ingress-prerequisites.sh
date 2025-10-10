#!/bin/bash

# Setup prerequisites for Kubernetes Ingress
# This script installs NGINX Ingress Controller and configures DNS for testing

set -e

# Configuration
NGINX_INGRESS_VERSION="v1.8.2"
HOSTS_TO_ADD=("mcu.com" "shield.mcu.com" "hydra.mcu.com")
METALLB_IP="192.168.1.75"  # Expected MetalLB IP allocation

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
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

# Function to check if kubectl is available
check_kubectl() {
    if ! command -v kubectl &> /dev/null; then
        print_error "kubectl is not installed or not in PATH"
        print_status "Please install kubectl first or run the setup-local-kubectl.sh script"
        exit 1
    fi
    
    print_status "kubectl found: $(kubectl version --client --short 2>/dev/null || echo 'version check failed')"
}

# Function to check cluster connectivity
check_cluster() {
    print_status "Checking cluster connectivity..."
    
    if ! kubectl cluster-info &> /dev/null; then
        print_error "Cannot connect to Kubernetes cluster"
        print_status "Please ensure your cluster is running and kubeconfig is set correctly"
        exit 1
    fi
    
    print_success "Cluster connection verified"
    kubectl get nodes
}

# Function to check if MetalLB is installed
check_metallb() {
    print_status "Checking MetalLB installation..."
    
    if kubectl get namespace metallb-system &> /dev/null; then
        print_success "MetalLB namespace found"
        
        # Check if MetalLB pods are running
        METALLB_PODS=$(kubectl get pods -n metallb-system --no-headers 2>/dev/null | wc -l)
        if [ "$METALLB_PODS" -gt 0 ]; then
            print_success "MetalLB pods are running:"
            kubectl get pods -n metallb-system
        else
            print_warning "MetalLB namespace exists but no pods found"
        fi
        
        # Check IP address pool
        if kubectl get ipaddresspool -n metallb-system &> /dev/null; then
            print_success "MetalLB IP address pool configured:"
            kubectl get ipaddresspool -n metallb-system
        else
            print_warning "No MetalLB IP address pool found"
        fi
    else
        print_error "MetalLB is not installed"
        print_status "Please run your cluster setup script first to install MetalLB"
        exit 1
    fi
}

# Function to check if NGINX Ingress Controller is already installed
check_existing_ingress() {
    if kubectl get namespace ingress-nginx &> /dev/null; then
        print_warning "NGINX Ingress Controller namespace already exists"
        
        # Check if pods are running
        INGRESS_PODS=$(kubectl get pods -n ingress-nginx --no-headers 2>/dev/null | grep -c "Running" || echo "0")
        if [ "$INGRESS_PODS" -gt 0 ]; then
            print_warning "NGINX Ingress Controller appears to be already running:"
            kubectl get pods -n ingress-nginx
            read -p "Do you want to reinstall NGINX Ingress Controller? (y/N): " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                print_status "Skipping NGINX Ingress Controller installation"
                return 1
            fi
        fi
    fi
    return 0
}

# Function to install NGINX Ingress Controller
install_nginx_ingress() {
    print_status "Installing NGINX Ingress Controller $NGINX_INGRESS_VERSION..."
    
    # Download and apply the NGINX Ingress Controller manifest
    INGRESS_MANIFEST="https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-$NGINX_INGRESS_VERSION/deploy/static/provider/cloud/deploy.yaml"
    
    print_status "Downloading from: $INGRESS_MANIFEST"
    
    if command -v curl &> /dev/null; then
        curl -L "$INGRESS_MANIFEST" | kubectl apply -f -
    elif command -v wget &> /dev/null; then
        wget -q -O - "$INGRESS_MANIFEST" | kubectl apply -f -
    else
        print_error "Neither curl nor wget found. Cannot download ingress manifest."
        exit 1
    fi
    
    print_success "NGINX Ingress Controller manifests applied"
}

# Function to wait for NGINX Ingress Controller to be ready
wait_for_ingress_controller() {
    print_status "Waiting for NGINX Ingress Controller to be ready..."
    
    # Wait for namespace to be created
    kubectl wait --for=condition=complete --timeout=60s job/ingress-nginx-admission-create -n ingress-nginx || true
    
    # Wait for deployment to be ready
    print_status "Waiting for ingress controller deployment..."
    kubectl wait --namespace ingress-nginx \
        --for=condition=ready pod \
        --selector=app.kubernetes.io/component=controller \
        --timeout=300s
    
    print_success "NGINX Ingress Controller is ready"
    
    # Show the service details
    print_status "NGINX Ingress Controller service:"
    kubectl get svc -n ingress-nginx
}

# Function to verify ingress controller has external IP
verify_external_ip() {
    print_status "Checking for external IP assignment..."
    
    # Get the LoadBalancer service
    EXTERNAL_IP=""
    for i in {1..30}; do
        EXTERNAL_IP=$(kubectl get svc ingress-nginx-controller -n ingress-nginx -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "")
        if [ -n "$EXTERNAL_IP" ] && [ "$EXTERNAL_IP" != "null" ]; then
            break
        fi
        print_status "Waiting for external IP assignment... (attempt $i/30)"
        sleep 10
    done
    
    if [ -n "$EXTERNAL_IP" ] && [ "$EXTERNAL_IP" != "null" ]; then
        print_success "External IP assigned: $EXTERNAL_IP"
        METALLB_IP="$EXTERNAL_IP"  # Update the IP for hosts file
    else
        print_warning "No external IP assigned yet. Using expected MetalLB IP: $METALLB_IP"
        print_status "You may need to wait a few more minutes for MetalLB to assign an IP"
    fi
}

# Function to setup local DNS (hosts file)
setup_local_dns() {
    print_status "Setting up local DNS entries..."
    
    # Determine hosts file location
    if [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "cygwin" ]] || [[ "$OSTYPE" == "win32" ]]; then
        HOSTS_FILE="/c/Windows/System32/drivers/etc/hosts"
    else
        HOSTS_FILE="/etc/hosts"
    fi
    
    print_status "Hosts file location: $HOSTS_FILE"
    
    # Check if we can write to hosts file
    if [ ! -w "$HOSTS_FILE" ]; then
        print_warning "Cannot write to hosts file. Manual configuration required."
        print_status "Please add these entries to your hosts file ($HOSTS_FILE):"
        for host in "${HOSTS_TO_ADD[@]}"; do
            echo "$METALLB_IP $host"
        done
        print_status ""
        print_status "On Linux/macOS: sudo nano $HOSTS_FILE"
        print_status "On Windows: Run notepad as administrator and open $HOSTS_FILE"
        return 0
    fi
    
    # Backup hosts file
    cp "$HOSTS_FILE" "${HOSTS_FILE}.backup.$(date +%Y%m%d_%H%M%S)"
    print_status "Hosts file backed up"
    
    # Remove existing entries for our hosts
    for host in "${HOSTS_TO_ADD[@]}"; do
        sed -i "/$host/d" "$HOSTS_FILE" 2>/dev/null || true
    done
    
    # Add new entries
    echo "" >> "$HOSTS_FILE"
    echo "# Kubernetes Ingress Test Entries - Added $(date)" >> "$HOSTS_FILE"
    for host in "${HOSTS_TO_ADD[@]}"; do
        echo "$METALLB_IP $host" >> "$HOSTS_FILE"
        print_success "Added: $METALLB_IP $host"
    done
    
    print_success "Local DNS entries configured"
}

# Function to test the setup
test_ingress_setup() {
    print_status "Testing NGINX Ingress Controller setup..."
    
    # Create a simple test pod and service
    cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: ingress-test-pod
  labels:
    app: ingress-test
spec:
  containers:
  - name: nginx
    image: nginx:alpine
    ports:
    - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: ingress-test-svc
spec:
  selector:
    app: ingress-test
  ports:
  - port: 80
    targetPort: 80
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: ingress-test
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
spec:
  ingressClassName: nginx
  rules:
  - host: test.local
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: ingress-test-svc
            port:
              number: 80
EOF

    print_status "Test resources created"
    
    # Wait for pod to be ready
    kubectl wait --for=condition=ready pod/ingress-test-pod --timeout=60s
    
    print_success "Test pod is ready"
    print_status "You can test the ingress with: curl -H 'Host: test.local' http://$METALLB_IP"
    
    # Clean up test resources
    read -p "Do you want to clean up test resources? (Y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Nn]$ ]]; then
        kubectl delete pod ingress-test-pod
        kubectl delete svc ingress-test-svc
        kubectl delete ingress ingress-test
        print_success "Test resources cleaned up"
    fi
}

# Function to display usage instructions
display_usage() {
    echo
    print_success "NGINX Ingress Controller setup completed!"
    echo
    print_status "Summary:"
    echo "  ✅ NGINX Ingress Controller installed and running"
    echo "  ✅ MetalLB integration verified"
    echo "  ✅ External IP: $METALLB_IP"
    echo "  ✅ Local DNS configured for: ${HOSTS_TO_ADD[*]}"
    echo
    print_status "Next steps:"
    echo "  1. Deploy your applications: kubectl apply -f app.yml"
    echo "  2. Deploy your ingress: kubectl apply -f ig-all.yml"
    echo "  3. Test the endpoints:"
    echo "     - curl http://shield.mcu.com"
    echo "     - curl http://hydra.mcu.com"
    echo "     - curl http://mcu.com/shield"
    echo "     - curl http://mcu.com/hydra"
    echo
    print_status "Troubleshooting commands:"
    echo "  - kubectl get ingress"
    echo "  - kubectl describe ingress mcu-all"
    echo "  - kubectl get svc -n ingress-nginx"
    echo "  - kubectl logs -n ingress-nginx deployment/ingress-nginx-controller"
}

# Main execution
main() {
    echo "=============================================="
    echo "    Kubernetes Ingress Prerequisites Setup"
    echo "=============================================="
    echo
    
    # Check prerequisites
    check_kubectl
    check_cluster
    check_metallb
    
    # Install NGINX Ingress Controller
    if check_existing_ingress; then
        install_nginx_ingress
    fi
    
    # Wait for controller to be ready
    wait_for_ingress_controller
    
    # Verify external IP
    verify_external_ip
    
    # Setup local DNS
    setup_local_dns
    
    # Optional test
    read -p "Do you want to run a quick ingress test? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        test_ingress_setup
    fi
    
    # Display usage instructions
    display_usage
}

# Run main function
main "$@"