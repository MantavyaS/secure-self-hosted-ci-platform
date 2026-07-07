#!/bin/bash

set -euo pipefail

GRAFANA_URL="http://monitoring-grafana.monitoring"
DASHBOARD_DIR="/home/ubuntu/projects/secure-self-hosted-ci-platform/monitoring/dashboards"

USER=$(kubectl get secret -n monitoring monitoring-grafana -o jsonpath="{.data.admin-user}" | base64 -d)
PASS=$(kubectl get secret -n monitoring monitoring-grafana -o jsonpath="{.data.admin-password}" | base64 -d)

for file in "$DASHBOARD_DIR"/*.json; do
    name=$(jq -r '.metadata.name' "$file")
    echo "Provisioning $name from $file"

    code=$(curl -s -o /tmp/grafana_response.json -w "%{http_code}" \
    -u "$USER:$PASS"   \
    -H "Content-Type: application/json"   \
    -X POST   \
    "$GRAFANA_URL/apis/dashboard.grafana.app/v2/namespaces/default/dashboards"   \
    --data-binary @"$file")

    if [ "$code" = "409" ]; then
        echo "Dashboard already exists updating $name"
        curl -s -o /tmp/grafana_response.json -w "%{http_code}" \
        -u "$USER:$PASS"   \
        -H "Content-Type: application/json"   \
        -X PUT   \
        "$GRAFANA_URL/apis/dashboard.grafana.app/v2/namespaces/default/dashboards/$name"   \
        --data-binary @"$file" | jq
    
    else
        cat /tmp/grafana_response.json | jq
    
    fi
done
    
