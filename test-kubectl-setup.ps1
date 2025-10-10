# Test script to verify kubectl setup on Windows
# Run this after setup-local-kubectl.ps1 to validate installation

param(
    [switch]$Verbose
)

function Write-TestResult {
    param(
        [string]$TestName,
        [bool]$Success,
        [string]$Details = ""
    )
    
    $status = if ($Success) { "✅ PASS" } else { "❌ FAIL" }
    $color = if ($Success) { "Green" } else { "Red" }
    
    Write-Host "[$status] $TestName" -ForegroundColor $color
    if ($Details -and ($Verbose -or -not $Success)) {
        Write-Host "    $Details" -ForegroundColor Gray
    }
}

function Test-KubectlInstallation {
    Write-Host "`n=== Testing kubectl Installation ===" -ForegroundColor Cyan
    
    # Test 1: kubectl command exists
    $kubectl = Get-Command kubectl -ErrorAction SilentlyContinue
    $kubectlExists = $null -ne $kubectl
    Write-TestResult "kubectl command available" $kubectlExists $kubectl.Source
    
    if (-not $kubectlExists) {
        return $false
    }
    
    # Test 2: kubectl version
    try {
        $version = & kubectl version --client --output=yaml 2>$null | Select-String "gitVersion" | ForEach-Object { $_.ToString().Split(":")[1].Trim() }
        $versionSuccess = $null -ne $version
        Write-TestResult "kubectl version check" $versionSuccess "Version: $version"
    }
    catch {
        Write-TestResult "kubectl version check" $false $_.Exception.Message
        $versionSuccess = $false
    }
    
    return $kubectlExists -and $versionSuccess
}

function Test-KubeconfigSetup {
    Write-Host "`n=== Testing kubeconfig Setup ===" -ForegroundColor Cyan
    
    # Test 1: kubeconfig file exists
    $kubeconfigPath = "$env:USERPROFILE\.kube\config"
    $kubeconfigExists = Test-Path $kubeconfigPath
    Write-TestResult "kubeconfig file exists" $kubeconfigExists $kubeconfigPath
    
    if (-not $kubeconfigExists) {
        return $false
    }
    
    # Test 2: kubeconfig is valid YAML
    try {
        $kubeconfigContent = Get-Content $kubeconfigPath -Raw
        $kubeconfigValid = $kubeconfigContent -like "*apiVersion: v1*" -and $kubeconfigContent -like "*kind: Config*"
        Write-TestResult "kubeconfig format valid" $kubeconfigValid
    }
    catch {
        Write-TestResult "kubeconfig format valid" $false $_.Exception.Message
        $kubeconfigValid = $false
    }
    
    # Test 3: Current context set
    try {
        $currentContext = & kubectl config current-context 2>$null
        $contextSet = $null -ne $currentContext -and $currentContext.Trim() -ne ""
        Write-TestResult "kubectl context configured" $contextSet "Context: $currentContext"
    }
    catch {
        Write-TestResult "kubectl context configured" $false $_.Exception.Message
        $contextSet = $false
    }
    
    return $kubeconfigExists -and $kubeconfigValid -and $contextSet
}

function Test-ClusterConnectivity {
    Write-Host "`n=== Testing Cluster Connectivity ===" -ForegroundColor Cyan
    
    # Test 1: Network connectivity to cluster
    try {
        $clusterServer = & kubectl config view --minify --output jsonpath='{.clusters[0].cluster.server}' 2>$null
        if ($clusterServer -match "https://([^:]+):(\d+)") {
            $clusterHost = $matches[1]
            $clusterPort = $matches[2]
            
            $networkTest = Test-NetConnection -ComputerName $clusterHost -Port $clusterPort -InformationLevel Quiet -WarningAction SilentlyContinue
            Write-TestResult "Network connectivity to cluster" $networkTest "$clusterHost`:$clusterPort"
        }
        else {
            Write-TestResult "Network connectivity to cluster" $false "Could not parse cluster server URL"
            $networkTest = $false
        }
    }
    catch {
        Write-TestResult "Network connectivity to cluster" $false $_.Exception.Message
        $networkTest = $false
    }
    
    # Test 2: kubectl cluster-info
    try {
        & kubectl cluster-info 2>$null | Out-Null
        $clusterInfoSuccess = $LASTEXITCODE -eq 0
        Write-TestResult "kubectl cluster-info" $clusterInfoSuccess
    }
    catch {
        Write-TestResult "kubectl cluster-info" $false $_.Exception.Message
        $clusterInfoSuccess = $false
    }
    
    # Test 3: Basic API access
    try {
        $nodes = & kubectl get nodes --no-headers 2>$null
        $apiAccess = $LASTEXITCODE -eq 0 -and $nodes
        $nodeCount = if ($nodes) { ($nodes | Measure-Object).Count } else { 0 }
        Write-TestResult "API access (get nodes)" $apiAccess "Found $nodeCount nodes"
    }
    catch {
        Write-TestResult "API access (get nodes)" $false $_.Exception.Message
        $apiAccess = $false
    }
    
    return $networkTest -and $clusterInfoSuccess -and $apiAccess
}

function Test-PowerShellAliases {
    Write-Host "`n=== Testing PowerShell Aliases ===" -ForegroundColor Cyan
    
    # Test 1: PowerShell profile exists
    $profileExists = Test-Path $PROFILE
    Write-TestResult "PowerShell profile exists" $profileExists $PROFILE
    
    if (-not $profileExists) {
        return $false
    }
    
    # Test 2: Aliases in profile
    $profileContent = Get-Content $PROFILE -Raw
    $aliasesExist = $profileContent -like "*# Kubectl aliases*"
    Write-TestResult "kubectl aliases in profile" $aliasesExist
    
    # Test 3: Test specific aliases
    $aliasesToTest = @("k", "kgp", "kgs", "kgn")
    $aliasesWorking = 0
    
    foreach ($alias in $aliasesToTest) {
        try {
            $aliasCmd = Get-Command $alias -ErrorAction SilentlyContinue
            if ($aliasCmd) {
                $aliasesWorking++
            }
        }
        catch {
            # Alias not loaded
        }
    }
    
    $allAliasesWork = $aliasesWorking -eq $aliasesToTest.Count
    Write-TestResult "kubectl aliases functional" $allAliasesWork "$aliasesWorking/$($aliasesToTest.Count) aliases working"
    
    if (-not $allAliasesWork) {
        Write-Host "    Note: Run '. `$PROFILE' to load aliases in current session" -ForegroundColor Yellow
    }
    
    return $profileExists -and $aliasesExist
}

function Test-KubectlCompletion {
    Write-Host "`n=== Testing kubectl Completion ===" -ForegroundColor Cyan
    
    # Test 1: Completion in profile
    if (Test-Path $PROFILE) {
        $profileContent = Get-Content $PROFILE -Raw
        $completionConfigured = $profileContent -like "*kubectl completion*"
        Write-TestResult "kubectl completion configured" $completionConfigured
        return $completionConfigured
    }
    else {
        Write-TestResult "kubectl completion configured" $false "PowerShell profile not found"
        return $false
    }
}

function Show-Summary {
    param(
        [bool]$InstallationOK,
        [bool]$KubeconfigOK,
        [bool]$ConnectivityOK,
        [bool]$AliasesOK,
        [bool]$CompletionOK
    )
    
    Write-Host "`n=== Test Summary ===" -ForegroundColor Cyan
    
    $totalTests = 5
    $passedTests = 0
    
    if ($InstallationOK) { $passedTests++ }
    if ($KubeconfigOK) { $passedTests++ }
    if ($ConnectivityOK) { $passedTests++ }
    if ($AliasesOK) { $passedTests++ }
    if ($CompletionOK) { $passedTests++ }
    
    $overallSuccess = $passedTests -eq $totalTests
    $color = if ($overallSuccess) { "Green" } else { "Yellow" }
    
    Write-Host "`nOverall Result: $passedTests/$totalTests tests passed" -ForegroundColor $color
    
    if ($overallSuccess) {
        Write-Host "🎉 kubectl setup is working perfectly!" -ForegroundColor Green
        Write-Host "`nYou can now use kubectl to manage your cluster:" -ForegroundColor White
        Write-Host "  kubectl get nodes" -ForegroundColor Gray
        Write-Host "  kubectl get pods -A" -ForegroundColor Gray
        Write-Host "  k get svc  # using alias" -ForegroundColor Gray
    }
    else {
        Write-Host "`n⚠️  Some issues were found. Please check the failed tests above." -ForegroundColor Yellow
        
        if (-not $InstallationOK) {
            Write-Host "  - kubectl installation issues" -ForegroundColor Red
        }
        if (-not $KubeconfigOK) {
            Write-Host "  - kubeconfig configuration issues" -ForegroundColor Red
        }
        if (-not $ConnectivityOK) {
            Write-Host "  - cluster connectivity issues" -ForegroundColor Red
        }
        if (-not $AliasesOK) {
            Write-Host "  - PowerShell aliases issues" -ForegroundColor Red
        }
        if (-not $CompletionOK) {
            Write-Host "  - kubectl completion issues" -ForegroundColor Red
        }
    }
}

# Main execution
Write-Host "kubectl Windows Setup Validation" -ForegroundColor Magenta
Write-Host "=================================" -ForegroundColor Magenta

$installationOK = Test-KubectlInstallation
$kubeconfigOK = Test-KubeconfigSetup
$connectivityOK = Test-ClusterConnectivity
$aliasesOK = Test-PowerShellAliases
$completionOK = Test-KubectlCompletion

Show-Summary $installationOK $kubeconfigOK $connectivityOK $aliasesOK $completionOK

Write-Host "`nFor detailed help, see: WINDOWS-KUBECTL-SETUP.md" -ForegroundColor Blue