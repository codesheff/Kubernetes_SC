# External Access Testing Script for Kubernetes Setup
# Tests connectivity from external perspective and provides setup guidance

param(
    [switch]$CheckPortForwarding,
    [switch]$TestFromExternal,
    [string]$ExternalIP
)

Write-Host "🌍 External Access Testing for Kubernetes Setup" -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan

# Get current network information
Write-Host "`n📡 Gathering Network Information..." -ForegroundColor Yellow

try {
    # External IP
    $myExternalIP = (Invoke-WebRequest -Uri "https://api.ipify.org" -UseBasicParsing -TimeoutSec 10).Content.Trim()
    Write-Host "External IP: $myExternalIP" -ForegroundColor White
    
    # Local IP and Gateway
    $localIP = (Get-NetIPAddress -AddressFamily IPv4 | Where-Object { 
        $_.InterfaceAlias -like "*Wi-Fi*" -or $_.InterfaceAlias -like "*Ethernet*" 
    } | Select-Object -First 1).IPAddress
    
    $gateway = (Get-NetRoute -DestinationPrefix "0.0.0.0/0").NextHop | Select-Object -First 1
    
    Write-Host "Local IP: $localIP" -ForegroundColor White
    Write-Host "Gateway: $gateway" -ForegroundColor White
    Write-Host "Raspberry Pi: 192.168.1.114" -ForegroundColor White
}
catch {
    Write-Host "❌ Failed to gather network info: $($_.Exception.Message)" -ForegroundColor Red
    return
}

Write-Host "`n🏠 Current Network Setup:" -ForegroundColor Cyan
Write-Host "┌─────────────────────────────────────┐" -ForegroundColor Gray
Write-Host "│ Internet (Your External IP)         │" -ForegroundColor Gray
Write-Host "│ $myExternalIP                    │" -ForegroundColor White
Write-Host "└─────────────────┬───────────────────┘" -ForegroundColor Gray
Write-Host "                  │" -ForegroundColor Gray
Write-Host "         ┌────────┴────────┐" -ForegroundColor Gray
Write-Host "         │ Router/Gateway  │" -ForegroundColor Gray
Write-Host "         │ $gateway        │" -ForegroundColor White
Write-Host "         └────────┬────────┘" -ForegroundColor Gray
Write-Host "                  │" -ForegroundColor Gray
Write-Host "┌─────────────────────────────────────┐" -ForegroundColor Gray
Write-Host "│ Local Network (192.168.1.0/24)     │" -ForegroundColor Gray
Write-Host "│ - Your PC: $localIP             │" -ForegroundColor White
Write-Host "│ - Raspberry Pi: 192.168.1.114      │" -ForegroundColor White
Write-Host "│ - NGINX Reverse Proxy: Port 80     │" -ForegroundColor White
Write-Host "│ - Kubernetes Ingress: Port 31763   │" -ForegroundColor White
Write-Host "└─────────────────────────────────────┘" -ForegroundColor Gray

# Test local access (what works now)
Write-Host "`n✅ What CURRENTLY WORKS (Local Network):" -ForegroundColor Green
Write-Host "- http://192.168.1.114 (direct to NGINX reverse proxy)" -ForegroundColor White
Write-Host "- http://192.168.1.114:31763 (direct to Kubernetes ingress)" -ForegroundColor White
Write-Host "- All your MCU applications via local IP" -ForegroundColor White

# Test connectivity
Write-Host "`n🔍 Testing Current Access..." -ForegroundColor Yellow

Write-Host "`n1. Testing local access to Raspberry Pi NGINX:" -ForegroundColor Cyan
try {
    $localTest = Test-NetConnection -ComputerName "192.168.1.114" -Port 80 -InformationLevel Quiet -WarningAction SilentlyContinue
    if ($localTest) {
        Write-Host "✅ Local NGINX access: WORKING" -ForegroundColor Green
        
        # Test actual HTTP response
        try {
            $response = Invoke-WebRequest -Uri "http://192.168.1.114" -Headers @{Host="mcu.com"} -TimeoutSec 5 -UseBasicParsing
            Write-Host "✅ HTTP Response: $($response.StatusCode)" -ForegroundColor Green
        }
        catch {
            Write-Host "⚠️  HTTP test failed: $($_.Exception.Message)" -ForegroundColor Yellow
        }
    } else {
        Write-Host "❌ Local NGINX access: FAILED" -ForegroundColor Red
    }
}
catch {
    Write-Host "❌ Local test error: $($_.Exception.Message)" -ForegroundColor Red
}

if ($CheckPortForwarding) {
    Write-Host "`n🔧 Testing External Access (requires port forwarding)..." -ForegroundColor Yellow
    
    # Try to access via external IP (will fail without port forwarding)
    Write-Host "`n2. Testing external access via your public IP:" -ForegroundColor Cyan
    try {
        $externalTest = Test-NetConnection -ComputerName $myExternalIP -Port 80 -InformationLevel Quiet -WarningAction SilentlyContinue
        if ($externalTest) {
            Write-Host "✅ External HTTP access: WORKING (port forwarding is set up!)" -ForegroundColor Green
            
            # Test actual HTTP response
            try {
                $response = Invoke-WebRequest -Uri "http://$myExternalIP" -Headers @{Host="mcu.com"} -TimeoutSec 10 -UseBasicParsing
                Write-Host "✅ External HTTP Response: $($response.StatusCode)" -ForegroundColor Green
                Write-Host "🎉 Your Kubernetes setup is accessible from the internet!" -ForegroundColor Green
            }
            catch {
                Write-Host "⚠️  External HTTP test failed: $($_.Exception.Message)" -ForegroundColor Yellow
            }
        } else {
            Write-Host "❌ External HTTP access: NOT ACCESSIBLE" -ForegroundColor Red
            Write-Host "   This is expected if port forwarding is not configured" -ForegroundColor Gray
        }
    }
    catch {
        Write-Host "❌ External test error: $($_.Exception.Message)" -ForegroundColor Red
    }
}

# Provide setup instructions
Write-Host "`n🔧 TO ENABLE EXTERNAL ACCESS:" -ForegroundColor Yellow
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Yellow

Write-Host "`n1. Configure Router Port Forwarding:" -ForegroundColor Cyan
Write-Host "   - Log into your router admin panel (usually http://$gateway)" -ForegroundColor White
Write-Host "   - Navigate to Port Forwarding/Virtual Servers/NAT" -ForegroundColor White
Write-Host "   - Add rule: External Port 80 → Internal IP 192.168.1.114 Port 80" -ForegroundColor Green
Write-Host "   - Add rule: External Port 443 → Internal IP 192.168.1.114 Port 443" -ForegroundColor Green
Write-Host "   - Save and restart router if required" -ForegroundColor White

Write-Host "`n2. Test External Access:" -ForegroundColor Cyan
Write-Host "   - Run: .\test-external-access.ps1 -CheckPortForwarding" -ForegroundColor White
Write-Host "   - Or visit: http://$myExternalIP" -ForegroundColor Green
Write-Host "   - Configure DNS to point domains to $myExternalIP" -ForegroundColor White

Write-Host "`n3. Security Recommendations:" -ForegroundColor Cyan
Write-Host "   - Set up SSL/TLS certificates (Let's Encrypt)" -ForegroundColor Yellow
Write-Host "   - Implement authentication (OAuth, basic auth, etc.)" -ForegroundColor Yellow
Write-Host "   - Configure firewall rules" -ForegroundColor Yellow
Write-Host "   - Monitor access logs" -ForegroundColor Yellow
Write-Host "   - Consider VPN access instead of public exposure" -ForegroundColor Yellow

Write-Host "`n4. Dynamic DNS (if your IP changes):" -ForegroundColor Cyan
Write-Host "   - Sign up for Dynamic DNS service (DuckDNS, No-IP, etc.)" -ForegroundColor White
Write-Host "   - Configure automatic IP updates" -ForegroundColor White
Write-Host "   - Use domain name instead of IP address" -ForegroundColor White

Write-Host "`n🌐 Once configured, your apps will be accessible at:" -ForegroundColor Green
Write-Host "   - http://$myExternalIP (MCU Portal)" -ForegroundColor White
Write-Host "   - http://shield.yourdomain.com (if using custom domain)" -ForegroundColor White
Write-Host "   - http://hydra.yourdomain.com (if using custom domain)" -ForegroundColor White

Write-Host "`n💡 Usage:" -ForegroundColor Yellow
Write-Host "   .\test-external-access.ps1                    # Basic network analysis" -ForegroundColor Gray
Write-Host "   .\test-external-access.ps1 -CheckPortForwarding # Test if port forwarding works" -ForegroundColor Gray

Write-Host "`n⚠️  IMPORTANT SECURITY WARNING:" -ForegroundColor Red
Write-Host "   Exposing your Kubernetes cluster to the internet without proper" -ForegroundColor White
Write-Host "   security measures can be dangerous. Ensure you understand the" -ForegroundColor White
Write-Host "   security implications before proceeding." -ForegroundColor White