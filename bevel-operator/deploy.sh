#!/bin/bash
# =============================================================================
# Hyperledger Fabric Network Deployment Script - Bevel Operator
# =============================================================================
# Bu script Bevel-Operator-Fabric kullanarak tüm ağı deploy eder
# =============================================================================

set -e

NAMESPACE="fabric-bevel"
OPERATOR_NAMESPACE="hlf-operator-system"

echo "=============================================="
echo "Hyperledger Fabric Network Deployment"
echo "=============================================="

# ------------------------------------------------
# Step 0: Operator Kurulumu Kontrolü
# ------------------------------------------------
echo ""
echo "Step 0: Checking Bevel Operator..."
if ! kubectl get deployment -n $OPERATOR_NAMESPACE hlf-operator-controller-manager &> /dev/null; then
    echo "Installing Bevel Operator via Helm..."
    helm repo add kfs https://kfsoftware.github.io/hlf-helm-charts --force-update
    helm install hlf-operator --version=1.11.0 kfs/hlf-operator -n $OPERATOR_NAMESPACE --create-namespace
    echo "Waiting for operator to be ready..."
    kubectl wait --for=condition=available --timeout=300s deployment/hlf-operator-controller-manager -n $OPERATOR_NAMESPACE
else
    echo "✅ Operator already installed"
fi

# ------------------------------------------------
# Step 1: Namespace Oluştur
# ------------------------------------------------
echo ""
echo "Step 1: Creating namespace..."
kubectl create namespace $NAMESPACE --dry-run=client -o yaml | kubectl apply -f -
echo "✅ Namespace ready"

# ------------------------------------------------
# Step 2: Certificate Authorities
# ------------------------------------------------
echo ""
echo "Step 2: Deploying Certificate Authorities..."
kubectl apply -f 01-cas/
echo "Waiting for CAs to be ready (this may take 1-2 minutes)..."
sleep 30

# CA'ların hazır olmasını bekle
for ca in ca-orderer ca-admin ca-student; do
    echo "Waiting for $ca..."
    kubectl wait --for=condition=Running --timeout=180s fabricca/$ca -n $NAMESPACE 2>/dev/null || true
done
echo "✅ CAs deployed"

# ------------------------------------------------
# Step 3: Peers
# ------------------------------------------------
echo ""
echo "Step 3: Deploying Peers..."
kubectl apply -f 02-peers/
echo "Waiting for peers to be ready..."
sleep 30

for peer in peer0-admin peer0-student; do
    echo "Waiting for $peer..."
    kubectl wait --for=condition=Running --timeout=180s fabricpeer/$peer -n $NAMESPACE 2>/dev/null || true
done
echo "✅ Peers deployed"

# ------------------------------------------------
# Step 4: Orderer
# ------------------------------------------------
echo ""
echo "Step 4: Deploying Orderer..."
kubectl apply -f 03-orderers/
echo "Waiting for orderer to be ready..."
sleep 30
echo "✅ Orderer deployed"

# ------------------------------------------------
# Step 5: Channel Oluştur
# ------------------------------------------------
echo ""
echo "Step 5: Creating Channel..."
kubectl apply -f 04-channels/
echo "✅ Channel configuration applied"

# ------------------------------------------------
# Step 6: Chaincode Deploy
# ------------------------------------------------
echo ""
echo "Step 6: Deploying External Chaincode..."
kubectl apply -f 05-chaincode/
echo "✅ Chaincode deployed"

# ------------------------------------------------
# Summary
# ------------------------------------------------
echo ""
echo "=============================================="
echo "Deployment Complete!"
echo "=============================================="
echo ""
echo "Resources:"
kubectl get pods -n $NAMESPACE
echo ""
echo "CRDs:"
kubectl get fabriccas,fabricpeers,fabricorderingservices,fabricmainchannels -n $NAMESPACE 2>/dev/null || true
echo ""
echo "Next Steps:"
echo "1. Install chaincode package on peers using kubectl-hlf plugin"
echo "2. Update CHAINCODE_ID in 05-chaincode/chaincode-external.yaml"
echo "3. Approve and commit chaincode"
echo ""
