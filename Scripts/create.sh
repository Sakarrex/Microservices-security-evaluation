#!/bin/bash

# Create a multinode minikube cluster, set up certs, load images, and apply base yamls
# Usage: ./create.sh
# Dependencies: mkcert, minikube, kubectl, docker, gnome-terminal


SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

setCerts() {
    if [ ! -e "$SCRIPT_DIR/../certs/mydomain.com.pem" ] || [ ! -e "$SCRIPT_DIR/../certs/mydomain.com-key.pem" ]; then
        mkcert -install
        mkcert mydomain.com 
        mv mydomain.com.pem mydomain.com-key.pem "$SCRIPT_DIR/../certs/"
    fi
    kubectl -n kube-system create secret tls mkcert --key "$SCRIPT_DIR/../certs/mydomain.com-key.pem" --cert "$SCRIPT_DIR/../certs/mydomain.com.pem"
}

loadImages(){
    gnome-terminal -- kubectl port-forward -n kube-system service/registry 5000:80
    docker build -t localhost:5000/front "$SCRIPT_DIR/../Docker-Images/front/"
    docker build -t localhost:5000/back "$SCRIPT_DIR/../Docker-Images/back/"
    docker push localhost:5000/front
    docker push localhost:5000/back
}

applyBase(){
    kubectl apply -f "$SCRIPT_DIR/../Yamls/base-multinode.yaml"
    kubectl rollout status deployment/back
    kubectl rollout status deployment/front
}

applyGateways(){
    kubectl get crd gateways.gateway.networking.k8s.io &> /dev/null || \
    kubectl apply --server-side -f "$SCRIPT_DIR/../Yamls/experimental-install.yaml"
    istioctl install --set profile=minimal --skip-confirmation 
    kubectl apply -f "$SCRIPT_DIR/../Yamls/gateways.yaml"
}

minikube delete
minikube start --nodes 3 --addons registry
setCerts
loadImages
applyBase
applyGateways
