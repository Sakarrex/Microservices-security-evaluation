#!/bin/bash
TOKEN=$(curl https://raw.githubusercontent.com/istio/istio/release-1.29/security/tools/jwt/samples/demo.jwt -s)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RUN_AMOUNT="${1:-5}" # Default to 5 runs if not specified

function getResults() {
    PROTOCOL=$1
    COMPONENT=$2
    HTTP=$3
    RUN_NUMBER=$4

    BASE_ROUTE="$SCRIPT_DIR/../Results/$PROTOCOL/Run_$RUN_NUMBER/$COMPONENT"

    autocannon -c 100 -a 10000 -H "Authorization: Bearer $TOKEN" -j $HTTP://mydomain.com/run  > $BASE_ROUTE/http_results.json 2>&1
    DURATION=$(jq -r '.duration' "$BASE_ROUTE/http_results.json" 2>/dev/null)
    DURATION=$(printf "%.0f" "$DURATION")
    echo "Benchmark of $PROTOCOL:$COMPONENT running for approximately $DURATION seconds"


    #CPU usages
    #CONTROL_PLANE
    curl --data-urlencode "query=rate(container_cpu_usage_seconds_total{pod=~\"istiod.*\"}[${DURATION}s])" http://localhost:9090/api/v1/query > $BASE_ROUTE/Cpu/data_plane_cpu_results.json -s
    #APPS
    curl --data-urlencode "query=rate(container_cpu_usage_seconds_total{pod=~\"cpu-bench.*|mem-bench.*|front.*\"}[${DURATION}s])" http://localhost:9090/api/v1/query > $BASE_ROUTE/Cpu/app_cpu_results.json -s
    #GATEWAY
    curl --data-urlencode "query=rate(container_cpu_usage_seconds_total{pod=~\"app-gateway.*\"}[${DURATION}s])" http://localhost:9090/api/v1/query > $BASE_ROUTE/Cpu/gateway_cpu_results.json -s
    #TOTAL
    curl --data-urlencode "query=sum(rate(container_cpu_usage_seconds_total{pod=~\"istiod.*|cpu-bench.*|mem-bench.*|front.*|app-gateway.*\"}[${DURATION}s]))" http://localhost:9090/api/v1/query > $BASE_ROUTE/Cpu/total_cpu_results.json -s

    #Memory usages
    #CONTROL_PLANE
    curl --data-urlencode "query=avg(avg_over_time(container_memory_working_set_bytes{pod=~\"istiod.*\"}[${DURATION}s]))" http://localhost:9090/api/v1/query > $BASE_ROUTE/Mem/data_plane_mem_results.json -s
    #APPS
    curl --data-urlencode "query=avg(avg_over_time(container_memory_working_set_bytes{pod=~\"cpu-bench.*|mem-bench.*|front.*\"}[${DURATION}s]))" http://localhost:9090/api/v1/query > $BASE_ROUTE/Mem/app_mem_results.json -s
    #GATEWAY
    curl --data-urlencode "query=avg(avg_over_time(container_memory_working_set_bytes{pod=~\"app-gateway.*\"}[${DURATION}s]))" http://localhost:9090/api/v1/query > $BASE_ROUTE/Mem/gateway_mem_results.json -s
    #TOTAL
    curl --data-urlencode "query=sum(avg(avg_over_time(container_memory_working_set_bytes{pod=~\"app-gateway.*|cpu-bench.*|mem-bench.*|front.*|istiod.*\"}[${DURATION}s])))" http://localhost:9090/api/v1/query > $BASE_ROUTE/Mem/total_mem_results.json -s

    #curl --data-urlencode "query=max_over_time(container_memory_working_set_bytes{pod=~\"mem-bench.*|cpu-bench.*|front.*|app-gateway.*\"}[${DURATION}s])" http://localhost:9090/api/v1/query > mem-res.json -s

    #curl --data-urlencode "query=node_memory_MemAvailable_bytes{node=\"minikube-m03\"}" http://localhost:9090/api/v1/query > node-mem-res.json -s
}

createFolders() {
    mkdir -p $SCRIPT_DIR/../Results/Control/Run_$1/Cpu/ $SCRIPT_DIR/../Results/Control/Run_$1/Mem/ > /dev/null
    mkdir -p $SCRIPT_DIR/../Results/Mtls/Run_$1/Gateway/Cpu/ $SCRIPT_DIR/../Results/Mtls/Run_$1/Gateway/Mem/ $SCRIPT_DIR/../Results/Mtls/Run_$1/Sidecar/Cpu/ $SCRIPT_DIR/../Results/Mtls/Run_$1/Sidecar/Mem/ $SCRIPT_DIR/../Results/Mtls/Run_$1/All/Cpu/ $SCRIPT_DIR/../Results/Mtls/Run_$1/All/Mem/ > /dev/null
    mkdir -p $SCRIPT_DIR/../Results/Jwt/Run_$1/Gateway/Cpu/ $SCRIPT_DIR/../Results/Jwt/Run_$1/Gateway/Mem/ $SCRIPT_DIR/../Results/Jwt/Run_$1/Sidecar/Cpu/ $SCRIPT_DIR/../Results/Jwt/Run_$1/Sidecar/Mem/ $SCRIPT_DIR/../Results/Jwt/Run_$1/All/Cpu/ $SCRIPT_DIR/../Results/Jwt/Run_$1/All/Mem/ > /dev/null
    mkdir -p $SCRIPT_DIR/../Results/Waf/Run_$1/Gateway/Cpu/ $SCRIPT_DIR/../Results/Waf/Run_$1/Gateway/Mem/ $SCRIPT_DIR/../Results/Waf/Run_$1/Sidecar/Cpu/ $SCRIPT_DIR/../Results/Waf/Run_$1/Sidecar/Mem/ $SCRIPT_DIR/../Results/Waf/Run_$1/All/Cpu/ $SCRIPT_DIR/../Results/Waf/Run_$1/All/Mem/ > /dev/null
}

i=1
while [ $i -lt $(($RUN_AMOUNT + 1)) ]; do

createFolders $i

#Disable Mtls, bc it comes enabled by default in istio, then we will enable it back for the other runs
kubectl apply -f $SCRIPT_DIR/../Yamls/Mtls/disable-mtls-all.yaml

#Benchmark Control
echo "Starting benchmark run..."
sleep 30
getResults Control "" http $i



#Benchmark Jwt gateway only
echo "Starting benchmark run for Jwt in gateway only..."

kubectl apply -f $SCRIPT_DIR/../Yamls/Jwt/jwt-gateway.yaml
sleep 30
getResults Jwt Gateway http $i
kubectl delete -f $SCRIPT_DIR/../Yamls/Jwt/jwt-gateway.yaml

#Benchmark Jwt sidecar only
echo "Starting benchmark run for Jwt in sidecar only..."

kubectl apply -f $SCRIPT_DIR/../Yamls/Jwt/jwt-apps.yaml
sleep 30
getResults Jwt Sidecar http $i
kubectl delete -f $SCRIPT_DIR/../Yamls/Jwt/jwt-apps.yaml

#Benchmark Jwt in all
echo "Starting benchmark run for Jwt in sidecars and gateway..."

kubectl apply -f $SCRIPT_DIR/../Yamls/Jwt/jwt-all.yaml
sleep 30
getResults Jwt All http $i
kubectl delete -f $SCRIPT_DIR/../Yamls/Jwt/jwt-all.yaml

#Benchmark Waf in gateway only
echo "Starting benchmark run for Waf in gateway only..."

kubectl apply -f $SCRIPT_DIR/../Yamls/Waf/waf-gateway.yaml
sleep 30
getResults Waf Gateway http $i
kubectl delete -f $SCRIPT_DIR/../Yamls/Waf/waf-gateway.yaml

#Benchmark Waf in sidecar only
echo "Starting benchmark run for Waf in sidecar only..."

kubectl apply -f $SCRIPT_DIR/../Yamls/Waf/waf-apps.yaml
sleep 30
getResults Waf Sidecar http $i
kubectl delete -f $SCRIPT_DIR/../Yamls/Waf/waf-apps.yaml

#Benchmark Waf in all
echo "Starting benchmark run for Waf in sidecars and gateway..."

kubectl apply -f $SCRIPT_DIR/../Yamls/Waf/waf-all.yaml
sleep 30
getResults Waf All http $i
kubectl delete -f $SCRIPT_DIR/../Yamls/Waf/waf-all.yaml

#Enable Mtls back
kubectl delete -f $SCRIPT_DIR/../Yamls/Mtls/disable-mtls-all.yaml

echo "Starting benchmark run for Mtls in sidecars and gateway "

kubectl apply -f $SCRIPT_DIR/../Yamls/Mtls/enable-mtls-all.yaml
sleep 30
getResults Mtls Sidecar http $i
kubectl delete -f $SCRIPT_DIR/../Yamls/Mtls/enable-mtls-all.yaml


#Benchmark Mtls and https gateway only
echo "Starting benchmark run for Https gateway only..."

kubectl apply -f $SCRIPT_DIR/../Yamls/Mtls/disable-mtls-all.yaml
kubectl apply -f $SCRIPT_DIR/../Yamls/Apps/gateway-https.yaml
kubectl rollout restart deployment app-gateway-istio -n default
kubectl rollout status deployment app-gateway-istio -n default
sleep 30
getResults Mtls Gateway https $i
kubectl delete -f $SCRIPT_DIR/../Yamls/Mtls/disable-mtls-all.yaml

#Benchmark Mtls in all
echo "Starting benchmark run for Https and Mtls in sidecars and gateway..."

kubectl apply -f $SCRIPT_DIR/../Yamls/Mtls/enable-mtls-all.yaml
sleep 30
getResults Mtls All https $i
kubectl apply -f $SCRIPT_DIR/../Yamls/Apps/gateway-http.yaml
kubectl delete -f $SCRIPT_DIR/../Yamls/Mtls/enable-mtls-all.yaml
kubectl rollout restart deployment app-gateway-istio -n default
kubectl rollout status deployment app-gateway-istio -n default

i=$((i+1))
done
