#!/bin/bash
# =============================================================================
# Hyperledger Fabric Network Deployment - CRD Approach
# =============================================================================

set -e

NAMESPACE="fabric-bevel"
STORAGE_CLASS="local-path"

echo "=============================================="
echo "Hyperledger Fabric Network Deployment"
echo "=============================================="

# ------------------------------------------------
# Step 1: Install HLF Operator
# ------------------------------------------------
echo ""
echo "Step 1: Installing HLF Operator..."

# First install CRDs from GitHub
echo "Installing CRDs..."
kubectl apply -f https://github.com/hyperledger-bevel/bevel-operator-fabric/releases/download/v1.11.0/hlf-operator-crds.yaml 2>/dev/null || \
kubectl apply -f https://raw.githubusercontent.com/hyperledger-bevel/bevel-operator-fabric/main/config/crd/bases/ 2>/dev/null || \
echo "CRDs may already exist or will be installed with Helm"

helm repo add kfs https://kfsoftware.github.io/hlf-helm-charts --force-update

if helm list -n hlf-operator-system 2>/dev/null | grep -q hlf-operator; then
    echo "Upgrading operator..."
    helm upgrade hlf-operator kfs/hlf-operator -n hlf-operator-system --wait
else
    echo "Installing operator..."
    helm install hlf-operator kfs/hlf-operator -n hlf-operator-system --create-namespace --wait
fi

echo "Waiting for operator deployment..."
kubectl wait --for=condition=available --timeout=180s deployment -l app.kubernetes.io/name=hlf-operator -n hlf-operator-system || true
sleep 30

echo "Waiting for CRDs to be registered..."
for i in {1..60}; do
    if kubectl get crd fabriccas.hlf.kungfusoftware.es &>/dev/null; then
        echo "✅ CRDs registered"
        break
    fi
    echo "Waiting for CRDs... ($i/60)"
    sleep 5
done

# Verify CRDs
echo "Installed CRDs:"
kubectl get crd | grep hlf || { echo "❌ No HLF CRDs found!"; exit 1; }
echo "✅ Operator and CRDs ready"

# ------------------------------------------------
# Step 2: Create Namespace
# ------------------------------------------------
echo ""
echo "Step 2: Creating namespace..."
kubectl create namespace $NAMESPACE --dry-run=client -o yaml | kubectl apply -f -
echo "✅ Namespace ready"

# ------------------------------------------------
# Step 3: Deploy CAs via CRDs
# ------------------------------------------------
echo ""
echo "Step 3: Deploying Certificate Authorities..."

# CA OrdererOrg
cat <<EOF | kubectl apply -f -
apiVersion: hlf.kungfusoftware.es/v1alpha1
kind: FabricCA
metadata:
  name: ca-orderer
  namespace: $NAMESPACE
spec:
  image: hyperledger/fabric-ca
  version: 1.5.6
  debug: false
  hosts:
    - ca-orderer
    - ca-orderer.$NAMESPACE
    - ca-orderer.$NAMESPACE.svc.cluster.local
  service:
    type: ClusterIP
  storage:
    accessMode: ReadWriteOnce
    size: 2Gi
    storageClass: "$STORAGE_CLASS"
  resources:
    requests:
      cpu: 50m
      memory: 128Mi
    limits:
      cpu: 200m
      memory: 256Mi
  ca:
    name: ca
    bccsp:
      default: SW
      sw:
        hash: SHA2
        security: "256"
    cfg:
      affiliations:
        allowRemove: true
      identities:
        allowRemove: true
    crl:
      expiry: 24h
    csr:
      ca:
        expiry: 131400h
        pathLength: 0
      cn: ca
      hosts:
        - localhost
        - ca-orderer
      names:
        - C: TR
          L: Istanbul
          O: OrdererOrg
          OU: ""
          ST: ""
    intermediate:
      parentServer:
        caName: ""
        url: ""
    registry:
      identities:
        - name: admin
          pass: adminpw
          type: client
          affiliation: ""
          attrs:
            hf.Registrar.Roles: "*"
            hf.Registrar.DelegateRoles: "*"
            hf.Revoker: true
            hf.IntermediateCA: true
            hf.GenCRL: true
            hf.Registrar.Attributes: "*"
            hf.AffiliationMgr: true
      max_enrollments: -1
    subject:
      C: TR
      L: Istanbul
      O: OrdererOrg
      OU: ""
      ST: ""
      cn: ca
  tlsCA:
    name: tlsca
    bccsp:
      default: SW
      sw:
        hash: SHA2
        security: "256"
    cfg:
      affiliations:
        allowRemove: true
      identities:
        allowRemove: true
    crl:
      expiry: 24h
    csr:
      ca:
        expiry: 131400h
        pathLength: 0
      cn: tlsca
      hosts:
        - localhost
        - ca-orderer
      names:
        - C: TR
          L: Istanbul
          O: OrdererOrg
          OU: ""
          ST: ""
    intermediate:
      parentServer:
        caName: ""
        url: ""
    registry:
      identities:
        - name: admin
          pass: adminpw
          type: client
          affiliation: ""
          attrs:
            hf.Registrar.Roles: "*"
            hf.Registrar.DelegateRoles: "*"
            hf.Revoker: true
            hf.IntermediateCA: true
            hf.GenCRL: true
            hf.Registrar.Attributes: "*"
            hf.AffiliationMgr: true
      max_enrollments: -1
    subject:
      C: TR
      L: Istanbul
      O: OrdererOrg
      OU: ""
      ST: ""
      cn: tlsca
  rootCA:
    subject:
      C: TR
      L: Istanbul
      O: OrdererOrg
      OU: ""
      ST: ""
      cn: ca
  metrics:
    provider: prometheus
  db:
    type: sqlite3
    datasource: fabric-ca-server.db
  clrSizeLimit: 512000
  cors:
    enabled: false
    origins: []
EOF

# CA AdminOrg
cat <<EOF | kubectl apply -f -
apiVersion: hlf.kungfusoftware.es/v1alpha1
kind: FabricCA
metadata:
  name: ca-admin
  namespace: $NAMESPACE
spec:
  image: hyperledger/fabric-ca
  version: 1.5.6
  debug: false
  hosts:
    - ca-admin
    - ca-admin.$NAMESPACE
    - ca-admin.$NAMESPACE.svc.cluster.local
  service:
    type: ClusterIP
  storage:
    accessMode: ReadWriteOnce
    size: 2Gi
    storageClass: "$STORAGE_CLASS"
  resources:
    requests:
      cpu: 50m
      memory: 128Mi
    limits:
      cpu: 200m
      memory: 256Mi
  ca:
    name: ca
    bccsp:
      default: SW
      sw:
        hash: SHA2
        security: "256"
    cfg:
      affiliations:
        allowRemove: true
      identities:
        allowRemove: true
    crl:
      expiry: 24h
    csr:
      ca:
        expiry: 131400h
        pathLength: 0
      cn: ca
      hosts:
        - localhost
        - ca-admin
      names:
        - C: TR
          L: Istanbul
          O: AdminOrg
          OU: ""
          ST: ""
    intermediate:
      parentServer:
        caName: ""
        url: ""
    registry:
      identities:
        - name: admin
          pass: adminpw
          type: client
          affiliation: ""
          attrs:
            hf.Registrar.Roles: "*"
            hf.Registrar.DelegateRoles: "*"
            hf.Revoker: true
            hf.IntermediateCA: true
            hf.GenCRL: true
            hf.Registrar.Attributes: "*"
            hf.AffiliationMgr: true
      max_enrollments: -1
    subject:
      C: TR
      L: Istanbul
      O: AdminOrg
      OU: ""
      ST: ""
      cn: ca
  tlsCA:
    name: tlsca
    bccsp:
      default: SW
      sw:
        hash: SHA2
        security: "256"
    cfg:
      affiliations:
        allowRemove: true
      identities:
        allowRemove: true
    crl:
      expiry: 24h
    csr:
      ca:
        expiry: 131400h
        pathLength: 0
      cn: tlsca
      hosts:
        - localhost
        - ca-admin
      names:
        - C: TR
          L: Istanbul
          O: AdminOrg
          OU: ""
          ST: ""
    intermediate:
      parentServer:
        caName: ""
        url: ""
    registry:
      identities:
        - name: admin
          pass: adminpw
          type: client
          affiliation: ""
          attrs:
            hf.Registrar.Roles: "*"
            hf.Registrar.DelegateRoles: "*"
            hf.Revoker: true
            hf.IntermediateCA: true
            hf.GenCRL: true
            hf.Registrar.Attributes: "*"
            hf.AffiliationMgr: true
      max_enrollments: -1
    subject:
      C: TR
      L: Istanbul
      O: AdminOrg
      OU: ""
      ST: ""
      cn: tlsca
  rootCA:
    subject:
      C: TR
      L: Istanbul
      O: AdminOrg
      OU: ""
      ST: ""
      cn: ca
  metrics:
    provider: prometheus
  db:
    type: sqlite3
    datasource: fabric-ca-server.db
  clrSizeLimit: 512000
  cors:
    enabled: false
    origins: []
EOF

# CA StudentOrg
cat <<EOF | kubectl apply -f -
apiVersion: hlf.kungfusoftware.es/v1alpha1
kind: FabricCA
metadata:
  name: ca-student
  namespace: $NAMESPACE
spec:
  image: hyperledger/fabric-ca
  version: 1.5.6
  debug: false
  hosts:
    - ca-student
    - ca-student.$NAMESPACE
    - ca-student.$NAMESPACE.svc.cluster.local
  service:
    type: ClusterIP
  storage:
    accessMode: ReadWriteOnce
    size: 2Gi
    storageClass: "$STORAGE_CLASS"
  resources:
    requests:
      cpu: 50m
      memory: 128Mi
    limits:
      cpu: 200m
      memory: 256Mi
  ca:
    name: ca
    bccsp:
      default: SW
      sw:
        hash: SHA2
        security: "256"
    cfg:
      affiliations:
        allowRemove: true
      identities:
        allowRemove: true
    crl:
      expiry: 24h
    csr:
      ca:
        expiry: 131400h
        pathLength: 0
      cn: ca
      hosts:
        - localhost
        - ca-student
      names:
        - C: TR
          L: Istanbul
          O: StudentOrg
          OU: ""
          ST: ""
    intermediate:
      parentServer:
        caName: ""
        url: ""
    registry:
      identities:
        - name: admin
          pass: adminpw
          type: client
          affiliation: ""
          attrs:
            hf.Registrar.Roles: "*"
            hf.Registrar.DelegateRoles: "*"
            hf.Revoker: true
            hf.IntermediateCA: true
            hf.GenCRL: true
            hf.Registrar.Attributes: "*"
            hf.AffiliationMgr: true
      max_enrollments: -1
    subject:
      C: TR
      L: Istanbul
      O: StudentOrg
      OU: ""
      ST: ""
      cn: ca
  tlsCA:
    name: tlsca
    bccsp:
      default: SW
      sw:
        hash: SHA2
        security: "256"
    cfg:
      affiliations:
        allowRemove: true
      identities:
        allowRemove: true
    crl:
      expiry: 24h
    csr:
      ca:
        expiry: 131400h
        pathLength: 0
      cn: tlsca
      hosts:
        - localhost
        - ca-student
      names:
        - C: TR
          L: Istanbul
          O: StudentOrg
          OU: ""
          ST: ""
    intermediate:
      parentServer:
        caName: ""
        url: ""
    registry:
      identities:
        - name: admin
          pass: adminpw
          type: client
          affiliation: ""
          attrs:
            hf.Registrar.Roles: "*"
            hf.Registrar.DelegateRoles: "*"
            hf.Revoker: true
            hf.IntermediateCA: true
            hf.GenCRL: true
            hf.Registrar.Attributes: "*"
            hf.AffiliationMgr: true
      max_enrollments: -1
    subject:
      C: TR
      L: Istanbul
      O: StudentOrg
      OU: ""
      ST: ""
      cn: tlsca
  rootCA:
    subject:
      C: TR
      L: Istanbul
      O: StudentOrg
      OU: ""
      ST: ""
      cn: ca
  metrics:
    provider: prometheus
  db:
    type: sqlite3
    datasource: fabric-ca-server.db
  clrSizeLimit: 512000
  cors:
    enabled: false
    origins: []
EOF

echo "Waiting for CAs to be ready (this may take 2-3 minutes)..."
sleep 60
kubectl get pods -n $NAMESPACE
kubectl get fabriccas.hlf.kungfusoftware.es -n $NAMESPACE
echo "✅ CAs deployed"

# ------------------------------------------------
# Step 4: Wait for CAs to be Running
# ------------------------------------------------
echo ""
echo "Step 4: Waiting for CA pods to be running..."

# First check if operator created pods
sleep 30
echo "Checking operator logs..."
kubectl logs -n hlf-operator-system -l app.kubernetes.io/name=hlf-operator --tail=20 2>/dev/null || true

echo ""
echo "Checking FabricCA status..."
kubectl get fabriccas.hlf.kungfusoftware.es -n $NAMESPACE -o wide

echo ""
echo "Waiting for pods (max 5 minutes)..."
for i in {1..30}; do
    POD_COUNT=$(kubectl get pods -n $NAMESPACE --no-headers 2>/dev/null | wc -l | tr -d ' ')
    RUNNING_COUNT=$(kubectl get pods -n $NAMESPACE --no-headers 2>/dev/null | grep -c "Running" || true)
    
    # Default to 0 if empty
    POD_COUNT=${POD_COUNT:-0}
    RUNNING_COUNT=${RUNNING_COUNT:-0}
    
    echo "Pods: $RUNNING_COUNT running out of $POD_COUNT total"
    
    if [[ "$RUNNING_COUNT" =~ ^[0-9]+$ ]] && [ "$RUNNING_COUNT" -ge 3 ]; then
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

# Peer0 AdminOrg
cat <<EOF | kubectl apply -f -
apiVersion: hlf.kungfusoftware.es/v1alpha1
kind: FabricPeer
metadata:
  name: peer0-admin
  namespace: $NAMESPACE
spec:
  image: hyperledger/fabric-peer
  tag: 2.5.0
  mspID: AdminOrgMSP
  hosts: []
  service:
    type: ClusterIP
  storage:
    peer:
      accessMode: ReadWriteOnce
      size: 5Gi
      storageClass: "$STORAGE_CLASS"
    chaincode:
      accessMode: ReadWriteOnce
      size: 2Gi
      storageClass: "$STORAGE_CLASS"
    couchdb:
      accessMode: ReadWriteOnce
      size: 5Gi
      storageClass: "$STORAGE_CLASS"
  resources:
    peer:
      requests:
        cpu: 100m
        memory: 256Mi
      limits:
        cpu: 500m
        memory: 512Mi
    couchdb:
      requests:
        cpu: 100m
        memory: 256Mi
      limits:
        cpu: 500m
        memory: 512Mi
    chaincode:
      requests:
        cpu: 100m
        memory: 128Mi
      limits:
        cpu: 500m
        memory: 256Mi
  couchdb:
    user: couchdb
    password: couchdb
  stateDb: couchdb
  gossip:
    externalEndpoint: ""
    bootstrap: ""
    endpoint: ""
    useLeaderElection: true
    orgLeader: false
  logging:
    level: info
    peer: info
    cauthdsl: warning
    gossip: info
    grpc: error
    ledger: info
    msp: info
    policies: warning
  discovery:
    period: 60s
    touchPeriod: 60s
  externalChaincodeBuilder: true
  secret:
    enrollment:
      component:
        cahost: ca-admin.$NAMESPACE.svc.cluster.local
        caname: ca
        caport: 7054
        catls:
          cacert: ""
        enrollid: admin
        enrollsecret: adminpw
      tls:
        cahost: ca-admin.$NAMESPACE.svc.cluster.local
        caname: tlsca
        caport: 7054
        catls:
          cacert: ""
        enrollid: admin
        enrollsecret: adminpw
        csr:
          cn: peer0-admin
          hosts:
            - peer0-admin
            - peer0-admin.$NAMESPACE.svc.cluster.local
EOF

# Peer0 StudentOrg
cat <<EOF | kubectl apply -f -
apiVersion: hlf.kungfusoftware.es/v1alpha1
kind: FabricPeer
metadata:
  name: peer0-student
  namespace: $NAMESPACE
spec:
  image: hyperledger/fabric-peer
  tag: 2.5.0
  mspID: StudentOrgMSP
  hosts: []
  service:
    type: ClusterIP
  storage:
    peer:
      accessMode: ReadWriteOnce
      size: 5Gi
      storageClass: "$STORAGE_CLASS"
    chaincode:
      accessMode: ReadWriteOnce
      size: 2Gi
      storageClass: "$STORAGE_CLASS"
    couchdb:
      accessMode: ReadWriteOnce
      size: 5Gi
      storageClass: "$STORAGE_CLASS"
  resources:
    peer:
      requests:
        cpu: 100m
        memory: 256Mi
      limits:
        cpu: 500m
        memory: 512Mi
    couchdb:
      requests:
        cpu: 100m
        memory: 256Mi
      limits:
        cpu: 500m
        memory: 512Mi
    chaincode:
      requests:
        cpu: 100m
        memory: 128Mi
      limits:
        cpu: 500m
        memory: 256Mi
  couchdb:
    user: couchdb
    password: couchdb
  stateDb: couchdb
  gossip:
    externalEndpoint: ""
    bootstrap: ""
    endpoint: ""
    useLeaderElection: true
    orgLeader: false
  logging:
    level: info
    peer: info
    cauthdsl: warning
    gossip: info
    grpc: error
    ledger: info
    msp: info
    policies: warning
  discovery:
    period: 60s
    touchPeriod: 60s
  externalChaincodeBuilder: true
  secret:
    enrollment:
      component:
        cahost: ca-student.$NAMESPACE.svc.cluster.local
        caname: ca
        caport: 7054
        catls:
          cacert: ""
        enrollid: admin
        enrollsecret: adminpw
      tls:
        cahost: ca-student.$NAMESPACE.svc.cluster.local
        caname: tlsca
        caport: 7054
        catls:
          cacert: ""
        enrollid: admin
        enrollsecret: adminpw
        csr:
          cn: peer0-student
          hosts:
            - peer0-student
            - peer0-student.$NAMESPACE.svc.cluster.local
EOF

echo "Waiting for Peers..."
sleep 30
kubectl get fabricpeers.hlf.kungfusoftware.es -n $NAMESPACE
echo "✅ Peers deployed"

# ------------------------------------------------
# Step 6: Deploy Orderer
# ------------------------------------------------
echo ""
echo "Step 6: Deploying Orderer..."

cat <<EOF | kubectl apply -f -
apiVersion: hlf.kungfusoftware.es/v1alpha1
kind: FabricOrdererNode
metadata:
  name: orderer0
  namespace: $NAMESPACE
spec:
  image: hyperledger/fabric-orderer
  tag: 2.5.0
  mspID: OrdererOrgMSP
  hosts: []
  service:
    type: ClusterIP
  storage:
    accessMode: ReadWriteOnce
    size: 5Gi
    storageClass: "$STORAGE_CLASS"
  resources:
    requests:
      cpu: 100m
      memory: 256Mi
    limits:
      cpu: 500m
      memory: 512Mi
  genesis: ""
  secret:
    enrollment:
      component:
        cahost: ca-orderer.$NAMESPACE.svc.cluster.local
        caname: ca
        caport: 7054
        catls:
          cacert: ""
        enrollid: admin
        enrollsecret: adminpw
      tls:
        cahost: ca-orderer.$NAMESPACE.svc.cluster.local
        caname: tlsca
        caport: 7054
        catls:
          cacert: ""
        enrollid: admin
        enrollsecret: adminpw
        csr:
          cn: orderer0
          hosts:
            - orderer0
            - orderer0.$NAMESPACE.svc.cluster.local
EOF

echo "Waiting for Orderer..."
sleep 30
kubectl get fabricorderernodes.hlf.kungfusoftware.es -n $NAMESPACE
echo "✅ Orderer deployed"

# ------------------------------------------------
# Summary
# ------------------------------------------------
echo ""
echo "=============================================="
echo "✅ Deployment Complete!"
echo "=============================================="
echo ""
echo "All Resources:"
echo ""
echo "CAs:"
kubectl get fabriccas.hlf.kungfusoftware.es -n $NAMESPACE
echo ""
echo "Peers:"
kubectl get fabricpeers.hlf.kungfusoftware.es -n $NAMESPACE
echo ""
echo "Orderers:"
kubectl get fabricorderernodes.hlf.kungfusoftware.es -n $NAMESPACE
echo ""
echo "Pods:"
kubectl get pods -n $NAMESPACE
echo ""
echo "Next Steps:"
echo "1. Wait for all pods to be Running"
echo "2. Create channel"
echo "3. Deploy chaincode"
