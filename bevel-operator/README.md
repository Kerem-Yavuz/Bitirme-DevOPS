# Hyperledger Fabric Deployment with Bevel-Operator-Fabric

Bu klasör, Bevel-Operator-Fabric kullanarak Hyperledger Fabric ağını Kubernetes üzerine otomatik olarak deploy etmek için gerekli tüm dosyaları içerir.

## Ağ Yapısı

| Organizasyon | MSP ID | Bileşen |
|--------------|--------|---------|
| OrdererOrg | OrdererOrgMSP | 1 Orderer (Raft) |
| AdminOrg | AdminOrgMSP | 1 Peer + CouchDB |
| StudentOrg | StudentOrgMSP | 1 Peer + CouchDB |

**Kanal:** `enrollchannel`

## Kurulum Adımları

### 1. Operator Kurulumu

```bash
# Bevel Operator'ı kur
kubectl apply -f https://github.com/hyperledger-bevel/bevel-operator-fabric/releases/latest/download/install.yaml

# Operator'ın çalıştığını kontrol et
kubectl get pods -n hlf-operator-system
```

### 2. Kubectl HLF Plugin Kurulumu (Opsiyonel ama Önerilen)

```bash
# Krew yoksa kur
# https://krew.sigs.k8s.io/docs/user-guide/setup/install/

# HLF plugin'i kur
kubectl krew install hlf
```

### 3. Namespace Oluştur

```bash
kubectl create namespace fabric-bevel
```

### 4. Bileşenleri Sırayla Deploy Et

```bash
# 1. CA'ları deploy et
kubectl apply -f 01-cas/

# CA'ların hazır olmasını bekle (1-2 dakika)
kubectl get pods -n fabric-bevel -w

# 2. Peer'ları deploy et (CA'lar hazır olduktan sonra)
kubectl apply -f 02-peers/

# 3. Orderer'ı deploy et
kubectl apply -f 03-orderers/

# 4. Kanalı oluştur
kubectl apply -f 04-channels/
```

### 5. Chaincode Deploy Et

External chaincode deploy etmek için:

```bash
kubectl apply -f 05-chaincode/
```

## Dosya Yapısı

```
bevel-operator/
├── README.md                 # Bu dosya
├── 01-cas/                   # Certificate Authority tanımları
│   ├── ca-orderer.yaml
│   ├── ca-admin.yaml
│   └── ca-student.yaml
├── 02-peers/                 # Peer tanımları
│   ├── peer0-admin.yaml
│   └── peer0-student.yaml
├── 03-orderers/              # Orderer tanımları
│   └── orderer0.yaml
├── 04-channels/              # Kanal tanımları
│   └── enrollchannel.yaml
└── 05-chaincode/             # External chaincode
    └── chaincode-external.yaml
```

## Ağı Silmek

```bash
kubectl delete -f 05-chaincode/
kubectl delete -f 04-channels/
kubectl delete -f 03-orderers/
kubectl delete -f 02-peers/
kubectl delete -f 01-cas/
kubectl delete namespace fabric
```

## Sorun Giderme

```bash
# Pod durumlarını kontrol et
kubectl get pods -n fabric

# Pod loglarını gör
kubectl logs -n fabric <pod-name>

# CRD durumlarını kontrol et
kubectl get fabriccas,fabricpeers,fabricorderers -n fabric
```
