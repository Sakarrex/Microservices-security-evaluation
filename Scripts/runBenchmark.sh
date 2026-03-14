#!/bin/bash
TOKEN=$(curl https://raw.githubusercontent.com/istio/istio/release-1.29/security/tools/jwt/samples/demo.jwt -s)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

function getResults() {
    PROTOCOL=$1
    COMPONENT=$2
    HTTP=$3
    RUN_NUMBER=$4
    autocannon -c 100 -a 10000 -H "Authorization: Bearer $TOKEN" -j $HTTP://mydomain.com/run  > $SCRIPT_DIR/../Results/$PROTOCOL/$COMPONENT/Run_$RUN_NUMBER/http_results.json 2>&1
    DURATION=$(jq -r '.duration' "$SCRIPT_DIR/../Results/$PROTOCOL/$COMPONENT/Run_$RUN_NUMBER/http_results.json" 2>/dev/null)
    DURATION=$(printf "%.0f" "$DURATION")
    echo "Benchmark of $PROTOCOL:$COMPONENT running for approximately $DURATION seconds"


    CPU_USAGE_DATA_PLANE_PODS=$(curl --data-urlencode "query=rate(container_cpu_usage_seconds_total{pod=~\"istiod.*\"}[${DURATION}s])" http://localhost:9090/api/v1/query > $SCRIPT_DIR/../Results/$PROTOCOL/$COMPONENT/Run_$RUN_NUMBER/Cpu/data_plane_cpu_results.json -s)
    CPU_USAGE_APP_PODS=$(curl --data-urlencode "query=rate(container_cpu_usage_seconds_total{pod=~\"cpu-bench.*|mem-bench.*|front.*\"}[${DURATION}s])" http://localhost:9090/api/v1/query > $SCRIPT_DIR/../Results/$PROTOCOL/$COMPONENT/Run_$RUN_NUMBER/Cpu/app_cpu_results.json -s)
    CPU_USAGE_GATEWAY_PODS=$(curl --data-urlencode "query=rate(container_cpu_usage_seconds_total{pod=~\"app-gateway.*\"}[${DURATION}s])" http://localhost:9090/api/v1/query > $SCRIPT_DIR/../Results/$PROTOCOL/$COMPONENT/Run_$RUN_NUMBER/Cpu/gateway_cpu_results.json -s)

    CPU_USAGE_NODES=$(curl --data-urlencode "query=sum by(instance) (rate(container_cpu_usage_seconds_total{pod=~\"istiod.*|cpu-bench.*|mem-bench.*|front.*|app-gateway.*\"}[100m]))" http://localhost:9090/api/v1/query > $SCRIPT_DIR/../Results/$PROTOCOL/$COMPONENT/Run_$RUN_NUMBER/Cpu/nodes_cpu_results.json -s)

    #echo "CPU usage for nodes: $CPU_USAGE_NODES"
    #echo "CPU usage for pods: $CPU_USAGE_APP_PODS"
    MEM_USAGE_DATA_PLANE_PODS=$(curl --data-urlencode "query=avg(avg_over_time(container_memory_usage_bytes{pod=~\"istiod.*\"}[${DURATION}s]))" http://localhost:9090/api/v1/query > $SCRIPT_DIR/../Results/$PROTOCOL/$COMPONENT/Run_$RUN_NUMBER/Mem/data_plane_mem_results.json -s)
    MEM_USAGE_APP_PODS=$(curl --data-urlencode "query=avg(avg_over_time(container_memory_usage_bytes{pod=~\"cpu-bench.*|mem-bench.*|front.*\"}[${DURATION}s]))" http://localhost:9090/api/v1/query > $SCRIPT_DIR/../Results/$PROTOCOL/$COMPONENT/Run_$RUN_NUMBER/Mem/app_mem_results.json -s)
    MEM_USAGE_GATEWAY_PODS=$(curl --data-urlencode "query=avg(avg_over_time(container_memory_usage_bytes{pod=~\"app-gateway.*\"}[${DURATION}s]))" http://localhost:9090/api/v1/query > $SCRIPT_DIR/../Results/$PROTOCOL/$COMPONENT/Run_$RUN_NUMBER/Mem/gateway_mem_results.json -s)
    #echo "Memory usage for pods: $MEM_USAGE_PODS"
}

createFolders() {

    mkdir -p $SCRIPT_DIR/../Results/Control/Run_$1/Cpu/ $SCRIPT_DIR/../Results/Control/Run_$1/Mem/ > /dev/null
    mkdir -p $SCRIPT_DIR/../Results/Mtls/Gateway/Run_$1/Cpu/ $SCRIPT_DIR/../Results/Mtls/Gateway/Run_$1/Mem/ $SCRIPT_DIR/../Results/Mtls/Sidecar/Run_$1/Cpu/ $SCRIPT_DIR/../Results/Mtls/Sidecar/Run_$1/Mem/ $SCRIPT_DIR/../Results/Mtls/All/Run_$1/Cpu/ $SCRIPT_DIR/../Results/Mtls/All/Run_$1/Mem/ > /dev/null
    mkdir -p $SCRIPT_DIR/../Results/Jwt/Gateway/Run_$1/Cpu/ $SCRIPT_DIR/../Results/Jwt/Gateway/Run_$1/Mem/ $SCRIPT_DIR/../Results/Jwt/Sidecar/Run_$1/Cpu/ $SCRIPT_DIR/../Results/Jwt/Sidecar/Run_$1/Mem/ $SCRIPT_DIR/../Results/Jwt/All/Run_$1/Cpu/ $SCRIPT_DIR/../Results/Jwt/All/Run_$1/Mem/ > /dev/null
    mkdir -p $SCRIPT_DIR/../Results/Waf/Gateway/Run_$1/Cpu/ $SCRIPT_DIR/../Results/Waf/Gateway/Run_$1/Mem/ $SCRIPT_DIR/../Results/Waf/Sidecar/Run_$1/Cpu/ $SCRIPT_DIR/../Results/Waf/Sidecar/Run_$1/Mem/ $SCRIPT_DIR/../Results/Waf/All/Run_$1/Cpu/ $SCRIPT_DIR/../Results/Waf/All/Run_$1/Mem/ > /dev/null
}

i=1
#Benchmark Control
while [ $i -lt 4 ]; do

createFolders $i

echo "Starting benchmark run..."
getResults Control "" http $i

#echo "Starting benchmark run for Mtl sidercars only..."
# echo "Starting benchmark run for Mtls in sidecars and gateway only..."
# kubectl apply -f $SCRIPT_DIR/../Yamls/Mtls/enable-mtls-apps.yaml
# kubectl apply -f $SCRIPT_DIR/../Yamls/Mtls/enable-mtls-gateway.yaml
# getResults Mtls Sidecar http $i
# kubectl delete -f $SCRIPT_DIR/../Yamls/Mtls/enable-mtls-apps.yaml
# kubectl delete -f $SCRIPT_DIR/../Yamls/Mtls/enable-mtls-gateway.yaml

#Benchmark Mtls and https gateway only
# echo "Starting benchmark run for Https gateway only..."
# kubectl apply -f $SCRIPT_DIR/../Yamls/Mtls/disable-mtls-gateway.yaml
# kubectl apply -f $SCRIPT_DIR/../Yamls/Mtls/disable-mtls-apps.yaml
# kubectl apply -f $SCRIPT_DIR/../Yamls/Apps/gateway-https.yaml
# kubectl rollout restart deployment app-gateway-istio -n default
# kubectl rollout status deployment app-gateway-istio -n default
# getResults Mtls Gateway https $i
# kubectl delete -f $SCRIPT_DIR/../Yamls/Mtls/disable-mtls-gateway.yaml
# kubectl delete -f $SCRIPT_DIR/../Yamls/Mtls/disable-mtls-apps.yaml


#Benchmark Mtls in all 
# echo "Starting benchmark run for Https and Mtls in sidecars and gateway..."
# kubectl apply -f $SCRIPT_DIR/../Yamls/Mtls/enable-mtls-all.yaml
# getResults Mtls All https $i
# kubectl apply -f $SCRIPT_DIR/../Yamls/Apps/gateway-http.yaml
# kubectl delete -f $SCRIPT_DIR/../Yamls/Mtls/enable-mtls-all.yaml
# kubectl rollout restart deployment app-gateway-istio -n default
# kubectl rollout status deployment app-gateway-istio -n default

# kubectl apply -f $SCRIPT_DIR/../Yamls/Mtls/disable-mtls-all.yaml

#Benchmark Jwt gateway only
# echo "Starting benchmark run for Jwt in gateway only..."
# kubectl apply -f $SCRIPT_DIR/../Yamls/Jwt/jwt-gateway.yaml
# getResults Jwt Gateway http $i
# kubectl delete -f $SCRIPT_DIR/../Yamls/Jwt/jwt-gateway.yaml

# #Benchmark Jwt sidecar only
# echo "Starting benchmark run for Jwt in sidecar only..."
# kubectl apply -f $SCRIPT_DIR/../Yamls/Jwt/jwt-apps.yaml
# getResults Jwt Sidecar http $i
# kubectl delete -f $SCRIPT_DIR/../Yamls/Jwt/jwt-apps.yaml

# #Benchmark Jwt in all
# echo "Starting benchmark run for Jwt in sidecars and gateway..."
# kubectl apply -f $SCRIPT_DIR/../Yamls/Jwt/jwt-all.yaml
# getResults Jwt All http $i
# kubectl delete -f $SCRIPT_DIR/../Yamls/Jwt/jwt-all.yaml

#Benchmark Waf in gateway only
# echo "Starting benchmark run for Waf in gateway only..."
# kubectl apply -f $SCRIPT_DIR/../Yamls/Waf/waf-gateway.yaml
# getResults Waf Gateway http $i
# kubectl delete -f $SCRIPT_DIR/../Yamls/Waf/waf-gateway.yaml

# #Benchmark Waf in sidecar only
# echo "Starting benchmark run for Waf in sidecar only..."
# kubectl apply -f $SCRIPT_DIR/../Yamls/Waf/waf-apps.yaml
# getResults Waf Sidecar http $i
# kubectl delete -f $SCRIPT_DIR/../Yamls/Waf/waf-apps.yaml

# #Benchmark Waf in all
# echo "Starting benchmark run for Waf in sidecars and gateway..."
# kubectl apply -f $SCRIPT_DIR/../Yamls/Waf/waf-all.yaml
# getResults Waf All http $i
# kubectl delete -f $SCRIPT_DIR/../Yamls/Waf/waf-all.yaml

# kubectl delete -f $SCRIPT_DIR/../Yamls/Mtls/disable-mtls-all.yaml

i=$((i+1))
done
