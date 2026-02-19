#!/bin/bash

# Create a multinode minikube cluster, set up certs, load images, and apply base yamls
# Usage: ./create.sh
# Dependencies: mkcert, minikube, kubectl, docker, gnome-terminal

#CHANCE THIS ABSOLUTE ROUTE
ISTIO_HOME="/home/micros/Desktop/istio-1.28.3" 
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

setCerts() {
    Echo "Setting up TLS certificates..."
    if [ ! -e "$SCRIPT_DIR/../Certs/mydomain.com.pem" ] || [ ! -e "$SCRIPT_DIR/../Certs/mydomain.com-key.pem" ]; then
         mkcert -install
    mkcert -cert-file "$SCRIPT_DIR/../Certs/mydomain.com.pem" \
           -key-file "$SCRIPT_DIR/../Certs/mydomain.com-key.pem" \
           mydomain.com
    fi
    kubectl -n default create secret tls secret-tls \
        --key "$SCRIPT_DIR/../Certs/mydomain.com-key.pem" \
        --cert "$SCRIPT_DIR/../Certs/mydomain.com.pem"
}

loadImages(){
    echo "Loading Docker images into minikube registry..."
    kubectl port-forward -n kube-system service/registry 5000:80 & PID=$!
    docker build -t localhost:5000/front "$SCRIPT_DIR/../Docker-Images/front/"
    docker build -t localhost:5000/back "$SCRIPT_DIR/../Docker-Images/back/"
    docker push localhost:5000/front
    docker push localhost:5000/back
    kill $PID
}

applyBase(){
    echo "Applying app manifests..."
    kubectl apply -f "$SCRIPT_DIR/../Yamls/base-multinode.yaml"
    kubectl rollout status deployment/back
    kubectl rollout status deployment/front
}

setIstio(){
    echo "Setting up Istio..."
    istioctl install --set profile=default --set values.global.platform=minikube --skip-confirmation 
    kubectl label namespace default istio-injection=enabled
}

applyGateways(){
    echo "Setting up Gateways..."
    kubectl get crd gateways.gateway.networking.k8s.io &> /dev/null || \
    kubectl apply --server-side -f "$SCRIPT_DIR/../Yamls/experimental-install.yaml"
    kubectl apply -f "$SCRIPT_DIR/../Yamls/gateways.yaml"
}

connectTunnel(){
    minikube tunnel & PID=$!

    echo "Waiting for gateway IP..."
    local INGRESS_HOST=""
    until [ -n "$INGRESS_HOST" ]; do
        sleep 3
        INGRESS_HOST=$(kubectl get gtw app-gateway -o jsonpath='{.status.addresses[0].value}' 2>/dev/null)
    done

    echo "Gateway IP: $INGRESS_HOST"

    if grep -q "mydomain.com" /etc/hosts; then
        sudo sed -i "/mydomain.com/d" /etc/hosts
    fi
    echo "Adding $INGRESS_HOST to /etc/hosts for mydomain.com..."
    echo "$INGRESS_HOST  mydomain.com" | sudo tee -a /etc/hosts
}

setTelemetry(){
    kubectl apply -f "$ISTIO_HOME/samples/addons/prometheus.yaml"
    kubectl apply -f "$ISTIO_HOME/samples/addons/kiali.yaml"
    kubectl rollout status deployment/kiali -n istio-system
}

sudo -v
minikube delete
minikube start --nodes 3 --addons registry
setCerts
loadImages
setIstio
applyBase
applyGateways
connectTunnel
setTelemetry

echo "Cluster setup complete. You can access the application at https://mydomain.com, or be redirected from http://mydomain.com"
