#!/bin/bash

# Create a multinode kind cluster, set up certs, load images, and apply base yamls
# Usage: ./create.sh
# Dependencies: mkcert, kind, kind-cloud-provider, kubectl, docker, istioctl, 

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

setCerts() {
    echo "Setting up TLS certificates..."
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
    echo "Loading Docker images into kind registry..."
    docker build -t front "$SCRIPT_DIR/../Docker-Images/front/"
    docker build -t cpu-bench "$SCRIPT_DIR/../Docker-Images/cpu-bench/"
    docker build -t mem-bench "$SCRIPT_DIR/../Docker-Images/mem-bench/"
    kind load docker-image front
    kind load docker-image cpu-bench
    kind load docker-image mem-bench
}

applyBase(){
    echo "Applying app manifests..."
    kubectl apply -f "$SCRIPT_DIR/../Yamls/Apps/front-app.yaml"
    kubectl apply -f "$SCRIPT_DIR/../Yamls/Apps/cpu-bench-app.yaml"
    kubectl apply -f "$SCRIPT_DIR/../Yamls/Apps/mem-bench-app.yaml"
    kubectl rollout status deployment/cpu-bench
    kubectl rollout status deployment/mem-bench
    kubectl rollout status deployment/front
}

setIstio(){
    echo "Setting up Istio..."
    #Minimal to avoid adding the ingress it comes by default
    istioctl install --set profile=minimal --skip-confirmation 
    kubectl label namespace default istio-injection=enabled
}

applyGateways(){
    echo "Setting up Gateways..."
    kubectl get crd gateways.gateway.networking.k8s.io &> /dev/null || \
    kubectl apply --server-side -f "$SCRIPT_DIR/../Yamls/Apps/experimental-install.yaml"
    kubectl apply -f "$SCRIPT_DIR/../Yamls/Apps/gateway-http.yaml"
}


connectTunnel(){
    echo "Connecting kind cluster to host network using Cloud Provider KIND..."
    cloud-provider-kind &

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
    echo "Setting up telemetry"
    kubectl apply -f "$SCRIPT_DIR/../Yamls/Addons/prometheus.yaml"
    kubectl apply -f "$SCRIPT_DIR/../Yamls/Addons/kiali.yaml"
    kubectl rollout status deployment/prometheus -n istio-system
    kubectl port-forward svc/prometheus -n istio-system 9090:9090 > /dev/null 2>&1 & PID_PROMETHEUS=$! 
    kubectl rollout status deployment/kiali -n istio-system
}


#CAMBIAR
sudo -v
kind delete cluster

kind create cluster --config "$SCRIPT_DIR/../Yamls/cluster-config.yaml" 
setCerts
loadImages
setIstio
applyBase
#applyGateways
#connectTunnel
#setTelemetry

echo "Cluster setup complete. You can access the application at http://mydomain.com"
