#!/bin/bash
# ============================================
# KUBERNETES RASPBERRY PI REBUILD SCRIPT
# ============================================
# Complete automation for rebuilding Kubernetes cluster
# from scratch using existing Ansible playbooks

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="/mnt/c/git/SC_Kubernetes"
INVENTORY="./ansible/inventory/all-server.ini"

# Function to print colored output
print_step() {
    echo -e "${CYAN}============================================${NC}"
    echo -e "${CYAN}$1${NC}"
    echo -e "${CYAN}============================================${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

# Function to wait for user confirmation
confirm() {
    read -p "Continue? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Aborted by user"
        exit 1
    fi
}

# Function to run ansible playbook with error handling
run_playbook() {
    local playbook=$1
    local description=$2
    
    print_step "$description"
    print_info "Running: ansible-playbook $playbook -i $INVENTORY"
    
    if ansible-playbook "$playbook" -i "$INVENTORY"; then
        print_success "$description completed successfully"
        sleep 2
    else
        print_error "$description failed"
        exit 1
    fi
}

# Function to wait for pods to be ready
wait_for_pods() {
    local namespace=$1
    local timeout=${2:-300}  # Default 5 minutes
    
    print_info "Waiting for pods in namespace '$namespace' to be ready (timeout: ${timeout}s)..."
    
    local count=0
    while [ $count -lt $timeout ]; do
        if kubectl get pods -n "$namespace" 2>/dev/null | grep -v "STATUS" | grep -v "Completed" | awk '{print $3}' | grep -v "Running" > /dev/null; then
            echo -n "."
            sleep 5
            count=$((count + 5))
        else
            echo ""
            print_success "All pods in namespace '$namespace' are ready"
            return 0
        fi
    done
    
    echo ""
    print_warning "Timeout waiting for pods in namespace '$namespace'"
    kubectl get pods -n "$namespace"
}

# Function to test connectivity
test_connectivity() {
    print_step "Testing Connectivity"
    
    print_info "Testing MetalLB LoadBalancer..."
    if timeout 10 curl -s -H "Host: shield.mcu.com" http://192.168.1.75 > /dev/null; then
        print_success "MetalLB LoadBalancer is responding"
    else
        print_warning "MetalLB LoadBalancer not responding yet (this is normal, may need more time)"
    fi
    
    print_info "Testing Ingress routing..."
    if timeout 10 curl -s -H "Host: hydra.mcu.com" http://192.168.1.75 > /dev/null; then
        print_success "Ingress routing is working"
    else
        print_warning "Ingress routing not working yet (may need more time for apps to start)"
    fi
}

# Main script
main() {
    print_step "KUBERNETES RASPBERRY PI CLUSTER REBUILD"
    echo -e "${YELLOW}This script will completely rebuild your Kubernetes cluster.${NC}"
    echo -e "${RED}⚠️  ALL EXISTING DATA WILL BE LOST! ⚠️${NC}"
    echo ""
    echo "Steps that will be performed:"
    echo "1. Reset existing Kubernetes cluster"
    echo "2. Set up base Kubernetes environment"
    echo "3. Initialize Kubernetes master"
    echo "4. Configure master node"
    echo "5. Configure Ethernet networking"
    echo "6. Deploy MetalLB LoadBalancer"
    echo "7. Install NGINX Ingress Controller"
    echo "8. Deploy test applications"
    echo "9. Verify complete setup"
    echo ""
    
    confirm
    
    # Change to script directory
    cd "$SCRIPT_DIR" || {
        print_error "Failed to change to directory: $SCRIPT_DIR"
        exit 1
    }
    
    # Step 1: Reset existing Kubernetes cluster
    run_playbook "./ansible/k8s/reset-kubernetes.yml" "🔄 STEP 1: Resetting Kubernetes cluster"
    
    # Step 2: Set up base Kubernetes environment
    run_playbook "./ansible/k8s/setup.yml" "🛠️  STEP 2: Setting up base Kubernetes environment"
    
    # Step 3: Initialize Kubernetes master
    run_playbook "./ansible/k8s/initialise.yml" "🚀 STEP 3: Initializing Kubernetes master"
    
    # Step 4: Configure master node
    run_playbook "./ansible/k8s/masters.yml" "⚙️  STEP 4: Configuring master node"
    
    # Step 5: Skip workers (commented out in inventory)
    print_info "⏭️  STEP 5: Skipping worker nodes (none configured in inventory)"
    
    # Step 6: Configure Ethernet networking
    run_playbook "./ansible/k8s/ethernet-setup.yml" "🌐 STEP 6: Configuring Ethernet networking"
    
    # Step 7: Deploy MetalLB LoadBalancer
    run_playbook "./ansible/k8s/metallb-ethernet.yml" "🔧 STEP 7: Deploying MetalLB LoadBalancer"
    
    # Step 8: Install NGINX Ingress Controller
    run_playbook "./ansible/k8s/ingress.yml" "📡 STEP 8: Installing NGINX Ingress Controller"
    
    # Wait for ingress controller to be ready
    wait_for_pods "ingress-nginx" 180
    
    # Step 9: Deploy test applications
    print_step "🧪 STEP 9: Deploying test applications"
    
    if [ -f "/mnt/c/git/SC_Kubernetes/ingress-test/app.yml" ]; then
        print_info "Deploying Shield and Hydra test apps..."
        kubectl apply -f /mnt/c/git/SC_Kubernetes/ingress-test/app.yml
        print_success "Test apps deployed"
    else
        print_warning "Test app file not found, skipping"
    fi
    
    if [ -f "/mnt/c/git/SC_Kubernetes/ingress-test/ig-all.yml" ]; then
        print_info "Deploying ingress rules..."
        kubectl apply -f /mnt/c/git/SC_Kubernetes/ingress-test/ig-all.yml
        print_success "Ingress rules deployed"
    else
        print_warning "Ingress rules file not found, skipping"
    fi
    
    # Wait for test apps
    print_info "Waiting for test applications to start..."
    sleep 30
    
    # Step 10: Verify complete setup
    print_step "✅ STEP 10: Verifying complete setup"
    
    print_info "Cluster nodes:"
    kubectl get nodes
    echo ""
    
    print_info "All pods:"
    kubectl get pods -A
    echo ""
    
    print_info "All services:"
    kubectl get services -A
    echo ""
    
    print_info "Ingress resources:"
    kubectl get ingress -A
    echo ""
    
    # Test connectivity
    test_connectivity
    
    # Final summary
    print_step "🎉 REBUILD COMPLETE!"
    echo ""
    print_success "Kubernetes cluster has been successfully rebuilt!"
    echo ""
    echo -e "${CYAN}📋 SUMMARY:${NC}"
    echo "• Master Node: 192.168.1.112"
    echo "• MetalLB LoadBalancer: 192.168.1.75"
    echo "• Ingress Controller: NGINX (LoadBalancer type)"
    echo "• Test Applications: Shield & Hydra"
    echo ""
    echo -e "${CYAN}🧪 TEST COMMANDS:${NC}"
    echo "curl -H \"Host: shield.mcu.com\" http://192.168.1.75"
    echo "curl -H \"Host: hydra.mcu.com\" http://192.168.1.75"
    echo "curl -H \"Host: mcu.com\" http://192.168.1.75/shield"
    echo "curl -H \"Host: mcu.com\" http://192.168.1.75/hydra"
    echo ""
    echo -e "${CYAN}🌐 EXTERNAL ACCESS:${NC}"
    echo "Configure router port forwarding:"
    echo "External Port 80  → 192.168.1.75:80"
    echo "External Port 443 → 192.168.1.75:443"
    echo ""
    echo -e "${GREEN}Ready for production use! 🚀${NC}"
}

# Run main function
main "$@"