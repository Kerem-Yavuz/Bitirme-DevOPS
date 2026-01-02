öncelikle ca serverlerımızı kuracağız tabi bundanda önce clusterımıza longhorn kurmalıyız ve longhorunun kurulu 
olup çalıştığı nodelara storage=longhorn label i atamalıyız daha sonra bu ca serverlarımız kurulduktan sonra 
önce pod-cli-ca yaml ı çalıştırıp o podun içine girip her 3 org için mspleri oluşturmalıyız
daha sonra pod-cli yaml ı çalıştırıp o pod içinde genesis.block dosyamızı oluşturmalıyız
daha sonra aynı pod içinde channelımızı oluşturmalıyız
ardından student org ve admin org için anchor peer oluşturmalıyız bu peerları arası gossip için önemli
şimdi pod-cli-ca ya geçip ca-orderer-org a bağlanıp orderer podu için bir kimlik alacağız
şimdi aynı pod içindeyken orderer node için tls sertifikalarıyla enroll olacağız

Artık orderer asıl deploymentını deploy edebiliriz


#Bazı Gerekli komutlar
## Admin Peer Kanala Sokma (fabric tools içinde)

```
export FABRIC_CFG_PATH=/etc/hyperledger/fabric
export CORE_PEER_LOCALMSPID="AdminOrgMSP"
export CORE_PEER_MSPCONFIGPATH=/crypto-config/organizations/peerOrganizations/AdminOrg.com/users/Admin@AdminOrg.com/msp
export CORE_PEER_ADDRESS=svc-admin-peer.fabric.svc.cluster.local:7051
export CORE_PEER_TLS_ROOTCERT_FILE=/crypto-config/organizations/peerOrganizations/AdminOrg.com/peers/peer0.AdminOrg.com/tls/ca.crt
export CORE_PEER_TLS_ENABLED=true

echo "--- AdminPeer Kanala Katılıyor... ---"
peer channel join -b /crypto-config/channel-artifacts/enrollchanell.block
```

## Student Peer Kanala Sokma (fabric tools içinde)

```
export CORE_PEER_LOCALMSPID="StudentOrgMSP"
export CORE_PEER_MSPCONFIGPATH=/crypto-config/organizations/peerOrganizations/StudentOrg.com/users/Admin@StudentOrg.com/msp
export CORE_PEER_ADDRESS=svc-student-peer.fabric.svc.cluster.local:7051
export CORE_PEER_TLS_ROOTCERT_FILE=/crypto-config/organizations/peerOrganizations/StudentOrg.com/peers/peer0.StudentOrg.com/tls/ca.crt

echo "--- StudentPeer Kanala Katılıyor... ---"
peer channel join -b /crypto-config/channel-artifacts/enrollchanell.block
```

## Chain kod onay

CC_PACKAGE_ID=chain code idsi bu onayda orgları ayrı ayrı envleriyle onaylayacak

```
peer lifecycle chaincode approveformyorg -o svc-orderer:7050 --ordererTLSHostnameOverride svc-orderer \
  --channelID $CHANNEL_NAME --name basic --version 1.0 --package-id $CC_PACKAGE_ID \
  --sequence 1 --tls --cafile $ORDERER_CA --connTimeout 30s
```

## Chain Kod Onay Kontrolü

```
peer lifecycle chaincode checkcommitreadiness --channelID $CHANNEL_NAME --name basic --version 1.0 --sequence 1 --tls --cafile $ORDERER_CA
```

## AdminOrg env variables

```
export FABRIC_CFG_PATH=/etc/hyperledger/fabric
export CORE_PEER_LOCALMSPID="AdminOrgMSP"
export CORE_PEER_MSPCONFIGPATH=/crypto-config/organizations/peerOrganizations/AdminOrg.com/users/Admin@AdminOrg.com/msp
export CORE_PEER_ADDRESS=svc-admin-peer.fabric.svc.cluster.local:7051
export CORE_PEER_TLS_ROOTCERT_FILE=/crypto-config/organizations/peerOrganizations/AdminOrg.com/peers/peer0.AdminOrg.com/tls/ca.crt
export CORE_PEER_TLS_ENABLED=true
export ORDERER_CA=/crypto-config/organizations/ordererOrganizations/OrdererOrg.com/orderers/orderer.OrdererOrg.com/tls/tlscacerts/tls-svc-ca-orderer-org-7054.pem
```

## StudentOrg env variables
```
export FABRIC_CFG_PATH=/etc/hyperledger/fabric
export CORE_PEER_LOCALMSPID="StudentOrgMSP"
export CORE_PEER_MSPCONFIGPATH=/crypto-config/organizations/peerOrganizations/StudentOrg.com/users/Admin@StudentOrg.com/msp
export CORE_PEER_ADDRESS=svc-student-peer.fabric.svc.cluster.local:7051
export CORE_PEER_TLS_ROOTCERT_FILE=/crypto-config/organizations/peerOrganizations/StudentOrg.com/peers/peer0.StudentOrg.com/tls/ca.crt
export CORE_PEER_TLS_ENABLED=true
export ORDERER_CA=/crypto-config/organizations/ordererOrganizations/OrdererOrg.com/orderers/orderer.OrdererOrg.com/tls/tlscacerts/tls-svc-ca-orderer-org-7054.pem
```


## Channel Create and join
Should be in adminOrg:
```
peer channel create -o svc-orderer:7050 -c $CHANNEL_NAME -f /crypto-config/channel-artifacts/${CHANNEL_NAME}.tx --outputBlock /crypto-config/channel-artifacts/${CHANNEL_NAME}.block --tls --cafile $ORDERER_CA
```
## Commit
```
peer lifecycle chaincode commit \
  -o svc-orderer:7050 \
  --ordererTLSHostnameOverride svc-orderer \
  --channelID $CHANNEL_NAME \
  --name basic \
  --version 1.0 \
  --sequence 1 \
  --tls \
  --cafile $ORDERER_CA \
  --peerAddresses svc-admin-peer.fabric.svc.cluster.local:7051 --tlsRootCertFiles /crypto-config/organizations/peerOrganizations/AdminOrg.com/peers/peer0.AdminOrg.com/tls/ca.crt \
  --peerAddresses svc-student-peer.fabric.svc.cluster.local:7051 --tlsRootCertFiles /crypto-config/organizations/peerOrganizations/StudentOrg.com/peers/peer0.StudentOrg.com/tls/ca.crt \
  --connTimeout 30s
```
## Invoke
Should be in adminORG:
```
peer chaincode invoke \
  -o svc-orderer:7050 \
  --ordererTLSHostnameOverride svc-orderer \
  --tls \
  --cafile $ORDERER_CA \
  -C $CHANNEL_NAME \
  -n basic \
  --peerAddresses svc-admin-peer.fabric.svc.cluster.local:7051 --tlsRootCertFiles /crypto-config/organizations/peerOrganizations/AdminOrg.com/peers/peer0.AdminOrg.com/tls/ca.crt \
  --peerAddresses svc-student-peer.fabric.svc.cluster.local:7051 --tlsRootCertFiles /crypto-config/organizations/peerOrganizations/StudentOrg.com/peers/peer0.StudentOrg.com/tls/ca.crt \
  -c '{"function":"CreateAsset","Args":["asset100","kirmizi","ahmet"]}'
```

