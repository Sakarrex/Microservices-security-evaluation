#!/bin/bash

# Create a multinode minikube cluster, set up certs, load images, and apply base yamls
# Usage: ./create.sh
# Dependencies: mkcert, minikube, kubectl, docker, gnome-terminal

setCerts() {
    if [ ! -e ../certs/mydomain.com.pem ] || [ ! -e ../certs/mydomain.com-key.pem ]; then
        mkcert -install
        mkcert mydomain.com 
        mv mydomain.com.pem mydomain.com-key.pem ../certs/
    fi
    kubectl -n kube-system create secret tls mkcert --key ../certs/mydomain.com-key.pem --cert ../certs/mydomain.com.pem
}

loadImages(){
    gnome-terminal -- kubectl port-forward -n kube-system service/registry 5000:80
    docker build -t localhost:5000/front ../Docker-Images/front/
    docker build -t localhost:5000/back ../Docker-Images/back/
    docker push localhost:5000/front
    docker push localhost:5000/back
}

applyBase(){
    kubectl apply -f ../Yamls/base-multinode.yaml
    kubectl rollout status deployment/back
    kubectl rollout status deployment/front
}

applyGateways(){
    kubectl get crd gateways.gateway.networking.k8s.io &> /dev/null || \
    kubectl apply --server-side -f ../Yamls/experimental-install.yaml
    istioctl install --set profile=minimal --skip-confirmation 
    kubectl apply -f ../Yamls/gateways.yaml
}

minikube delete
minikube start --nodes 3 --addons registry
setCerts
loadImages
applyBase
applyGateways
