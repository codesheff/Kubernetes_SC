#!/bin/bash

# Configuration update script for Kubernetes cluster
# This script updates all configuration files based on config.env

CONFIG_FILE="$(dirname "$0")/config.env"

if [ ! -f "$CONFIG_FILE" ]; then
    echo "Error: Configuration file $CONFIG_FILE not found"
    exit 1
fi

# Source the configuration
source "$CONFIG_FILE"

# Update inventory file
INVENTORY_FILE="$(dirname "$0")/ansible/inventory/all-server.ini"
if [ -f "$INVENTORY_FILE" ]; then
    echo "Updating Ansible inventory..."
    sed -i "s/ansible_user=.*/ansible_user=$ANSIBLE_USER/" "$INVENTORY_FILE"
    sed -i "s/^[a-zA-Z0-9_-]* ansible_host=.*/$CONTROL_NODE ansible_host=$CONTROL_IP/" "$INVENTORY_FILE"
    sed -i "s/^[a-zA-Z0-9_-]*$/$CONTROL_NODE/" "$INVENTORY_FILE"
fi

# Update rebuild script if needed
REBUILD_SCRIPT="$(dirname "$0")/rebuild-k8s.sh"
if [ -f "$REBUILD_SCRIPT" ]; then
    echo "Updating rebuild script references..."
    # Get the current control node name from inventory
    CURRENT_CONTROL_NODE=$(grep "ansible_host=" "$INVENTORY_FILE" | cut -d' ' -f1)
    if [ ! -z "$CURRENT_CONTROL_NODE" ]; then
        # Update ansible commands to use the correct control node name
        sed -i "s/ansible [a-zA-Z0-9_-]* -i/ansible $CURRENT_CONTROL_NODE -i/g" "$REBUILD_SCRIPT"
    fi
fi

# Update documentation
CHECKLIST_FILE="$(dirname "$0")/pre-rebuild-checklist.md"
if [ -f "$CHECKLIST_FILE" ]; then
    echo "Updating documentation..."
    sed -i "s/ssh [a-zA-Z0-9]*@/ssh $ANSIBLE_USER@/g" "$CHECKLIST_FILE"
    sed -i "s/'[a-zA-Z0-9]*' user/'$ANSIBLE_USER' user/g" "$CHECKLIST_FILE"
    sed -i "s/@[0-9.]*/@$CONTROL_IP/g" "$CHECKLIST_FILE"
fi

echo "Configuration updated successfully!"
echo "Current settings:"
echo "  User: $ANSIBLE_USER"
echo "  Control Node: $CONTROL_NODE"
echo "  Control IP: $CONTROL_IP"
echo "  MetalLB Version: $METALLB_VERSION"