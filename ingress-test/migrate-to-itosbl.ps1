# Migration Script: Update Ingress from ig-all.yml to ig-itosbl.yml
# This script helps migrate your Kubernetes ingress to support both mcu.com and itosbl.com domains

param(
    [switch]$Apply,
    [switch]$DryRun,
    [switch]$Rollback
)

Write-Host "🔄 KUBERNETES INGRESS MIGRATION SCRIPT" -ForegroundColor Cyan
Write-Host "=======================================" -ForegroundColor Cyan

function Show-CurrentIngress {
    Write-Host "`n📋 Current Ingress Status:" -ForegroundColor Yellow
    try {
        $ingress = kubectl get ingress -o json | ConvertFrom-Json
        if ($ingress.items.Count -gt 0) {
            foreach ($ing in $ingress.items) {
                Write-Host "Name: $($ing.metadata.name)" -ForegroundColor White
                Write-Host "Hosts: $($ing.spec.rules | ForEach-Object { $_.host } | Where-Object { $_ } | Join-String -Separator ', ')" -ForegroundColor Green
            }
        } else {
            Write-Host "No ingress resources found" -ForegroundColor Red
        }
    }
    catch {
        Write-Host "Error checking ingress: $($_.Exception.Message)" -ForegroundColor Red
    }
}

function Test-Files {
    Write-Host "`n🔍 Checking Required Files:" -ForegroundColor Yellow
    $files = @("ig-all.yml", "ig-itosbl.yml", "app.yml")
    $allPresent = $true
    
    foreach ($file in $files) {
        if (Test-Path $file) {
            Write-Host "✅ $file - Found" -ForegroundColor Green
        } else {
            Write-Host "❌ $file - Missing" -ForegroundColor Red
            $allPresent = $false
        }
    }
    return $allPresent
}

function Show-Migration-Plan {
    Write-Host "`n📋 MIGRATION PLAN:" -ForegroundColor Cyan
    Write-Host "==================" -ForegroundColor Cyan
    
    Write-Host "`n1. BACKUP CURRENT CONFIGURATION" -ForegroundColor Yellow
    Write-Host "   • Export current ingress: kubectl get ingress mcu-all -o yaml > backup-ingress.yml" -ForegroundColor White
    
    Write-Host "`n2. REMOVE OLD INGRESS" -ForegroundColor Yellow
    Write-Host "   • Delete: kubectl delete -f ig-all.yml" -ForegroundColor White
    
    Write-Host "`n3. APPLY NEW INGRESS" -ForegroundColor Yellow
    Write-Host "   • Deploy: kubectl apply -f ig-itosbl.yml" -ForegroundColor White
    
    Write-Host "`n4. VERIFY MIGRATION" -ForegroundColor Yellow
    Write-Host "   • Test both mcu.com and itosbl.com domains" -ForegroundColor White
    
    Write-Host "`n🔍 WHAT CHANGES:" -ForegroundColor Green
    Write-Host "✅ KEEPS WORKING: All existing mcu.com URLs" -ForegroundColor Green
    Write-Host "✅ ADDS SUPPORT: New itosbl.com URLs" -ForegroundColor Green
    Write-Host "✅ NO DOWNTIME: Same backend services" -ForegroundColor Green
    
    Write-Host "`n🌐 NEW URLS AVAILABLE AFTER MIGRATION:" -ForegroundColor Green
    Write-Host "• http://shield.itosbl.com (once DNS configured)" -ForegroundColor White
    Write-Host "• http://hydra.itosbl.com (once DNS configured)" -ForegroundColor White
    Write-Host "• http://itosbl.com/shield (once DNS configured)" -ForegroundColor White
    Write-Host "• http://itosbl.com/hydra (once DNS configured)" -ForegroundColor White
}

function Perform-Migration {
    Write-Host "`n🚀 PERFORMING MIGRATION..." -ForegroundColor Green
    Write-Host "===========================" -ForegroundColor Green
    
    # Step 1: Backup
    Write-Host "`n1. Creating backup..." -ForegroundColor Yellow
    try {
        kubectl get ingress mcu-all -o yaml > backup-ingress.yml
        Write-Host "✅ Backup created: backup-ingress.yml" -ForegroundColor Green
    }
    catch {
        Write-Host "⚠️  Could not create backup (ingress may not exist): $($_.Exception.Message)" -ForegroundColor Yellow
    }
    
    # Step 2: Remove old ingress
    Write-Host "`n2. Removing old ingress..." -ForegroundColor Yellow
    try {
        kubectl delete -f ig-all.yml --ignore-not-found=true
        Write-Host "✅ Old ingress removed" -ForegroundColor Green
    }
    catch {
        Write-Host "⚠️  Issue removing old ingress: $($_.Exception.Message)" -ForegroundColor Yellow
    }
    
    # Step 3: Apply new ingress
    Write-Host "`n3. Applying new ingress..." -ForegroundColor Yellow
    try {
        kubectl apply -f ig-itosbl.yml
        Write-Host "✅ New ingress applied" -ForegroundColor Green
    }
    catch {
        Write-Host "❌ Failed to apply new ingress: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "💡 Rolling back..." -ForegroundColor Yellow
        kubectl apply -f backup-ingress.yml
        return $false
    }
    
    # Step 4: Verify
    Write-Host "`n4. Verifying migration..." -ForegroundColor Yellow
    Start-Sleep -Seconds 3
    Show-CurrentIngress
    
    Write-Host "`n✅ MIGRATION COMPLETED!" -ForegroundColor Green
    Write-Host "🔍 Please test your endpoints to verify everything works" -ForegroundColor White
    return $true
}

function Perform-DryRun {
    Write-Host "`n🔍 DRY RUN MODE - No changes will be made" -ForegroundColor Cyan
    Write-Host "=========================================" -ForegroundColor Cyan
    
    Write-Host "`nWould execute these commands:" -ForegroundColor Yellow
    Write-Host "1. kubectl get ingress mcu-all -o yaml > backup-ingress.yml" -ForegroundColor Gray
    Write-Host "2. kubectl delete -f ig-all.yml" -ForegroundColor Gray
    Write-Host "3. kubectl apply -f ig-itosbl.yml" -ForegroundColor Gray
    
    Write-Host "`nTo actually perform the migration, run:" -ForegroundColor Green
    Write-Host ".\migrate-to-itosbl.ps1 -Apply" -ForegroundColor White
}

function Perform-Rollback {
    Write-Host "`n⏪ ROLLING BACK TO ORIGINAL CONFIGURATION..." -ForegroundColor Yellow
    Write-Host "=============================================" -ForegroundColor Yellow
    
    if (Test-Path "backup-ingress.yml") {
        try {
            kubectl delete -f ig-itosbl.yml --ignore-not-found=true
            kubectl apply -f backup-ingress.yml
            Write-Host "✅ Rollback completed" -ForegroundColor Green
        }
        catch {
            Write-Host "❌ Rollback failed: $($_.Exception.Message)" -ForegroundColor Red
        }
    } else {
        Write-Host "❌ No backup file found. Applying ig-all.yml instead..." -ForegroundColor Yellow
        try {
            kubectl delete -f ig-itosbl.yml --ignore-not-found=true
            kubectl apply -f ig-all.yml
            Write-Host "✅ Restored to ig-all.yml" -ForegroundColor Green
        }
        catch {
            Write-Host "❌ Rollback failed: $($_.Exception.Message)" -ForegroundColor Red
        }
    }
}

# Main execution
if (-not (Test-Files)) {
    Write-Host "`n❌ Missing required files. Please run from ingress-test directory." -ForegroundColor Red
    exit 1
}

Show-CurrentIngress

if ($Rollback) {
    Perform-Rollback
}
elseif ($Apply) {
    if (Perform-Migration) {
        Write-Host "`n🎉 SUCCESS! Your ingress now supports both domains:" -ForegroundColor Green
        Write-Host "• mcu.com (existing - should still work)" -ForegroundColor White
        Write-Host "• itosbl.com (new - configure DNS to use)" -ForegroundColor White
    }
}
elseif ($DryRun) {
    Perform-DryRun
}
else {
    Show-Migration-Plan
    Write-Host "`n💡 USAGE:" -ForegroundColor Yellow
    Write-Host ".\migrate-to-itosbl.ps1           # Show this plan" -ForegroundColor Gray
    Write-Host ".\migrate-to-itosbl.ps1 -DryRun   # Show what would be done" -ForegroundColor Gray
    Write-Host ".\migrate-to-itosbl.ps1 -Apply    # Perform the migration" -ForegroundColor Gray
    Write-Host ".\migrate-to-itosbl.ps1 -Rollback # Rollback to previous config" -ForegroundColor Gray
}

Write-Host "`n📚 After migration, update your DNS with these A records:" -ForegroundColor Cyan
Write-Host "itosbl.com → 146.198.242.247" -ForegroundColor White
Write-Host "shield.itosbl.com → 146.198.242.247" -ForegroundColor White
Write-Host "hydra.itosbl.com → 146.198.242.247" -ForegroundColor White
Write-Host "*.itosbl.com → 146.198.242.247" -ForegroundColor White