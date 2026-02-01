#!/bin/bash
# =============================================================================
# Hyperledger Fabric Network Deployment - Internal Only (No Istio)
# Uses ClusterIP services with port-forward for kubectl-hlf access
# =============================================================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
echo_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
echo_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Configuration
PEER_IMAGE=hyperledger/fabric-peer
PEER_VERSION=2.5.0
ORDERER_IMAGE=hyperledger/fabric-orderer
ORDERER_VERSION=2.5.0
CA_IMAGE=hyperledger/fabric-ca
CA_VERSION=1.5.6
SC_NAME=local-path  # For K3s

echo "=============================================="
echo "Hyperledger Fabric Network Deployment"
echo "Internal Only Method (No Istio)"
echo "=============================================="

# ------------------------------------------------
# Step 1: Install HLF Operator
# ------------------------------------------------
echo ""
echo_info "Step 1: Installing HLF Operator..."

helm repo add kfs https://kfsoftware.github.io/hlf-helm-charts --force-update

if helm list 2>/dev/null | grep -q hlf-operator; then
    echo_info "Operator already installed"
else
    echo_info "Installing operator..."
    helm install hlf-operator --version=1.13.0 kfs/hlf-operator
fi

echo_info "Waiting for operator to be ready..."
sleep 10
kubectl wait --for=condition=available --timeout=180s deployment -l app.kubernetes.io/name=hlf-operator || true

echo_info "✅ Operator ready"

# ------------------------------------------------
# Step 2: Check kubectl-hlf plugin
# ------------------------------------------------
echo ""
echo_info "Step 2: Checking kubectl-hlf plugin..."

if ! kubectl hlf version &>/dev/null; then
    echo_error "kubectl-hlf plugin not found!"
    echo_warn "Please install it manually:"
    echo "  kubectl krew install hlf"
    exit 1
fi

echo_info "✅ kubectl-hlf plugin found"

# ------------------------------------------------
# Step 3: Create Certificate Authorities (No Istio)
# ------------------------------------------------
echo ""
echo_info "Step 3: Creating Certificate Authorities..."

# AdminOrg CA - NO hosts, NO istio-port
echo_info "Creating CA for AdminOrg..."
kubectl hlf ca create --image=$CA_IMAGE --version=$CA_VERSION \
  --storage-class=$SC_NAME --capacity=1Gi \
  --name=ca-admin --enroll-id=enroll --enroll-pw=enrollpw \
  || echo_warn "CA admin may already exist"

# StudentOrg CA
echo_info "Creating CA for StudentOrg..."
kubectl hlf ca create --image=$CA_IMAGE --version=$CA_VERSION \
  --storage-class=$SC_NAME --capacity=1Gi \
  --name=ca-student --enroll-id=enroll --enroll-pw=enrollpw \
  || echo_warn "CA student may already exist"

# Orderer CA
echo_info "Creating CA for Orderer..."
kubectl hlf ca create --image=$CA_IMAGE --version=$CA_VERSION \
  --storage-class=$SC_NAME --capacity=1Gi \
  --name=ca-orderer --enroll-id=enroll --enroll-pw=enrollpw \
  || echo_warn "CA orderer may already exist"

echo_info "Waiting for CAs to be ready..."
for i in {1..60}; do
    READY=$(kubectl get fabriccas --no-headers 2>/dev/null | grep -c "Running" || echo "0")
    echo "  CAs Running: $READY / 3 (attempt $i/60)"
    if [ "$READY" -ge 3 ]; then
        break
    fi
    sleep 5
done

echo_info "✅ CAs created"

# ------------------------------------------------
# Step 4: Register Identities
# ------------------------------------------------
echo ""
echo_info "Step 4: Registering identities..."

# AdminOrg peer
kubectl hlf ca register --name=ca-admin --user=peer --secret=peerpw --type=peer \
  --enroll-id enroll --enroll-secret=enrollpw --mspid AdminOrgMSP || echo_warn "Peer identity may already exist"

# StudentOrg peer
kubectl hlf ca register --name=ca-student --user=peer --secret=peerpw --type=peer \
  --enroll-id enroll --enroll-secret=enrollpw --mspid StudentOrgMSP || echo_warn "Peer identity may already exist"

# Orderer
kubectl hlf ca register --name=ca-orderer --user=orderer --secret=ordererpw --type=orderer \
  --enroll-id enroll --enroll-secret=enrollpw --mspid OrdererMSP || echo_warn "Orderer identity may already exist"

echo_info "✅ Identities registered"

# ------------------------------------------------
# Step 5: Create Peers (No Istio)
# ------------------------------------------------
echo ""
echo_info "Step 5: Creating Peers..."

# AdminOrg Peer - NO hosts, NO istio-port
echo_info "Creating peer for AdminOrg..."
kubectl hlf peer create --statedb=couchdb --image=$PEER_IMAGE --version=$PEER_VERSION \
  --storage-class=$SC_NAME --enroll-id=peer --mspid=AdminOrgMSP \
  --enroll-pw=peerpw --capacity=5Gi --name=peer0-admin --ca-name=ca-admin.default \
  || echo_warn "Peer admin may already exist"

# StudentOrg Peer
echo_info "Creating peer for StudentOrg..."
kubectl hlf peer create --statedb=couchdb --image=$PEER_IMAGE --version=$PEER_VERSION \
  --storage-class=$SC_NAME --enroll-id=peer --mspid=StudentOrgMSP \
  --enroll-pw=peerpw --capacity=5Gi --name=peer0-student --ca-name=ca-student.default \
  || echo_warn "Peer student may already exist"

echo_info "Waiting for peers to be ready..."
for i in {1..60}; do
    READY=$(kubectl get fabricpeers --no-headers 2>/dev/null | grep -c "Running" || echo "0")
    echo "  Peers Running: $READY / 2 (attempt $i/60)"
    if [ "$READY" -ge 2 ]; then
        break
    fi
    sleep 5
done

echo_info "✅ Peers created"

# ------------------------------------------------
# Step 6: Create Orderer (No Istio)
# ------------------------------------------------
echo ""
echo_info "Step 6: Creating Orderer..."

kubectl hlf ordnode create --image=$ORDERER_IMAGE --version=$ORDERER_VERSION \
  --storage-class=$SC_NAME --enroll-id=orderer --mspid=OrdererMSP \
  --enroll-pw=ordererpw --capacity=2Gi --name=orderer0 --ca-name=ca-orderer.default \
  || echo_warn "Orderer may already exist"

echo_info "Waiting for orderer to be ready..."
for i in {1..60}; do
    READY=$(kubectl get fabricorderernodes --no-headers 2>/dev/null | grep -c "Running" || echo "0")
    echo "  Orderers Running: $READY / 1 (attempt $i/60)"
    if [ "$READY" -ge 1 ]; then
        break
    fi
    sleep 5
done

echo_info "✅ Orderer created"

# ------------------------------------------------
# Step 7: Create Channel Identities
# ------------------------------------------------
echo ""
echo_info "Step 7: Creating channel admin identities..."

# OrdererMSP admin
kubectl hlf ca register --name=ca-orderer --user=admin --secret=adminpw \
  --type=admin --enroll-id enroll --enroll-secret=enrollpw --mspid=OrdererMSP || true

kubectl hlf ca enroll --name=ca-orderer --namespace=default \
  --user=admin --secret=adminpw --mspid OrdererMSP \
  --ca-name tlsca --output orderermsp.yaml || true

kubectl hlf ca enroll --name=ca-orderer --namespace=default \
  --user=admin --secret=adminpw --mspid OrdererMSP \
  --ca-name ca --output orderermspsign.yaml || true

# AdminOrgMSP admin
kubectl hlf ca register --name=ca-admin --user=admin --secret=adminpw \
  --type=admin --enroll-id enroll --enroll-secret=enrollpw --mspid=AdminOrgMSP || true

kubectl hlf ca enroll --name=ca-admin --namespace=default \
  --user=admin --secret=adminpw --mspid AdminOrgMSP \
  --ca-name ca --output adminorgmsp.yaml || true

kubectl hlf identity create --name adminorg-admin --namespace default \
  --ca-name ca-admin --ca-namespace default \
  --ca ca --mspid AdminOrgMSP --enroll-id admin --enroll-secret adminpw || true

# StudentOrgMSP admin
kubectl hlf ca register --name=ca-student --user=admin --secret=adminpw \
  --type=admin --enroll-id enroll --enroll-secret=enrollpw --mspid=StudentOrgMSP || true

kubectl hlf ca enroll --name=ca-student --namespace=default \
  --user=admin --secret=adminpw --mspid StudentOrgMSP \
  --ca-name ca --output studentorgmsp.yaml || true

kubectl hlf identity create --name studentorg-admin --namespace default \
  --ca-name ca-student --ca-namespace default \
  --ca ca --mspid StudentOrgMSP --enroll-id admin --enroll-secret adminpw || true

echo_info "✅ Channel identities created"

# ------------------------------------------------
# Step 8: Create Wallet Secret
# ------------------------------------------------
echo ""
echo_info "Step 8: Creating wallet secret..."

kubectl delete secret wallet --ignore-not-found

kubectl create secret generic wallet --namespace=default \
  --from-file=adminorgmsp.yaml=$PWD/adminorgmsp.yaml \
  --from-file=studentorgmsp.yaml=$PWD/studentorgmsp.yaml \
  --from-file=orderermsp.yaml=$PWD/orderermsp.yaml \
  --from-file=orderermspsign.yaml=$PWD/orderermspsign.yaml || true

echo_info "✅ Wallet secret created"

# ------------------------------------------------
# Step 9: Create Main Channel
# ------------------------------------------------
echo ""
echo_info "Step 9: Creating main channel..."

# Get orderer TLS cert
ORDERER_TLS_CERT=$(kubectl get fabricorderernodes orderer0 -o=jsonpath='{.status.tlsCert}' | sed -e "s/^/        /")

kubectl apply -f - <<EOF
apiVersion: hlf.kungfusoftware.es/v1alpha1
kind: FabricMainChannel
metadata:
  name: demo
spec:
  name: demo
  adminOrdererOrganizations:
    - mspID: OrdererMSP
  adminPeerOrganizations:
    - mspID: AdminOrgMSP
  channelConfig:
    application:
      capabilities:
        - V2_0
    capabilities:
      - V2_0
    orderer:
      batchSize:
        absoluteMaxBytes: 1048576
        maxMessageCount: 10
        preferredMaxBytes: 524288
      batchTimeout: 2s
      capabilities:
        - V2_0
      etcdRaft:
        options:
          electionTick: 10
          heartbeatTick: 1
          maxInflightBlocks: 5
          snapshotIntervalSize: 16777216
          tickInterval: 500ms
      ordererType: etcdraft
    state: STATE_NORMAL
  peerOrganizations:
    - mspID: AdminOrgMSP
      caName: "ca-admin"
      caNamespace: "default"
    - mspID: StudentOrgMSP
      caName: "ca-student"
      caNamespace: "default"
  identities:
    OrdererMSP:
      secretKey: orderermsp.yaml
      secretName: wallet
      secretNamespace: default
    OrdererMSP-sign:
      secretKey: orderermspsign.yaml
      secretName: wallet
      secretNamespace: default
    AdminOrgMSP:
      secretKey: adminorgmsp.yaml
      secretName: wallet
      secretNamespace: default
  ordererOrganizations:
    - caName: "ca-orderer"
      caNamespace: "default"
      externalOrderersToJoin:
        - host: orderer0.default
          port: 7053
      mspID: OrdererMSP
      ordererEndpoints:
        - orderer0.default:7050
      orderersToJoin: []
      orderers:
        - host: orderer0.default
          port: 7050
          tlsCert: |-
${ORDERER_TLS_CERT}
EOF

echo_info "✅ Main channel created"

# ------------------------------------------------
# Step 10: Join Peers to Channel
# ------------------------------------------------
echo ""
echo_info "Step 10: Joining peers to channel..."

ORDERER_TLS_CERT=$(kubectl get fabricorderernodes orderer0 -o=jsonpath='{.status.tlsCert}' | sed -e "s/^/        /")

# AdminOrg peer join
kubectl apply -f - <<EOF
apiVersion: hlf.kungfusoftware.es/v1alpha1
kind: FabricFollowerChannel
metadata:
  name: demo-adminorg
spec:
  anchorPeers:
    - host: peer0-admin.default
      port: 7051
  hlfIdentity:
    secretKey: adminorgmsp.yaml
    secretName: wallet
    secretNamespace: default
  mspId: AdminOrgMSP
  name: demo
  externalPeersToJoin: []
  orderers:
    - certificate: |
${ORDERER_TLS_CERT}
      url: grpcs://orderer0.default:7050
  peersToJoin:
    - name: peer0-admin
      namespace: default
EOF

# StudentOrg peer join
kubectl apply -f - <<EOF
apiVersion: hlf.kungfusoftware.es/v1alpha1
kind: FabricFollowerChannel
metadata:
  name: demo-studentorg
spec:
  anchorPeers:
    - host: peer0-student.default
      port: 7051
  hlfIdentity:
    secretKey: studentorgmsp.yaml
    secretName: wallet
    secretNamespace: default
  mspId: StudentOrgMSP
  name: demo
  externalPeersToJoin: []
  orderers:
    - certificate: |
${ORDERER_TLS_CERT}
      url: grpcs://orderer0.default:7050
  peersToJoin:
    - name: peer0-student
      namespace: default
EOF

echo_info "✅ Peers joined to channel"

# ------------------------------------------------
# Summary
# ------------------------------------------------
echo ""
echo "=============================================="
echo "Deployment Complete!"
echo "=============================================="
echo ""
echo "Resources:"
kubectl get fabriccas
echo ""
kubectl get fabricpeers
echo ""
kubectl get fabricorderernodes
echo ""
kubectl get fabricmainchannels
echo ""
kubectl get fabricfollowerchannels
echo ""
echo "Pods:"
kubectl get pods
echo ""
echo "=============================================="
