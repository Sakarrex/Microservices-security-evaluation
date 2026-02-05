#!/bin/bash
minikube delete
minikube start --nodes 3 --addons registry

kubectl -n kube-system create secret tls mkcert --key mydomain.com-key.pem --cert mydomain.com.pem
minikube addons configure ingress << EOF
kube-system/mkcert
EOF
minikube addons enable ingress
kubectl rollout status deployment/ingress-nginx-controller -n ingress-nginx

gnome-terminal -- kubectl port-forward -n kube-system service/registry 5000:80
docker build -t localhost:5000/front ./front/
docker build -t localhost:5000/back ./back/
docker push localhost:5000/front
docker push localhost:5000/back

kubectl apply -f base-multinode-final.yaml
kubectl rollout status deployment/back
kubectl rollout status deployment/front