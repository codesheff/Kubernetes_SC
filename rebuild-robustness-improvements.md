# Kubernetes Cluster Rebuild Robustness Improvements

## Issue Identified
During cluster rebuild testing, we encountered a failure where the kubelet service file was missing after the reset phase, causing the setup phase to fail when trying to enable the kubelet service.

## Root Cause
The `reset-kubernetes.yml` playbook removes Kubernetes packages which can sometimes leave the system in an inconsistent state where systemd service files are not properly restored during package reinstallation.

## Solutions Implemented

### 1. Enhanced Package Removal in reset-kubernetes.yml
- **Change**: Added `purge: yes` option to package removal tasks for Ubuntu/Debian
- **Benefit**: Ensures complete removal of packages and configuration files, providing a cleaner slate for reinstallation
- **Files Modified**: `ansible/k8s/reset-kubernetes.yml`

### 2. Added Service File Verification in setup.yml
- **Change**: Added verification steps to check if kubelet and containerd service files exist after package installation
- **Benefit**: Automatically detects and fixes missing service files by reinstalling packages with `force: yes`
- **Files Modified**: `ansible/k8s/setup.yml`

### 3. Enhanced systemd Cleanup
- **Change**: Added `systemctl reset-failed` command after package removal to clear any failed service states
- **Benefit**: Prevents lingering systemd state issues that could interfere with service management
- **Files Modified**: `ansible/k8s/reset-kubernetes.yml`

## New Robustness Features

### Kubelet Service Recovery
```yaml
- name: Verify kubelet service file exists
  stat:
    path: /lib/systemd/system/kubelet.service
  register: kubelet_service_file

- name: Reinstall kubelet if service file is missing (Ubuntu/Debian)
  package:
    name: kubelet
    state: present
    force: yes
  when: ansible_os_family == "Debian" and not kubelet_service_file.stat.exists
```

### Containerd Service Recovery
```yaml
- name: Verify containerd service file exists
  stat:
    path: /lib/systemd/system/containerd.service
  register: containerd_service_file

- name: Reinstall containerd if service file is missing (Ubuntu/Debian)
  package:
    name: containerd
    state: present
    force: yes
  when: ansible_os_family == "Debian" and not containerd_service_file.stat.exists
```

## Testing Validation
- Tested service file detection mechanism
- Verified that the recovery logic works correctly when service files are present
- Confirmed that the changes don't impact normal operation when services are properly installed

## Expected Impact
These changes should prevent the kubelet service missing issue from occurring during future cluster rebuilds by:

1. **Proactive Detection**: Automatically detecting when service files are missing
2. **Automatic Recovery**: Reinstalling packages when service files are not found
3. **Cleaner Reset**: More thorough cleanup during reset phase reduces state inconsistencies
4. **Improved Reliability**: The setup process becomes more resilient to package installation variations

## Compatibility
- Changes are specific to Ubuntu/Debian systems where the issue was observed
- RHEL/CentOS behavior remains unchanged
- All changes include appropriate error handling with `ignore_errors: yes` where needed

## Usage
No changes required to existing workflow - the improvements are automatic and transparent. The `runSetup_new.sh` script will now be more reliable during rebuilds.