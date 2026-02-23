#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
echo "Loading Docker images into minikube registry..."
kubectl port-forward -n kube-system service/registry 5000:80 & PID=$!
docker build -t localhost:5000/front "$SCRIPT_DIR/../Docker-Images/front/"
docker build -t localhost:5000/cpu-bench "$SCRIPT_DIR/../Docker-Images/cpu-bench/"
docker push localhost:5000/front
docker push localhost:5000/cpu-bench
kill $PID
kubectl rollout restart deployment/front -n default
kubectl rollout restart deployment/cpu-bench -n default