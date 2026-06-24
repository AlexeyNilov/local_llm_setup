#!/usr/bin/sh

set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
STACK_DIR=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)
REPO_DIR=$(CDPATH= cd -- "$STACK_DIR/.." && pwd)
. "$STACK_DIR/env.sh"

: "${GEMMA_SERVER_BENCH_PORT:=12346}"
: "${GEMMA_SERVER_BENCH_HOST:=127.0.0.1}"
: "${GEMMA_SERVER_BENCH_OUTPUT_DIR:=$REPO_DIR/bench/server-results}"
: "${GEMMA_SERVER_BENCH_REPETITIONS:=3}"
: "${GEMMA_SERVER_BENCH_NGL:=all}"
: "${GEMMA_SERVER_BENCH_DEVICE:=Vulkan0}"
: "${GEMMA_SERVER_BENCH_THREADS:=8}"
: "${GEMMA_SERVER_BENCH_THREADS_BATCH:=8}"
: "${GEMMA_SERVER_BENCH_BATCH:=2048}"
: "${GEMMA_SERVER_BENCH_UBATCH:=512}"
: "${GEMMA_SERVER_BENCH_CTX:=8192}"
: "${GEMMA_SERVER_BENCH_CACHE_K:=f16}"
: "${GEMMA_SERVER_BENCH_CACHE_V:=f16}"
: "${GEMMA_SERVER_BENCH_FLASH_ATTN:=on}"
: "${GEMMA_SERVER_BENCH_MTP_N_MAX:=4}"

SERVER_BIN="$LLAMA_CPP_BACKEND_DIR/llama-server"
RESULT_DIR="$GEMMA_SERVER_BENCH_OUTPUT_DIR/$(date +%Y%m%d-%H%M%S)"
BASE_URL="http://$GEMMA_SERVER_BENCH_HOST:$GEMMA_SERVER_BENCH_PORT"
SERVER_PID=""

usage() {
  cat <<EOF
Usage: $0 <command>

Commands:
  dry-run       Print baseline and MTP server commands without running them.
  run           Run baseline and MTP server benchmarks.

Environment:
  GEMMA_MODEL                         $GEMMA_MODEL
  GEMMA_MTP_MODEL                     $GEMMA_MTP_MODEL
  GEMMA_SERVER_BENCH_PORT             $GEMMA_SERVER_BENCH_PORT
  GEMMA_SERVER_BENCH_REPETITIONS      $GEMMA_SERVER_BENCH_REPETITIONS
  GEMMA_SERVER_BENCH_OUTPUT_DIR       $GEMMA_SERVER_BENCH_OUTPUT_DIR
  GEMMA_SERVER_BENCH_MTP_N_MAX        $GEMMA_SERVER_BENCH_MTP_N_MAX
EOF
}

require_file "$SERVER_BIN"
require_file "$GEMMA_MODEL"
require_file "$GEMMA_MTP_MODEL"

common_server_args() {
  printf '%s\n' \
    -m "$GEMMA_MODEL" \
    --alias gemma-mtp-bench \
    --ctx-size "$GEMMA_SERVER_BENCH_CTX" \
    --n-gpu-layers "$GEMMA_SERVER_BENCH_NGL" \
    --device "$GEMMA_SERVER_BENCH_DEVICE" \
    --threads "$GEMMA_SERVER_BENCH_THREADS" \
    --threads-batch "$GEMMA_SERVER_BENCH_THREADS_BATCH" \
    --batch-size "$GEMMA_SERVER_BENCH_BATCH" \
    --ubatch-size "$GEMMA_SERVER_BENCH_UBATCH" \
    --parallel 1 \
    --cache-type-k "$GEMMA_SERVER_BENCH_CACHE_K" \
    --cache-type-v "$GEMMA_SERVER_BENCH_CACHE_V" \
    --mmap \
    --flash-attn "$GEMMA_SERVER_BENCH_FLASH_ATTN" \
    --cache-reuse 256 \
    --jinja \
    --temp 0 \
    --host "$GEMMA_SERVER_BENCH_HOST" \
    --port "$GEMMA_SERVER_BENCH_PORT"
}

server_cmd() {
  mode=$1
  if [ "$mode" = "mtp" ]; then
    printf '%s ' "$SERVER_BIN"
    common_server_args | tr '\n' ' '
    printf '%s\n' "--spec-type draft-mtp --spec-draft-model $GEMMA_MTP_MODEL --spec-draft-n-max $GEMMA_SERVER_BENCH_MTP_N_MAX --spec-draft-device $GEMMA_SERVER_BENCH_DEVICE --spec-draft-ngl $GEMMA_SERVER_BENCH_NGL"
  else
    printf '%s ' "$SERVER_BIN"
    common_server_args | tr '\n' ' '
    printf '\n'
  fi
}

stop_server() {
  if [ -n "$SERVER_PID" ] && kill -0 "$SERVER_PID" 2>/dev/null; then
    kill "$SERVER_PID" 2>/dev/null || true
    wait "$SERVER_PID" 2>/dev/null || true
  fi
  SERVER_PID=""
}

wait_for_server() {
  i=0
  while [ "$i" -lt 120 ]; do
    if curl -fsS "$BASE_URL/health" >/dev/null 2>&1; then
      return 0
    fi
    i=$((i + 1))
    sleep 1
  done
  return 1
}

ensure_port_free() {
  python3 - "$GEMMA_SERVER_BENCH_HOST" "$GEMMA_SERVER_BENCH_PORT" <<'PY'
import socket
import sys

host = sys.argv[1]
port = int(sys.argv[2])
sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
try:
    sock.bind((host, port))
except OSError as exc:
    print(f"{host}:{port} is not available: {exc}", file=sys.stderr)
    sys.exit(1)
finally:
    sock.close()
PY
}

start_server() {
  mode=$1
  out_dir=$2
  mkdir -p "$out_dir"
  server_cmd "$mode" > "$out_dir/server-command.txt"

  cd "$LLAMA_CPP_BACKEND_DIR" || exit 1
  if [ "$mode" = "mtp" ]; then
    # shellcheck disable=SC2046
    "$SERVER_BIN" $(common_server_args) \
      --spec-type draft-mtp \
      --spec-draft-model "$GEMMA_MTP_MODEL" \
      --spec-draft-n-max "$GEMMA_SERVER_BENCH_MTP_N_MAX" \
      --spec-draft-device "$GEMMA_SERVER_BENCH_DEVICE" \
      --spec-draft-ngl "$GEMMA_SERVER_BENCH_NGL" \
      > "$out_dir/server.log" 2>&1 &
  else
    # shellcheck disable=SC2046
    "$SERVER_BIN" $(common_server_args) > "$out_dir/server.log" 2>&1 &
  fi
  SERVER_PID=$!

  if ! wait_for_server; then
    stop_server
    echo "Server did not become healthy for mode: $mode" >&2
    echo "See: $out_dir/server.log" >&2
    exit 1
  fi
}

write_payload() {
  name=$1
  n_predict=$2
  out=$3
  python3 - "$name" "$n_predict" "$out" <<'PY'
import json
import sys

name, n_predict, out = sys.argv[1], int(sys.argv[2]), sys.argv[3]
prompts = {
    "short": "Explain why hash maps are usually O(1). Keep the answer practical and concise.",
    "medium": """You are reviewing a Python service that intermittently times out under load.
Give a concrete debugging plan covering metrics, logs, dependency latency, queueing, and rollback criteria.
Avoid generic advice; focus on what an SRE should check first.""",
    "long": """We run a local LLM stack with llama.cpp, a Vulkan AMD GPU backend, Qdrant for retrieval, and small shell scripts for service management.
The goal is to improve interactive latency without making the setup fragile.
Analyze the tradeoffs among smaller context windows, prompt caching, speculative decoding, batch sizes, and full GPU offload.
Give a decision framework and call out measurements that would falsify each optimization.""",
    "coding": """Write a POSIX shell function wait_for_http_health URL TIMEOUT_SECONDS that polls the URL once per second and returns 0 only if curl succeeds before timeout.
It should print a useful error to stderr on timeout and avoid bash-only syntax.""",
}
payload = {
    "prompt": prompts[name],
    "n_predict": n_predict,
    "temperature": 0,
    "cache_prompt": False,
}
with open(out, "w", encoding="utf-8") as f:
    json.dump(payload, f)
PY
}

run_case() {
  mode=$1
  name=$2
  n_predict=$3
  rep=$4
  out_dir="$RESULT_DIR/$mode/$name"
  mkdir -p "$out_dir"
  payload="$out_dir/payload.json"
  response="$out_dir/response-$rep.json"
  curl_timing="$out_dir/curl-time-$rep.txt"

  write_payload "$name" "$n_predict" "$payload"
  curl -fsS \
    -H 'Content-Type: application/json' \
    -w 'wall_seconds=%{time_total}\n' \
    -o "$response" \
    -d "@$payload" \
    "$BASE_URL/completion" > "$curl_timing"
}

run_mode() {
  mode=$1
  mode_dir="$RESULT_DIR/$mode"
  start_server "$mode" "$mode_dir"

  rep=1
  while [ "$rep" -le "$GEMMA_SERVER_BENCH_REPETITIONS" ]; do
    run_case "$mode" short 128 "$rep"
    run_case "$mode" medium 256 "$rep"
    run_case "$mode" long 256 "$rep"
    run_case "$mode" coding 512 "$rep"
    rep=$((rep + 1))
  done

  stop_server
}

write_metadata() {
  mkdir -p "$RESULT_DIR"
  {
    printf 'timestamp=%s\n' "$(date --iso-8601=seconds)"
    printf 'repo=%s\n' "$REPO_DIR"
    printf 'backend=%s\n' "$LLAMA_CPP_BACKEND_DIR"
    printf 'server_bin=%s\n' "$SERVER_BIN"
    printf 'model=%s\n' "$GEMMA_MODEL"
    printf 'mtp_model=%s\n' "$GEMMA_MTP_MODEL"
    printf 'host=%s\n' "$GEMMA_SERVER_BENCH_HOST"
    printf 'port=%s\n' "$GEMMA_SERVER_BENCH_PORT"
    printf 'repetitions=%s\n' "$GEMMA_SERVER_BENCH_REPETITIONS"
  } > "$RESULT_DIR/metadata.env"

  if command -v rocm-smi >/dev/null 2>&1; then
    rocm-smi > "$RESULT_DIR/rocm-smi-before.txt" 2>&1 || true
  fi
  git -C "$REPO_DIR" status --short > "$RESULT_DIR/git-status.txt" 2>&1 || true
}

summarize() {
  python3 - "$RESULT_DIR" <<'PY'
import csv
import json
import pathlib
import statistics
import sys

root = pathlib.Path(sys.argv[1])
rows = []
for mode_dir in sorted(p for p in root.iterdir() if p.is_dir()):
    mode = mode_dir.name
    for case_dir in sorted(p for p in mode_dir.iterdir() if p.is_dir()):
        case = case_dir.name
        for response in sorted(case_dir.glob("response-*.json")):
            rep = response.stem.split("-")[-1]
            data = json.loads(response.read_text())
            timing_file = case_dir / f"curl-time-{rep}.txt"
            wall = None
            if timing_file.exists():
                text = timing_file.read_text().strip()
                if text.startswith("wall_seconds="):
                    wall = float(text.split("=", 1)[1])
            timings = data.get("timings", {})
            rows.append({
                "mode": mode,
                "case": case,
                "rep": int(rep),
                "wall_seconds": wall,
                "prompt_tokens": timings.get("prompt_n"),
                "prompt_tok_s": timings.get("prompt_per_second"),
                "predicted_tokens": timings.get("predicted_n"),
                "predicted_tok_s": timings.get("predicted_per_second"),
            })

with (root / "summary.csv").open("w", newline="", encoding="utf-8") as f:
    writer = csv.DictWriter(f, fieldnames=[
        "mode", "case", "rep", "wall_seconds", "prompt_tokens",
        "prompt_tok_s", "predicted_tokens", "predicted_tok_s",
    ])
    writer.writeheader()
    writer.writerows(rows)

groups = {}
for row in rows:
    groups.setdefault((row["mode"], row["case"]), []).append(row)

lines = [
    "| mode | case | avg wall s | avg gen tok/s | avg prompt tok/s | reps |",
    "|---|---|---:|---:|---:|---:|",
]
for (mode, case), items in sorted(groups.items()):
    wall = [x["wall_seconds"] for x in items if x["wall_seconds"] is not None]
    gen = [x["predicted_tok_s"] for x in items if x["predicted_tok_s"] is not None]
    prompt = [x["prompt_tok_s"] for x in items if x["prompt_tok_s"] is not None]
    lines.append(
        f"| {mode} | {case} | "
        f"{statistics.mean(wall):.3f} | "
        f"{statistics.mean(gen):.2f} | "
        f"{statistics.mean(prompt):.1f} | "
        f"{len(items)} |"
    )
(root / "summary.md").write_text("\n".join(lines) + "\n", encoding="utf-8")
print(root / "summary.md")
PY
}

run_all() {
  ensure_port_free
  write_metadata
  trap stop_server EXIT INT TERM
  run_mode baseline
  run_mode mtp
  if command -v rocm-smi >/dev/null 2>&1; then
    rocm-smi > "$RESULT_DIR/rocm-smi-after.txt" 2>&1 || true
  fi
  summarize
  printf 'results: %s\n' "$RESULT_DIR"
}

case "${1:-}" in
  dry-run)
    server_cmd baseline
    server_cmd mtp
    ;;
  run)
    run_all
    ;;
  -h|--help|help)
    usage
    ;;
  *)
    usage >&2
    exit 2
    ;;
esac
