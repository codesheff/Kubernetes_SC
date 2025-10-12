# 🌐 External Internet Access Setup Guide

This guide will help you make your Marvel Kubernetes services accessible from anywhere on the internet.

## 📋 Complete Setup Checklist

### ✅ Step 1: Router Configuration (REQUIRED)

**Access your router's admin panel** and configure port forwarding:

#### **Port Forwarding Rules:**
```
Service: Marvel-HTTP
External Port: 80
Internal IP: 192.168.1.114
Internal Port: 80
Protocol: TCP
Enable: ✓

Service: Marvel-HTTPS (Future)
External Port: 443  
Internal IP: 192.168.1.114
Internal Port: 443
Protocol: TCP
Enable: ✓
```

#### **Common Router Interface Locations:**
- **Linksys:** Advanced → Security → Apps and Gaming → Single Port Forwarding
- **Netgear:** Dynamic DNS → Port Forwarding / Port Triggering
- **TP-Link:** Advanced → NAT Forwarding → Port Forwarding
- **ASUS:** Adaptive QoS → Port Forwarding
- **D-Link:** Advanced → Port Forwarding

### ✅ Step 2: Deploy Enhanced NGINX Configuration

```bash
cd /mnt/c/git/SC_Kubernetes/ansible

# Deploy the external-access version
ansible-playbook -i inventory/all-server.ini nginx-reverse-proxy-external.yml --ask-become-pass
```

### ✅ Step 3: Domain Name Setup (Choose One Option)

#### **Option A: Free Dynamic DNS (Recommended for Testing)**

**1. Sign up for free DDNS service:**
- [Duck DNS](https://www.duckdns.org/) (easiest)
- [No-IP](https://www.noip.com/)
- [FreeDNS](https://freedns.afraid.org/)

**2. Example with Duck DNS:**
```bash
# Create subdomains:
yourusername-shield.duckdns.org
yourusername-hydra.duckdns.org  
yourusername-mcu.duckdns.org

# Update your Pi to keep IP current:
crontab -e
# Add line:
*/5 * * * * curl "https://www.duckdns.org/update?domains=yourusername-shield,yourusername-hydra,yourusername-mcu&token=YOUR_TOKEN"
```

#### **Option B: Purchase Custom Domain**
- Buy domain from Cloudflare, Namecheap, etc.
- Point A records to your public IP
- Enable Cloudflare proxy for DDoS protection (optional)

#### **Option C: Use Public IP Directly (Testing Only)**
```bash
# Find your public IP
curl ipinfo.io/ip

# Test with IP + Host header
curl -H "Host: shield.mcu.com" http://YOUR_PUBLIC_IP
```

### ✅ Step 4: Test External Access

#### **Internal Test (from your network):**
```bash
# Test from your laptop
curl -H "Host: shield.mcu.com" http://192.168.1.114
curl -H "Host: hydra.mcu.com" http://192.168.1.114
curl -H "Host: mcu.com" http://192.168.1.114/shield
curl -H "Host: mcu.com" http://192.168.1.114/hydra
```

#### **External Test (from internet):**
```bash
# Use your phone's mobile data or ask a friend
curl -H "Host: shield.mcu.com" http://YOUR_PUBLIC_IP
# Or visit in browser with domains configured
```

## 🔒 Security Features Included

### **Firewall Protection (UFW)**
- Only allows necessary ports (22, 80, 443, 8080)
- Blocks all other incoming traffic
- Logs suspicious activity

### **Intrusion Prevention (Fail2ban)**
- Automatically bans IPs with suspicious behavior
- Monitors NGINX logs for attack patterns
- Protects against brute force and bot attacks

### **Rate Limiting**
- Limits requests per IP to prevent abuse
- Different limits for different endpoints
- Burst handling for legitimate traffic spikes

### **Security Headers**
- X-Frame-Options: Prevents clickjacking
- X-XSS-Protection: Blocks XSS attacks
- X-Content-Type-Options: Prevents MIME sniffing
- Content-Security-Policy: Controls resource loading

### **Attack Pattern Blocking**
- Blocks access to common attack URLs (.php, wp-admin, etc.)
- Denies access to hidden files (.htaccess, etc.)
- Returns 444 (connection closed) for suspicious requests

## 📊 Monitoring & Maintenance

### **Real-time Monitoring:**
```bash
# Watch access logs
ssh pi@192.168.1.114
sudo tail -f /var/log/nginx/access.log

# Watch error logs
sudo tail -f /var/log/nginx/error.log

# Check fail2ban status
sudo fail2ban-client status
sudo fail2ban-client status nginx-http-auth

# View health check logs
sudo tail -f /var/log/nginx/k8s-ingress-health.log
```

### **Check Banned IPs:**
```bash
# List currently banned IPs
sudo fail2ban-client status nginx-http-auth

# Unban an IP if needed
sudo fail2ban-client set nginx-http-auth unbanip IP_ADDRESS
```

### **NGINX Status:**
```bash
# Check NGINX status
sudo systemctl status nginx

# Test configuration
sudo nginx -t

# Reload configuration (no downtime)
sudo nginx -s reload
```

## 🚨 Troubleshooting

### **Can't Access from Internet:**

1. **Check Port Forwarding:**
   ```bash
   # Test from external network
   telnet YOUR_PUBLIC_IP 80
   ```

2. **Check Firewall:**
   ```bash
   sudo ufw status
   sudo systemctl status nginx
   ```

3. **Check Router Logs:**
   - Look for blocked or dropped connections
   - Verify port forwarding rules are active

4. **ISP Restrictions:**
   - Some ISPs block port 80/443
   - Try using alternative ports (8080, 8443)
   - Contact ISP if needed

### **High Traffic/Resource Usage:**

1. **Monitor System Resources:**
   ```bash
   htop
   sudo iotop
   ```

2. **Optimize NGINX:**
   ```bash
   # Check worker processes
   ps aux | grep nginx
   
   # Monitor connections
   sudo netstat -tuln | grep :80
   ```

3. **Review Access Patterns:**
   ```bash
   # Top requesting IPs
   sudo awk '{print $1}' /var/log/nginx/access.log | sort | uniq -c | sort -nr | head -10
   
   # Most requested URLs
   sudo awk '{print $7}' /var/log/nginx/access.log | sort | uniq -c | sort -nr | head -10
   ```

## 🎯 Production Recommendations

### **SSL/HTTPS Setup (Highly Recommended):**
```bash
# Install Certbot for Let's Encrypt
sudo apt install certbot python3-certbot-nginx

# Get SSL certificates
sudo certbot --nginx -d shield.mcu.com -d hydra.mcu.com -d mcu.com

# Auto-renewal
sudo crontab -e
# Add: 0 12 * * * /usr/bin/certbot renew --quiet
```

### **Enhanced Security:**
- Set up Cloudflare for DDoS protection
- Configure Geographic IP blocking if needed
- Add basic authentication for admin access
- Set up log monitoring alerts

### **Performance Optimization:**
- Enable response caching
- Configure CDN for static assets
- Implement connection pooling
- Add health check endpoints

### **Backup Strategy:**
- Regular NGINX config backups
- Monitor disk space for logs
- Set up alerting for service failures

## 📱 Mobile Access Example

After setup, your services will be accessible like:
```
https://yourusername-shield.duckdns.org
https://yourusername-hydra.duckdns.org
https://yourusername-mcu.duckdns.org/shield
https://yourusername-mcu.duckdns.org/hydra
```

## 🆘 Emergency Recovery

If something goes wrong:
```bash
# Restore original NGINX config
sudo cp /etc/nginx/nginx.conf.backup /etc/nginx/nginx.conf
sudo systemctl restart nginx

# Disable external access
sudo ufw deny 80
sudo ufw deny 443

# Check what's running on port 80
sudo netstat -tulpn | grep :80
```

Your Marvel services will now be accessible from anywhere in the world! 🌍