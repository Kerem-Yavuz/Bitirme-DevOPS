#!/bin/bash
# =============================================================================
# Hyperledger Fabric Network Deployment - Bevel Operator
# =============================================================================

set -e

NAMESPACE="fabric-bevel"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=============================================="
echo "Hyperledger Fabric Network Deployment"
echo "=============================================="

# ------------------------------------------------
# Step 1: Install HLF Operator
# ------------------------------------------------
echo ""
echo "Step 1: Installing HLF Operator..."

helm repo add kfs https://kfsoftware.github.io/hlf-helm-charts --force-update

if helm list -n hlf-operator-system 2>/dev/null | grep -q hlf-operator; then
    echo "✅ Operator already installed"
else
    echo "Installing operator..."
    helm install hlf-operator kfs/hlf-operator -n hlf-operator-system --create-namespace --wait
fi

echo "Waiting for operator..."
kubectl wait --for=condition=available --timeout=180s deployment -l app.kubernetes.io/name=hlf-operator -n hlf-operator-system || true
sleep 20

echo "Checking CRDs..."
kubectl get crd | grep hlf
echo "✅ Operator ready"

# ------------------------------------------------
# Step 2: Create Namespace
# ------------------------------------------------
echo ""
echo "Step 2: Creating namespace..."
kubectl create namespace $NAMESPACE --dry-run=client -o yaml | kubectl apply -f -
echo "✅ Namespace ready"

# ------------------------------------------------
# Step 3: Delete old CAs if exist (clean state)
# ------------------------------------------------
echo ""
echo "Step 3: Cleaning old resources..."
kubectl delete fabriccas.hlf.kungfusoftware.es --all -n $NAMESPACE 2>/dev/null || true
sleep 5

# ------------------------------------------------
# Step 4: Deploy CAs
# ------------------------------------------------
echo ""
echo "Step 4: Deploying Certificate Authorities..."
kubectl apply -f "$SCRIPT_DIR/manifests/ca-orderer.yaml"
kubectl apply -f "$SCRIPT_DIR/manifests/ca-admin.yaml"
kubectl apply -f "$SCRIPT_DIR/manifests/ca-student.yaml"
echo "✅ CA resources created"

# ------------------------------------------------
# Step 5: Wait for CAs to be running
# ------------------------------------------------
echo ""
echo "Step 5: Waiting for CA pods (this may take 2-3 minutes)..."

for i in {1..30}; do
    echo "Checking pods... ($i/30)"
    kubectl get pods -n $NAMESPACE 2>/dev/null || true
    
    RUNNING=$(kubectl get pods -n $NAMESPACE --no-headers 2>/dev/null | grep -c "Running" || echo "0")
    if [ "$RUNNING" -ge 3 ] 2>/dev/null; then
        echo "✅ All CA pods running"
        break
    fi
    sleep 10
done

# ------------------------------------------------
# Summary
# ------------------------------------------------
echo ""
echo "=============================================="
echo "CA Deployment Status"
echo "=============================================="
echo ""
echo "FabricCAs:"
kubectl get fabriccas.hlf.kungfusoftware.es -n $NAMESPACE -o wide
echo ""
echo "Pods:"
kubectl get pods -n $NAMESPACE -o wide
echo ""
echo "If pods are not running, check operator logs:"
echo "  kubectl logs -n hlf-operator-system deployment/hlf-operator-controller-manager -c manager --tail=50"
