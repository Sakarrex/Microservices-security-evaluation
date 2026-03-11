#!/bin/bash
TOKEN=$(curl https://raw.githubusercontent.com/istio/istio/release-1.29/security/tools/jwt/samples/demo.jwt -s)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

function getResults() {
    FOLDER_NAME=$1
    autocannon -c 100 -a 10000 -H "Authorization: Bearer $TOKEN" -j http://mydomain.com/run  > $SCRIPT_DIR/../Results/$FOLDER_NAME/http_results.json 2>&1
    DURATION=$(jq -r '.duration' $SCRIPT_DIR/../Results/$FOLDER_NAME/http_results.json 2>/dev/null)
    DURATION=$(printf "%.0f" "$DURATION")
    echo "Benchmark of $FOLDER_NAME running for approximately $DURATION seconds"


    CPU_USAGE_DATA_PLANE_PODS=$(curl --data-urlencode "query=rate(container_cpu_usage_seconds_total{pod=~\"istiod.*\"}[${DURATION}s])" http://localhost:9090/api/v1/query > $SCRIPT_DIR/../Results/$FOLDER_NAME/data_plane_cpu_results.json -s)
    CPU_USAGE_APP_PODS=$(curl --data-urlencode "query=rate(container_cpu_usage_seconds_total{pod=~\"cpu-bench.*|mem-bench.*|front.*\"}[${DURATION}s])" http://localhost:9090/api/v1/query > $SCRIPT_DIR/../Results/$FOLDER_NAME/app_cpu_results.json -s)
    CPU_USAGE_GATEWAY_PODS=$(curl --data-urlencode "query=rate(container_cpu_usage_seconds_total{pod=~\"app-gateway.*\"}[${DURATION}s])" http://localhost:9090/api/v1/query > $SCRIPT_DIR/../Results/$FOLDER_NAME/gateway_cpu_results.json -s)
    
    CPU_USAGE_NODES=$(curl --data-urlencode "query=sum by(instance) (rate(container_cpu_usage_seconds_total{pod=~\"istiod.*|cpu-bench.*|mem-bench.*|front.*|app-gateway.*\"}[100m]))" http://localhost:9090/api/v1/query > $SCRIPT_DIR/../Results/$FOLDER_NAME/nodes_cpu_results.json -s)

    #echo "CPU usage for nodes: $CPU_USAGE_NODES"
    #echo "CPU usage for pods: $CPU_USAGE_APP_PODS"
    MEM_USAGE_APP_PODS=$(curl --data-urlencode "query=avg(avg_over_time(container_memory_usage_bytes{pod=~\"cpu-bench.*|mem-bench.*|front.*\"}[${DURATION}s]))" http://localhost:9090/api/v1/query > $SCRIPT_DIR/../Results/$FOLDER_NAME/app_mem_results.json -s)
    MEM_USAGE_GATEWAY_PODS=$(curl --data-urlencode "query=avg(avg_over_time(container_memory_usage_bytes{pod=~\"app-gateway.*\"}[${DURATION}s]))" http://localhost:9090/api/v1/query > $SCRIPT_DIR/../Results/$FOLDER_NAME/gateway_mem_results.json -s)
    #echo "Memory usage for pods: $MEM_USAGE_PODS"
}

#Benchmark Control
echo "Starting benchmark run..."
getResults Control


