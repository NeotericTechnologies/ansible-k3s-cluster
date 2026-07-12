#!/bin/bash
# Rancher Diagnostic Script for test-k3s-cluster
# Purpose: Troubleshoot Rancher deployment and networking issues
# Run this on one of the control-plane nodes: k3s-server-01, k3s-server-02, or k3s-server-03

set -e

echo "════════════════════════════════════════════════════════════════"
echo "RANCHER DIAGNOSTIC REPORT - $(date)"
echo "════════════════════════════════════════════════════════════════"
echo ""

export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

echo "1. KUBERNETES CLUSTER STATUS"
echo "────────────────────────────────────────────────────────────────"
kubectl get nodes -o wide || echo "ERROR: Could not get nodes"
echo ""

echo "2. RANCHER DEPLOYMENT STATUS"
echo "────────────────────────────────────────────────────────────────"
kubectl get ns cattle-system 2>/dev/null || echo "ERROR: cattle-system namespace not found"
kubectl get deployment -n cattle-system -o wide 2>/dev/null || echo "ERROR: Could not get deployments"
kubectl get pods -n cattle-system -o wide 2>/dev/null || echo "ERROR: Could not get pods"
echo ""

echo "3. RANCHER SERVICE"
echo "────────────────────────────────────────────────────────────────"
kubectl get svc -n cattle-system -o wide 2>/dev/null || echo "ERROR: Could not get services"
echo ""

echo "4. RANCHER INGRESS"
echo "────────────────────────────────────────────────────────────────"
kubectl get ingress -n cattle-system -o wide 2>/dev/null || echo "ERROR: Could not get ingresses"
echo ""

echo "5. TRAEFIK INGRESS CONTROLLER"
echo "────────────────────────────────────────────────────────────────"
kubectl get deployment -n kube-system -l app.kubernetes.io/name=traefik -o wide 2>/dev/null || echo "ERROR: traefik deployment not found"
kubectl get pods -n kube-system -l app.kubernetes.io/name=traefik -o wide 2>/dev/null || echo "ERROR: traefik pods not found"
kubectl get svc -n kube-system -l app.kubernetes.io/name=traefik -o wide 2>/dev/null || echo "ERROR: traefik service not found"
echo ""

echo "6. LOADBALANCER SERVICES"
echo "────────────────────────────────────────────────────────────────"
kubectl get svc --all-namespaces --field-selector spec.type=LoadBalancer -o wide 2>/dev/null || echo "ERROR: Could not get loadbalancer services"
echo ""

echo "7. VIP ASSIGNMENT CHECK"
echo "────────────────────────────────────────────────────────────────"
VIP_IP=$(kubectl get svc --all-namespaces --field-selector spec.type=LoadBalancer | awk 'NR==2 {print $5}')
ip addr show enp6s18 | grep ${VIP_IP} 2>/dev/null || echo "ERROR: Unable to find VIP ${VIP_IP} on interface enp6s18"
echo ""

echo "8. HELM RELEASE STATUS"
echo "────────────────────────────────────────────────────────────────"
helm list -n cattle-system 2>/dev/null || echo "ERROR: Could not list helm releases"
helm status rancher -n cattle-system 2>/dev/null || echo "ERROR: Could not get helm status"
echo ""

echo "════════════════════════════════════════════════════════════════"
echo "DIAGNOSTIC REPORT COMPLETE - $(date)"
echo "════════════════════════════════════════════════════════════════"
