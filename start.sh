#!/bin/sh
# Start one HydraDB graph-node on local disk, then run a smoke test and log it.
# Works as root or as an unprivileged user (all paths live under /tmp).
set -eu

BASE=/tmp/hydra
mkdir -p "$BASE/store" "$BASE/cache" "$BASE/secrets"

# Random 64-hex-char token, generated here and never printed.
umask 077
head -c 32 /dev/urandom | od -An -tx1 | tr -d ' \n' >"$BASE/secrets/auth-token"
printf '\n' >>"$BASE/secrets/auth-token"
umask 022

export CLOUD_PROVIDER=local
export LOCAL_PATH="$BASE/store"
export GRAPH_NAMESPACE=default GRAPH_ID=default
export GRAPH_CELL_ID=cell-0 GRAPH_CELLS=cell-0 GRAPH_NODE_ID=node-0
export GRAPH_BOLT_ADDR=127.0.0.1:7687
HTTP_PORT="${PORT:-8443}"   # Render passes PORT; default 8443 elsewhere
export GRAPH_HTTP_ADDR="0.0.0.0:$HTTP_PORT"
# Small-box sizing (512 MB RAM free tiers). Values follow the community
# Railway template's formulas at a 512 MiB budget.
export GRAPH_SLATE_DB_CACHE_BYTES="${GRAPH_SLATE_DB_CACHE_BYTES:-167772160}"   # 160 MiB
export GRAPH_MAX_GRAPHBLAS_BYTES="${GRAPH_MAX_GRAPHBLAS_BYTES:-33554432}"      # 32 MiB
export GRAPH_DATA_CACHE_BYTES="${GRAPH_DATA_CACHE_BYTES:-268435456}"          # 256 MiB disk
export GRAPHBLAS_NTHREADS="${GRAPHBLAS_NTHREADS:-1}"
export OMP_NUM_THREADS="${OMP_NUM_THREADS:-1}"
export TOKIO_WORKER_THREADS="${TOKIO_WORKER_THREADS:-2}"
export MALLOC_ARENA_MAX="${MALLOC_ARENA_MAX:-2}"
export GRAPH_ADMIN_ADDR=127.0.0.1:9090
export GRAPH_BOLT_NODE_ADDRESSES=node-0=127.0.0.1:7687
export GRAPH_ADVERTISED_BOLT_ADDR=127.0.0.1:7687
export GRAPH_DATA_CACHE_DIR="$BASE/cache"
export GRAPH_AUTH_TOKEN_FILE="$BASE/secrets/auth-token"
export GRAPH_ALLOW_PLAINTEXT=true
export RUST_MIN_STACK=33554432
export HOME="$BASE"
cd "$BASE"

echo "[spike] starting graph-node as uid $(id -u)"
/usr/local/bin/graph-node &
NODE_PID=$!

smoke() {
  TOKEN="$(tr -d '\n' <"$BASE/secrets/auth-token")"
  Q="http://127.0.0.1:$HTTP_PORT/v1/graphs/default/query"
  run() {
    curl -sS -m 15 -X POST "$Q" \
      -H "Authorization: Bearer $TOKEN" \
      -H 'Content-Type: application/json' \
      --data "{\"cell_id\":\"cell-0\",\"query\":\"$1\"}" || echo "CURL_FAILED"
  }

  i=0
  until curl -sf -m 3 -o /dev/null http://127.0.0.1:9090/readyz; do
    i=$((i + 1))
    if [ "$i" -ge 120 ]; then echo "[spike] SMOKE FAIL: not ready after 120s"; return 0; fi
    sleep 1
  done
  echo "[spike] ready after ${i}s"

  echo "[spike] write: $(run 'MERGE (a {id: 1})-[:LINKS]->(b {id: 2})')"
  echo "[spike] write: $(run 'MERGE (a {id: 2})-[:LINKS]->(b {id: 3})')"
  echo "[spike] write: $(run 'MERGE (a {id: 3})-[:LINKS]->(b {id: 4})')"
  OUT="$(run 'MATCH (a {id: 1})-[:LINKS]->(b) RETURN b.id AS id')"
  echo "[spike] 1-hop read: $OUT"
  echo "[spike] 3-hop read: $(run 'MATCH (a {id: 1})-[:LINKS*1..3]->(b) RETURN b.id AS id')"
  case "$OUT" in
    *'"value":2'*) echo "[spike] SMOKE OK" ;;
    *) echo "[spike] SMOKE FAIL: unexpected read result" ;;
  esac
}

smoke &
set +e
wait "$NODE_PID"
STATUS=$?
echo "[spike] graph-node exited with status $STATUS"
exit "$STATUS"
