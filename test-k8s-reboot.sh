#!/bin/bash

# Kubernetes Reboot Test Script
# This script helps test and validate post-reboot recovery

echo "🔄 Starting Kubernetes Reboot Test..."

# Function to check cluster health
check_cluster_health() {
    echo "📊 Checking cluster health..."
    
    # Check node status
    echo "Node Status:"
    kubectl get nodes -o wide
    
    # Check system pods
    echo -e "\n🔍 System Pods Status:"
    kubectl get pods -n kube-system
    
    # Check Flannel
    echo -e "\n🌐 Flannel Status:"
    kubectl get pods -n kube-flannel
    
    # Check any problematic pods
    echo -e "\n⚠️  Problematic Pods:"
    kubectl get pods -A | grep -E "(Pending|Unknown|Error|CrashLoop|ContainerCreating)" || echo "No problematic pods found"
    
    # Check services
    echo -e "\n🚀 LoadBalancer Services:"
    kubectl get svc --all-namespaces | grep LoadBalancer || echo "No LoadBalancer services found"
}

case "${1:-check}" in
    "reboot")
        echo "🔄 Performing controlled reboot..."
        echo "Current cluster status:"
        check_cluster_health
        echo -e "\n⏰ Rebooting in 10 seconds... (Ctrl+C to cancel)"
        sleep 10
        sudo reboot
        ;;
    "check")
        check_cluster_health
        ;;
    "recovery")
        echo "🔧 Running manual recovery..."
        
        # Remove taints
        echo "Removing control-plane taints..."
        kubectl taint nodes --all node-role.kubernetes.io/control-plane- 2>/dev/null || true
        
        # Clean unknown pods
        echo "Cleaning Unknown status pods..."
        kubectl get pods -A --field-selector=status.phase=Unknown --no-headers 2>/dev/null | while read namespace pod rest; do
            if [ ! -z "$pod" ]; then
                echo "Deleting Unknown pod: $namespace/$pod"
                kubectl delete pod "$pod" -n "$namespace" --force --grace-period=0 || true
            fi
        done
        
        # Restart problematic pods
        echo "Restarting problematic pods..."
        kubectl get pods -A | grep -E "(CrashLoop|Error)" | while read namespace pod rest; do
            if [ ! -z "$pod" ]; then
                echo "Restarting pod: $namespace/$pod"
                kubectl delete pod "$pod" -n "$namespace" --force --grace-period=0 || true
            fi
        done
        
        echo "✅ Manual recovery completed"
        ;;
    *)
        echo "Usage: $0 [check|reboot|recovery]"
        echo "  check    - Check cluster health (default)"
        echo "  reboot   - Perform controlled reboot"
        echo "  recovery - Run manual recovery procedures"
        exit 1
        ;;
esac