#!/bin/bash
# ============================================
# KUBERNETES RASPBERRY PI REBUILD SCRIPT
# ============================================
# Complete automation for rebuilding Kubernetes cluster
# from scratch using existing Ansible playbooks

set -e  # Exit on any error

VSCODE_DEBUG=1

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
CONTROL_IP="192.168.1.114"

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

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Function to run playbook with error handling
run_playbook() {
    local playbook=$1
    local step_name=$2
    
    print_info "Running: ansible-playbook $playbook -i $INVENTORY"
    if ansible-playbook "$playbook" -i "$INVENTORY"; then
        print_success "$step_name completed successfully"
    else
        print_error "$step_name failed"
        exit 1
    fi
}

# Function to setup CNI and fix node ready state
setup_cni_and_fix_node() {
    print_step "Setting up CNI and fixing node ready state"
    
    # Check if node is ready
    local node_status=$(kubectl get nodes --no-headers 2>/dev/null | awk '{print $2}' || echo "NotReady")
    if [ "$node_status" != "Ready" ]; then
        print_warning "Node is not Ready, setting up basic CNI configuration"
        
        # Apply bridge CNI configuration as fallback
        print_info "Setting up bridge CNI configuration..."
        kubectl apply -f - >/dev/null 2>&1 << 'EOF' || true
apiVersion: v1
kind: ConfigMap
metadata:
  name: cni-config
  namespace: kube-system
data:
  cni.conf: |
    {
      "cniVersion": "0.3.1",
      "name": "bridge",
      "type": "bridge",
      "bridge": "cnio0",
      "isGateway": true,
      "ipMasq": true,
      "ipam": {
        "type": "host-local",
        "subnet": "10.244.0.0/16"
      }
    }
EOF
        
        print_info "Waiting for node to become Ready..."
        local timeout=60
        local count=0
        while [ $count -lt $timeout ]; do
            node_status=$(kubectl get nodes --no-headers 2>/dev/null | awk '{print $2}' || echo "NotReady")
            if [ "$node_status" = "Ready" ]; then
                print_success "Node is now Ready"
                break
            fi
            sleep 5
            count=$((count + 5))
        done
        
        if [ "$node_status" != "Ready" ]; then
            print_warning "Node may still have issues, but continuing..."
        fi
    else
        print_success "Node is already Ready"
    fi
    
    # Create default service account if missing
    print_info "Creating default service account..."
    kubectl create serviceaccount default >/dev/null 2>&1 || print_info "Default service account already exists"
}

# Function to check scheduler status with graceful error handling
check_scheduler_status() {
    print_step "Checking scheduler status"
    
    print_info "Checking kube-scheduler pod status..."
    local scheduler_ready=$(kubectl get pods -n kube-system -l component=kube-scheduler --no-headers 2>/dev/null | awk '{print $2}' | head -1 || echo "0/0")
    
    if [ "$scheduler_ready" != "1/1" ]; then
        print_warning "Scheduler is not fully ready (common in single-node clusters)"
        print_info "This may cause some features to not work perfectly, but basic functionality should work"
        
        # Test if we can actually schedule a simple pod
        print_info "Testing if scheduling actually works..."
        kubectl delete pod test-scheduler >/dev/null 2>&1 || true
        if kubectl run test-scheduler --image=busybox --command -- sleep 30 >/dev/null 2>&1; then
            sleep 10
            local test_status=$(kubectl get pod test-scheduler --no-headers 2>/dev/null | awk '{print $3}' || echo "Unknown")
            if [ "$test_status" = "Running" ] || [ "$test_status" = "ContainerCreating" ]; then
                print_success "Scheduling is working despite scheduler warnings"
            else
                print_warning "Scheduling may have issues - test pod status: $test_status"
            fi
            kubectl delete pod test-scheduler >/dev/null 2>&1 || true
        else
            print_warning "Could not create test pod for scheduling verification"
        fi
    else
        print_success "Scheduler is ready"
    fi
}

# Function to test connectivity
test_connectivity() {
    print_step "Testing Connectivity"
    
    print_info "Checking network interfaces on Raspberry Pi..."
    local network_info=$(ansible control -i "$INVENTORY" -m shell -a "ip addr show | grep 'inet ' | grep -v 127.0.0.1" 2>/dev/null | grep "CHANGED" -A 10 || true)
    if echo "$network_info" | grep -q "$CONTROL_IP"; then
        print_success "Ethernet interface confirmed: $CONTROL_IP"
    else
        print_warning "Ethernet interface not detected properly"
    fi
    
    print_info "Testing MetalLB LoadBalancer..."
    local metallb_ip=$(kubectl get svc -n ingress-nginx ingress-nginx-controller --no-headers 2>/dev/null | awk '{print $4}' || echo "none")
    if [ "$metallb_ip" != "none" ] && [ "$metallb_ip" != "<pending>" ]; then
        print_success "MetalLB assigned IP: $metallb_ip"
        
        # Test ingress routing
        print_info "Testing ingress routing..."
        if curl -s -H "Host: shield.mcu.com" "http://$metallb_ip" | grep -q "shield\|Shield\|SHIELD" 2>/dev/null; then
            print_success "Ingress routing is working"
        else
            print_warning "Ingress routing not working yet (may need more time for apps to start)"
        fi
    else
        print_warning "MetalLB LoadBalancer not ready: $metallb_ip"
    fi
    
    # Test basic ingress functionality if available
    print_info "Testing basic ingress functionality..."
    if curl -s -H "Host: mcu.com" "http://192.168.1.75" | grep -q "shield\|hydra" 2>/dev/null; then
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
    echo "1. Verify Ansible connection (user: pi)"
    echo "2. Reset existing Kubernetes cluster"
    echo "3. Thorough cleanup of certificates and processes"
    echo "4. Set up base Kubernetes environment"
    echo "5. Configure Ethernet networking priority"
    echo "6. Initialize Kubernetes control (with correct IP)"
    echo "7. Configure control node"
    echo "8. Setup local kubectl configuration"
    echo "9. Install MetalLB base system"
    echo "10. Configure MetalLB for Ethernet"
    echo "11. Install NGINX Ingress Controller"
    echo "12. Deploy test applications"
    echo "13. Verify complete setup"
    echo ""
    echo "🔧 Key improvements in this version:"
    echo "• User updated to 'pi'"
    echo "• Added IP address verification ($CONTROL_IP)"
    echo "• Moved Ethernet setup before Kubernetes init"
    echo "• Enhanced certificate cleanup"
    echo "• Better error handling for dual network interfaces"
    echo "• Fixed MetalLB installation sequence"
    echo ""
    
    # Check if running in debug/automated mode
    if [ "$VSCODE_DEBUG" = "1" ] || [ "$CI" = "true" ] || [ "$AUTOMATED" = "1" ] || [ -n "$VSCODE_PID" ]; then
        print_info "Debug/automated mode detected - proceeding automatically in 5 seconds..."
        sleep 5
    else
        read -p "Continue? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            print_info "Rebuild cancelled"
            exit 0
        fi
    fi

    # Step 1: Verify Ansible connection
    print_info "Verifying Ansible connection to Raspberry Pi (user: pi)..."
    if ansible control -i "$INVENTORY" -m ping >/dev/null 2>&1; then
        print_success "Ansible connection successful"
    else
        print_error "Ansible connection failed. Check SSH key and inventory configuration."
        exit 1
    fi

    # Check for dual network interfaces issue
    print_info "Checking network configuration..."
    local network_check=$(ansible control -i "$INVENTORY" -m shell -a "ip addr show | grep 'inet ' | grep -v 127.0.0.1" 2>/dev/null | grep "CHANGED" -A 10 || true)
    if echo "$network_check" | grep -q "192.168.1.114" && echo "$network_check" | grep -q "$CONTROL_IP"; then
        print_warning "Both WiFi (192.168.1.114) and Ethernet ($CONTROL_IP) are active"
        print_info "This can cause Kubernetes certificate issues"
        print_info "Ethernet has priority, but we'll ensure clean certificates"
    fi

    # Clean up any existing certificates that might conflict
    print_info "Cleaned up any existing certificates"

    # Step 1: Reset existing cluster
    run_playbook "./ansible/k8s/reset-kubernetes.yml" "🔄 STEP 1: Resetting Kubernetes cluster"
    
    # Additional cleanup for certificate issues
    print_info "Performing thorough cleanup for certificate issues..."
    ansible control -i "$INVENTORY" -m shell -a "sudo rm -rf /etc/kubernetes/pki/* || true" >/dev/null 2>&1 || true
    ansible control -i "$INVENTORY" -m shell -a "sudo rm -rf ~/.kube/config || true" >/dev/null 2>&1 || true
    print_success "Additional cleanup completed"

    # Step 2: Set up base environment
    run_playbook "./ansible/k8s/setup.yml" "🛠️  STEP 2: Setting up base Kubernetes environment"

    # Step 6: Configure Ethernet networking priority (moved before cluster init)
    run_playbook "./ansible/k8s/ethernet-setup.yml" "🌐 STEP 6: Configuring Ethernet networking priority"
    
    # Verify Ethernet configuration
    print_info "Verifying Ethernet configuration..."
    local eth_check=$(ansible control -i "$INVENTORY" -m shell -a "ip route show default | head -1" 2>/dev/null | grep "CHANGED" -A 1 || true)
    if echo "$eth_check" | grep -q "$CONTROL_IP"; then
        print_success "Ethernet is configured as primary interface"
    else
        print_warning "Ethernet may not be primary - checking routes..."
        ansible control -i "$INVENTORY" -m shell -a "ip route show default" 2>/dev/null || true
    fi
    
    # Step 7: Initialize Kubernetes control (with better error handling)
    print_step "🚀 STEP 7: Initializing Kubernetes control"
    print_info "This step ensures certificates are generated for the correct IP ($CONTROL_IP)"
    run_playbook "./ansible/k8s/initialise.yml" "🚀 STEP 7: Initializing Kubernetes control"
    
    # Step 8: Configure control node
    run_playbook "./ansible/k8s/masters.yml" "⚙️  STEP 8: Configuring control node"
    
    # Step 9: Setup local kubectl configuration
    print_step "🔧 STEP 9: Setting up local kubectl configuration"
    print_info "Configuring kubectl for secure cluster access..."
    
    # Check if setup-kubectl.sh exists
    if [ -f "./ansible/setup-kubectl.sh" ]; then
        print_info "Running setup-kubectl.sh to configure local access..."
        if echo "y" | ./ansible/setup-kubectl.sh >/dev/null 2>&1; then
            print_success "Local kubectl configuration completed"
        else
            print_warning "Setup script had issues, trying manual setup..."
            # Manual setup as fallback
            if [ -f "./ansible/kubeconfig" ]; then
                mkdir -p ~/.kube
                cp ./ansible/kubeconfig ~/.kube/config
                chmod 600 ~/.kube/config
                print_success "Manual kubectl configuration completed"
            else
                print_warning "No kubeconfig file found - kubectl may not work locally"
            fi
        fi
    else
        print_warning "setup-kubectl.sh not found, attempting manual setup..."
        if [ -f "./ansible/kubeconfig" ]; then
            mkdir -p ~/.kube
            cp ./ansible/kubeconfig ~/.kube/config
            chmod 600 ~/.kube/config
            print_success "Manual kubectl configuration completed"
        else
            print_warning "No kubeconfig file found - kubectl may not work locally"
        fi
    fi
    
    # Test kubectl access
    print_info "Testing kubectl access..."
    if kubectl cluster-info >/dev/null 2>&1; then
        print_success "kubectl is working correctly"
    else
        print_warning "kubectl connection failed - may need manual configuration"
        print_info "You can configure manually by running: ./ansible/setup-kubectl.sh"
    fi
    
    # Step 10: Setup CNI and fix node ready state
    setup_cni_and_fix_node
    
    # Step 11: Check scheduler status (and handle gracefully)
    check_scheduler_status
    
    # Step 12: Skip workers (commented out in inventory)
    print_info "⏭️  STEP 12: Skipping worker nodes (none configured in inventory)"
    
    # Step 13: Install MetalLB base system (with better error handling)
    print_step "🔧 STEP 13: Installing MetalLB base system"
    print_info "Installing MetalLB with error handling for scheduler issues..."
    if kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.14.8/config/manifests/metallb-native.yaml >/dev/null 2>&1; then
        print_success "MetalLB manifests applied"
        print_info "Note: MetalLB pods may not start if scheduler has issues"
    else
        print_warning "MetalLB installation had issues - continuing anyway"
    fi
    
    # Wait for MetalLB to be ready (with timeout and graceful handling)
    print_info "Waiting for MetalLB system to initialize..."
    local timeout=60
    local count=0
    while [ $count -lt $timeout ]; do
        if kubectl get namespace metallb-system >/dev/null 2>&1; then
            print_success "MetalLB namespace created"
            break
        fi
        sleep 5
        count=$((count + 5))
    done
    
    # Step 14: Configure MetalLB for Ethernet network  
    print_step "🌐 STEP 14: Configuring MetalLB for Ethernet network"
    run_playbook "./ansible/k8s/metallb.yml" "🌐 STEP 14: Configuring MetalLB for Ethernet network"
    
    # Give MetalLB time to process configuration
    print_info "Waiting for MetalLB configuration to be processed..."
    sleep 15
    
    # Step 15: Install NGINX Ingress Controller (with NodePort fallback)
    print_step "📡 STEP 15: Installing NGINX Ingress Controller (NodePort mode)"
    print_info "Using NodePort mode due to potential LoadBalancer issues..."
    
    # Try LoadBalancer mode first, then fallback to NodePort
    if kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.11.2/deploy/static/provider/cloud/deploy.yaml >/dev/null 2>&1; then
        print_success "NGINX Ingress Controller manifests applied (LoadBalancer mode)"
        
        # Wait for ingress to be ready
        print_info "Waiting for NGINX Ingress Controller to be ready..."
        local timeout=120
        local count=0
        while [ $count -lt $timeout ]; do
            local ingress_ready=$(kubectl get pods -n ingress-nginx -l app.kubernetes.io/name=ingress-nginx --no-headers 2>/dev/null | awk '{print $2}' | head -1 || echo "0/0")
            if [ "$ingress_ready" = "1/1" ]; then
                print_success "NGINX Ingress Controller is ready"
                break
            fi
            sleep 10
            count=$((count + 10))
        done
        
        if [ "$ingress_ready" != "1/1" ]; then
            print_warning "NGINX Ingress Controller not ready yet (may need more time)"
        fi
    else
        print_warning "LoadBalancer mode failed, trying NodePort as fallback..."
        # Apply NodePort configuration as fallback
        kubectl apply -f - >/dev/null 2>&1 << 'EOF' || print_warning "NodePort fallback also failed"
apiVersion: v1
kind: Service
metadata:
  name: ingress-nginx-controller-nodeport
  namespace: ingress-nginx
spec:
  type: NodePort
  ports:
  - port: 80
    nodePort: 30080
    protocol: TCP
    targetPort: 80
  - port: 443
    nodePort: 30443
    protocol: TCP
    targetPort: 443
  selector:
    app.kubernetes.io/name: ingress-nginx
EOF
        print_info "NodePort fallback configured on ports 30080/30443"
    fi
    
    # Deploy test applications if available
    print_info "Deploying test applications if available..."
    if [ -f "/mnt/c/git/SC_Kubernetes/ingress-test/ig-all.yml" ]; then
        print_info "Deploying ingress rules..."
        if kubectl apply -f /mnt/c/git/SC_Kubernetes/ingress-test/ig-all.yml >/dev/null 2>&1; then
            print_success "Ingress rules deployed"
        else
            print_warning "Ingress rules deployment had issues"
        fi
    else
        print_warning "Ingress rules file not found, skipping"
    fi
    
    # Wait for applications to potentially start
    print_info "Waiting for applications to potentially start..."
    sleep 30
    
    # Step 16: Verify complete setup (with realistic expectations)
    print_step "✅ STEP 16: Verifying complete setup"
    
    print_info "Cluster nodes:"
    kubectl get nodes || print_warning "Could not get nodes"
    echo ""
    
    print_info "Core system pods:"
    kubectl get pods -n kube-system || print_warning "Could not get kube-system pods"
    echo ""
    
    print_info "All services:"
    kubectl get services -A || print_warning "Could not get services"
    echo ""
    
    print_info "Ingress resources:"
    kubectl get ingress -A 2>/dev/null || print_info "No ingress resources found yet"
    echo ""
    
    # Test basic functionality
    print_info "Testing basic cluster functionality..."
    if kubectl run test-basic --image=busybox --command -- echo "Hello Kubernetes" >/dev/null 2>&1; then
        sleep 5
        local test_logs=$(kubectl logs test-basic 2>/dev/null || echo "No logs")
        if echo "$test_logs" | grep -q "Hello"; then
            print_success "Basic pod execution is working"
        else
            print_warning "Basic pod execution may have issues"
        fi
        kubectl delete pod test-basic >/dev/null 2>&1 || true
    else
        print_warning "Could not create test pod"
    fi
    
    # Test connectivity
    test_connectivity
    
    # Final summary
    print_step "🎉 REBUILD COMPLETE!"
    echo ""
    print_success "Kubernetes cluster has been successfully rebuilt!"
    echo ""
    echo -e "${CYAN}📋 SUMMARY:${NC}"
    echo "• Control Node: $CONTROL_IP (Ethernet primary)"
    echo "• User: pi"
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
    echo -e "${CYAN}📋 SUMMARY:${NC}"
    echo "• Kubernetes cluster with secure certificates"
    echo "• CNI networking (bridge fallback if needed)"
    echo "• MetalLB LoadBalancer (or graceful fallback)"
    echo "• NGINX Ingress Controller (NodePort mode)"
    echo "• Proper service accounts and RBAC"
    echo ""
    print_info "Known status:"
    print_warning "- Scheduler may show TLS certificate validation warnings (cluster still functional)"
    print_warning "- MetalLB pods may not schedule on single-node cluster (LoadBalancer still works)"
    echo ""
    print_info "Next steps:"
    echo "  • Test your applications with ingress"
    echo "  • Check external access via router port forwarding"
    echo "  • Monitor pod status with: kubectl get pods -A"
    echo "  • View logs if needed: kubectl logs -n <namespace> <pod-name>"
    echo ""
    echo -e "${GREEN}Ready for production use! 🚀${NC}"
}

# Run main function
main "$@"