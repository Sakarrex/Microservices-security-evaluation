#!/bin/bash
TOKEN=$(curl https://raw.githubusercontent.com/istio/istio/release-1.29/security/tools/jwt/samples/demo.jwt -s)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROTOCOL_INPUT="$1"
COMPONENT_INPUT="$2"
#First leeter uppercase, rest lowercase
PROTOCOL="$(echo "${PROTOCOL_INPUT,,}" | awk '{print toupper(substr($0,1,1)) tolower(substr($0,2))}')"
COMPONENT="$(echo "${COMPONENT_INPUT,,}" | awk '{print toupper(substr($0,1,1)) tolower(substr($0,2))}')"

RUN_AMOUNT="${3:-5}" # Default to 5 runs if not specified

function getResults() {
    http_s=$1
    disable_mtls=$2

    if [ $disable_mtls -eq 1 ]; then
        #Forced disable Mtls, bc it comes enabled by default in istio
        kubectl apply -f $SCRIPT_DIR/../Yamls/Mtls/disable-mtls-all.yaml
        sleep 15
    fi
    
    i=1
    while [ $i -lt $(($RUN_AMOUNT + 1)) ]; do
    echo "Beginning run $i"

    base_route="$SCRIPT_DIR/../Results/$PROTOCOL/Run_$i/$COMPONENT"
    
    mkdir -p $base_route/Cpu/ $base_route/Mem/ > /dev/null

    autocannon -c 100 -a 10000 -H "Authorization: Bearer $TOKEN" -j $http_s://mydomain.com/run  > $base_route/http_results.json 2>&1
    duration=$(jq -r '.duration' "$base_route/http_results.json" 2>/dev/null)
    duration=$(printf "%.0f" "$duration")
    echo "Benchmark of $PROTOCOL:$COMPONENT running for approximately $duration seconds"


    #CPU usages
    #CONTROL_PLANE
    curl --data-urlencode "query=rate(container_cpu_usage_seconds_total{pod=~\"istiod.*\",image=\"\"}[${duration}s])" http://localhost:9090/api/v1/query > $base_route/Cpu/data_plane_cpu_results.json -s
    #APPS
    curl --data-urlencode "query=rate(container_cpu_usage_seconds_total{pod=~\"cpu-bench.*|mem-bench.*|front.*\",image=\"\"}[${duration}s])" http://localhost:9090/api/v1/query > $base_route/Cpu/app_cpu_results.json -s
    #GATEWAY
    curl --data-urlencode "query=rate(container_cpu_usage_seconds_total{pod=~\"app-gateway.*\",image=\"\"}[${duration}s])" http://localhost:9090/api/v1/query > $base_route/Cpu/gateway_cpu_results.json -s
    #TOTAL
    curl --data-urlencode "query=sum(rate(container_cpu_usage_seconds_total{pod=~\"istiod.*|cpu-bench.*|mem-bench.*|front.*|app-gateway.*\",image=\"\"}[${duration}s]))" http://localhost:9090/api/v1/query > $base_route/Cpu/total_cpu_results.json -s

    #curl --data-urlencode "query=max(rate(container_cpu_usage_seconds_total{pod=~\"istiod.*|cpu-bench.*|mem-bench.*|front.*|app-gateway.*\",image=\"\"}[${duration}s])) by (pod)}" http://localhost:9090/api/v1/query > $base_route/Cpu/max_cpu_by_pod.json -s

    curl --data-urlencode "query=rate(container_cpu_cfs_throttled_periods_total{container!=\"\"}[${duration}s]) / rate(container_cpu_cfs_periods_total{container!=\"\"}[${duration}s])" http://localhost:9090/api/v1/query > $base_route/Cpu/cpu_throttling.json  -s

    #Memory usages
    #CONTROL_PLANE
    curl --data-urlencode "query=avg(avg_over_time(container_memory_working_set_bytes{pod=~\"istiod.*\",image=\"\"}[${duration}s]))" http://localhost:9090/api/v1/query > $base_route/Mem/data_plane_mem_results.json -s
    #APPS
    curl --data-urlencode "query=avg(avg_over_time(container_memory_working_set_bytes{pod=~\"cpu-bench.*|mem-bench.*|front.*\",image=\"\"}[${duration}s]))" http://localhost:9090/api/v1/query > $base_route/Mem/app_mem_results.json -s
    #GATEWAY
    curl --data-urlencode "query=avg(avg_over_time(container_memory_working_set_bytes{pod=~\"app-gateway.*\",image=\"\"}[${duration}s]))" http://localhost:9090/api/v1/query > $base_route/Mem/gateway_mem_results.json -s
    #TOTAL
    curl --data-urlencode "query=sum(avg(avg_over_time(container_memory_working_set_bytes{pod=~\"app-gateway.*|cpu-bench.*|mem-bench.*|front.*|istiod.*\",image=\"\"}[${duration}s])))" http://localhost:9090/api/v1/query > $base_route/Mem/total_mem_results.json -s

    #curl --data-urlencode "query=max_over_time(container_memory_working_set_bytes{pod=~\"mem-bench.*|cpu-bench.*|front.*|app-gateway.*\"}[${duration}s])" http://localhost:9090/api/v1/query > mem-res.json -s

    #curl --data-urlencode "query=node_memory_MemAvailable_bytes{node=\"minikube-m03\"}" http://localhost:9090/api/v1/query > node-mem-res.json -s
    

    #Avoid bleeding between runs
    sleep 15

    i=$((i+1))
    done

    if [ $disable_mtls -eq 1 ]; then
        #Allow mtls back
        kubectl delete -f $SCRIPT_DIR/../Yamls/Mtls/disable-mtls-all.yaml
        sleep 15
    fi

}



case $PROTOCOL in
    Control)
        COMPONENT=None
        #Benchmark Control
        echo "Starting benchmark run..."
        getResults http 1
        ;;

    Jwt)
        case $COMPONENT in
            Gateway)
                #Benchmark Jwt gateway only
                echo "Starting benchmark run for Jwt in gateway only..."

                kubectl apply -f $SCRIPT_DIR/../Yamls/Jwt/jwt-gateway.yaml
                sleep 15
                getResults http 1
                kubectl delete -f $SCRIPT_DIR/../Yamls/Jwt/jwt-gateway.yaml
                ;;

            Sidecar)
                #Benchmark Jwt sidecar only
                echo "Starting benchmark run for Jwt in sidecar only..."

                kubectl apply -f $SCRIPT_DIR/../Yamls/Jwt/jwt-apps.yaml
                sleep 15
                getResults http 1
                kubectl delete -f $SCRIPT_DIR/../Yamls/Jwt/jwt-apps.yaml
                ;;

            All)
                #Benchmark Jwt in all
                echo "Starting benchmark run for Jwt in sidecars and gateway..."

                kubectl apply -f $SCRIPT_DIR/../Yamls/Jwt/jwt-all.yaml
                sleep 15
                getResults http 1
                kubectl delete -f $SCRIPT_DIR/../Yamls/Jwt/jwt-all.yaml
                ;;

            *)
                echo "not a component"
                ;;
            
        esac
        ;;

    Waf)
        case $COMPONENT in
            Gateway)
                #Benchmark Waf in gateway only
                echo "Starting benchmark run for Waf in gateway only..."
                
                kubectl apply -f $SCRIPT_DIR/../Yamls/Waf/waf-gateway.yaml
                sleep 15
                getResults http 1
                kubectl delete -f $SCRIPT_DIR/../Yamls/Waf/waf-gateway.yaml
                ;;

            Sidecar)
                #Benchmark Waf in sidecar only
                echo "Starting benchmark run for Waf in sidecar only..."

                kubectl apply -f $SCRIPT_DIR/../Yamls/Waf/waf-apps.yaml
                sleep 15
                getResults http 1
                kubectl delete -f $SCRIPT_DIR/../Yamls/Waf/waf-apps.yaml
                ;;

            All)
                #Benchmark Waf in all
                echo "Starting benchmark run for Waf in sidecars and gateway..."

                kubectl apply -f $SCRIPT_DIR/../Yamls/Waf/waf-all.yaml
                sleep 15
                getResults http 1
                kubectl delete -f $SCRIPT_DIR/../Yamls/Waf/waf-all.yaml
                ;;
            
            *)
                echo "not a component"
                ;;
        esac
        ;;

    Mtls)
        case $COMPONENT in
            Gateway)
                #Benchmark Mtls and https gateway only
                echo "Starting benchmark run for Https gateway only..."

                kubectl apply -f $SCRIPT_DIR/../Yamls/Mtls/disable-mtls-all.yaml
                kubectl apply -f $SCRIPT_DIR/../Yamls/Apps/gateway-https.yaml
                kubectl rollout restart deployment app-gateway-istio -n default
                kubectl rollout status deployment app-gateway-istio -n default
                sleep 15
                getResults https 0
                kubectl delete -f $SCRIPT_DIR/../Yamls/Mtls/disable-mtls-all.yaml
                ;;

            Sidecar)
                echo "Starting benchmark run for Mtls in sidecars and gateway "

                kubectl apply -f $SCRIPT_DIR/../Yamls/Mtls/enable-mtls-all.yaml
                sleep 15
                getResults http 0
                kubectl delete -f $SCRIPT_DIR/../Yamls/Mtls/enable-mtls-all.yaml
                ;;

            All)
                #Benchmark Mtls in all
                echo "Starting benchmark run for Https and Mtls in sidecars and gateway..."

                kubectl apply -f $SCRIPT_DIR/../Yamls/Mtls/enable-mtls-all.yaml
                sleep 15
                getResults https 0
                kubectl apply -f $SCRIPT_DIR/../Yamls/Apps/gateway-http.yaml
                kubectl delete -f $SCRIPT_DIR/../Yamls/Mtls/enable-mtls-all.yaml
                kubectl rollout restart deployment app-gateway-istio -n default
                kubectl rollout status deployment app-gateway-istio -n default
                ;;

            *)
                echo "not a component"
                ;;
        esac
        ;;
    *)
        echo "not a protocol to run"
        ;;
        
esac
