# Kubernetes Ingress Testing

This directory contains configuration and scripts for testing Kubernetes Ingress functionality with NGINX Ingress Controller and MetalLB.

## Files Overview

- `app.yml` - Application pods and services (Shield and Hydra)
- `ig-all.yml` - Ingress configuration with host-based and path-based routing
- `setup-ingress-prerequisites.sh` - Sets up NGINX Ingress Controller and prerequisites
- `deploy-and-test.sh` - Deploys applications and tests ingress functionality
- `README.md` - This file

## Quick Start

### 1. Prerequisites Setup

First, set up the NGINX Ingress Controller and configure local DNS:

```bash
cd ingress-test
./setup-ingress-prerequisites.sh
```

This script will:
- ✅ Verify cluster connectivity and MetalLB installation
- ✅ Install NGINX Ingress Controller v1.8.2
- ✅ Wait for controller to be ready and get external IP
- ✅ Configure local DNS entries (/etc/hosts)
- ✅ Run optional connectivity test

### 2. Deploy and Test Applications

Deploy the MCU applications and test ingress:

```bash
./deploy-and-test.sh
```

This script will:
- ✅ Deploy Shield and Hydra applications
- ✅ Deploy ingress configuration
- ✅ Test all routing endpoints automatically
- ✅ Provide manual test commands
- ✅ Offer cleanup option

## Application Architecture

### Applications
- **Shield**: Marvel character app (port 8080)
- **Hydra**: Marvel character app (port 8080)

### Services
- `svc-shield` - ClusterIP service for Shield app
- `svc-hydra` - ClusterIP service for Hydra app

### Ingress Routing

**Host-based routing:**
- `shield.mcu.com` → svc-shield
- `hydra.mcu.com` → svc-hydra

**Path-based routing:**
- `mcu.com/shield` → svc-shield
- `mcu.com/hydra` → svc-hydra

## Manual Operations

### Deploy Applications Only
```bash
kubectl apply -f app.yml
```

### Deploy Ingress Only
```bash
kubectl apply -f ig-all.yml
```

### Check Status
```bash
kubectl get pods,svc,ingress
kubectl describe ingress mcu-all
```

### Test Endpoints

#### Using curl with Host headers:
```bash
# Get ingress IP
INGRESS_IP=$(kubectl get svc ingress-nginx-controller -n ingress-nginx -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

# Host-based routing
curl -H 'Host: shield.mcu.com' http://$INGRESS_IP
curl -H 'Host: hydra.mcu.com' http://$INGRESS_IP

# Path-based routing  
curl -H 'Host: mcu.com' http://$INGRESS_IP/shield
curl -H 'Host: mcu.com' http://$INGRESS_IP/hydra
```

#### Using domain names (if DNS configured):
```bash
curl http://shield.mcu.com
curl http://hydra.mcu.com
curl http://mcu.com/shield
curl http://mcu.com/hydra
```

## Troubleshooting

### Check Ingress Controller Status
```bash
kubectl get pods -n ingress-nginx
kubectl logs -n ingress-nginx deployment/ingress-nginx-controller
```

### Check Service External IP
```bash
kubectl get svc -n ingress-nginx
```

### Verify MetalLB IP Assignment
```bash
kubectl get ipaddresspool -n metallb-system
kubectl get svc ingress-nginx-controller -n ingress-nginx -o wide
```

### Check Application Logs
```bash
kubectl logs shield
kubectl logs hydra
```

### Verify DNS Resolution
```bash
# Check hosts file entries
cat /etc/hosts | grep mcu.com

# Test DNS resolution
nslookup shield.mcu.com
```

### Common Issues

1. **Pods not starting**: Check image pull and resource availability
   ```bash
   kubectl describe pod shield
   kubectl describe pod hydra
   ```

2. **No external IP**: MetalLB may not be configured correctly
   ```bash
   kubectl get ipaddresspool -n metallb-system
   kubectl describe svc ingress-nginx-controller -n ingress-nginx
   ```

3. **DNS not resolving**: Check /etc/hosts entries or run setup script again
   ```bash
   cat /etc/hosts | grep -E "(mcu\.com|shield\.mcu\.com|hydra\.mcu\.com)"
   ```

4. **404 errors**: Check ingress configuration and service names
   ```bash
   kubectl describe ingress mcu-all
   kubectl get endpoints
   ```

## Cleanup

### Remove Applications and Ingress
```bash
kubectl delete -f ig-all.yml
kubectl delete -f app.yml
```

### Remove DNS Entries
Remove these lines from your hosts file:
```
# Kubernetes Ingress Test Entries
192.168.1.75 mcu.com
192.168.1.75 shield.mcu.com  
192.168.1.75 hydra.mcu.com
```

### Remove NGINX Ingress Controller (optional)
```bash
kubectl delete namespace ingress-nginx
```

## Expected Results

When working correctly, you should see:

### Host-based routing:
- `http://shield.mcu.com` → "Agent of S.H.I.E.L.D" page
- `http://hydra.mcu.com` → "Hail Hydra!" page

### Path-based routing:
- `http://mcu.com/shield` → "Agent of S.H.I.E.L.D" page  
- `http://mcu.com/hydra` → "Hail Hydra!" page

## Integration with Your Cluster

This ingress setup works with your existing:
- ✅ Kubernetes cluster (v1.33.5)
- ✅ MetalLB load balancer (IP range: 192.168.1.75-100)
- ✅ Flannel pod network (10.244.0.0/16)
- ✅ Single-node cluster configuration

The NGINX Ingress Controller will get an external IP from your MetalLB pool and route traffic to your applications based on HTTP Host headers and URL paths.