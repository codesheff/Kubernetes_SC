# ============================================
# EXTERNAL ACCESS SETUP GUIDE
# ============================================
# Configure your router for external access to Kubernetes ingress

## 🎯 CURRENT SETUP STATUS

### MetalLB LoadBalancer Service:
- **Service Type**: LoadBalancer
- **External IP**: 192.168.1.75 (MetalLB assigned)
- **HTTP Port**: 80
- **HTTPS Port**: 443
- **Raspberry Pi**: 192.168.1.112 (eth0 primary interface)

### Ingress Controller:
- **Type**: NGINX Ingress Controller
- **Status**: ✅ Running and tested
- **Routing**: Host-based and path-based working

## 🌐 ROUTER PORT FORWARDING CONFIGURATION

### Required Port Forwarding Rules:

```
External Port 80  → Internal IP 192.168.1.75 Port 80  (HTTP)
External Port 443 → Internal IP 192.168.1.75 Port 443 (HTTPS)
```

### Router Admin Interface Steps:
1. **Access your router** (usually http://192.168.1.1 or http://192.168.1.254)
2. **Navigate to Port Forwarding** (may be under "Advanced" or "NAT")
3. **Add new rules**:
   - **Rule 1**: HTTP
     - External Port: 80
     - Internal IP: 192.168.1.75
     - Internal Port: 80
     - Protocol: TCP
   - **Rule 2**: HTTPS  
     - External Port: 443
     - Internal IP: 192.168.1.75
     - Internal Port: 443
     - Protocol: TCP
4. **Save and restart router** if required

## 🏠 DNS CONFIGURATION OPTIONS

### Option 1: Public Domain (Recommended for Production)
If you own a domain (e.g., mydomain.com):

```bash
# DNS A Records:
shield.mydomain.com  → YOUR_PUBLIC_IP
hydra.mydomain.com   → YOUR_PUBLIC_IP
api.mydomain.com     → YOUR_PUBLIC_IP
```

### Option 2: Dynamic DNS (Free Option)
Use services like DuckDNS, No-IP, or FreeDNS:

```bash
# Example with DuckDNS:
mypi.duckdns.org → YOUR_PUBLIC_IP

# Then use subdomains:
shield.mypi.duckdns.org
hydra.mypi.duckdns.org
```

### Option 3: Direct IP Access (Testing)
Use your public IP directly with Host headers:

```bash
curl -H "Host: shield.mcu.com" http://YOUR_PUBLIC_IP
curl -H "Host: hydra.mcu.com" http://YOUR_PUBLIC_IP
```

## 🔧 KUBERNETES INGRESS CONFIGURATION

### Current Working Ingress Rules:
```yaml
# Host-based routing:
shield.mcu.com → Shield app
hydra.mcu.com  → Hydra app

# Path-based routing:
mcu.com/shield → Shield app  
mcu.com/hydra  → Hydra app
```

### To Add New Domain (example: mydomain.com):
```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: external-ingress
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
spec:
  ingressClassName: nginx
  rules:
  - host: shield.mydomain.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: svc-shield
            port:
              number: 8080
  - host: hydra.mydomain.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: svc-hydra
            port:
              number: 8080
```

## ✅ VERIFICATION STEPS

### 1. Test Internal Access (from local network):
```bash
# From any device on 192.168.1.x network:
curl -H "Host: shield.mcu.com" http://192.168.1.75
curl -H "Host: hydra.mcu.com" http://192.168.1.75
```

### 2. Test External Access (after port forwarding):
```bash
# From external network (use your public IP):
curl -H "Host: shield.mcu.com" http://YOUR_PUBLIC_IP
curl -H "Host: hydra.mcu.com" http://YOUR_PUBLIC_IP
```

### 3. Test Browser Access:
```bash
# Update hosts file or use real DNS:
http://shield.yourdomain.com/
http://hydra.yourdomain.com/
```

## 🔒 SECURITY CONSIDERATIONS

### Firewall Rules (Optional but Recommended):
```bash
# On Raspberry Pi, allow only specific ports:
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw enable
```

### SSL/TLS Setup (Recommended for Production):
```bash
# Install cert-manager for automatic SSL certificates:
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.0/cert-manager.yaml

# Configure Let's Encrypt for automatic SSL:
# (Separate guide needed for this)
```

## 🎯 ADVANTAGES OF THIS SETUP

✅ **True LoadBalancer**: Real external IP, not NodePort  
✅ **Standard Ports**: HTTP:80, HTTPS:443 (no :30000+ ports)  
✅ **High Performance**: Direct Layer 2 routing via MetalLB  
✅ **Production Ready**: Enterprise-grade ingress controller  
✅ **Scalable**: Add more services easily with ingress rules  
✅ **SSL Ready**: Can add automatic SSL certificates  

## 🚀 NEXT STEPS

1. **Configure router port forwarding** (see steps above)
2. **Get your public IP**: `curl ifconfig.me`
3. **Test external access** with curl commands
4. **Set up DNS** (domain or dynamic DNS)
5. **Add SSL certificates** (optional, for HTTPS)
6. **Deploy more applications** and add ingress rules

## 📞 GETTING YOUR PUBLIC IP

```bash
# Find your public IP address:
curl ifconfig.me
curl icanhazip.com
curl ipinfo.io/ip
```

Use this IP in your DNS records or for direct testing.

## 🔗 EXAMPLE ROUTER BRANDS

### Common Router Interfaces:
- **Netgear**: Advanced → Dynamic DNS/Port Forwarding
- **Linksys**: Smart Wi-Fi Tools → Port Range Forwarding  
- **ASUS**: WAN → Virtual Server/Port Forwarding
- **TP-Link**: Advanced → NAT Forwarding → Port Forwarding
- **D-Link**: Advanced → Port Forwarding

============================================
Your MetalLB setup is PERFECT for external access!
The LoadBalancer service gives you a clean, professional
setup that's ready for internet-facing traffic.
============================================