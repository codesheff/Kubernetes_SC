# PowerShell script to add Kubernetes ingress entries to Windows hosts file
# Run as Administrator

param(
    [switch]$Remove
)

$hostsFile = "C:\Windows\System32\drivers\etc\hosts"
$nodeIP = "192.168.1.114"
$hostEntries = @(
    "$nodeIP mcu.com",
    "$nodeIP shield.mcu.com", 
    "$nodeIP hydra.mcu.com"
)
$marker = "# Kubernetes Ingress Test Entries"

function Test-Administrator {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

if (-not (Test-Administrator)) {
    Write-Host "ERROR: This script must be run as Administrator" -ForegroundColor Red
    Write-Host "Right-click PowerShell and select 'Run as Administrator'" -ForegroundColor Yellow
    exit 1
}

if ($Remove) {
    Write-Host "Removing Kubernetes ingress entries from hosts file..." -ForegroundColor Yellow
    
    $content = Get-Content $hostsFile
    $newContent = @()
    $skipMode = $false
    
    foreach ($line in $content) {
        if ($line -eq $marker) {
            $skipMode = $true
            continue
        }
        if ($skipMode -and ($line.Trim() -eq "" -or $line -notmatch "192\.168\.1\.114")) {
            $skipMode = $false
        }
        if (-not $skipMode) {
            $newContent += $line
        }
    }
    
    Set-Content $hostsFile $newContent
    Write-Host "✅ Kubernetes ingress entries removed from hosts file" -ForegroundColor Green
}
else {
    Write-Host "Adding Kubernetes ingress entries to hosts file..." -ForegroundColor Cyan
    
    # Check if entries already exist
    $content = Get-Content $hostsFile -Raw
    if ($content -like "*$marker*") {
        Write-Host "⚠️  Entries already exist in hosts file" -ForegroundColor Yellow
        $response = Read-Host "Do you want to update them? (y/N)"
        if ($response -ne "y" -and $response -ne "Y") {
            Write-Host "Cancelled" -ForegroundColor Gray
            exit 0
        }
        
        # Remove existing entries first
        & $MyInvocation.MyCommand.Path -Remove
    }
    
    # Add new entries
    $newEntries = @("", $marker) + $hostEntries
    Add-Content $hostsFile $newEntries
    
    Write-Host "✅ Kubernetes ingress entries added to hosts file" -ForegroundColor Green
}

Write-Host "`n📋 Current hosts file entries:" -ForegroundColor Cyan
Get-Content $hostsFile | Where-Object { $_ -match "(mcu\.com|192\.168\.1\.114)" } | ForEach-Object {
    Write-Host "   $_" -ForegroundColor White
}

if (-not $Remove) {
    Write-Host "`n🌐 You can now test these URLs in your browser:" -ForegroundColor Cyan
    Write-Host "   http://shield.mcu.com:31763      → Shield App" -ForegroundColor White
    Write-Host "   http://hydra.mcu.com:31763       → Hydra App" -ForegroundColor White  
    Write-Host "   http://mcu.com:31763/shield      → Shield App (path-based)" -ForegroundColor White
    Write-Host "   http://mcu.com:31763/hydra       → Hydra App (path-based)" -ForegroundColor White
    Write-Host "   http://mcu.com:31763             → MCU Landing Page" -ForegroundColor White
    Write-Host "   http://192.168.1.114:31763       → MCU Landing Page" -ForegroundColor White
    
    Write-Host "`n💡 Tip: You may need to clear your browser's DNS cache" -ForegroundColor Yellow
    Write-Host "   Chrome: chrome://net-internals/#dns" -ForegroundColor Gray
    Write-Host "   Or run: ipconfig /flushdns" -ForegroundColor Gray
}