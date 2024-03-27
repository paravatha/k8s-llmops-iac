curl -sSL -o argocd-linux-amd64 https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
sudo install -m 555 argocd-linux-amd64 /usr/local/bin/argocd
rm argocd-linux-amd64

##
argocd admin initial-password -n argocd
kubectl port-forward svc/argocd-server -n argocd 8080:443
argocd login 127.0.0.1:8080

argocd cluster add <cluster-arn>
kubectl config set-context --current --namespace=argocd

k apply -f argocd-cmd-params-cm.yaml 

data:
  server.insecure: "true"

k rollout restart deployment argocd-server
k apply -f grpc-service.yaml 
k apply -f ingress.yaml  

kubectl port-forward svc/argocd-server -n argocd 8090:443

echo $(kubectl -n argocd get secret/argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d)

ARGOCD_PASSWORD=""
argocd login localhost:8090 --username "admin" --password "$ARGOCD_PASSWORD" --insecure

argocd login <argocd-alb> --username "admin" --password "$ARGOCD_PASSWORD" --insecure