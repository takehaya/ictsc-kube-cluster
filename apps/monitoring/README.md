```
kubectl apply -f  monitoring-ns.yaml 
kubectl apply -f ./alertmanager
kubectl apply -f ./grafana
kubectl apply -f ./prometheus

kubectl get po,svc -n monitoring

kubectl delete -f ./alertmanager
kubectl delete -f ./grafana
kubectl delete -f ./prometheus
```
