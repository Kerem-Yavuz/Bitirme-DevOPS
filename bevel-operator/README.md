# Hyperledger Fabric - Bevel Operator Deployment

Production-ready Hyperledger Fabric network deployment using Bevel Operator on Kubernetes.

## Prerequisites

- Kubernetes cluster (k3s, minikube, kind, etc.)
- kubectl configured
- Helm 3.x
- Storage class available (default: `local-path`)

## Quick Start

```bash
# Make script executable
chmod +x deploy.sh

# Run deployment
./deploy.sh
```

The script will automatically:
1. Install Helm (if missing)
2. Install kubectl-hlf CLI plugin
3. Deploy HLF Operator
4. Create Certificate Authorities (OrdererOrg, AdminOrg, StudentOrg)
5. Register identities
6. Deploy Peers with CouchDB
7. Deploy Orderer (Raft)
8. Create and join channel

## Network Topology

```
┌─────────────────────────────────────────────────────────────┐
│                        Kubernetes                           │
├─────────────────────────────────────────────────────────────┤
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐         │
│  │ ca-orderer  │  │  ca-admin   │  │ ca-student  │         │
│  │   (CA)      │  │    (CA)     │  │    (CA)     │         │
│  └─────────────┘  └─────────────┘  └─────────────┘         │
│                                                             │
│  ┌─────────────┐  ┌─────────────┐                          │
│  │ peer0-admin │  │peer0-student│                          │
│  │  (CouchDB)  │  │  (CouchDB)  │                          │
│  └─────────────┘  └─────────────┘                          │
│                                                             │
│  ┌─────────────┐                                           │
│  │   orderer   │   Channel: enrollchannel                  │
│  │   (Raft)    │                                           │
│  └─────────────┘                                           │
└─────────────────────────────────────────────────────────────┘
```

## Organizations

| Organization | MSP ID         | Components          |
|-------------|----------------|---------------------|
| OrdererOrg  | OrdererOrgMSP  | ca-orderer, orderer |
| AdminOrg    | AdminOrgMSP    | ca-admin, peer0-admin |
| StudentOrg  | StudentOrgMSP  | ca-student, peer0-student |

## Chaincode Deployment

After network deployment:

```bash
# 1. Package your chaincode
kubectl hlf chaincode package --name=enrollment --version=1.0 --lang=golang --path=./chaincode

# 2. Install on peers
kubectl hlf chaincode install --peer=peer0-admin.fabric-bevel --package=enrollment-1.0.tar.gz
kubectl hlf chaincode install --peer=peer0-student.fabric-bevel --package=enrollment-1.0.tar.gz

# 3. Approve and commit
kubectl hlf chaincode approveformyorg --peer=peer0-admin.fabric-bevel --channel=enrollchannel --name=enrollment --version=1.0 --sequence=1
kubectl hlf chaincode commit --peer=peer0-admin.fabric-bevel --channel=enrollchannel --name=enrollment --version=1.0 --sequence=1
```

## External Chaincode

For external chaincode (running outside Kubernetes):

```bash
kubectl apply -f 05-chaincode/chaincode-external.yaml
```

## Useful Commands

```bash
# Check components
kubectl get pods -n fabric-bevel
kubectl get fabricca,fabricpeer,fabricorderingservice -n fabric-bevel

# View CA logs
kubectl logs -n fabric-bevel -l app=ca-admin

# View peer logs
kubectl logs -n fabric-bevel -l app=peer0-admin

# Cleanup
helm uninstall hlf-operator -n hlf-operator-system
kubectl delete namespace fabric-bevel
```

## Troubleshooting

**Storage issues:**
```bash
# Check PVCs
kubectl get pvc -n fabric-bevel
```

**CA not ready:**
```bash
# Check CA status
kubectl describe fabricca ca-admin -n fabric-bevel
```

**Peer enrollment failed:**
```bash
# Check if identity is registered
kubectl hlf ca identity list --name=ca-admin --namespace=fabric-bevel
```
