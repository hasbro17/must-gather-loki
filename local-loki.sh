#!/bin/bash
set -euo pipefail

if [ -z "$1" ]
  then
    echo "./local-loki.sh <path to unpacked must-gather>"
    exit 1
fi

# Get absolute path of current directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Get absolute path of must-gather directory
MUST_GATHER_PATH="$(cd "$1" && pwd)"

# Create a pod with absolute paths
sed -e "s;REPLACE_ME;${MUST_GATHER_PATH};g" \
    -e "s;\\./grafana/data;${SCRIPT_DIR}/grafana/data;g" \
    -e "s;\\./grafana/grafana.ini;${SCRIPT_DIR}/grafana/grafana.ini;g" \
    -e "s;\\./grafana/provisioning;${SCRIPT_DIR}/grafana/provisioning;g" \
    -e "s;\\./loki/data;${SCRIPT_DIR}/loki/data;g" \
    -e "s;\\./loki/loki-local-config.yaml;${SCRIPT_DIR}/loki/loki-local-config.yaml;g" \
    -e "s;\\./promtail;${SCRIPT_DIR}/promtail;g" \
    grafana-stack-template.yaml > grafana-stack.yaml

podman play kube grafana-stack.yaml

echo "Grafana started at http://localhost:3000/explore"
echo "Run \`podman pod rm -f grafana-stack-pod\` to stop all containers"
