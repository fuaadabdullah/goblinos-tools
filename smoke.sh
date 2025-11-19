#!/bin/bash
# Overmind/Kubecost smoke test
set -euo pipefail

# Test Kubecost endpoint
KUBECOST_NS="kubecost"
KUBECOST_DEPLOY="kubecost-cost-analyzer"
PORT=9090

# Port-forward in background


# Check kubectl connectivity
if ! kubectl get nodes &>/dev/null; then
  echo "❌ kubectl cannot connect to a Kubernetes cluster. Is your cluster running?"
  exit 1
fi

# Check if Kubecost namespace exists
if ! kubectl get ns "$KUBECOST_NS" &>/dev/null; then
  echo "❌ Namespace '$KUBECOST_NS' does not exist. Kubecost is not deployed."
  exit 1
fi

# Check if Kubecost deployment exists
if ! kubectl get deployment -n "$KUBECOST_NS" "$KUBECOST_DEPLOY" &>/dev/null; then
  echo "❌ Deployment '$KUBECOST_DEPLOY' not found in namespace '$KUBECOST_NS'."
  exit 1
fi

# Check if deployment is available
AVAILABLE=$(kubectl get deployment -n "$KUBECOST_NS" "$KUBECOST_DEPLOY" -o jsonpath='{.status.availableReplicas}')
if [[ "$AVAILABLE" == "" || "$AVAILABLE" == "0" ]]; then
  echo "❌ Kubecost deployment is not available."
  exit 1
fi

# Port-forward in background
echo "Port-forwarding Kubecost..."
kubectl port-forward -n "$KUBECOST_NS" deployment/$KUBECOST_DEPLOY $PORT:$PORT &
PF_PID=$!
sleep 5

# Test allocation API
echo "Testing Kubecost allocation API..."
if curl -s -G http://localhost:$PORT/model/allocation -d window=today -d aggregate=namespace --max-time 5 | grep 'data'; then
  echo "✅ Kubecost allocation API healthy"
else
  echo "❌ Kubecost allocation API failed"
fi

kill $PF_PID 2>/dev/null || true

echo "Smoke test complete."
