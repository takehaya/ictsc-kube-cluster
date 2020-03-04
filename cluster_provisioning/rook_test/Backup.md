# Backup

これはrookで展開したcephでバックアップ方法を書いている方法です

## install
```
wget https://github.com/vmware-tanzu/velero/releases/download/v1.2.0/velero-v1.2.0-linux-amd64.tar.gz
tar -xvf velero-v1.2.0-linux-amd64.tar.gz
cd velero-v1.2.0-linux-amd64/
sudo mv velero /usr/local/bin
cd $HOME
wget https://github.com/openebs/velero-plugin/archive/1.6.0-velero_1.0.0.tar.gz
tar -xvf 1.6.0-velero_1.0.0.tar.gz
cd velero-plugin-1.6.0-velero_1.0.0

# pre conf
kubectl apply -f 00-prereqs.yaml 
cd example

# minio
cd $HOME
cd velero-v1.2.0-linux-amd64/examples/minio

vim 00-minio-deployment.yaml
---
# expect edited access key
env:
- name: MINIO_ACCESS_KEY
    value: "ictsc"
- name: MINIO_SECRET_KEY
    value: "aWPBBh6i2"
---

kubectl apply -f 00-minio-deployment.yaml
kubectl apply -f 05-backupstoragelocation.yaml
```
