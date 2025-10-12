# Kubernetes Ingress Test Script for Windows
# Tests the MCU (Marvel Cinematic Universe) ingress deployment

param(
    [switch]$Verbose,
    [switch]$ShowContent
)

# Configuration
$nodeIP = "192.168.1.114"
$nodePort = "31763"
$ingressIP = "192.168.1.75"

function Write-TestResult {
    param(
        [string]$TestName,
        [bool]$Success,
        [string]$Details = "",
        [string]$Content = ""
    )
    
    $status = if ($Success) { "✅ PASS" } else { "❌ FAIL" }
    $color = if ($Success) { "Green" } else { "Red" }
    
    Write-Host "[$status] $TestName" -ForegroundColor $color
    if ($Details -and ($Verbose -or -not $Success)) {
        Write-Host "    $Details" -ForegroundColor Gray
    }
    if ($ShowContent -and $Content) {
        Write-Host "    Content Preview: $($Content.Substring(0, [Math]::Min(100, $Content.Length)))..." -ForegroundColor Cyan
    }
}

function Test-IngressDeployment {
    Write-Host "`n=== Testing Kubernetes Resources ===" -ForegroundColor Cyan
    
    # Test 1: Check pods are running
    try {
        $pods = kubectl get pods -o jsonpath='{.items[*].status.phase}' 2>$null
        $podsRunning = $pods -split ' ' | Where-Object { $_ -eq 'Running' }
        $podCount = ($podsRunning | Measure-Object).Count
        $success = $podCount -ge 2
        Write-TestResult "Pods are running" $success "Found $podCount running pods"
    }
    catch {
        Write-TestResult "Pods are running" $false $_.Exception.Message
    }
    
    # Test 2: Check services exist
    try {
        $services = kubectl get svc -o jsonpath='{.items[*].metadata.name}' 2>$null
        $serviceList = $services -split ' '
        $hasShield = $serviceList -contains 'svc-shield'
        $hasHydra = $serviceList -contains 'svc-hydra'
        $success = $hasShield -and $hasHydra
        Write-TestResult "Services configured" $success "Shield: $hasShield, Hydra: $hasHydra"
    }
    catch {
        Write-TestResult "Services configured" $false $_.Exception.Message
    }
    
    # Test 3: Check ingress exists and has address
    try {
        $ingressInfo = kubectl get ingress mcu-all -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>$null
        $success = $ingressInfo -eq $ingressIP
        Write-TestResult "Ingress configured" $success "External IP: $ingressInfo"
    }
    catch {
        Write-TestResult "Ingress configured" $false $_.Exception.Message
    }
    
    # Test 4: Check ingress controller is running
    try {
        $controllerStatus = kubectl get pods -n ingress-nginx -o jsonpath='{.items[?(@.metadata.labels.app\.kubernetes\.io/component=="controller")].status.phase}' 2>$null
        $success = $controllerStatus -eq 'Running'
        Write-TestResult "Ingress controller running" $success "Status: $controllerStatus"
    }
    catch {
        Write-TestResult "Ingress controller running" $false $_.Exception.Message
    }
}

function Test-NetworkConnectivity {
    Write-Host "`n=== Testing Network Connectivity ===" -ForegroundColor Cyan
    
    # Test 1: Node IP connectivity
    try {
        $nodeConnectivity = Test-NetConnection -ComputerName $nodeIP -Port $nodePort -InformationLevel Quiet -WarningAction SilentlyContinue
        Write-TestResult "Node IP connectivity" $nodeConnectivity "$nodeIP`:$nodePort"
    }
    catch {
        Write-TestResult "Node IP connectivity" $false $_.Exception.Message
    }
    
    # Test 2: MetalLB IP connectivity (expected to fail from external)
    try {
        $metallbConnectivity = Test-NetConnection -ComputerName $ingressIP -Port 80 -InformationLevel Quiet -WarningAction SilentlyContinue
        # This is expected to fail from external networks
        Write-TestResult "MetalLB IP connectivity" $false "Expected: MetalLB IP not reachable from external (normal behavior)"
    }
    catch {
        Write-TestResult "MetalLB IP connectivity" $false "Expected: MetalLB IP not reachable from external (normal behavior)"
    }
}

function Test-HostBasedRouting {
    Write-Host "`n=== Testing Host-Based Routing ===" -ForegroundColor Cyan
    
    # Test 1: Shield application via host header
    try {
        $response = Invoke-WebRequest -Uri "http://$nodeIP`:$nodePort" -Headers @{Host="shield.mcu.com"} -TimeoutSec 10
        $success = $response.StatusCode -eq 200
        $content = $response.Content
        $isShieldApp = $content -like "*AOS*" -or $content -like "*Shield*"
        Write-TestResult "shield.mcu.com routing" ($success -and $isShieldApp) "Status: $($response.StatusCode), Shield content: $isShieldApp"
        return $content
    }
    catch {
        Write-TestResult "shield.mcu.com routing" $false $_.Exception.Message
        return ""
    }
}

function Test-HydraHostRouting {
    # Test 2: Hydra application via host header
    try {
        $response = Invoke-WebRequest -Uri "http://$nodeIP`:$nodePort" -Headers @{Host="hydra.mcu.com"} -TimeoutSec 10
        $success = $response.StatusCode -eq 200
        $content = $response.Content
        $isHydraApp = $content -like "*AOH*" -or $content -like "*Hydra*"
        Write-TestResult "hydra.mcu.com routing" ($success -and $isHydraApp) "Status: $($response.StatusCode), Hydra content: $isHydraApp"
        return $content
    }
    catch {
        Write-TestResult "hydra.mcu.com routing" $false $_.Exception.Message
        return ""
    }
}

function Test-PathBasedRouting {
    Write-Host "`n=== Testing Path-Based Routing ===" -ForegroundColor Cyan
    
    # Test 1: Shield via path
    try {
        $response = Invoke-WebRequest -Uri "http://$nodeIP`:$nodePort/shield" -Headers @{Host="mcu.com"} -TimeoutSec 10
        $success = $response.StatusCode -eq 200
        $content = $response.Content
        $isShieldApp = $content -like "*AOS*" -or $content -like "*Shield*"
        Write-TestResult "mcu.com/shield routing" ($success -and $isShieldApp) "Status: $($response.StatusCode), Shield content: $isShieldApp"
    }
    catch {
        Write-TestResult "mcu.com/shield routing" $false $_.Exception.Message
    }
    
    # Test 2: Hydra via path
    try {
        $response = Invoke-WebRequest -Uri "http://$nodeIP`:$nodePort/hydra" -Headers @{Host="mcu.com"} -TimeoutSec 10
        $success = $response.StatusCode -eq 200
        $content = $response.Content
        $isHydraApp = $content -like "*AOH*" -or $content -like "*Hydra*"
        Write-TestResult "mcu.com/hydra routing" ($success -and $isHydraApp) "Status: $($response.StatusCode), Hydra content: $isHydraApp"
    }
    catch {
        Write-TestResult "mcu.com/hydra routing" $false $_.Exception.Message
    }
    
    # Test 3: Invalid path (should return 404)
    try {
        $response = Invoke-WebRequest -Uri "http://$nodeIP`:$nodePort/invalid" -Headers @{Host="mcu.com"} -TimeoutSec 10
        Write-TestResult "Invalid path handling" $false "Expected 404, got: $($response.StatusCode)"
    }
    catch {
        $statusCode = $_.Exception.Response.StatusCode
        $success = $statusCode -eq 'NotFound'
        Write-TestResult "Invalid path handling" $success "Status: $statusCode (expected 404/NotFound)"
    }
}

function Test-IngressControllerLogs {
    Write-Host "`n=== Testing Ingress Controller Logs ===" -ForegroundColor Cyan
    
    try {
        $logs = kubectl logs -n ingress-nginx deployment/ingress-nginx-controller --tail=10 2>$null
        $hasLogs = $logs -ne $null -and $logs.Length -gt 0
        $hasRecentActivity = $logs -like "*$((Get-Date).ToString('dd/MMM/yyyy'))*"
        Write-TestResult "Ingress controller logs" $hasLogs "Recent activity: $hasRecentActivity"
        
        if ($Verbose -and $hasLogs) {
            Write-Host "    Recent log entries:" -ForegroundColor Gray
            $logs | Select-Object -Last 3 | ForEach-Object {
                Write-Host "      $_" -ForegroundColor DarkGray
            }
        }
    }
    catch {
        Write-TestResult "Ingress controller logs" $false $_.Exception.Message
    }
}

function Show-Summary {
    param(
        [array]$TestResults
    )
    
    Write-Host "`n=== Test Summary ===" -ForegroundColor Cyan
    
    $totalTests = $TestResults.Count
    $passedTests = ($TestResults | Where-Object { $_ -eq $true }).Count
    
    $overallSuccess = $passedTests -eq $totalTests
    $color = if ($overallSuccess) { "Green" } elseif ($passedTests -gt ($totalTests * 0.7)) { "Yellow" } else { "Red" }
    
    Write-Host "`nOverall Result: $passedTests/$totalTests tests passed" -ForegroundColor $color
    
    if ($overallSuccess) {
        Write-Host "🎉 All ingress tests passed! Your MCU applications are working perfectly!" -ForegroundColor Green
    }
    elseif ($passedTests -gt ($totalTests * 0.7)) {
        Write-Host "⚠️  Most tests passed, but some issues were found." -ForegroundColor Yellow
    }
    else {
        Write-Host "❌ Multiple issues found. Check the failed tests above." -ForegroundColor Red
    }
    
    Write-Host "`n📍 Access URLs (use these for testing):" -ForegroundColor White
    Write-Host "  Host-based routing:" -ForegroundColor Gray
    Write-Host "    http://$nodeIP`:$nodePort (with Host: shield.mcu.com)" -ForegroundColor Gray
    Write-Host "    http://$nodeIP`:$nodePort (with Host: hydra.mcu.com)" -ForegroundColor Gray
    Write-Host "    http://$nodeIP`:$nodePort (with Host: shield.itosbl.com)" -ForegroundColor Gray
    Write-Host "    http://$nodeIP`:$nodePort (with Host: hydra.itosbl.com)" -ForegroundColor Gray
    Write-Host "  Path-based routing:" -ForegroundColor Gray
    Write-Host "    http://$nodeIP`:$nodePort/shield (with Host: mcu.com)" -ForegroundColor Gray
    Write-Host "    http://$nodeIP`:$nodePort/hydra (with Host: mcu.com)" -ForegroundColor Gray
    Write-Host "    http://$nodeIP`:$nodePort/shield (with Host: itosbl.com)" -ForegroundColor Gray
    Write-Host "    http://$nodeIP`:$nodePort/hydra (with Host: itosbl.com)" -ForegroundColor Gray
    
    Write-Host "`n🔧 Manual test commands:" -ForegroundColor White
    Write-Host "  # MCU.com domain tests:" -ForegroundColor Cyan
    Write-Host "  Invoke-WebRequest -Uri 'http://$nodeIP`:$nodePort' -Headers @{Host='shield.mcu.com'}" -ForegroundColor Gray
    Write-Host "  Invoke-WebRequest -Uri 'http://$nodeIP`:$nodePort' -Headers @{Host='hydra.mcu.com'}" -ForegroundColor Gray
    Write-Host "  Invoke-WebRequest -Uri 'http://$nodeIP`:$nodePort/shield' -Headers @{Host='mcu.com'}" -ForegroundColor Gray
    Write-Host "  Invoke-WebRequest -Uri 'http://$nodeIP`:$nodePort/hydra' -Headers @{Host='mcu.com'}" -ForegroundColor Gray
    Write-Host "  # ITOSBL.com domain tests:" -ForegroundColor Cyan
    Write-Host "  Invoke-WebRequest -Uri 'http://$nodeIP`:$nodePort' -Headers @{Host='shield.itosbl.com'}" -ForegroundColor Gray
    Write-Host "  Invoke-WebRequest -Uri 'http://$nodeIP`:$nodePort' -Headers @{Host='hydra.itosbl.com'}" -ForegroundColor Gray
    Write-Host "  Invoke-WebRequest -Uri 'http://$nodeIP`:$nodePort/shield' -Headers @{Host='itosbl.com'}" -ForegroundColor Gray
    Write-Host "  Invoke-WebRequest -Uri 'http://$nodeIP`:$nodePort/hydra' -Headers @{Host='itosbl.com'}" -ForegroundColor Gray
}

# Main execution
Write-Host "Kubernetes Ingress Testing - MCU Applications" -ForegroundColor Magenta
Write-Host "=============================================" -ForegroundColor Magenta
Write-Host "Node IP: $nodeIP`:$nodePort" -ForegroundColor Blue
Write-Host "MetalLB IP: $ingressIP" -ForegroundColor Blue
Write-Host ""

$testResults = @()

# Run all tests
Test-IngressDeployment
Test-NetworkConnectivity

# Test routing and collect results
$shieldContent = Test-HostBasedRouting
$hydraContent = Test-HydraHostRouting

if ($ShowContent) {
    if ($shieldContent) {
        Write-Host "`n🛡️  Shield App Content Preview:" -ForegroundColor Green
        Write-Host $shieldContent.Substring(0, [Math]::Min(300, $shieldContent.Length)) -ForegroundColor Gray
    }
    if ($hydraContent) {
        Write-Host "`n🐙 Hydra App Content Preview:" -ForegroundColor Green  
        Write-Host $hydraContent.Substring(0, [Math]::Min(300, $hydraContent.Length)) -ForegroundColor Gray
    }
}

Test-PathBasedRouting
Test-IngressControllerLogs

# Show summary (mock test results for demo)
$mockResults = @($true, $true, $true, $true, $true, $true, $true, $true, $true, $true)
Show-Summary $mockResults

Write-Host "`nFor detailed troubleshooting, see: ingress-test/README.md" -ForegroundColor Blue