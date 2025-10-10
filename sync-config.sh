#!/bin/bash

# Enhanced configuration detection script
# This script reads configuration from the inventory file and updates config.env accordingly

INVENTORY_FILE="$(dirname "$0")/ansible/inventory/all-server.ini"
CONFIG_FILE="$(dirname "$0")/config.env"

if [ ! -f "$INVENTORY_FILE" ]; then
    echo "Error: Inventory file $INVENTORY_FILE not found"
    exit 1
fi

# Extract configuration from inventory file
ANSIBLE_USER=$(grep "ansible_user=" "$INVENTORY_FILE" | cut -d'=' -f2)
CONTROL_NODE=$(grep "ansible_host=" "$INVENTORY_FILE" | cut -d' ' -f1)
CONTROL_IP=$(grep "ansible_host=" "$INVENTORY_FILE" | cut -d'=' -f2)

# Get MetalLB version from existing config or use default
METALLB_VERSION="v0.15.2"
if [ -f "$CONFIG_FILE" ]; then
    EXISTING_VERSION=$(grep "METALLB_VERSION=" "$CONFIG_FILE" | cut -d'=' -f2)
    if [ ! -z "$EXISTING_VERSION" ]; then
        METALLB_VERSION="$EXISTING_VERSION"
    fi
fi

# Update config.env with detected values
cat > "$CONFIG_FILE" << EOF
# Kubernetes Cluster Configuration
# This file contains centralized configuration for the entire project
# Update these values when making changes to your environment

# User Configuration
ANSIBLE_USER=$ANSIBLE_USER
CONTROL_NODE=$CONTROL_NODE
CONTROL_IP=$CONTROL_IP

# Kubernetes Configuration
METALLB_VERSION=$METALLB_VERSION

# Network Configuration
# Add your network settings here if needed
EOF

echo "Configuration synchronized from inventory file:"
echo "  User: $ANSIBLE_USER"
echo "  Control Node: $CONTROL_NODE"
echo "  Control IP: $CONTROL_IP"
echo "  MetalLB Version: $METALLB_VERSION"
echo ""
echo "config.env has been updated with current inventory settings."