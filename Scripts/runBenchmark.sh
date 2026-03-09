#!/bin/bash
TOKEN=$(curl https://raw.githubusercontent.com/istio/istio/release-1.29/security/tools/jwt/samples/demo.jwt -s)

autocannon -c 100 -a 10000 -H "Authorization: Bearer $TOKEN" -j https://mydomain.com/run  >> benchmark_results.json 2>&1
DURATION=$(jq -r '.duration' benchmark_results.json 2>/dev/null) 
DURATION=$(printf "%.0f" "$DURATION")
echo "Benchmark running for approximately $DURATION seconds"
#CPU_USAGE_NODES-START= $(curl --data-urlencode "query=process_cpu_seconds_total" http://localhost:9090/api/v1/query -s)
#CPU_USAGE_PODS=$(curl --data-urlencode "query=container_cpu_usage_seconds_total{pod=~"cpu-bench.*|mem-bench.*|front"}[${DURATION}s]" http://localhost:9090/api/v1/query -s)
#echo "CPU usage for cpu-bench pods: $CPU_USAGE_PODS"
