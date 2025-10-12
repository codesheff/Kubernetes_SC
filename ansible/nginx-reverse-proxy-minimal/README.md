# NGINX Reverse Proxy - Minimal Setup

## Quick Start

### For External Internet Access:
```bash
./setup-reverse-proxy.sh external
```

### For Local Network Only:
```bash
./setup-reverse-proxy.sh
```

## Files Included:
- `inventory/all-server.ini` - Server connection details
- `nginx-reverse-proxy-external.yml` - External access playbook
- `nginx-reverse-proxy.yml` - Local access playbook  
- `setup-reverse-proxy.sh` - Interactive setup script
- `rebuild-reverse-proxy.sh` - Quick rebuild script (optional)

## Access Your Services:
After setup, visit `http://192.168.1.114` for instructions.

## Domain Access:
Add to your hosts file:
```
192.168.1.114 shield.mcu.com
192.168.1.114 hydra.mcu.com
192.168.1.114 mcu.com
```

Then visit:
- http://shield.mcu.com
- http://hydra.mcu.com
- http://mcu.com/shield
- http://mcu.com/hydra
