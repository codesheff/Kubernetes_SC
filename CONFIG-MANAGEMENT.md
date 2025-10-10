# Configuration Management Guide

## Overview
This project uses a centralized configuration system to make username, node names, and other environment changes simple and consistent.

## Quick Configuration Change
**Option 1: Update inventory first (Recommended)**
1. Edit `ansible/inventory/all-server.ini` with your desired settings
2. Run `./sync-config.sh` to automatically update `config.env`
3. Run `./update-config.sh` to propagate changes to all files

**Option 2: Update config.env directly**
1. Edit `config.env` with your desired values
2. Run `./update-config.sh` to apply changes across all files

## Configuration Files

### ansible/inventory/all-server.ini
Primary source of truth for:
- Control node name and IP address
- Username (ansible_user)

### config.env
Central configuration file containing:
- `ANSIBLE_USER`: Username for SSH/Ansible connections
- `CONTROL_NODE`: Name of the Kubernetes control node
- `CONTROL_IP`: IP address of the Kubernetes control node
- `METALLB_VERSION`: Version of MetalLB to install

### sync-config.sh
Script that reads configuration from inventory file and updates config.env automatically.

### update-config.sh
Script that applies configuration changes from config.env to all relevant files.

## Manual Changes Previously Required
Before this system, changing the username required updating:
1. `ansible/inventory/all-server.ini` - ansible_user setting
2. All Ansible playbooks - hardcoded username references
3. `rebuild-k8s.sh` - script output messages
4. `pre-rebuild-checklist.md` - documentation examples

## Current System Benefits
- ✅ Single point of configuration (`config.env`)
- ✅ Automated propagation of changes
- ✅ Ansible playbooks use `{{ ansible_user }}` variable
- ✅ Consistent configuration across all files
- ✅ Easy to maintain and update

## Usage Examples

### Change Control Node Name
```bash
# Method 1: Update inventory first (recommended)
# Edit ansible/inventory/all-server.ini:
# Change: control ansible_host=192.168.1.112
# To:     k8s-control ansible_host=192.168.1.112

./sync-config.sh      # Sync config.env with inventory
./update-config.sh    # Apply to all files
```

### Change Username and Control Node
```bash
# Method 2: Direct config.env update
echo "ANSIBLE_USER=ubuntu" > config.env
echo "CONTROL_NODE=controlplane" >> config.env
echo "CONTROL_IP=192.168.1.112" >> config.env
echo "METALLB_VERSION=v0.15.2" >> config.env

./update-config.sh    # Apply changes
```

### Complete Setup for New Environment
```bash
# 1. Edit inventory file with your actual values
# 2. Sync configuration
./sync-config.sh

# 3. Verify config.env is correct
cat config.env

# 4. Apply to all files
./update-config.sh
```