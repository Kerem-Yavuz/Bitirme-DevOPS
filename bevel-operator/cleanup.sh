#!/bin/bash
# =============================================================================
# Cleanup Script - Remove all Fabric resources
# =============================================================================

set -e

echo "=============================================="
echo "Cleaning up Hyperledger Fabric Network"
echo "=============================================="

echo ""
echo "Deleting Fabric Follower Channels..."
kubectl delete fabricfollowerchannels --all --ignore-not-found

echo ""
echo "Deleting Fabric Main Channels..."
kubectl delete fabricmainchannels --all --ignore-not-found

echo ""
echo "Deleting Fabric Orderer Nodes..."
kubectl delete fabricorderernodes --all --ignore-not-found

echo ""
echo "Deleting Fabric Peers..."
kubectl delete fabricpeers --all --ignore-not-found

echo ""
echo "Deleting Fabric CAs..."
kubectl delete fabriccas --all --ignore-not-found

echo ""
echo "Deleting Wallet Secret..."
kubectl delete secret wallet --ignore-not-found

echo ""
echo "Deleting Identity Secrets..."
kubectl delete fabricidentities --all --ignore-not-found 2>/dev/null || true

echo ""
echo "Cleaning up local enrollment files..."
rm -f *.yaml 2>/dev/null || true

echo ""
echo "Waiting for resources to be deleted..."
sleep 10

echo ""
echo "Remaining pods:"
kubectl get pods

echo ""
echo "=============================================="
echo "Cleanup Complete!"
echo "=============================================="
echo ""
echo "Note: HLF Operator and Istio are NOT removed."
echo "To remove them, run:"
echo "  helm uninstall hlf-operator"
echo "  kubectl delete namespace istio-system"
echo "=============================================="
