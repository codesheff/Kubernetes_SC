#!/bin/bash
# ============================================
# KUBERNETES RASPBERRY PI REBUILD SCRIPT
# ============================================
# Complete automation for rebuilding Kubernetes cluster
# from scratch using existing Ansible playbooks

set -e  # Exit on any error

VSCODE_DEBUG=0

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



# Main script
main() {
    print_step "KUBERNETES RASPBERRY PI CLUSTER REBUILD"
    echo -e "${YELLOW}This script will completely rebuild your Kubernetes cluster.${NC}"
    echo -e "${RED}⚠️  ALL EXISTING DATA WILL BE LOST! ⚠️${NC}"
    echo ""
    echo "Steps that will be performed:"
    echo "1. Verify Ansible connection (user: pi)"
    echo "2. Update OS and install packages"
    echo "3. Reset existing Kubernetes cluster"
    echo "4. Thorough cleanup of certificates and processes"
    echo "5. Set up base Kubernetes environment"
    echo "6. Configure Ethernet networking priority"
    echo "7. Initialize Kubernetes control (with correct IP)"
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

    
    # Step 1: Reset existing cluster
    # run_playbook "./ansible/k8s/reset-kubernetes.yml" "🔄 STEP 1: Resetting Kubernetes cluster"
    # run_playbook "./ansible/configure-pi.yml" "🔄 STEP 2: Configuring Raspberry Pi settings"
    # run_playbook "./ansible/k8s/setup-kubernetes.yml" "🔄 STEP 3: Setting up base Kubernetes environment"
    run_playbook "./ansible/k8s/masters.yml" "⚙️  STEP 8: Configuring control node"

        #  reset)      run_step ansible-playbook ${vInventory} ./k8s/reset-kubernetes.yml ;;
        # reboot)     run_step ansible-playbook ${vInventory} ./reboot.yml ;;
        # setup)      run_step ansible-playbook ${vInventory} ./k8s/setup.yml ;;
        # initialise) run_step ansible-playbook ${vInventory} ./k8s/initialise.yml ;;
        # masters)    run_step ansible-playbook ${vInventory} ./k8s/masters.yml ;;
        # metalb)     run_step ansible-playbook ${vInventory} ./k8s/metallb.yml ;;
        # workers)    run_step ansible-playbook ${vInventory} ./k8s/workers.yml ;;

}

# Run main function
main "$@"