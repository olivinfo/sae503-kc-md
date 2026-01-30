helm install haddock .
kubectl create secret docker-registry regcred   --docker-server=ghcr.io   --docker-username=0xKILL1   --docker-password=   --namespace=haddock
kubectl rollout restart deployment -n haddock
