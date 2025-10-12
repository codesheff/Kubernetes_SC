# DNS Configuration and Browser Testing Guide for itosbl.com
# Test your Kubernetes applications with your custom domain

Write-Host "🌐 ITOSBL.COM DOMAIN SETUP GUIDE" -ForegroundColor Cyan
Write-Host "=================================" -ForegroundColor Cyan

# Get current external IP
try {
    $externalIP = (Invoke-WebRequest -Uri "https://api.ipify.org" -UseBasicParsing -TimeoutSec 10).Content.Trim()
    Write-Host "`nYour External IP: $externalIP" -ForegroundColor Green
}
catch {
    Write-Host "`nCould not retrieve external IP" -ForegroundColor Red
    $externalIP = "146.198.242.247"
    Write-Host "Using known IP: $externalIP" -ForegroundColor Yellow
}

Write-Host "`n📋 DNS RECORDS TO CONFIGURE:" -ForegroundColor Yellow
Write-Host "============================" -ForegroundColor Yellow
Write-Host "Add these A records in your DNS provider control panel:" -ForegroundColor White
Write-Host ""
Write-Host "Record Type | Name              | Value" -ForegroundColor Cyan
Write-Host "------------|-------------------|------------------" -ForegroundColor Gray
Write-Host "A Record    | itosbl.com        | $externalIP" -ForegroundColor White
Write-Host "A Record    | shield.itosbl.com | $externalIP" -ForegroundColor White
Write-Host "A Record    | hydra.itosbl.com  | $externalIP" -ForegroundColor White
Write-Host "A Record    | *.itosbl.com      | $externalIP (wildcard)" -ForegroundColor White

Write-Host "`n🌍 BROWSER TEST URLS:" -ForegroundColor Green
Write-Host "====================" -ForegroundColor Green
Write-Host "`n⚡ IMMEDIATE TESTING (works right now):" -ForegroundColor Yellow
Write-Host "• http://$externalIP                 (MCU Portal)" -ForegroundColor White
Write-Host "• http://$externalIP/shield          (Shield/AOS)" -ForegroundColor White  
Write-Host "• http://$externalIP/hydra           (Hydra/AOH)" -ForegroundColor White

Write-Host "`n⏰ AFTER DNS PROPAGATION (1-24 hours):" -ForegroundColor Yellow
Write-Host "• http://itosbl.com                  (MCU Portal)" -ForegroundColor Green
Write-Host "• http://shield.itosbl.com           (Shield/AOS)" -ForegroundColor Green
Write-Host "• http://hydra.itosbl.com            (Hydra/AOH)" -ForegroundColor Green
Write-Host "• http://itosbl.com/shield           (Shield/AOS - path routing)" -ForegroundColor Green
Write-Host "• http://itosbl.com/hydra            (Hydra/AOH - path routing)" -ForegroundColor Green

Write-Host "`n🔧 OPTIONAL: Update Kubernetes Ingress" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "To add itosbl.com support to your Kubernetes cluster:" -ForegroundColor White
Write-Host "1. kubectl apply -f ig-itosbl.yml" -ForegroundColor Green
Write-Host "2. This adds itosbl.com rules while keeping mcu.com compatibility" -ForegroundColor White

Write-Host "`n🧪 TEST DNS PROPAGATION:" -ForegroundColor Yellow
Write-Host "nslookup itosbl.com" -ForegroundColor White
Write-Host "nslookup shield.itosbl.com" -ForegroundColor White
Write-Host "nslookup hydra.itosbl.com" -ForegroundColor White

Write-Host "`n📈 NEXT STEPS:" -ForegroundColor Cyan
Write-Host "1. Configure DNS records with your domain provider" -ForegroundColor White
Write-Host "2. Wait for DNS propagation (check with nslookup)" -ForegroundColor White
Write-Host "3. Test the URLs in your browser" -ForegroundColor White
Write-Host "4. Consider setting up SSL certificates (Let's Encrypt)" -ForegroundColor White
Write-Host "5. Set up proper authentication for production use" -ForegroundColor White

Write-Host "`n✅ You can start testing immediately with: http://$externalIP" -ForegroundColor Green