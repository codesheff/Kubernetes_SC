# External IP Address Checker
# Quick script to find your current external (public) IP address

param(
    [switch]$All,
    [switch]$Json,
    [switch]$Location
)

Write-Host "🌐 External IP Address Checker" -ForegroundColor Cyan
Write-Host "==============================" -ForegroundColor Cyan

if ($All) {
    Write-Host "`n📡 Checking multiple sources..." -ForegroundColor Yellow
    
    $sources = @{
        "ipify.org" = "https://api.ipify.org"
        "icanhazip.com" = "https://icanhazip.com"
        "checkip.amazonaws.com" = "https://checkip.amazonaws.com"
        "ipecho.net" = "https://ipecho.net/plain"
        "httpbin.org" = "https://httpbin.org/ip"
    }
    
    foreach ($source in $sources.GetEnumerator()) {
        try {
            $response = Invoke-WebRequest -Uri $source.Value -UseBasicParsing -TimeoutSec 5
            if ($source.Key -eq "httpbin.org") {
                $ip = ($response.Content | ConvertFrom-Json).origin
            } else {
                $ip = $response.Content.Trim()
            }
            Write-Host "✅ $($source.Key.PadRight(20)) → $ip" -ForegroundColor Green
        }
        catch {
            Write-Host "❌ $($source.Key.PadRight(20)) → Failed" -ForegroundColor Red
        }
    }
}
elseif ($Json) {
    Write-Host "`n📊 Getting detailed IP information..." -ForegroundColor Yellow
    try {
        $response = Invoke-WebRequest -Uri "https://ipapi.co/json/" -UseBasicParsing
        $data = $response.Content | ConvertFrom-Json
        
        Write-Host "🌍 IP Address: $($data.ip)" -ForegroundColor White
        Write-Host "🏙️  City: $($data.city)" -ForegroundColor White
        Write-Host "🗺️  Region: $($data.region)" -ForegroundColor White
        Write-Host "🏳️  Country: $($data.country_name)" -ForegroundColor White
        Write-Host "🏢 ISP: $($data.org)" -ForegroundColor White
        Write-Host "🌐 Timezone: $($data.timezone)" -ForegroundColor White
    }
    catch {
        Write-Host "❌ Failed to get detailed information: $($_.Exception.Message)" -ForegroundColor Red
    }
}
elseif ($Location) {
    Write-Host "`n📍 Getting IP location information..." -ForegroundColor Yellow
    try {
        $response = Invoke-WebRequest -Uri "https://ipinfo.io/json" -UseBasicParsing
        $data = $response.Content | ConvertFrom-Json
        
        Write-Host "🌍 IP: $($data.ip)" -ForegroundColor White
        Write-Host "📍 Location: $($data.city), $($data.region), $($data.country)" -ForegroundColor White
        Write-Host "🏢 Organization: $($data.org)" -ForegroundColor White
        Write-Host "🗺️  Coordinates: $($data.loc)" -ForegroundColor White
        Write-Host "📮 Postal: $($data.postal)" -ForegroundColor White
    }
    catch {
        Write-Host "❌ Failed to get location information: $($_.Exception.Message)" -ForegroundColor Red
    }
}
else {
    Write-Host "`n🔍 Quick IP lookup..." -ForegroundColor Yellow
    try {
        $ip = (Invoke-WebRequest -Uri "https://api.ipify.org" -UseBasicParsing).Content.Trim()
        Write-Host "Your External IP: $ip" -ForegroundColor Green
        
        # Also show local info
        Write-Host "`n🏠 Local Network Info:" -ForegroundColor Cyan
        $localIP = (Get-NetIPAddress -AddressFamily IPv4 | Where-Object { 
            $_.InterfaceAlias -like "*Wi-Fi*" -or $_.InterfaceAlias -like "*Ethernet*" 
        } | Select-Object -First 1).IPAddress
        
        if ($localIP) {
            Write-Host "Local IP: $localIP" -ForegroundColor White
            
            $gateway = (Get-NetRoute -DestinationPrefix "0.0.0.0/0" | 
                       Where-Object { $_.InterfaceAlias -like "*Wi-Fi*" -or $_.InterfaceAlias -like "*Ethernet*" } | 
                       Select-Object -First 1).NextHop
            if ($gateway) {
                Write-Host "Gateway: $gateway" -ForegroundColor White
            }
        }
    }
    catch {
        Write-Host "❌ Failed to get IP address: $($_.Exception.Message)" -ForegroundColor Red
    }
}

Write-Host "`n💡 Usage examples:" -ForegroundColor Yellow
Write-Host "   .\get-external-ip.ps1           # Quick IP lookup" -ForegroundColor Gray
Write-Host "   .\get-external-ip.ps1 -All      # Check multiple sources" -ForegroundColor Gray
Write-Host "   .\get-external-ip.ps1 -Json     # Detailed IP information" -ForegroundColor Gray
Write-Host "   .\get-external-ip.ps1 -Location # IP location information" -ForegroundColor Gray