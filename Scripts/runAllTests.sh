#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ISTIO_MODE="${1:-minimal}" #select istio setup, minimal by default
ISTIO_MODE="${ISTIO_MODE,,}"
stop_background_processes() {
    echo "Stopping Prometheus port-forward..."  
    pkill -f "kubectl port-forward svc/prometheus" 2>/dev/null || true
    echo "Killing orphaned cloud-provider-kind processes..."
    sudo killall cloud-provider-kind 2>/dev/null || true
}

set_cluster(){
    echo "re/setting cluster"
    /bin/bash $SCRIPT_DIR/create.sh $ISTIO_MODE 
}

sudo -v
output_dir="$SCRIPT_DIR/../Results/$ISTIO_MODE/outputs"
mkdir -p "$output_dir"

Mechanism_list=("Jwt" "Mtls" "Waf")
Component_list=("Gateway" "Sidecar" "All")

#Control benchmark to have a baseline to compare with, without any security mechanism enabled, but with the overhead of istio in place
set_cluster
/bin/bash $SCRIPT_DIR/runBenchmark.sh Control a 20 $ISTIO_MODE > $output_dir/control_output.txt 2>&1
stop_background_processes

for mechanism in "${Mechanism_list[@]}"; do
    for component in "${Component_list[@]}"; do
        echo "Running benchmark for $mechanism on $component..."
        set_cluster
        /bin/bash $SCRIPT_DIR/runBenchmark.sh $mechanism $component 20 $ISTIO_MODE > "$output_dir/${mechanism,,}_${component,,}_output.txt" 2>&1
        stop_background_processes
    done
done
