# Setup kubectl on local Windows machine for Kubernetes cluster access
# This script downloads kubectl, configures it, and sets up convenient aliases

param(
    [switch]$Force,
    [string]$KubectlVersion = "v1.33.5",
    [string]$ClusterHost = "192.168.1.114",
    [string]$ClusterUser = "pi"
)

# Configuration
$KUBECTL_VERSION = $KubectlVersion
$KUBECONFIG_SOURCE_HOST = "$ClusterUser@$ClusterHost"
$KUBECONFIG_SOURCE_PATH = "/home/pi/.kube/config"
$LOCAL_KUBECONFIG_DIR = "$env:USERPROFILE\.kube"
$LOCAL_KUBECONFIG_PATH = "$LOCAL_KUBECONFIG_DIR\config"

# Function to print colored output
function Write-Status {
    param([string]$Message)
    Write-Host "[INFO] $Message" -ForegroundColor Blue
}

function Write-Success {
    param([string]$Message)
    Write-Host "[SUCCESS] $Message" -ForegroundColor Green
}

function Write-Warning {
    param([string]$Message)
    Write-Host "[WARNING] $Message" -ForegroundColor Yellow
}

function Write-Error {
    param([string]$Message)
    Write-Host "[ERROR] $Message" -ForegroundColor Red
}

# Function to check if running as administrator
function Test-Administrator {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# Function to detect architecture
function Get-Architecture {
    $arch = $env:PROCESSOR_ARCHITECTURE
    switch ($arch) {
        "AMD64" { return "amd64" }
        "ARM64" { return "arm64" }
        default { 
            Write-Error "Unsupported architecture: $arch"
            exit 1
        }
    }
}

# Function to check if kubectl is already installed
function Test-ExistingKubectl {
    $kubectl = Get-Command kubectl -ErrorAction SilentlyContinue
    if ($kubectl) {
        try {
            $existingVersion = & kubectl version --client --output=yaml 2>$null | Select-String "gitVersion" | ForEach-Object { $_.ToString().Split(":")[1].Trim() }
            Write-Warning "kubectl is already installed (version: $existingVersion)"
            
            if (-not $Force) {
                $response = Read-Host "Do you want to reinstall kubectl $KUBECTL_VERSION? (y/N)"
                if ($response -ne "y" -and $response -ne "Y") {
                    Write-Status "Skipping kubectl installation"
                    return $false
                }
            }
        }
        catch {
            Write-Warning "kubectl is installed but version check failed"
        }
    }
    return $true
}

# Function to install kubectl
function Install-Kubectl {
    Write-Status "Installing kubectl $KUBECTL_VERSION for Windows/amd64..."
    
    $arch = Get-Architecture
    $KUBECTL_URL = "https://dl.k8s.io/release/$KUBECTL_VERSION/bin/windows/$arch/kubectl.exe"
    Write-Status "Downloading from: $KUBECTL_URL"
    
    # Create temporary directory
    $tempDir = New-TemporaryFile | ForEach-Object { Remove-Item $_; New-Item -ItemType Directory -Path $_ }
    $kubectlPath = Join-Path $tempDir "kubectl.exe"
    
    try {
        # Download kubectl
        Write-Status "Downloading kubectl..."
        Invoke-WebRequest -Uri $KUBECTL_URL -OutFile $kubectlPath -UseBasicParsing
        
        # Determine installation directory
        $installDirs = @(
            "$env:USERPROFILE\bin",
            "$env:LOCALAPPDATA\Microsoft\WindowsApps",
            "C:\Windows\System32"
        )
        
        $installDir = $null
        foreach ($dir in $installDirs) {
            if (Test-Path $dir -PathType Container) {
                # Test write access
                $testFile = Join-Path $dir "test_write_access.tmp"
                try {
                    New-Item -Path $testFile -ItemType File -Force | Out-Null
                    Remove-Item $testFile -Force
                    $installDir = $dir
                    break
                }
                catch {
                    continue
                }
            }
        }
        
        if (-not $installDir) {
            # Create user bin directory
            $installDir = "$env:USERPROFILE\bin"
            New-Item -ItemType Directory -Path $installDir -Force | Out-Null
        }
        
        # Copy kubectl to installation directory
        $finalPath = Join-Path $installDir "kubectl.exe"
        Copy-Item $kubectlPath $finalPath -Force
        
        Write-Success "kubectl installed to $finalPath"
        
        # Check if installation directory is in PATH
        $currentPath = [Environment]::GetEnvironmentVariable("PATH", "User")
        if ($currentPath -notlike "*$installDir*") {
            Write-Warning "$installDir is not in your PATH"
            $response = Read-Host "Do you want to add $installDir to your PATH? (y/N)"
            if ($response -eq "y" -or $response -eq "Y") {
                $newPath = "$currentPath;$installDir"
                [Environment]::SetEnvironmentVariable("PATH", $newPath, "User")
                $env:PATH = "$env:PATH;$installDir"
                Write-Success "Added $installDir to user PATH"
                Write-Status "PATH updated for current session. Restart PowerShell or Command Prompt for permanent effect."
            }
            else {
                Write-Status "You can manually add $installDir to your PATH in System Properties > Environment Variables"
            }
        }
    }
    finally {
        # Clean up temp directory
        Remove-Item $tempDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# Function to setup kubeconfig using SCP (requires OpenSSH or WSL)
function Set-KubeconfigSCP {
    Write-Status "Setting up kubeconfig from cluster using SCP..."
    
    # Create .kube directory
    if (-not (Test-Path $LOCAL_KUBECONFIG_DIR)) {
        New-Item -ItemType Directory -Path $LOCAL_KUBECONFIG_DIR -Force | Out-Null
    }
    
    # Check if scp is available
    $scp = Get-Command scp -ErrorAction SilentlyContinue
    if (-not $scp) {
        Write-Error "scp command not found. Please install OpenSSH client or use WSL."
        Write-Status "Alternative: Install OpenSSH client via Windows Features or use the manual setup option."
        return $false
    }
    
    # Copy kubeconfig from cluster
    Write-Status "Copying kubeconfig from $KUBECONFIG_SOURCE_HOST`:$KUBECONFIG_SOURCE_PATH"
    
    try {
        & scp "$KUBECONFIG_SOURCE_HOST`:$KUBECONFIG_SOURCE_PATH" "$LOCAL_KUBECONFIG_PATH"
        if ($LASTEXITCODE -eq 0) {
            Write-Success "Kubeconfig copied to $LOCAL_KUBECONFIG_PATH"
            return $true
        }
        else {
            Write-Error "Failed to copy kubeconfig via SCP"
            return $false
        }
    }
    catch {
        Write-Error "SCP failed: $($_.Exception.Message)"
        return $false
    }
}

# Function to setup kubeconfig manually (copy from ansible directory)
function Set-KubeconfigManual {
    Write-Status "Setting up kubeconfig from local ansible directory..."
    
    # Create .kube directory
    if (-not (Test-Path $LOCAL_KUBECONFIG_DIR)) {
        New-Item -ItemType Directory -Path $LOCAL_KUBECONFIG_DIR -Force | Out-Null
    }
    
    # Look for kubeconfig in ansible directory
    $ansibleKubeconfig = Join-Path $PSScriptRoot "ansible\k8s\kubeconfig"
    if (Test-Path $ansibleKubeconfig) {
        Copy-Item $ansibleKubeconfig $LOCAL_KUBECONFIG_PATH -Force
        Write-Success "Kubeconfig copied from ansible directory to $LOCAL_KUBECONFIG_PATH"
        return $true
    }
    else {
        Write-Error "Kubeconfig not found in ansible directory: $ansibleKubeconfig"
        return $false
    }
}

# Function to verify kubectl setup
function Test-KubectlSetup {
    Write-Status "Verifying kubectl setup..."
    
    # Test kubectl version
    try {
        $clientVersion = & kubectl version --client --output=yaml 2>$null | Select-String "gitVersion" | ForEach-Object { $_.ToString().Split(":")[1].Trim() }
        Write-Success "kubectl client version: $clientVersion"
    }
    catch {
        Write-Error "kubectl client test failed"
        return $false
    }
    
    # Test cluster connection
    try {
        & kubectl cluster-info 2>$null | Out-Null
        if ($LASTEXITCODE -eq 0) {
            Write-Success "Successfully connected to cluster"
            & kubectl get nodes
        }
        else {
            Write-Warning "Could not connect to cluster. Check your kubeconfig and network connectivity."
        }
    }
    catch {
        Write-Warning "Cluster connection test failed: $($_.Exception.Message)"
    }
    
    return $true
}

# Function to setup PowerShell aliases
function Set-KubectlAliases {
    Write-Status "Setting up kubectl aliases for PowerShell..."
    
    $profilePath = $PROFILE
    $aliasesSection = @"

# Kubectl aliases
function k { kubectl @args }
function kgp { kubectl get pods @args }
function kgs { kubectl get svc @args }
function kgn { kubectl get nodes @args }
function kgd { kubectl get deployments @args }
function kga { kubectl get all @args }
function kdp { kubectl describe pod @args }
function kds { kubectl describe svc @args }
function kdn { kubectl describe node @args }
function kdd { kubectl describe deployment @args }
function kaf { kubectl apply -f @args }
function kdf { kubectl delete -f @args }
function klf { kubectl logs -f @args }
function kex { kubectl exec -it @args }
"@
    
    # Create profile directory if it doesn't exist
    $profileDir = Split-Path $profilePath -Parent
    if (-not (Test-Path $profileDir)) {
        New-Item -ItemType Directory -Path $profileDir -Force | Out-Null
    }
    
    # Check if aliases already exist
    if (Test-Path $profilePath) {
        $profileContent = Get-Content $profilePath -Raw
        if ($profileContent -like "*# Kubectl aliases*") {
            Write-Warning "Kubectl aliases already exist in PowerShell profile"
            if (-not $Force) {
                $response = Read-Host "Do you want to replace them? (y/N)"
                if ($response -ne "y" -and $response -ne "Y") {
                    Write-Status "Skipping alias setup"
                    return
                }
            }
            
            # Remove existing aliases section
            $lines = Get-Content $profilePath
            $newLines = @()
            $skipLines = $false
            
            foreach ($line in $lines) {
                if ($line -match "# Kubectl aliases") {
                    $skipLines = $true
                    continue
                }
                if ($skipLines -and ($line.Trim() -eq "" -or $line -match "^function \w+")) {
                    if ($line.Trim() -eq "" -and $newLines.Count -gt 0 -and $newLines[-1].Trim() -ne "") {
                        $skipLines = $false
                    }
                    continue
                }
                if ($skipLines -and $line -notmatch "^function") {
                    $skipLines = $false
                }
                if (-not $skipLines) {
                    $newLines += $line
                }
            }
            
            Set-Content $profilePath $newLines
        }
    }
    
    # Add aliases
    Add-Content $profilePath $aliasesSection
    Write-Success "Kubectl aliases added to PowerShell profile: $profilePath"
    Write-Status "Run '. `$PROFILE' or restart PowerShell to use aliases"
}

# Function to setup kubectl completion for PowerShell
function Set-KubectlCompletion {
    Write-Status "Setting up kubectl command completion for PowerShell..."
    
    $profilePath = $PROFILE
    $completionSection = @"

# kubectl completion
if (Get-Command kubectl -ErrorAction SilentlyContinue) {
    kubectl completion powershell | Out-String | Invoke-Expression
}
"@
    
    # Check if completion already exists
    if (Test-Path $profilePath) {
        $profileContent = Get-Content $profilePath -Raw
        if ($profileContent -like "*kubectl completion*") {
            Write-Status "kubectl completion already configured"
            return
        }
    }
    
    if (-not $Force) {
        $response = Read-Host "Do you want to enable kubectl command completion? (y/N)"
        if ($response -ne "y" -and $response -ne "Y") {
            return
        }
    }
    
    Add-Content $profilePath $completionSection
    Write-Success "kubectl completion added to PowerShell profile"
}

# Function to display summary
function Show-Summary {
    Write-Host ""
    Write-Success "kubectl setup completed!"
    Write-Host ""
    Write-Status "Summary:"
    Write-Host "  - kubectl installed and configured"
    Write-Host "  - kubeconfig copied from cluster"
    Write-Host "  - aliases and completion configured"
    Write-Host ""
    Write-Status "Quick test commands:"
    Write-Host "  kubectl get nodes"
    Write-Host "  kubectl get pods -A"
    Write-Host "  k get svc  # using alias"
    Write-Host ""
    Write-Status "Next steps:"
    Write-Host "  - Run '. `$PROFILE' to load aliases and completion"
    Write-Host "  - Test cluster connectivity: kubectl cluster-info"
    Write-Host "  - Explore your cluster: kubectl get all -A"
    Write-Host ""
    Write-Status "Useful aliases now available:"
    Write-Host "  k, kgp, kgs, kgn, kgd, kga, kdp, kds, kdn, kdd, kaf, kdf, klf, kex"
}

# Main execution
function Main {
    Write-Host "=============================================="
    Write-Host "     Kubernetes kubectl Local Setup (Windows)"
    Write-Host "=============================================="
    Write-Host ""
    
    # Check PowerShell version
    if ($PSVersionTable.PSVersion.Major -lt 5) {
        Write-Error "PowerShell 5.0 or later is required"
        exit 1
    }
    
    Write-Status "Running on PowerShell $($PSVersionTable.PSVersion)"
    Write-Status "Target cluster: $ClusterHost"
    Write-Status "kubectl version: $KUBECTL_VERSION"
    
    if ($Force) {
        Write-Status "Force mode enabled - will overwrite existing configurations"
    }
    
    # Install kubectl
    if (Test-ExistingKubectl) {
        Install-Kubectl
    }
    
    # Setup kubeconfig - try SCP first, then manual
    $kubeconfigSuccess = Set-KubeconfigSCP
    if (-not $kubeconfigSuccess) {
        Write-Status "SCP failed, trying manual copy from ansible directory..."
        $kubeconfigSuccess = Set-KubeconfigManual
    }
    
    if (-not $kubeconfigSuccess) {
        Write-Error "Failed to setup kubeconfig. Please copy it manually:"
        Write-Host "  1. Copy from cluster: scp $KUBECONFIG_SOURCE_HOST`:$KUBECONFIG_SOURCE_PATH $LOCAL_KUBECONFIG_PATH"
        Write-Host "  2. Or copy from: $PSScriptRoot\ansible\k8s\kubeconfig"
        Write-Host "  3. To: $LOCAL_KUBECONFIG_PATH"
        exit 1
    }
    
    # Verify setup
    Test-KubectlSetup
    
    # Setup aliases
    Set-KubectlAliases
    
    # Setup completion
    Set-KubectlCompletion
    
    # Display summary
    Show-Summary
}

# Run main function
Main