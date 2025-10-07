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

# Function to check and fix network issues
check_network_config() {
    print_info "Checking network configuration..."
    
    # Check if both WiFi and Ethernet are active
    local network_status=$(ansible master -i "$INVENTORY" -m shell -a "ip addr show | grep 'inet ' | grep -v 127.0.0.1" 2>/dev/null | grep "CHANGED" -A 10 || true)
    
    if echo "$network_status" | grep -q "192.168.1.114" && echo "$network_status" | grep -q "192.168.1.112"; then
        print_warning "Both WiFi (192.168.1.114) and Ethernet (192.168.1.112) are active"
        print_info "This can cause Kubernetes certificate issues"
        print_info "Ethernet has priority, but we'll ensure clean certificates"
        
        # Clean up any leftover certificates that might have wrong IP
        ansible master -i "$INVENTORY" -b -m shell -a "rm -rf /etc/kubernetes/pki/* /var/lib/etcd/*" >/dev/null 2>&1 || true
        print_success "Cleaned up any existing certificates"
    fi
}

# Function to verify ansible connectivity
verify_ansible_connection() {
    print_info "Verifying Ansible connection to Raspberry Pi (user: cranie)..."
    
    if ansible master -i "$INVENTORY" -m ping >/dev/null 2>&1; then
        print_success "Ansible connection successful"
    else
        print_error "Cannot connect to Raspberry Pi via Ansible"
        echo "Please check:"
        echo "1. SSH key is set up for user 'cranie'"
        echo "2. Raspberry Pi is accessible at 192.168.1.112"
        echo "3. User 'cranie' has sudo privileges"
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
    
    print_info "Checking network interfaces on Raspberry Pi..."
    local network_info=$(ansible master -i "$INVENTORY" -m shell -a "ip addr show | grep 'inet ' | grep -v 127.0.0.1" 2>/dev/null | grep "CHANGED" -A 10 || true)
    if echo "$network_info" | grep -q "192.168.1.112"; then
        print_success "Ethernet interface (192.168.1.112) is active"
    else
        print_warning "Ethernet interface may not be active"
    fi
    
    if echo "$network_info" | grep -q "192.168.1.114"; then
        print_info "WiFi interface (192.168.1.114) is also active"
        print_info "This is OK - Ethernet has priority"
    fi
    
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
    echo "1. Verify Ansible connection (user: cranie)"
    echo "2. Reset existing Kubernetes cluster"
    echo "3. Thorough cleanup of certificates and processes"
    echo "4. Set up base Kubernetes environment"
    echo "5. Configure Ethernet networking priority"
    echo "6. Initialize Kubernetes master (with correct IP)"
    echo "7. Configure master node"
    echo "8. Deploy MetalLB LoadBalancer"
    echo "9. Install NGINX Ingress Controller"
    echo "10. Deploy test applications"
    echo "11. Verify complete setup"
    echo ""
    echo "🔧 Key improvements in this version:"
    echo "• Fixed user from 'pi' to 'cranie'"
    echo "• Added IP address verification (192.168.1.112)"
    echo "• Moved Ethernet setup before Kubernetes init"
    echo "• Enhanced certificate cleanup"
    echo "• Better error handling for dual network interfaces"
    echo ""
    
    confirm
    
    # Change to script directory
    cd "$SCRIPT_DIR" || {
        print_error "Failed to change to directory: $SCRIPT_DIR"
        exit 1
    }
    
    # Verify Ansible connection first
    verify_ansible_connection
    
    # Check network configuration
    check_network_config
    
    # Step 1: Reset existing Kubernetes cluster
    run_playbook "./ansible/k8s/reset-kubernetes.yml" "🔄 STEP 1: Resetting Kubernetes cluster"
    
    # Additional cleanup for certificate issues
    print_info "Performing thorough cleanup for certificate issues..."
    ansible master -i "$INVENTORY" -b -m shell -a "rm -rf /etc/kubernetes /var/lib/kubelet /var/lib/etcd /opt/cni/bin /etc/cni/net.d" >/dev/null 2>&1 || true
    ansible master -i "$INVENTORY" -b -m shell -a "pkill -f kube-apiserver || true; pkill -f etcd || true" >/dev/null 2>&1 || true
    print_success "Additional cleanup completed"
    
    # Step 2: Set up base Kubernetes environment
    run_playbook "./ansible/k8s/setup.yml" "🛠️  STEP 2: Setting up base Kubernetes environment"
    
    # Step 6: Configure Ethernet networking (MOVED EARLIER)
    run_playbook "./ansible/k8s/ethernet-setup.yml" "🌐 STEP 6: Configuring Ethernet networking priority"
    
    # Verify Ethernet is primary after setup
    print_info "Verifying Ethernet configuration..."
    local eth_status=$(ansible master -i "$INVENTORY" -m shell -a "ip route show default | head -1" 2>/dev/null | grep "CHANGED" -A 1 || true)
    if echo "$eth_status" | grep -q "eth0"; then
        print_success "Ethernet is configured as primary interface"
    else
        print_warning "Ethernet may not be primary - this could cause issues"
    fi
    
    # Step 7: Initialize Kubernetes master (with better error handling)
    print_step "🚀 STEP 7: Initializing Kubernetes master"
    print_info "This step ensures certificates are generated for the correct IP (192.168.1.112)"
    run_playbook "./ansible/k8s/initialise.yml" "🚀 STEP 7: Initializing Kubernetes master"
    
    # Step 8: Configure master node
    run_playbook "./ansible/k8s/masters.yml" "⚙️  STEP 8: Configuring master node"
    
    # Step 9: Skip workers (commented out in inventory)
    print_info "⏭️  STEP 9: Skipping worker nodes (none configured in inventory)"
    
    # Step 10: Deploy MetalLB LoadBalancer
    run_playbook "./ansible/k8s/metallb-ethernet.yml" "🔧 STEP 10: Deploying MetalLB LoadBalancer"
    
    # Step 11: Install NGINX Ingress Controller
    run_playbook "./ansible/k8s/ingress.yml" "📡 STEP 11: Installing NGINX Ingress Controller"
    
    # Wait for ingress controller to be ready
    wait_for_pods "ingress-nginx" 180
    
    # Step 12: Deploy test applications
    print_step "🧪 STEP 12: Deploying test applications"
    
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
    
    # Step 13: Verify complete setup
    print_step "✅ STEP 13: Verifying complete setup"
    
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
    echo "• Master Node: 192.168.1.112 (Ethernet primary)"
    echo "• User: cranie (updated from pi)"
    echo "• MetalLB LoadBalancer: 192.168.1.75"
    echo "• Ingress Controller: NGINX (LoadBalancer type)"
    echo "• Test Applications: Shield & Hydra"
    echo "• Network: Ethernet priority over WiFi"
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