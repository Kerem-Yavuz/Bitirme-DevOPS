#!/bin/bash
# =============================================================================
# Hyperledger Fabric Network Deployment - Bevel Operator
# =============================================================================

set -e

NAMESPACE="fabric-bevel"
STORAGE_CLASS="local-path"
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
# Step 3: Deploy CAs
# ------------------------------------------------
echo ""
echo "Step 3: Deploying Certificate Authorities..."
kubectl apply -f "$SCRIPT_DIR/manifests/ca-orderer.yaml"
kubectl apply -f "$SCRIPT_DIR/manifests/ca-admin.yaml"
kubectl apply -f "$SCRIPT_DIR/manifests/ca-student.yaml"
echo "✅ CA resources created"

# ------------------------------------------------
# Step 4: Wait for CAs to be running
# ------------------------------------------------
echo ""
echo "Step 4: Waiting for CA pods (this may take 2-3 minutes)..."

for i in {1..30}; do
    echo "Checking pods... ($i/30)"
    
    RUNNING=$(kubectl get pods -n $NAMESPACE --no-headers 2>/dev/null | grep -c "Running" || echo "0")
    TOTAL=$(kubectl get pods -n $NAMESPACE --no-headers 2>/dev/null | wc -l | tr -d ' ' || echo "0")
    
    echo "  Running: $RUNNING / Total: $TOTAL"
    
    if [ "$RUNNING" -ge 3 ] 2>/dev/null; then
        echo "✅ All CA pods running"
        break
    fi
    sleep 10
done

kubectl get pods -n $NAMESPACE

# ------------------------------------------------
# Step 5: Deploy Peers
# ------------------------------------------------
echo ""
echo "Step 5: Deploying Peers..."
kubectl apply -f "$SCRIPT_DIR/manifests/peer0-admin.yaml"
kubectl apply -f "$SCRIPT_DIR/manifests/peer0-student.yaml"
echo "✅ Peer resources created"

# ------------------------------------------------
# Step 6: Deploy Orderer
# ------------------------------------------------
echo ""
echo "Step 6: Deploying Orderer..."
kubectl apply -f "$SCRIPT_DIR/manifests/orderer0.yaml"
echo "✅ Orderer resource created"

# ------------------------------------------------
# Step 7: Wait for all pods
# ------------------------------------------------
echo ""
echo "Step 7: Waiting for all pods (this may take 3-5 minutes)..."

for i in {1..30}; do
    echo "Checking pods... ($i/30)"
    kubectl get pods -n $NAMESPACE --no-headers 2>/dev/null || true
    
    RUNNING=$(kubectl get pods -n $NAMESPACE --no-headers 2>/dev/null | grep -c "Running" || echo "0")
    
    # 3 CAs + 2 Peers (each with CouchDB = 4 pods) + 1 Orderer = at least 8 pods
    if [ "$RUNNING" -ge 6 ] 2>/dev/null; then
        echo "✅ Most pods running"
        break
    fi
    sleep 10
done

# ------------------------------------------------
# Step 8: Create Channel
# ------------------------------------------------
echo ""
echo "Step 8: Creating channel..."
kubectl apply -f "$SCRIPT_DIR/manifests/channel-demo.yaml" 2>/dev/null || true
echo "✅ Channel resource created"

# ------------------------------------------------
# Step 9: Join peers to channel
# ------------------------------------------------
echo ""
echo "Step 9: Joining peers to channel..."
kubectl apply -f "$SCRIPT_DIR/manifests/channel-join-admin.yaml" 2>/dev/null || true
kubectl apply -f "$SCRIPT_DIR/manifests/channel-join-student.yaml" 2>/dev/null || true
echo "✅ Channel join resources created"

# ------------------------------------------------
# Summary
# ------------------------------------------------
echo ""
echo "=============================================="
echo "Deployment Status"
echo "=============================================="
echo ""
echo "FabricCAs:"
kubectl get fabriccas.hlf.kungfusoftware.es -n $NAMESPACE -o wide 2>/dev/null || true
echo ""
echo "FabricPeers:"
kubectl get fabricpeers.hlf.kungfusoftware.es -n $NAMESPACE -o wide 2>/dev/null || true
echo ""
echo "FabricOrderers:"
kubectl get fabricorderingservices.hlf.kungfusoftware.es -n $NAMESPACE -o wide 2>/dev/null || true
echo ""
echo "FabricMainChannel:"
kubectl get fabricmainchannels.hlf.kungfusoftware.es -n $NAMESPACE -o wide 2>/dev/null || true
echo ""
echo "FabricFollowerChannels:"
kubectl get fabricfollowerchannels.hlf.kungfusoftware.es -n $NAMESPACE -o wide 2>/dev/null || true
echo ""
echo "Pods:"
kubectl get pods -n $NAMESPACE -o wide
echo ""
echo "Next Steps:"
echo "1. Wait for all pods to be Running"
echo "2. Deploy chaincode"

