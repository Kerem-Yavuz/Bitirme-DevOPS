# Hyperledger Fabric Network - Bevel Operator Deployment

Bu proje, Hyperledger Fabric ağını Kubernetes üzerinde Bevel Operator (HLF-Operator) kullanarak deploy eder.

## Ağ Yapısı

```
┌─────────────────────────────────────────────────────────────────┐
│                    Hyperledger Fabric Network                    │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌───────────────┐  ┌───────────────┐  ┌───────────────┐        │
│  │   ca-admin    │  │  ca-student   │  │  ca-orderer   │        │
│  │  (AdminOrg)   │  │ (StudentOrg)  │  │  (Orderer)    │        │
│  └───────────────┘  └───────────────┘  └───────────────┘        │
│                                                                  │
│  ┌───────────────┐  ┌───────────────┐  ┌───────────────┐        │
│  │  peer0-admin  │  │ peer0-student │  │   orderer0    │        │
│  │  (AdminOrg)   │  │ (StudentOrg)  │  │  (Orderer)    │        │
│  │  + CouchDB    │  │  + CouchDB    │  │               │        │
│  └───────────────┘  └───────────────┘  └───────────────┘        │
│                                                                  │
│  ┌──────────────────────────────────────────────────────┐       │
│  │                  Channel: demo                        │       │
│  │   Members: AdminOrgMSP, StudentOrgMSP, OrdererMSP    │       │
│  └──────────────────────────────────────────────────────┘       │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

## Ön Gereksinimler

### 1. Kubernetes Cluster
- K3D veya K3s cluster çalışıyor olmalı
- `kubectl` ile erişim sağlanmış olmalı

### 2. Helm v3
```bash
# Helm kurulumu (Linux)
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
```

### 3. kubectl-hlf Plugin
```bash
# Önce Krew kur
(
  set -x; cd "$(mktemp -d)" &&
  OS="$(uname | tr '[:upper:]' '[:lower:]')" &&
  ARCH="$(uname -m | sed -e 's/x86_64/amd64/' -e 's/\(arm\)\(64\)\?.*/\1\2/' -e 's/aarch64$/arm64/')" &&
  KREW="krew-${OS}_${ARCH}" &&
  curl -fsSLO "https://github.com/kubernetes-sigs/krew/releases/latest/download/${KREW}.tar.gz" &&
  tar zxvf "${KREW}.tar.gz" &&
  ./"${KREW}" install krew
)

# PATH'e ekle (.bashrc veya .zshrc'ye de ekle)
export PATH="${KREW_ROOT:-$HOME/.krew}/bin:$PATH"

# hlf plugin kur
kubectl krew install hlf

# Doğrula
kubectl hlf version
```

### 4. Istio
```bash
# Istio binary indir
curl -L https://istio.io/downloadIstio | ISTIO_VERSION=1.23.3 sh -

# PATH'e ekle
export PATH="$PWD/istio-1.23.3/bin:$PATH"

# Doğrula
istioctl version
```

## Hızlı Başlangıç

### 1. Mevcut kaynakları temizle (opsiyonel)
```bash
kubectl delete fabricfollowerchannels --all
kubectl delete fabricmainchannels --all
kubectl delete fabricorderernodes --all
kubectl delete fabricpeers --all
kubectl delete fabriccas --all
kubectl delete secret wallet --ignore-not-found
```

### 2. Deploy script'i çalıştır
```bash
chmod +x deploy.sh
./deploy.sh
```

## Manuel Deployment

Eğer script yerine manuel deployment yapmak isterseniz, sırasıyla şu komutları çalıştırın:

### 1. HLF Operator Kurulumu
```bash
helm repo add kfs https://kfsoftware.github.io/hlf-helm-charts --force-update
helm install hlf-operator --version=1.13.0 kfs/hlf-operator
```

### 2. Istio Kurulumu
```bash
kubectl create namespace istio-system
istioctl operator init
kubectl apply -f istio-operator.yaml  # Aşağıdaki YAML'ı kullan
```

### 3. CoreDNS Yapılandırması
```bash
kubectl apply -f coredns-config.yaml  # Aşağıdaki YAML'ı kullan
kubectl rollout restart deployment coredns -n kube-system
```

### 4. CA'ları Oluştur
```bash
export CA_IMAGE=hyperledger/fabric-ca
export CA_VERSION=1.5.6
export SC_NAME=local-path

kubectl hlf ca create --image=$CA_IMAGE --version=$CA_VERSION \
  --storage-class=$SC_NAME --capacity=1Gi \
  --name=ca-admin --enroll-id=enroll --enroll-pw=enrollpw \
  --hosts=ca-admin.localho.st --istio-port=443

kubectl hlf ca create --image=$CA_IMAGE --version=$CA_VERSION \
  --storage-class=$SC_NAME --capacity=1Gi \
  --name=ca-student --enroll-id=enroll --enroll-pw=enrollpw \
  --hosts=ca-student.localho.st --istio-port=443

kubectl hlf ca create --image=$CA_IMAGE --version=$CA_VERSION \
  --storage-class=$SC_NAME --capacity=1Gi \
  --name=ca-orderer --enroll-id=enroll --enroll-pw=enrollpw \
  --hosts=ca-orderer.localho.st --istio-port=443

kubectl wait --timeout=300s --for=condition=Running fabriccas --all
```

### 5. Identity Registration
```bash
kubectl hlf ca register --name=ca-admin --user=peer --secret=peerpw --type=peer \
  --enroll-id enroll --enroll-secret=enrollpw --mspid AdminOrgMSP

kubectl hlf ca register --name=ca-student --user=peer --secret=peerpw --type=peer \
  --enroll-id enroll --enroll-secret=enrollpw --mspid StudentOrgMSP

kubectl hlf ca register --name=ca-orderer --user=orderer --secret=ordererpw --type=orderer \
  --enroll-id enroll --enroll-secret=enrollpw --mspid OrdererMSP
```

### 6. Peer ve Orderer Oluştur
```bash
export PEER_IMAGE=hyperledger/fabric-peer
export PEER_VERSION=2.5.0
export ORDERER_IMAGE=hyperledger/fabric-orderer
export ORDERER_VERSION=2.5.0

kubectl hlf peer create --statedb=couchdb --image=$PEER_IMAGE --version=$PEER_VERSION \
  --storage-class=$SC_NAME --enroll-id=peer --mspid=AdminOrgMSP \
  --enroll-pw=peerpw --capacity=5Gi --name=peer0-admin --ca-name=ca-admin.default \
  --hosts=peer0-admin.localho.st --istio-port=443

kubectl hlf peer create --statedb=couchdb --image=$PEER_IMAGE --version=$PEER_VERSION \
  --storage-class=$SC_NAME --enroll-id=peer --mspid=StudentOrgMSP \
  --enroll-pw=peerpw --capacity=5Gi --name=peer0-student --ca-name=ca-student.default \
  --hosts=peer0-student.localho.st --istio-port=443

kubectl hlf ordnode create --image=$ORDERER_IMAGE --version=$ORDERER_VERSION \
  --storage-class=$SC_NAME --enroll-id=orderer --mspid=OrdererMSP \
  --enroll-pw=ordererpw --capacity=2Gi --name=orderer0 --ca-name=ca-orderer.default \
  --hosts=orderer0.localho.st --admin-hosts=admin-orderer0.localho.st --istio-port=443

kubectl wait --timeout=300s --for=condition=Running fabricpeers --all
kubectl wait --timeout=300s --for=condition=Running fabricorderernodes --all
```

## Doğrulama

```bash
# Tüm kaynakları listele
kubectl get fabriccas
kubectl get fabricpeers
kubectl get fabricorderernodes
kubectl get fabricmainchannels
kubectl get fabricfollowerchannels

# Pod durumlarını kontrol et
kubectl get pods

# Logları kontrol et
kubectl logs -l app=ca-admin
kubectl logs -l app=peer0-admin
```

## Sorun Giderme

### CA'lar başlamıyor
```bash
kubectl describe fabricca ca-admin
kubectl logs -l app=ca-admin
```

### Peer'lar FAILED durumunda
```bash
kubectl describe fabricpeer peer0-admin
kubectl logs -l app=peer0-admin
```

### x509 certificate error
Bu hata genellikle Istio veya CoreDNS yapılandırmasının eksik olduğunu gösterir. CoreDNS config'inin uygulandığından ve Istio ingress gateway'in çalıştığından emin olun:
```bash
kubectl get pods -n istio-system
kubectl get pods -n kube-system | grep coredns
```

## Temizlik

Tüm kaynakları silmek için:
```bash
# Fabric kaynakları
kubectl delete fabricfollowerchannels --all
kubectl delete fabricmainchannels --all
kubectl delete fabricorderernodes --all
kubectl delete fabricpeers --all
kubectl delete fabriccas --all

# Secret'lar
kubectl delete secret wallet --ignore-not-found
rm -f *.yaml

# HLF Operator
helm uninstall hlf-operator

# Istio
kubectl delete namespace istio-system
```

## Kaynaklar

- [HLF-Operator GitHub](https://github.com/hyperledger-bevel/bevel-operator-fabric)
- [HLF-Operator Documentation](https://hyperledger-bevel.readthedocs.io/)
- [Hyperledger Fabric Documentation](https://hyperledger-fabric.readthedocs.io/)
