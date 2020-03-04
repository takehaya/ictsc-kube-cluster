# k8s setup
* required
    * terraform(0.12.5 <= x)
    * ansible(2.8.3 <= x)
    * terraform-provider-sakuracloud(1.15.2 <= x)
    * direnv
    * pipenv & python3.7
hint: [Terraform for さくらのクラウド](https://sacloud.github.io/terraform-provider-sakuracloud/installation/)
## claster setup
* 全て実行はこのカレントディレクトリで行ってください
* 事前準備
    * `.envrc` にさくらのクラウドのアクセストークンとシークレットとゾーンを書く。 `.envrc.sample` に例があるのでそこの `hoge` とかの変数をいい感じに埋めよう
    * 埋めたら `direnv allow` で適用される。このカレントディレクトリでその環境変数が適用される。
    * `var.yml`に ansibleで作成したいuserを書く。 `var.sample.yml` に例があるのでパスワードとかをいい感じに変えよう
    * `wget https://raw.githubusercontent.com/jetstack/cert-manager/release-0.9/deploy/manifests/00-crds.yaml` を `cluster_provisioning`のディレクトリでしておく

* `terraform workspace show` で今のステージングを確認しよう。
* `terraform workspace select dev` で devへ移動ができる
その環境において初めて使う場合は以下を叩いて環境を作っておく
* prd: 本番
* tra: トレーニング
* dev: 開発
* tmp: 監視などの多目的むけ

```
terraform workspace new prd
terraform workspace new dev
terraform workspace new tra
terraform workspace new tmp
```

* `terraform apply -auto-approve` をしてVMが上がるのを待とう。生成された `id_rsa` は `user:ubuntu` 向けに作られているものです
* `ssh-keygen  -f ~/.ssh/ictsc` でこの名前の鍵を作成
* `chmod +x inventry_handler.py`
* `ansible-playbook -u ubuntu --private-key=./id_rsa -i inventry_handler.py setup.yml --extra-vars "ansible_sudo_pass=PUT_YOUR_PASSWORD_HERE"` でAnsibleを実行して、ictsc user作成とdocker install, k8s installが行なわれる
    * これで`ssh -i ~/.ssh/ictsc ictsc@xxx.xxx.xxx.xxx` みたいな感じでログインできるようになります。
    * `scp -i ~/.ssh/ictsc ~/.ssh/ictsc ictsc@master1_ip:/home/ictsc` でmaster1に鍵も送っておきましょう

## LBの構築
* haproxy.cfgの `# Grobal VIPのbind ip`を変更する
* `scp -i ~/.ssh/ictsc ./haproxy.cfg ictsc@153.125.133.106:/home/ictsc`でLBたちに送りつける。同じように　`scp -i ~/.ssh/ictsc ./keepalived.conf ictsc@153.125.133.106:/home/ictsc`
* `keepalived.cfg` に masterにしたいほうを`priority`を大きくして `virtual_ipaddress` を書き換える。そしてmaster側を `state MASTER` する
  * vipを考える場合は terrform outputで未使用のアドレスリストを確認する
```
sudo su
echo "net.ipv4.ip_forward = 1" >> /etc/sysctl.conf
echo "net.ipv4.ip_nonlocal_bind = 1" >> /etc/sysctl.conf
sysctl -p

echo ENABLED=1 >> /etc/default/haproxy

# file move
mv haproxy.cfg /etc/haproxy/haproxy.cfg
mv keepalived.conf /etc/keepalived/keepalived.conf

# restart
systemctl restart haproxy 
systemctl restart keepalived
```

正常に立ち上がり、一つだけのサーバーにVIPが振られて（`ip a` とかで確認すべき）、VRRPが流れていて（`tcpdump -n vrrp` とかでみる）、最後にpingが任意のサーバーに届いてるか(`tcpdump -n icmp` とpingの結果で判断)をみてすべて問題ないなら問題ないと思われる。


## k8s クラスタの構築

以下のように `kubeadm-config.yaml` の中身がなっているので、書き換える。LBに降ったVIPを書く。
```
apiServer:
  certSANs:
  - Global VIP
controlPlaneEndpoint: "Global VIP:6443"
```

そしたら `scp -i ~/.ssh/ictsc kubeadm-config.yaml ictsc@master1_ip:/home/ictsc` で送りつけよう

* masterになるサーバーにログインして以下のコマンドを実行しよう
```shell
# master 1で実行する
sudo kubeadm init --config=kubeadm-config.yaml
```

そうすると以下のようなのが出てくるが、それをどこかに一旦コピーする。今回は便宜上数字を1~4まで振っている。
```
1. To start using your cluster, you need to run the following as a regular user:

  mkdir -p $HOME/.kube
  sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
  sudo chown $(id -u):$(id -g) $HOME/.kube/config

You should now deploy a pod network to the cluster.
2. Run "kubectl apply -f [podnetwork].yaml" with one of the options listed at:
  https://kubernetes.io/docs/concepts/cluster-administration/addons/

3. You can now join any number of control-plane nodes by copying certificate authorities 
and service account keys on each node and then running the following as root:

  kubeadm join (VIP):6443 --token oe7rzo.h5gxu1njkoctlb3a \
    --discovery-token-ca-cert-hash sha256:dcdd35707e6d0dac96ef368125c4a1cb028ab0e9473b10b156c8808ea7644b05 \
    --control-plane       

4. Then you can join any number of worker nodes by running the following on each as root:

kubeadm join (VIP):6443 --token oe7rzo.h5gxu1njkoctlb3a \
    --discovery-token-ca-cert-hash sha256:dcdd35707e6d0dac96ef368125c4a1cb028ab0e9473b10b156c8808ea7644b05 
```

まず、上部でいう **1** kubectlの利用する証明書をコピーしてkubectlを有効にする。

```shell
# master 1で,一般ユーザーで実行する
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

# rootになっておく
sudo su 

# master2, master3に証明書を送りつけておく。
HOST1=192.168.100.11
HOST2=192.168.100.12

USER=ictsc
CONTROL_PLANE_IPS="${HOST1} ${HOST2}"
for host in ${CONTROL_PLANE_IPS}; do
    scp -i ictsc /etc/kubernetes/pki/ca.crt "${USER}"@$host:
    scp -i ictsc /etc/kubernetes/pki/ca.key "${USER}"@$host:
    scp -i ictsc /etc/kubernetes/pki/sa.key "${USER}"@$host:
    scp -i ictsc /etc/kubernetes/pki/sa.pub "${USER}"@$host:
    scp -i ictsc /etc/kubernetes/pki/front-proxy-ca.crt "${USER}"@$host:
    scp -i ictsc /etc/kubernetes/pki/front-proxy-ca.key "${USER}"@$host:
    scp -i ictsc /etc/kubernetes/pki/etcd/ca.crt "${USER}"@$host:etcd-ca.crt
    scp -i ictsc /etc/kubernetes/pki/etcd/ca.key "${USER}"@$host:etcd-ca.key
    scp -i ictsc /etc/kubernetes/admin.conf "${USER}"@$host:
done
```

次に、**2**のCNIのインストールをする

```shell
# kubeadm init をしたmasterで行う
# apply flannel
kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml
``` 

その後 **3** の masterの追加をする。

```shell
# rootになっておく
sudo su 

# master2, master3になるやつでも同じように行う。
USER=ictsc
mkdir -p /etc/kubernetes/pki/etcd
mv /home/${USER}/ca.crt /etc/kubernetes/pki/
mv /home/${USER}/ca.key /etc/kubernetes/pki/
mv /home/${USER}/sa.pub /etc/kubernetes/pki/
mv /home/${USER}/sa.key /etc/kubernetes/pki/
mv /home/${USER}/front-proxy-ca.crt /etc/kubernetes/pki/
mv /home/${USER}/front-proxy-ca.key /etc/kubernetes/pki/
mv /home/${USER}/etcd-ca.crt /etc/kubernetes/pki/etcd/ca.crt
mv /home/${USER}/etcd-ca.key /etc/kubernetes/pki/etcd/ca.key
mv /home/${USER}/admin.conf /etc/kubernetes/admin.conf

kubeadm join (VIP) --token oe7rzo.h5gxu1njkoctlb3a \
  --discovery-token-ca-cert-hash sha256:dcdd35707e6d0dac96ef368125c4a1cb028ab0e9473b10b156c8808ea7644b05 \
  --control-plane

# master2, master3の一般ユーザーで実行する
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
```

最後に **4** の nodeの追加をする。

```shell

# node1~3を追加
kubeadm join (VIP) --token oe7rzo.h5gxu1njkoctlb3a \
    --discovery-token-ca-cert-hash sha256:dcdd35707e6d0dac96ef368125c4a1cb028ab0e9473b10b156c8808ea7644b05 

# master1で実行。node labelがつく
kubectl label node k8s-node-1-server-dev node-role.kubernetes.io/node=
kubectl label node k8s-node-2-server-dev node-role.kubernetes.io/node=
kubectl label node k8s-node-3-server-dev node-role.kubernetes.io/node=
```

## MetalLBの導入をする
BGPを使いたいが、今回はさくらクラウドなので、、、グローバルアドレスをBGPで流すことができない。ということでL2modeで利用する.まず、 terrform outputなどで全てのグローバルIPレンジを見れるのでそれで利用可能なアドレスを確認する。それをもとに `metallb-config.yaml` のアドレスレンジを書き換える。
その後

``` shell
scp -i ~/.ssh/ictsc metallb-config.yaml ictsc@master1_ip:/home/ictsc
```

```shell
# install
kubectl apply -f https://raw.githubusercontent.com/google/metallb/v0.8.3/manifests/metallb.yaml

# configure
kubectl apply -f metallb-config.yaml
```

これの確認としては `https://raw.githubusercontent.com/danderson/metallb/main/manifests/tutorial-2.yaml` を実行してみることです。これを使うとTypeLBでnginxが立ち上がります。（自分が試した場合はapiVersionが合わないので `apiVersion: apps/v1`としました）
以下のように EXTERNAL-IPがついて、グローバルアドレスを割り振ることができ、アクセスができます。 確認後は `kubectl delete -f <file.yaml>` をして削除しましょう。
```shell
ictsc@k8s-master-1-server-dev:~$ kubectl get po,svc
NAME                         READY   STATUS    RESTARTS   AGE
pod/nginx-5f78746595-d24tk   1/1     Running   0          14s

NAME                 TYPE           CLUSTER-IP       EXTERNAL-IP      PORT(S)        AGE
service/kubernetes   ClusterIP      10.96.0.1        <none>           443/TCP        86m
service/nginx        LoadBalancer   10.109.185.152   153.125.134.45   80:31269/TCP   14s
```

## rook(+cephfs)の導入
```
# master1
git clone https://github.com/rook/rook
cd rook
git checkout -b release-1.2 origin/release-1.2
cd cluster/examples/kubernetes/ceph
kubectl create -f common.yaml
kubectl create -f operator.yaml
```

以下を書き換える
```
ictsc@k8s-master-1-server-prd:~/rook$ git diff
diff --git a/cluster/examples/kubernetes/ceph/cluster.yaml b/cluster/examples/kubernetes/ceph/cluster.yaml
index 26801570..9c95bc89 100644
--- a/cluster/examples/kubernetes/ceph/cluster.yaml
+++ b/cluster/examples/kubernetes/ceph/cluster.yaml
@@ -41,13 +41,13 @@ spec:
   # set the amount of mons to be started
   mon:
     count: 3
-    allowMultiplePerNode: false
-  # mgr:
-    # modules:
+    allowMultiplePerNode: true 
+  mgr:
+    modules:
     # Several modules should not need to be included in this list. The "dashboard" and "monitoring" modules
     # are already enabled by other settings in the cluster CR and the "rook" module is always enabled.
-    # - name: pg_autoscaler
-    #   enabled: true
+    - name: pg_autoscaler
+      enabled: true
   # enable the ceph dashboard for viewing cluster status
   dashboard:
     enabled: true
@@ -56,7 +56,7 @@ spec:
     # serve the dashboard at the given port.
     # port: 8443
     # serve the dashboard using SSL
-    ssl: true
+    ssl: false 
   # enable prometheus alerting for cluster
   monitoring:
     # requires Prometheus to be pre-installed
@@ -137,15 +137,15 @@ spec:
     config:
       # The default and recommended storeType is dynamically set to bluestore for devices and filestore for directories.
       # Set the storeType explicitly only if it is required not to use the default.
-      # storeType: bluestore
+      storeType: filestore
       # metadataDevice: "md0" # specify a non-rotational storage so ceph-volume will use it as block db device of bluestore.
       # databaseSizeMB: "1024" # uncomment if the disks are smaller than 100 GB
       # journalSizeMB: "1024"  # uncomment if the disks are 20 GB or smaller
       # osdsPerDevice: "1" # this value can be overridden at the node or device level
       # encryptedDevice: "true" # the default value for this option is "false"
 # Cluster level list of directories to use for filestore-based OSD storage. If uncomment, this example would create an OSD under the dataDirHostPath.
-    #directories:
-    #- path: /var/lib/rook
+    directories:
+    - path: /var/lib/rook
diff --git a/cluster/examples/kubernetes/ceph/csi/cephfs/storageclass.yaml b/cluster/examples/kubernetes/ceph/csi/cephfs/storageclass.yaml
index 5299dfed..63a3d7df 100644
--- a/cluster/examples/kubernetes/ceph/csi/cephfs/storageclass.yaml
+++ b/cluster/examples/kubernetes/ceph/csi/cephfs/storageclass.yaml
@@ -31,7 +31,7 @@ parameters:
   # If omitted, default volume mounter will be used - this is determined by probing for ceph-fuse
   # or by setting the default mounter explicitly via --volumemounter command-line argument.
   # mounter: kernel
-reclaimPolicy: Delete
+reclaimPolicy: Retain 
 allowVolumeExpansion: true
 mountOptions:
   # uncomment the following line for debugging
```


```
# 書きかえた後実行
kubectl create -f cluster.yaml

# これで落ち着くまで少し待つ。1mぐらいで落ち着きそう
kubectl -n rook-ceph get pod

# 予め `./cluster_provisioning/took_test/toolbox.yaml` を持ってきておく
kubectl apply -f toolbox.yaml

# ceph statusで確認する
kubectl -n rook-ceph exec -it $(kubectl -n rook-ceph get pod -l "app=rook-ceph-tools" -o jsonpath='{.items[0].metadata.name}') ceph status
```

以下のようになっていれば良さそうです `HEALTH_OK`, `HEALTH_WARN` の場合もありますが、ちゃんと動いていれば問題ないです
```
  cluster:
    id:     f187d5aa-9b68-4058-af16-a7be5a7e2c3e
    health: HEALTH_OK
 
  services:
    mon: 3 daemons, quorum a,b,c (age 12m)
    mgr: a(active, since 11m)
    osd: 3 osds: 3 up (since 11m), 3 in (since 11m)
 
  data:
    pools:   0 pools, 0 pgs
    objects: 0 objects, 0 B
    usage:   47 GiB used, 236 GiB / 283 GiB avail
    pgs:     
```

次にファイルシステムの適用を行います。
```
kubectl create -f filesystem.yaml
kubectl create -f csi/cephfs/storageclass.yaml
```

この挙動を確認するためには`./cluster_provisioning/took_test/nginx.yaml`手元のリポジトリから持ってきてそれで適用する。これは pvc,pvを追加しててこれを元にnginxのファイルをマウントします。この場合ファイルがないのでForbiddenになるはず。
試しにpodに対して`kubectl exec -it pod/nginx-deployment-b6d98bd65-9ttw9 bash`をして中で`echo -e "<a>hoge</a>" > /usr/share/nginx/html/index.html` をして後にブラウザでアクセスするとhogeのみが出てくると思います。




## application setup
* `env.yaml`を作り、各パラメーターを埋める。 `env.sample.yaml` にテンプレートがあるのでパスワードとかFQDNをいい感じに変えよう
  * 別途FQDNの設定は自分でよしなにしておく必要があります。
* `pipenv install` をしたあと `pipenv shell` でサブシェルに入って `python deploy_ready.py` を叩く。これで各パラメーターを入れたk8sのmanifestが出来上がる。
* ここのカレントディレクトリで `scp -i ~/.ssh/ictsc -r ./deploy_ready_output ictsc@xxx.xxx.xxx.xxx:/home/ictsc`でmasterサーバーにファイルを転送する
  * ここでいうmasterServerというのは　`k8s-master-01-server` のことです。
* helm をインストール
```sh
# helm install
wget https://get.helm.sh/helm-v3.0.0-beta.3-linux-amd64.tar.gz
tar -zxvf helm-v3.0.0-beta.3-linux-amd64.tar.gz
sudo mv linux-amd64/helm /usr/local/bin/helm
```

### Try kubectl apply!
kubectl applyした時に前後関係があるので気持ち1~2秒ずつ打っていくといいです
<!--（TODO: 最初に数字を書いて前後の順番をつけておくと良さそう） -->
```sh
# namespaceの作成
kubectl create ns scoreserver

# nginx ingressをinstall
# 全体の構成に必須なので一度のみ  
kubectl apply -f mandatory.yaml
kubectl apply -f ingress-service.yaml
# cert-managerをinstall
# 全体の構成に必須なので一度のみ  
wget https://raw.githubusercontent.com/jetstack/cert-manager/release-0.9/deploy/manifests/00-crds.yaml
kubectl apply -f 00-crds.yaml
kubectl create namespace cert-manager
kubectl label namespace cert-manager certmanager.k8s.io/disable-validation=true
helm repo add jetstack https://charts.jetstack.io
helm repo update
helm install -g jetstack/cert-manager --namespace cert-manager --version v0.9.1
kubectl apply -f 00-crds.yaml

# helm list --namespace cert-manage

# cert-managerで動く証明書の設定
kubectl apply -f secret_cloudflare.yaml 
kubectl apply -f cluster-issuer.yaml
kubectl apply -f cretificate.yaml
kubectl apply -f ingress.yaml

# applicationのinstall
kubectl apply -f redis.yaml,ui.yaml,db.yaml,api.yaml,push.yaml
```

これを通じて無事立ち上げることができました！

あとは
*  `kubectl exec -it pod/api-5f9cd6794-9z9sr rails db:setup`みたいな感じで初期データ流し込みをする
* `http://xxx.xxx.xxx.xxx:/`にアクセスできてloginができたら無事一通り立ってる感じ。おめでとう！

## その他
* `kubectl apply -f monitering_manifests.yaml` で同一クラスタ内にnodeexpoterなどの諸々監視を実行することができます

## TroubleShooting & Tips
* `terraform apply`が失敗したら`terraform destroy -force` とかで削除してから立て直す。
* playbookを書き換えたら`ansible-playbook --private-key=./id_rsa -i hosts setup.yml --syntax-check` でいい感じに事前に構文チェックをしておくと良い。
* kubeadmでコピー忘れたら雑に `kubeadm reset` でjoinやinitしてた情報ごと削除できる
* `kubectl delete -f redis.yaml,ui.yaml,db.yaml,api.yaml`で削除。
    * もしマニフェストファイルを変更する場合は削除してから書き換えて `kubectl apply` する方が良い。
* `kubectl get all` で上がってるかどうかとか見れる。READYが1/1ならあがっているということ。0/1ならログを見てみたりしよう。
  * `kubectl logs <pod name>`で可能
* 時々DBが上がるのが失敗したりするのでそのときはログ(ex. kubectl logsやkubectl describe pod)見てから kubectl deleteしてapplyをして見てみる
* [https://wiki.icttoracon.net/knowledge/score-server](https://wiki.icttoracon.net/knowledge/score-server)を参考にしている
* 接続先わかんなくなったら `terraform output`で接続先が確認できます。
* 雑にクラスタを作るための物なのでterraformのパラメーターやディフォルトパスワードとして設定してる `PUT_YOUR_PASSWORD_HERE`とかはよしなに変えることとをお勧めします。（普通に利用する分にはその都度生成される秘密鍵のみの接続になるので問題はないです）
* CNIとかで死んだときは https://blog.51cto.com/wutengfei/2121202 とか見てみるとそれっぽいエラーが並んでるかも。
* rookをTeardownするときは以下を参考にして行う。
  * https://rook.io/docs/rook/v1.1/ceph-filesystem.html
  * https://rook.io/docs/rook/v1.1/ceph-teardown.html
  * 本当に忘れがちなんですが、各nodeにログインして `rm -rf /var/lib/rook` をしてから再度createしましょう
* apikeyを追加して applyするときに `Secret in version "v1" cannot be handled as a Secret: v1.Secret.ObjectMeta: v1.ObjectMeta.TypeMeta: Kind: Data: decode base64: illegal base64 data at input byte...` という感じのエラーが出たら `echo -n apikey  | base64 | tr -d '\n'` みたいな感じで行う(linuxの場合)
  * https://kubernetes.io/docs/concepts/configuration/secret/
