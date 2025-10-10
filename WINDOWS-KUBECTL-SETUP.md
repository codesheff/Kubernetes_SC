# Windows kubectl Setup Guide

This guide provides scripts and instructions for setting up kubectl on Windows to access your Kubernetes cluster.

## Quick Start 🚀

### Option 1: Run the Batch File (Easiest)
1. Double-click `setup-local-kubectl.bat`
2. Follow the prompts

### Option 2: Run PowerShell Script Directly
1. Open PowerShell as Administrator (recommended) or regular user
2. Navigate to this directory
3. Run: `.\setup-local-kubectl.ps1`

### Option 3: Command Line with Parameters
```powershell
# Basic usage
.\setup-local-kubectl.ps1

# Force reinstall everything
.\setup-local-kubectl.ps1 -Force

# Custom cluster settings
.\setup-local-kubectl.ps1 -ClusterHost "192.168.1.100" -ClusterUser "admin"

# Specific kubectl version
.\setup-local-kubectl.ps1 -KubectlVersion "v1.30.0"
```

## What the Script Does

### 1. Downloads and Installs kubectl
- ✅ Downloads the correct kubectl version (v1.33.5 by default) for Windows
- ✅ Installs to appropriate location (user bin directory or system directory)
- ✅ Adds kubectl to your PATH environment variable
- ✅ Supports both x64 and ARM64 architectures

### 2. Configures kubeconfig
- ✅ Tries to copy kubeconfig via SCP from cluster (requires OpenSSH)
- ✅ Falls back to copying from local ansible directory
- ✅ Creates `~/.kube/config` with proper permissions

### 3. Sets Up PowerShell Aliases
Adds convenient kubectl shortcuts to your PowerShell profile:
- `k` = `kubectl`
- `kgp` = `kubectl get pods`
- `kgs` = `kubectl get svc`
- `kgn` = `kubectl get nodes`
- `kgd` = `kubectl get deployments`
- `kga` = `kubectl get all`
- `kdp` = `kubectl describe pod`
- `kds` = `kubectl describe svc`
- `kdn` = `kubectl describe node`
- `kdd` = `kubectl describe deployment`
- `kaf` = `kubectl apply -f`
- `kdf` = `kubectl delete -f`
- `klf` = `kubectl logs -f`
- `kex` = `kubectl exec -it`

### 4. Enables kubectl Tab Completion
- ✅ Configures PowerShell tab completion for kubectl commands
- ✅ Works with arguments, resource names, and more

## Prerequisites

### Required
- **Windows 10/11** or **Windows Server 2016+**
- **PowerShell 5.0+** (included with Windows 10/11)

### Optional (for SCP kubeconfig copy)
- **OpenSSH Client** - Available via:
  - Windows Features (Settings > Apps > Optional Features > OpenSSH Client)
  - Windows Subsystem for Linux (WSL)
  - Git for Windows (includes SSH tools)

## Manual Setup (if scripts fail)

If the automated setup fails, you can set up kubectl manually:

### 1. Download kubectl manually
```powershell
# Download kubectl
$version = "v1.33.5"
$url = "https://dl.k8s.io/release/$version/bin/windows/amd64/kubectl.exe"
Invoke-WebRequest -Uri $url -OutFile "$env:USERPROFILE\bin\kubectl.exe"

# Add to PATH
$userPath = [Environment]::GetEnvironmentVariable("PATH", "User")
[Environment]::SetEnvironmentVariable("PATH", "$userPath;$env:USERPROFILE\bin", "User")
```

### 2. Copy kubeconfig manually
```powershell
# Create .kube directory
New-Item -ItemType Directory -Path "$env:USERPROFILE\.kube" -Force

# Option A: Copy from cluster via SCP
scp pi@192.168.1.114:/home/pi/.kube/config "$env:USERPROFILE\.kube\config"

# Option B: Copy from ansible directory
Copy-Item ".\ansible\k8s\kubeconfig" "$env:USERPROFILE\.kube\config"
```

### 3. Test setup
```powershell
kubectl version --client
kubectl get nodes
```

## Troubleshooting

### PowerShell Execution Policy Error
If you get an execution policy error:
```powershell
# Check current policy
Get-ExecutionPolicy

# Allow script execution (run as Administrator)
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser

# Or run with bypass (temporary)
powershell -ExecutionPolicy Bypass -File setup-local-kubectl.ps1
```

### kubectl Not Found After Installation
1. **Restart PowerShell/Command Prompt** - PATH changes require a new session
2. **Check PATH manually**:
   ```powershell
   $env:PATH -split ';' | Where-Object { $_ -like "*bin*" }
   ```
3. **Add to PATH manually** via System Properties > Environment Variables

### Cluster Connection Issues
1. **Test network connectivity**:
   ```powershell
   Test-NetConnection -ComputerName 192.168.1.114 -Port 6443
   ```

2. **Verify kubeconfig**:
   ```powershell
   Get-Content "$env:USERPROFILE\.kube\config" | Select-String "server:"
   ```

3. **Test SSH access** (if using SCP):
   ```powershell
   ssh pi@192.168.1.114 "kubectl get nodes"
   ```

### SCP Not Working
If SCP fails to copy kubeconfig:

1. **Install OpenSSH Client**:
   - Go to Settings > Apps > Optional Features
   - Add "OpenSSH Client"

2. **Use WSL** (if available):
   ```bash
   wsl scp pi@192.168.1.114:/home/pi/.kube/config /mnt/c/Users/$USER/.kube/config
   ```

3. **Manual copy**:
   - The kubeconfig is already available in `ansible/k8s/kubeconfig`
   - Just copy it to `%USERPROFILE%\.kube\config`

## Post-Setup Verification

After running the setup script:

### 1. Load new PowerShell profile
```powershell
. $PROFILE
```

### 2. Test kubectl
```powershell
# Test client
kubectl version --client

# Test cluster connection
kubectl cluster-info

# Test aliases
k get nodes
kgp -A
kgs
```

### 3. Explore your cluster
```powershell
# Get cluster information
kubectl get all -A

# Check cluster health
kubectl get componentstatuses

# View cluster events
kubectl get events --sort-by=.metadata.creationTimestamp
```

## Advanced Usage

### Different Cluster Configuration
```powershell
# Setup for different cluster
.\setup-local-kubectl.ps1 -ClusterHost "10.0.1.100" -ClusterUser "admin"
```

### Force Reinstall
```powershell
# Reinstall everything
.\setup-local-kubectl.ps1 -Force
```

### Specific kubectl Version
```powershell
# Install specific version
.\setup-local-kubectl.ps1 -KubectlVersion "v1.30.0"
```

## Files Created/Modified

The setup script creates or modifies:

- `%USERPROFILE%\bin\kubectl.exe` - kubectl binary
- `%USERPROFILE%\.kube\config` - Kubernetes configuration
- `$PROFILE` - PowerShell profile (for aliases and completion)
- User PATH environment variable

## Security Notes

- The script modifies your PowerShell profile to add aliases and completion
- kubeconfig contains credentials for cluster access - keep it secure
- The script may need to modify PATH environment variable
- Network communication with cluster happens over HTTPS (port 6443)

## Support

If you encounter issues:
1. Check the troubleshooting section above
2. Run with `-Verbose` flag for more details
3. Check the original bash script (`setup-local-kubectl.sh`) for reference
4. Verify cluster is accessible: `ping 192.168.1.114`