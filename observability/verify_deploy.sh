#!/usr/bin/env bash
set -euo pipefail

# Basic verification script for observability stack
# - waits for deployments to be ready
# - performs simple HTTP checks against services (cluster-internal)

NAMESPACE=observability
TIMEOUT=${1:-120}

echo "Checking namespace $NAMESPACE..."
kubectl get ns "$NAMESPACE" >/dev/null

echo "Waiting for deployments to be ready (timeout ${TIMEOUT}s)..."
kubectl wait --for=condition=available --timeout=${TIMEOUT}s deployment --all -n "$NAMESPACE"

echo "Checking core services..."
SERVICES=(otel-collector loki tempo grafana)
for svc in "${SERVICES[@]}"; do
  echo -n "- Service $svc: "
  if kubectl get svc -n "$NAMESPACE" "$svc" >/dev/null 2>&1; then
    echo "present"
  else
    echo "MISSING"
    exit 2
  fi
done

echo "Attempt simple API probes via port-forward (short-lived)..."
# probe grafana
kubectl -n $NAMESPACE port-forward svc/grafana 3000:3000 >/dev/null 2>&1 &
PF_PID=$!
sleep 2
if curl -sSfL --max-time 5 http://127.0.0.1:3000/ >/dev/null; then
  echo "Grafana HTTP probe OK"
else
  echo "Grafana probe failed"
  kill $PF_PID || true
  exit 3
fi
kill $PF_PID || true

echo "Checking Prometheus targets..."
PROM_SVC=prometheus
if kubectl get svc -n $NAMESPACE $PROM_SVC >/dev/null 2>&1; then
  kubectl -n $NAMESPACE port-forward svc/$PROM_SVC 9090:9090 >/dev/null 2>&1 &
  PROM_PID=$!
  sleep 2
  if curl -sSfL --max-time 5 http://127.0.0.1:9090/-/healthy >/dev/null; then
    echo "Prometheus healthy"
  else
    echo "Prometheus health check failed"
    kill $PROM_PID || true
    exit 4
  fi
  # Check that at least one scrape target is UP
  if curl -sSfL --max-time 5 http://127.0.0.1:9090/api/v1/targets | grep -q "UP"; then
    echo "Prometheus has UP targets"
  else
    echo "No UP targets found in Prometheus"
  fi
  kill $PROM_PID || true
else
  echo "Prometheus service not found; skipping Prometheus checks"
fi

echo "Checking S3 connectivity via MinIO (if available)..."
if kubectl get svc -n $NAMESPACE minio >/dev/null 2>&1; then
  # Port-forward MinIO and attempt a simple HTTP probe (auth required for object ops)
  kubectl -n $NAMESPACE port-forward svc/minio 9000:9000 >/dev/null 2>&1 &
  MINIO_PID=$!
  sleep 2
  # Check HTTP endpoint
  if curl -sSfL --max-time 5 http://127.0.0.1:9000/ >/dev/null; then
    echo "MinIO endpoint reachable"
  else
    echo "MinIO HTTP probe failed"
    kill $MINIO_PID || true
    exit 5
  fi
  kill $MINIO_PID || true
else
  echo "MinIO not present in namespace; skipping S3 checks"
fi

echo "Observation stack looks healthy (basic checks). For full verification, run integration tests against the cluster endpoints."
