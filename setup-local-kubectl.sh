#!/bin/bash

# Setup kubectl on local machine for Kubernetes cluster access
# This script downloads kubectl, configures it, and sets up convenient aliases

set -e

# Configuration
KUBECTL_VERSION="v1.33.5"  # Match your cluster version
KUBECONFIG_SOURCE_HOST="pi@192.168.1.114"
KUBECONFIG_SOURCE_PATH="/home/pi/.kube/config"
LOCAL_KUBECONFIG_DIR="$HOME/.kube"
LOCAL_KUBECONFIG_PATH="$LOCAL_KUBECONFIG_DIR/config"

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

# Function to detect OS and architecture
detect_platform() {
    OS="$(uname -s | tr '[:upper:]' '[:lower:]')"
    ARCH="$(uname -m)"
    
    case $ARCH in
        x86_64) ARCH="amd64" ;;
        aarch64|arm64) ARCH="arm64" ;;
        armv7l) ARCH="arm" ;;
        *) print_error "Unsupported architecture: $ARCH"; exit 1 ;;
    esac
    
    case $OS in
        linux|darwin) ;;
        mingw*|msys*|cygwin*) OS="windows"; KUBECTL_BINARY="kubectl.exe" ;;
        *) print_error "Unsupported OS: $OS"; exit 1 ;;
    esac
    
    if [[ $OS != "windows" ]]; then
        KUBECTL_BINARY="kubectl"
    fi
    
    print_status "Detected platform: $OS/$ARCH"
}

# Function to check if kubectl is already installed
check_existing_kubectl() {
    if command -v kubectl &> /dev/null; then
        EXISTING_VERSION=$(kubectl version --client --output=yaml 2>/dev/null | grep gitVersion | awk '{print $2}' || echo "unknown")
        print_warning "kubectl is already installed (version: $EXISTING_VERSION)"
        read -p "Do you want to reinstall kubectl $KUBECTL_VERSION? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            print_status "Skipping kubectl installation"
            return 1
        fi
    fi
    return 0
}

# Function to install kubectl
install_kubectl() {
    print_status "Installing kubectl $KUBECTL_VERSION for $OS/$ARCH..."
    
    # Create temporary directory
    TEMP_DIR=$(mktemp -d)
    cd "$TEMP_DIR"
    
    # Download kubectl
    KUBECTL_URL="https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/${OS}/${ARCH}/${KUBECTL_BINARY}"
    print_status "Downloading from: $KUBECTL_URL"
    
    if command -v curl &> /dev/null; then
        curl -LO "$KUBECTL_URL"
    elif command -v wget &> /dev/null; then
        wget "$KUBECTL_URL"
    else
        print_error "Neither curl nor wget found. Please install one of them."
        exit 1
    fi
    
    # Make kubectl executable
    chmod +x "$KUBECTL_BINARY"
    
    # Determine installation directory
    if [[ $OS == "windows" ]]; then
        # For Windows (Git Bash/WSL), try to find a suitable directory
        INSTALL_DIR="$HOME/bin"
    else
        # For Linux/macOS, prefer user local bin, fallback to system
        if [[ -d "$HOME/.local/bin" ]]; then
            INSTALL_DIR="$HOME/.local/bin"
        elif [[ -d "$HOME/bin" ]]; then
            INSTALL_DIR="$HOME/bin"
        elif [[ -w "/usr/local/bin" ]]; then
            INSTALL_DIR="/usr/local/bin"
        else
            print_error "No suitable installation directory found. Creating $HOME/bin"
            INSTALL_DIR="$HOME/bin"
            mkdir -p "$INSTALL_DIR"
        fi
    fi
    
    # Create installation directory if it doesn't exist
    mkdir -p "$INSTALL_DIR"
    
    # Move kubectl to installation directory
    mv "$KUBECTL_BINARY" "$INSTALL_DIR/"
    
    # Clean up temp directory
    cd - > /dev/null
    rm -rf "$TEMP_DIR"
    
    print_success "kubectl installed to $INSTALL_DIR/$KUBECTL_BINARY"
    
    # Check if installation directory is in PATH
    if [[ ":$PATH:" != *":$INSTALL_DIR:"* ]]; then
        print_warning "Warning: $INSTALL_DIR is not in your PATH"
        print_status "Add this line to your shell profile (~/.bashrc, ~/.zshrc, etc.):"
        echo "export PATH=\"\$PATH:$INSTALL_DIR\""
        
        # Offer to add to PATH automatically
        if [[ $OS != "windows" ]]; then
            read -p "Do you want to add $INSTALL_DIR to your PATH in ~/.bashrc? (y/N): " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                echo "export PATH=\"\$PATH:$INSTALL_DIR\"" >> ~/.bashrc
                print_success "Added $INSTALL_DIR to PATH in ~/.bashrc"
                print_status "Run 'source ~/.bashrc' or restart your terminal"
            fi
        fi
    fi
}

# Function to setup kubeconfig
setup_kubeconfig() {
    print_status "Setting up kubeconfig from cluster..."
    
    # Create .kube directory
    mkdir -p "$LOCAL_KUBECONFIG_DIR"
    
    # Copy kubeconfig from cluster
    print_status "Copying kubeconfig from $KUBECONFIG_SOURCE_HOST:$KUBECONFIG_SOURCE_PATH"
    
    if command -v scp &> /dev/null; then
        scp "$KUBECONFIG_SOURCE_HOST:$KUBECONFIG_SOURCE_PATH" "$LOCAL_KUBECONFIG_PATH"
    else
        print_error "scp command not found. Please install openssh-client or copy the kubeconfig manually."
        print_status "Manual copy command:"
        echo "scp $KUBECONFIG_SOURCE_HOST:$KUBECONFIG_SOURCE_PATH $LOCAL_KUBECONFIG_PATH"
        return 1
    fi
    
    # Set proper permissions
    chmod 600 "$LOCAL_KUBECONFIG_PATH"
    
    print_success "Kubeconfig copied to $LOCAL_KUBECONFIG_PATH"
}

# Function to verify kubectl setup
verify_setup() {
    print_status "Verifying kubectl setup..."
    
    # Test kubectl version
    if kubectl version --client > /dev/null 2>&1; then
        CLIENT_VERSION=$(kubectl version --client --output=yaml 2>/dev/null | grep gitVersion | awk '{print $2}')
        print_success "kubectl client version: $CLIENT_VERSION"
    else
        print_error "kubectl client test failed"
        return 1
    fi
    
    # Test cluster connection
    if kubectl cluster-info > /dev/null 2>&1; then
        print_success "Successfully connected to cluster"
        kubectl get nodes
    else
        print_warning "Could not connect to cluster. Check your kubeconfig and network connectivity."
    fi
}

# Function to setup convenient aliases
setup_aliases() {
    print_status "Setting up kubectl aliases..."
    
    ALIASES="
# Kubectl aliases
alias k='kubectl'
alias kgp='kubectl get pods'
alias kgs='kubectl get svc'
alias kgn='kubectl get nodes'
alias kgd='kubectl get deployments'
alias kga='kubectl get all'
alias kdp='kubectl describe pod'
alias kds='kubectl describe svc'
alias kdn='kubectl describe node'
alias kdd='kubectl describe deployment'
alias kaf='kubectl apply -f'
alias kdf='kubectl delete -f'
alias klf='kubectl logs -f'
alias kex='kubectl exec -it'
"
    
    # Determine shell profile file
    if [[ -f ~/.zshrc ]]; then
        PROFILE_FILE="$HOME/.zshrc"
    elif [[ -f ~/.bashrc ]]; then
        PROFILE_FILE="$HOME/.bashrc"
    else
        PROFILE_FILE="$HOME/.bash_profile"
    fi
    
    # Check if aliases already exist
    if grep -q "# Kubectl aliases" "$PROFILE_FILE" 2>/dev/null; then
        print_warning "Kubectl aliases already exist in $PROFILE_FILE"
        read -p "Do you want to replace them? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            # Remove existing aliases
            sed -i '/# Kubectl aliases/,/^$/d' "$PROFILE_FILE"
        else
            print_status "Skipping alias setup"
            return 0
        fi
    fi
    
    # Add aliases
    echo "$ALIASES" >> "$PROFILE_FILE"
    print_success "Kubectl aliases added to $PROFILE_FILE"
    print_status "Run 'source $PROFILE_FILE' or restart your terminal to use aliases"
}

# Function to display completion setup instructions
setup_completion() {
    print_status "Setting up kubectl command completion..."
    
    # Determine shell
    SHELL_NAME=$(basename "$SHELL")
    
    case $SHELL_NAME in
        bash)
            COMPLETION_CMD="source <(kubectl completion bash)"
            PROFILE_FILE="$HOME/.bashrc"
            ;;
        zsh)
            COMPLETION_CMD="source <(kubectl completion zsh)"
            PROFILE_FILE="$HOME/.zshrc"
            ;;
        *)
            print_warning "Shell completion not configured for $SHELL_NAME"
            return 0
            ;;
    esac
    
    # Check if completion already exists
    if grep -q "kubectl completion" "$PROFILE_FILE" 2>/dev/null; then
        print_status "kubectl completion already configured"
        return 0
    fi
    
    read -p "Do you want to enable kubectl command completion? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "# kubectl completion" >> "$PROFILE_FILE"
        echo "$COMPLETION_CMD" >> "$PROFILE_FILE"
        print_success "kubectl completion added to $PROFILE_FILE"
    fi
}

# Function to display summary
display_summary() {
    echo
    print_success "kubectl setup completed!"
    echo
    print_status "Summary:"
    echo "  - kubectl installed and configured"
    echo "  - kubeconfig copied from cluster"
    echo "  - aliases and completion configured"
    echo
    print_status "Quick test commands:"
    echo "  kubectl get nodes"
    echo "  kubectl get pods -A"
    echo "  k get svc  # using alias"
    echo
    print_status "Next steps:"
    echo "  - Run 'source ~/.bashrc' (or ~/.zshrc) to load aliases"
    echo "  - Test cluster connectivity: kubectl cluster-info"
    echo "  - Explore your cluster: kubectl get all -A"
}

# Main execution
main() {
    echo "=============================================="
    echo "     Kubernetes kubectl Local Setup"
    echo "=============================================="
    echo
    
    # Check if running from correct directory
    if [[ ! -f "runSetup_new.sh" ]]; then
        print_warning "Not running from the ansible directory"
        print_status "This script should be run from the same directory as runSetup_new.sh"
    fi
    
    # Detect platform
    detect_platform
    
    # Install kubectl
    if check_existing_kubectl; then
        install_kubectl
    fi
    
    # Setup kubeconfig
    setup_kubeconfig
    
    # Verify setup
    verify_setup
    
    # Setup aliases
    setup_aliases
    
    # Setup completion
    setup_completion
    
    # Display summary
    display_summary
}

# Run main function
main "$@"