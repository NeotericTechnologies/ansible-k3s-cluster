# Rancher Outage Troubleshooting Guide
## Test Cluster (v1.35.6+k3s1, Rancher 2.14.3)

**Issue**: Rancher website is not responding after full install/upgrade of all components.

---

## Quick Start

### Step 1: Use SSH to run the Diagnostic Script on each Control-Plane Node
```bash
ssh ansible@<control-plane-node-ip> 'bash -s' < ./diagnostics/rancher-diagnostic.sh
```

---

## Most Likely Root Causes

### 1. Look for issues with VIP assignment or Traefik LoadBalancer Having No External IP

**Root Cause**: kube-vip cloud-provider not running or missing RBAC permissions

---

## Full Diagnostic Workflow

1. **Run diagnostic script on all control plane nodes ** → Captures full cluster state
2. **Identify issue** from output
3. **Troubleshoot and fix issues**
4. **Verify Rancher is accessible** → `curl -k <rancher-url>`

---

**Created**: 2026-07-12
**Scripts**: rancher-diagnostic.sh
