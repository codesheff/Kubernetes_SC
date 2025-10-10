#!/bin/bash

vInventory="-i ./inventory/all-server.ini"

SKIP_RESET=0
SKIP_REBOOT=0
SKIP_SETUP=0
SKIP_MASTERS=0
SKIP_WORKERS=0
SKIP_METALLB=0
SKIP_INITIALISE=0

ONLY_STEP=""

usage() {
    echo "Usage: $0 [OPTIONS]"
    echo "Options:"
    echo "  --skip-reset      Skip running reset-kubernetes.yml"
    echo "  --skip-reboot     Skip running reboot.yml"
    echo "  --skip-setup      Skip running setup.yml"
    echo "  --skip-initialise Skip running initialise.yml"
    echo "  --skip-masters    Skip running masters.yml"
    echo "  --skip-metallb    Skip running metallb.yml"
    echo "  --skip-workers    Skip running workers.yml"
    echo "  --only-reset      Run only reset-kubernetes.yml"
    echo "  --only-reboot     Run only reboot.yml"
    echo "  --only-setup      Run only setup.yml"
    echo "  --only-initialise Run only initialise.yml"
    echo "  --only-masters    Run only masters.yml"
    echo "  --only-metallb    Run only metallb.yml"
    echo "  --only-workers    Run only workers.yml"
    echo "  -h, --help        Show this help message and exit"
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --configure-pi) ONLY_STEP="configure-pi" ;;
        --skip-reset) SKIP_RESET=1 ;;
        --skip-reboot) SKIP_REBOOT=1 ;;
        --skip-setup) SKIP_SETUP=1 ;;
        --skip-initialise) SKIP_INITIALISE=1 ;;
        --skip-masters) SKIP_MASTERS=1 ;;
        --skip-metallb) SKIP_METALLB=1 ;;
        --skip-workers) SKIP_WORKERS=1 ;;
        --only-reset) ONLY_STEP="reset" ;;
        --only-reboot) ONLY_STEP="reboot" ;;
        --only-setup) ONLY_STEP="setup" ;;
        --only-initialise) ONLY_STEP="initialise" ;;
        --only-masters) ONLY_STEP="masters" ;;
        --only-metallb) ONLY_STEP="metallb" ;;
        --only-workers) ONLY_STEP="workers" ;;
        -h|--help) usage; exit 0 ;;
        *) echo "Unknown option: $1"; usage; exit 1 ;;
    esac
    shift
done

run_step() {
    "$@"
    local status=$?
    if [ $status -ne 0 ]; then
        echo "Error: Command failed: $*"
        exit $status
    fi
}

if [ -n "$ONLY_STEP" ]; then
    case "$ONLY_STEP" in
        configure-pi) run_step ansible-playbook ${vInventory} ./configure-pi.yml ;;
        reset)      run_step ansible-playbook ${vInventory} ./k8s/reset-kubernetes.yml ;;
        reboot)     run_step ansible-playbook ${vInventory} ./reboot.yml ;;
        setup)      run_step ansible-playbook ${vInventory} ./k8s/setup.yml ;;
        initialise) run_step ansible-playbook ${vInventory} ./k8s/initialise.yml ;;
        masters)    run_step ansible-playbook ${vInventory} ./k8s/masters.yml ;;
        metalb)     run_step ansible-playbook ${vInventory} ./k8s/metallb.yml ;;
        workers)    run_step ansible-playbook ${vInventory} ./k8s/workers.yml ;;

    esac
    exit 0
fi

if [ $SKIP_RESET -eq 0 ]; then
    run_step ansible-playbook ${vInventory} ./k8s/reset-kubernetes.yml
fi

if [ $SKIP_SETUP -eq 0 ]; then
    run_step ansible-playbook ${vInventory} ./ansible/configure-pi.yml
fi

if [ $SKIP_REBOOT -eq 0 ]; then
    run_step ansible-playbook ${vInventory} ./reboot.yml
fi

if [ $SKIP_SETUP -eq 0 ]; then
    run_step ansible-playbook ${vInventory} ./k8s/setup.yml
fi

if [ $SKIP_INITIALISE -eq 0 ]; then
    run_step ansible-playbook ${vInventory} ./k8s/initialise.yml
fi

if [ $SKIP_MASTERS -eq 0 ]; then
    run_step ansible-playbook ${vInventory} ./k8s/install-cni-plugins.yml
fi

if [ $SKIP_MASTERS -eq 0 ]; then
    run_step ansible-playbook ${vInventory} ./k8s/flannel-network.yml
fi

if [ $SKIP_MASTERS -eq 0 ]; then
    run_step ansible-playbook ${vInventory} ./k8s/masters.yml
fi

if [ $SKIP_WORKERS -eq 0 ]; then
    run_step ansible-playbook ${vInventory} ./k8s/workers.yml
fi

if [ $SKIP_METALLB -eq 0 ]; then
    run_step ansible-playbook ${vInventory} ./k8s/metallb.yml
fi

