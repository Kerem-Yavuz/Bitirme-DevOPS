öncelikle ca serverlerımızı kuracağız tabi bundanda önce clusterımıza longhorn kurmalıyız ve longhorunun kurulu 
olup çalıştığı nodelara storage=longhorn label i atamalıyız daha sonra bu ca serverlarımız kurulduktan sonra 
önce pod-cli-ca yaml ı çalıştırıp o podun içine girip her 3 org için mspleri oluşturmalıyız
daha sonra pod-cli yaml ı çalıştırıp o pod içinde genesis.block dosyamızı oluşturmalıyız
daha sonra aynı pod içinde channelımızı oluşturmalıyız
ardından student org ve admin org için anchor peer oluşturmalıyız bu peerları arası gossip için önemli
şimdi pod-cli-ca ya geçip ca-orderer-org a bağlanıp orderer podu için bir kimlik alacağız
şimdi aynı pod içindeyken orderer node için tls sertifikalarıyla enroll olacağız

Artık orderer asıl deploymentını deploy edebiliriz
