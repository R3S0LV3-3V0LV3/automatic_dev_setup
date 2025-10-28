#!/usr/bin/env bash
# =============================================================================
# automatic-dev-container-suite.sh - Automatic Dev Setup
# Purpose: Assist with container runtime and Kubernetes bootstrap tasks.
# Version: 3.0.0
# Dependencies: bash, colima, kind, kubectl, helm
# Criticality: BETA
# =============================================================================

set -Eeuo pipefail
IFS=$'\n\t'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SUITE_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# shellcheck source=automatic-dev-suite/lib/automatic-dev-core.sh
source "$SUITE_ROOT/lib/automatic-dev-core.sh"

ads_enable_traps

usage() {
    cat <<'EOF'
Automatic Dev Container Suite

Usage: automatic-dev-container-suite.sh <command>

Commands:
  colima-start            Start the Colima container runtime with Kubernetes enabled
  colima-stop             Stop the Colima runtime
  colima-status           Show Colima status
  kind-bootstrap          Create a new kind cluster named "automatic-dev"
  kind-delete             Delete the "automatic-dev" kind cluster
  verify                  Run container/kubernetes verification checks
  help                    Show this message
EOF
}

verify_colima() {
    if ! command -v colima >/dev/null 2>&1; then
        log_error "colima CLI not found. Install via Homebrew."
        return 1
    fi
    colima status || true
}

verify_docker() {
    if command -v docker >/dev/null 2>&1; then
        docker --version || log_warning "Docker CLI present but daemon may not be running."
    else
        log_warning "Docker CLI not detected."
    fi
}

verify_kubernetes() {
    if command -v kubectl >/dev/null 2>&1; then
        kubectl version --client || true
    else
        log_warning "kubectl not detected."
    fi

    if command -v helm >/dev/null 2>&1; then
        helm version --short || true
    fi

    if command -v k9s >/dev/null 2>&1; then
        k9s version || true
    fi
}

case "${1:-help}" in
    colima-start)
        verify_colima || exit 1
        colima start --kubernetes 1
        ;;
    colima-stop)
        verify_colima || exit 1
        colima stop
        ;;
    colima-status)
        verify_colima || exit 1
        ;;
    kind-bootstrap)
        if ! command -v kind >/dev/null 2>&1; then
            log_error "kind CLI not found."
            exit 1
        fi
        kind create cluster --name automatic-dev --config <(cat <<'EOF'
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
  - role: control-plane
    kubeadmConfigPatches:
      - |
        kind: InitConfiguration
        nodeRegistration:
          kubeletExtraArgs:
            node-labels: "ingress-ready=true"
  - role: worker
EOF
)
        ;;
    kind-delete)
        if command -v kind >/dev/null 2>&1; then
            kind delete cluster --name automatic-dev || true
        fi
        ;;
    verify)
        verify_colima
        verify_docker
        verify_kubernetes
        ;;
    help|*)
        usage
        ;;
esac
