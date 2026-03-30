#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

stop_background_processes() {
    echo "Stopping Prometheus port-forward..."
    pkill -f "kubectl port-forward svc/prometheus" 2>/dev/null || true
}

set_cluster(){
    echo "re/setting cluster"
    /bin/bash $SCRIPT_DIR/create.sh > /dev/null
}

sudo -v


mkdir -p $SCRIPT_DIR/../Results/outputs

set_cluster

/bin/bash $SCRIPT_DIR/runBenchmark.sh Control a 20 > $SCRIPT_DIR/../Results/outputs/control_output.txt 2>&1

stop_background_processes
set_cluster

/bin/bash $SCRIPT_DIR/runBenchmark.sh Jwt Gateway 20 > $SCRIPT_DIR/../Results/outputs/jwt_gateway_output.txt 2>&1

stop_background_processes
set_cluster

/bin/bash $SCRIPT_DIR/runBenchmark.sh Jwt Sidecar 20 > $SCRIPT_DIR/../Results/outputs/jwt_sidecar_output.txt 2>&1

stop_background_processes
set_cluster

/bin/bash $SCRIPT_DIR/runBenchmark.sh Jwt All 20 > $SCRIPT_DIR/../Results/outputs/all_sidecar_output.txt 2>&1

stop_background_processes
set_cluster

/bin/bash $SCRIPT_DIR/runBenchmark.sh Mtls Gateway 20 > $SCRIPT_DIR/../Results/outputs/gateway_all_output.txt 2>&1

stop_background_processes
set_cluster

/bin/bash $SCRIPT_DIR/runBenchmark.sh Mtls Sidecar 20 > $SCRIPT_DIR/../Results/outputs/sidecar_all_output.txt 2>&1

stop_background_processes
set_cluster

/bin/bash $SCRIPT_DIR/runBenchmark.sh Mtls All 20 > $SCRIPT_DIR/../Results/outputs/jwt_all_output.txt 2>&1

stop_background_processes
set_cluster

/bin/bash $SCRIPT_DIR/runBenchmark.sh Waf Gateway 20 > $SCRIPT_DIR/../Results/outputs/waf_gateway_output.txt 2>&1

stop_background_processes
set_cluster

/bin/bash $SCRIPT_DIR/runBenchmark.sh Waf Sidecar 20 > $SCRIPT_DIR/../Results/outputs/waf_sidecar_output.txt 2>&1

stop_background_processes
set_cluster

/bin/bash $SCRIPT_DIR/runBenchmark.sh Waf All 20 > $SCRIPT_DIR/../Results/outputs/waf_all_output.txt 2>&1