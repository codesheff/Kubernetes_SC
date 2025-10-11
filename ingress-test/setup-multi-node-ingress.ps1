# Multi-Node Ingress Setup Script
# Run this after adding your second node

param(
    [switch]$CheckOnly,
    [switch]$ScaleApps
)

Write-Host "=== Multi-Node Kubernetes Ingress Setup ===" -ForegroundColor Cyan

# Function to check node readiness
function Test-MultiNodeSetup {
    Write-Host "`n1. Checking Node Status..." -ForegroundColor Yellow
    $nodes = kubectl get nodes --no-headers | Measure-Object
    if ($nodes.Count -lt 2) {
        Write-Host "❌ Only $($nodes.Count) node(s) detected. Add second node first." -ForegroundColor Red
        return $false
    }
    
    Write-Host "✅ $($nodes.Count) nodes detected" -ForegroundColor Green
    kubectl get nodes -o wide
    
    Write-Host "`n2. Checking MetalLB Speaker Distribution..." -ForegroundColor Yellow
    kubectl get pods -n metallb-system -o wide
    
    $speakers = kubectl get pods -n metallb-system --no-headers | Where-Object { $_ -like "*speaker*" } | Measure-Object
    Write-Host "✅ $($speakers.Count) MetalLB speakers running" -ForegroundColor Green
    
    Write-Host "`n3. Checking Current Pod Distribution..." -ForegroundColor Yellow
    kubectl get pods -o wide | Format-Table -AutoSize
    
    return $true
}

# Function to scale ingress controller
function Set-IngressControllerHA {
    Write-Host "`n4. Scaling NGINX Ingress Controller..." -ForegroundColor Yellow
    
    $currentReplicas = kubectl get deployment -n ingress-nginx ingress-nginx-controller -o jsonpath='{.spec.replicas}'
    Write-Host "Current replicas: $currentReplicas"
    
    if ($currentReplicas -eq "1") {
        Write-Host "Scaling to 2 replicas for HA..." -ForegroundColor Cyan
        kubectl patch deployment -n ingress-nginx ingress-nginx-controller -p '{"spec":{"replicas":2}}'
        
        Write-Host "Waiting for rollout..." -ForegroundColor Gray
        kubectl rollout status deployment/ingress-nginx-controller -n ingress-nginx --timeout=60s
        
        Write-Host "✅ Ingress controller scaled successfully" -ForegroundColor Green
    } else {
        Write-Host "✅ Already scaled ($currentReplicas replicas)" -ForegroundColor Green
    }
    
    kubectl get pods -n ingress-nginx -o wide
}

# Function to scale applications
function Set-ApplicationHA {
    Write-Host "`n5. Converting Apps to Deployments for HA..." -ForegroundColor Yellow
    
    # Create Deployments instead of Pods
    $deploymentYaml = @"
apiVersion: apps/v1
kind: Deployment
metadata:
  name: shield-deployment
spec:
  replicas: 2
  selector:
    matchLabels:
      app: shield
  template:
    metadata:
      labels:
        app: shield
        env: shield
    spec:
      affinity:
        podAntiAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
          - weight: 100
            podAffinityTerm:
              labelSelector:
                matchExpressions:
                - key: app
                  operator: In
                  values:
                  - shield
              topologyKey: kubernetes.io/hostname
      containers:
      - name: shield-ctr
        image: nigelpoulton/k8sbook:shield-ingress
        ports:
        - containerPort: 8080
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: hydra-deployment
spec:
  replicas: 2
  selector:
    matchLabels:
      app: hydra
  template:
    metadata:
      labels:
        app: hydra
        env: hydra
    spec:
      affinity:
        podAntiAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
          - weight: 100
            podAffinityTerm:
              labelSelector:
                matchExpressions:
                - key: app
                  operator: In
                  values:
                  - hydra
              topologyKey: kubernetes.io/hostname
      containers:
      - name: hydra-ctr
        image: nigelpoulton/k8sbook:hydra-ingress
        ports:
        - containerPort: 8080
"@

    # Save and apply
    $deploymentYaml | Out-File -FilePath "app-deployments.yml" -Encoding UTF8
    
    Write-Host "Removing existing pods..." -ForegroundColor Gray
    kubectl delete pod shield hydra --ignore-not-found=true
    
    Write-Host "Applying new deployments..." -ForegroundColor Gray
    kubectl apply -f app-deployments.yml
    
    Write-Host "Waiting for deployments..." -ForegroundColor Gray
    kubectl rollout status deployment/shield-deployment --timeout=60s
    kubectl rollout status deployment/hydra-deployment --timeout=60s
    
    Write-Host "✅ Applications converted to HA deployments" -ForegroundColor Green
    kubectl get pods -o wide | Where-Object { $_ -like "*shield*" -or $_ -like "*hydra*" }
}

# Function to test MetalLB IP accessibility
function Test-MetalLBConnectivity {
    Write-Host "`n6. Testing MetalLB IP Connectivity..." -ForegroundColor Yellow
    
    $metallbIP = kubectl get svc -n ingress-nginx ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].ip}'
    Write-Host "MetalLB IP: $metallbIP"
    
    # Test from cluster
    Write-Host "Testing from within cluster..." -ForegroundColor Gray
    $result = kubectl run test-curl --image=curlimages/curl --rm --restart=Never -- curl -s -H "Host: shield.mcu.com" http://$metallbIP --max-time 5 2>$null
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ MetalLB IP accessible from cluster" -ForegroundColor Green
    } else {
        Write-Host "❌ MetalLB IP not accessible from cluster" -ForegroundColor Red
    }
    
    # Test from Windows
    Write-Host "Testing from Windows machine..." -ForegroundColor Gray
    $connectivity = Test-NetConnection -ComputerName $metallbIP -Port 80 -InformationLevel Quiet -WarningAction SilentlyContinue
    
    if ($connectivity) {
        Write-Host "🎉 MetalLB IP now accessible from Windows!" -ForegroundColor Green
        Write-Host "You can now use: http://$metallbIP for ingress testing" -ForegroundColor Cyan
    } else {
        Write-Host "⚠️  MetalLB IP still not reachable from Windows" -ForegroundColor Yellow
        Write-Host "Continue using NodePort: 192.168.1.114:31763" -ForegroundColor Gray
    }
}

# Function to provide updated browser testing instructions
function Show-UpdatedBrowserInstructions {
    Write-Host "`n7. Updated Browser Testing Instructions..." -ForegroundColor Yellow
    
    $metallbIP = kubectl get svc -n ingress-nginx ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].ip}'
    $nodeIPs = kubectl get nodes -o jsonpath='{.items[*].status.addresses[?(@.type=="InternalIP")].address}'
    
    Write-Host "`n🌐 Browser Testing Options:" -ForegroundColor Cyan
    Write-Host "`nOption 1 - MetalLB IP (if accessible):" -ForegroundColor Green
    Write-Host "Add to hosts file: C:\Windows\System32\drivers\etc\hosts" -ForegroundColor Gray
    Write-Host "$metallbIP mcu.com" -ForegroundColor White
    Write-Host "$metallbIP shield.mcu.com" -ForegroundColor White
    Write-Host "$metallbIP hydra.mcu.com" -ForegroundColor White
    Write-Host "URLs: http://shield.mcu.com, http://hydra.mcu.com, http://mcu.com" -ForegroundColor White
    
    Write-Host "`nOption 2 - NodePort (always works):" -ForegroundColor Green
    Write-Host "Add to hosts file:" -ForegroundColor Gray
    $nodeIPs.Split(' ') | ForEach-Object {
        Write-Host "$_ mcu.com" -ForegroundColor White
        Write-Host "$_ shield.mcu.com" -ForegroundColor White
        Write-Host "$_ hydra.mcu.com" -ForegroundColor White
    }
    Write-Host "URLs: http://shield.mcu.com:31763, http://hydra.mcu.com:31763, etc." -ForegroundColor White
}

# Main execution
if (-not (Test-MultiNodeSetup)) {
    exit 1
}

if ($CheckOnly) {
    Write-Host "`n✅ Multi-node check complete. Use -ScaleApps to scale applications." -ForegroundColor Green
    exit 0
}

Set-IngressControllerHA

if ($ScaleApps) {
    Set-ApplicationHA
}

Test-MetalLBConnectivity
Show-UpdatedBrowserInstructions

Write-Host "`n🎉 Multi-node ingress setup complete!" -ForegroundColor Green