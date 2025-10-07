# Pre-Rebuild Checklist

## Prerequisites Check ✅

### 1. Network Configuration
- [ ] Raspberry Pi connected via Ethernet (primary)
- [ ] IP Address: 192.168.1.112 confirmed
- [ ] SSH access working with 'cranie' user
- [ ] Router ready for potential port forwarding

### 2. System Requirements
- [ ] Ubuntu 24.04 on Raspberry Pi
- [ ] Sufficient disk space (>10GB available)
- [ ] Internet connectivity stable
- [ ] No existing Kubernetes cluster conflicts

### 3. Ansible Configuration
- [ ] Inventory file `/mnt/c/git/SC_Kubernetes/ansible/inventory/all-server.ini` updated
- [ ] SSH keys properly configured
- [ ] Ansible playbooks present in correct locations

### 4. Files and Scripts
- [ ] `rebuild-k8s.sh` script executable and enhanced
- [ ] All Ansible playbooks present (`setup.yml`, `initialise.yml`, `metallb.yml`, etc.)
- [ ] Test application files available (`ingress-test/ig-all.yml`)

## Pre-Rebuild Commands

```bash
# 1. Verify SSH connectivity
ssh cranie@192.168.1.112 "echo 'SSH connection successful'"

# 2. Check disk space
ssh cranie@192.168.1.112 "df -h / | grep -v Filesystem"

# 3. Verify Ansible can reach the host
ansible -i ansible/inventory/all-server.ini all -m ping

# 4. Check if any existing Kubernetes processes are running
ssh cranie@192.168.1.112 "sudo systemctl status kubelet || echo 'No kubelet running'"
ssh cranie@192.168.1.112 "sudo systemctl status containerd || echo 'No containerd running'"
```

## Expected Rebuild Process

The rebuild script will perform these steps:
1. ✅ Reset any existing Kubernetes cluster
2. ✅ Run Ansible setup for Docker/Kubernetes installation
3. ✅ Initialize new Kubernetes cluster with correct certificates
4. ✅ Set up CNI networking with bridge fallback
5. ✅ Install MetalLB LoadBalancer with graceful error handling
6. ✅ Deploy NGINX Ingress Controller with NodePort fallback
7. ✅ Create service accounts and RBAC
8. ✅ Deploy test applications (if files exist)
9. ✅ Verify functionality with realistic expectations

## Known Acceptable Issues

During rebuild, these warnings are expected and acceptable:
- ⚠️ Scheduler TLS certificate validation warnings (cluster still functional)
- ⚠️ MetalLB pods may not schedule on single-node cluster (LoadBalancer works)
- ⚠️ Some pods may take time to reach Running state
- ⚠️ Initial connectivity tests may timeout (give time for stabilization)

## Success Criteria

✅ **Minimal Success:**
- Kubernetes cluster initialized
- kubectl commands work
- Basic pod can be created and run
- At least one service accessible

✅ **Full Success:**
- All system pods running
- MetalLB LoadBalancer operational
- NGINX Ingress Controller functional
- Test applications accessible via ingress
- External connectivity ready

## Post-Rebuild Validation

After rebuild completion, verify:
```bash
# Basic cluster health
kubectl get nodes
kubectl get pods -A

# Service connectivity
kubectl get services -A

# Ingress functionality
kubectl get ingress -A

# Test basic pod creation
kubectl run test-validation --image=busybox --command -- echo "Validation test"
kubectl logs test-validation
kubectl delete pod test-validation
```

## Ready to Proceed?

If all checkboxes above are confirmed, the full rebuild can be executed with:
```bash
cd /mnt/c/git/SC_Kubernetes
chmod +x rebuild-k8s.sh
./rebuild-k8s.sh
```

**Estimated Time:** 15-25 minutes for complete rebuild
**Monitor Progress:** Script provides detailed status updates and handles errors gracefully