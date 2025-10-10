# Local kubectl Setup

This directory contains a script for setting up kubectl on your local machine to access the Kubernetes cluster.

## Setup Script 🚀

**File:** `setup-local-kubectl.sh`

**Advantages:**
- ✅ No dependencies (works without Ansible)
- ✅ Cross-platform (Linux, macOS, Windows/WSL)
- ✅ Interactive prompts for user preferences
- ✅ Automatic platform detection
- ✅ Better error handling and user feedback
- ✅ Easy to distribute and share

**Usage:**
```bash
cd /mnt/c/git/SC_Kubernetes
./setup-local-kubectl.sh
```

**What it does:**
- Detects your OS and architecture automatically
- Downloads the correct kubectl version (v1.33.5 to match cluster)
- Installs kubectl to an appropriate location
- Copies kubeconfig from your cluster via SSH
- Sets up helpful kubectl aliases (k, kgp, kgs, etc.)
- Configures bash completion for kubectl
- Verifies the setup and connection to cluster
- ## Setup Details

The script will:
- Install kubectl v1.33.5 (matching your cluster version)
- Copy kubeconfig from `pi@192.168.1.114:/home/pi/.kube/config`
- Set up these useful aliases:
  - `k` = `kubectl`
  - `kgp` = `kubectl get pods`
  - `kgs` = `kubectl get svc`
  - `kgn` = `kubectl get nodes`
  - `kga` = `kubectl get all`
  - And many more...

## Post-Setup Verification

After running either option, test your setup:

```bash
# Source your shell profile to load aliases
source ~/.bashrc

# Test kubectl
kubectl version --client
kubectl cluster-info
kubectl get nodes

# Test aliases
k get pods -A
kgn
```

## Troubleshooting

If kubectl can't connect to the cluster:
1. Verify SSH access to the cluster: `ssh pi@192.168.1.114`
2. Check kubeconfig exists: `ls -la ~/.kube/config`
3. Verify cluster is running: SSH to cluster and run `kubectl get nodes`
4. Check network connectivity to cluster IP 192.168.1.114

## Manual Setup (if scripts fail)

If both automated options fail, you can set up kubectl manually:

```bash
# 1. Download kubectl
curl -LO "https://dl.k8s.io/release/v1.33.5/bin/linux/amd64/kubectl"
chmod +x kubectl
sudo mv kubectl /usr/local/bin/

# 2. Copy kubeconfig
mkdir -p ~/.kube
scp pi@192.168.1.114:/home/pi/.kube/config ~/.kube/config
chmod 600 ~/.kube/config

# 3. Test
kubectl get nodes
```