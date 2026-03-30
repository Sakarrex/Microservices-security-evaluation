#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
echo "Loading Docker images into kind ..."
docker build -t front "$SCRIPT_DIR/../Docker-Images/front/"
docker build -t cpu-bench "$SCRIPT_DIR/../Docker-Images/cpu-bench/"
docker build -t mem-bench "$SCRIPT_DIR/../Docker-Images/mem-bench/"
kind load docker-image front
kind load docker-image cpu-bench
kind load docker-image mem-bench
kubectl rollout restart deployment/front
kubectl rollout restart deployment/cpu-bench
kubectl rollout restart deployment/mem-bench 
kubectl rollout status deployment/cpu-bench
kubectl rollout status deployment/mem-bench
kubectl rollout status deployment/front