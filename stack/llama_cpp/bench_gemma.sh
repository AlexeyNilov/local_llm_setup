#!/usr/bin/sh

set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
STACK_DIR=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)
REPO_DIR=$(CDPATH= cd -- "$STACK_DIR/.." && pwd)
. "$STACK_DIR/env.sh"

: "${GEMMA_BENCH_THREADS:=8}"
: "${GEMMA_BENCH_REPETITIONS:=5}"
: "${GEMMA_BENCH_GPU_LAYERS:=999}"
: "${GEMMA_BENCH_DEVICE:=Vulkan0}"
: "${GEMMA_BENCH_OUTPUT_DIR:=$REPO_DIR/bench/results}"

BENCH_BIN="$LLAMA_CPP_BENCH_BACKEND_DIR/llama-bench"
RESULT_DIR="$GEMMA_BENCH_OUTPUT_DIR/$(date +%Y%m%d-%H%M%S)"

usage() {
  cat <<EOF
Usage: $0 <command>

Commands:
  dry-run       Print the benchmark plan without running llama-bench.
  devices       Run llama-bench --list-devices using the benchmark backend.
  run           Run the benchmark suite and write results under bench/results/.

Environment:
  LLAMA_CPP_BENCH_BACKEND_DIR  $LLAMA_CPP_BENCH_BACKEND_DIR
  GEMMA_MODEL                  $GEMMA_MODEL
  GEMMA_BENCH_THREADS          $GEMMA_BENCH_THREADS
  GEMMA_BENCH_REPETITIONS      $GEMMA_BENCH_REPETITIONS
  GEMMA_BENCH_GPU_LAYERS       $GEMMA_BENCH_GPU_LAYERS
  GEMMA_BENCH_DEVICE           $GEMMA_BENCH_DEVICE
  GEMMA_BENCH_OUTPUT_DIR       $GEMMA_BENCH_OUTPUT_DIR
EOF
}

require_file "$BENCH_BIN"
require_file "$GEMMA_MODEL"

common_args() {
  printf '%s\n' \
    -m "$GEMMA_MODEL" \
    -r "$GEMMA_BENCH_REPETITIONS" \
    -o jsonl \
    -t "$GEMMA_BENCH_THREADS" \
    -dev "$GEMMA_BENCH_DEVICE" \
    -mmp 1
}

bench_case() {
  name=$1
  shift
  out="$RESULT_DIR/$name.jsonl"
  cmd="$BENCH_BIN $(common_args | tr '\n' ' ') $*"

  if [ "${DRY_RUN:-0}" = "1" ]; then
    printf '%s\n' "$cmd"
    return
  fi

  printf '%s\n' "$cmd" >> "$RESULT_DIR/commands.txt"
  printf 'running %s\n' "$name"
  # shellcheck disable=SC2046
  "$BENCH_BIN" $(common_args) "$@" > "$out"
}

write_metadata() {
  mkdir -p "$RESULT_DIR"
  {
    printf 'timestamp=%s\n' "$(date --iso-8601=seconds)"
    printf 'repo=%s\n' "$REPO_DIR"
    printf 'backend=%s\n' "$LLAMA_CPP_BENCH_BACKEND_DIR"
    printf 'bench_bin=%s\n' "$BENCH_BIN"
    printf 'model=%s\n' "$GEMMA_MODEL"
    printf 'threads=%s\n' "$GEMMA_BENCH_THREADS"
    printf 'repetitions=%s\n' "$GEMMA_BENCH_REPETITIONS"
    printf 'gpu_layers=%s\n' "$GEMMA_BENCH_GPU_LAYERS"
    printf 'device=%s\n' "$GEMMA_BENCH_DEVICE"
  } > "$RESULT_DIR/metadata.env"

  if command -v rocm-smi >/dev/null 2>&1; then
    rocm-smi > "$RESULT_DIR/rocm-smi.txt" 2>&1 || true
  fi

  "$BENCH_BIN" --list-devices > "$RESULT_DIR/devices.txt" 2>&1 || true
  git -C "$REPO_DIR" status --short > "$RESULT_DIR/git-status.txt" 2>&1 || true
}

run_suite() {
  if [ "${DRY_RUN:-0}" != "1" ]; then
    write_metadata
  fi

  bench_case baseline_pg_512_128 -ngl "$GEMMA_BENCH_GPU_LAYERS" -fa on -b 2048 -ub 512 -ctk f16 -ctv f16 -pg 512,128

  bench_case workload_pg_128_128 -ngl "$GEMMA_BENCH_GPU_LAYERS" -fa on -b 2048 -ub 512 -ctk f16 -ctv f16 -pg 128,128
  bench_case workload_pg_2048_128 -ngl "$GEMMA_BENCH_GPU_LAYERS" -fa on -b 2048 -ub 512 -ctk f16 -ctv f16 -pg 2048,128
  bench_case workload_pg_4096_256 -ngl "$GEMMA_BENCH_GPU_LAYERS" -fa on -b 2048 -ub 512 -ctk f16 -ctv f16 -pg 4096,256

  bench_case cache_f16_f16 -ngl "$GEMMA_BENCH_GPU_LAYERS" -fa on -b 2048 -ub 512 -ctk f16 -ctv f16 -pg 512,128
  bench_case cache_q8_q8 -ngl "$GEMMA_BENCH_GPU_LAYERS" -fa on -b 2048 -ub 512 -ctk q8_0 -ctv q8_0 -pg 512,128
  bench_case cache_q4_q4 -ngl "$GEMMA_BENCH_GPU_LAYERS" -fa on -b 2048 -ub 512 -ctk q4_0 -ctv q4_0 -pg 512,128

  bench_case batch_1024_256 -ngl "$GEMMA_BENCH_GPU_LAYERS" -fa on -b 1024 -ub 256 -ctk f16 -ctv f16 -pg 512,128
  bench_case batch_2048_512 -ngl "$GEMMA_BENCH_GPU_LAYERS" -fa on -b 2048 -ub 512 -ctk f16 -ctv f16 -pg 512,128
  bench_case batch_4096_512 -ngl "$GEMMA_BENCH_GPU_LAYERS" -fa on -b 4096 -ub 512 -ctk f16 -ctv f16 -pg 512,128
  bench_case batch_4096_1024 -ngl "$GEMMA_BENCH_GPU_LAYERS" -fa on -b 4096 -ub 1024 -ctk f16 -ctv f16 -pg 512,128

  bench_case flash_on -ngl "$GEMMA_BENCH_GPU_LAYERS" -fa on -b 2048 -ub 512 -ctk f16 -ctv f16 -pg 512,128
  bench_case flash_auto -ngl "$GEMMA_BENCH_GPU_LAYERS" -fa auto -b 2048 -ub 512 -ctk f16 -ctv f16 -pg 512,128
  bench_case flash_off -ngl "$GEMMA_BENCH_GPU_LAYERS" -fa off -b 2048 -ub 512 -ctk f16 -ctv f16 -pg 512,128

  bench_case offload_cpu -ngl 0 -fa on -b 2048 -ub 512 -ctk f16 -ctv f16 -pg 512,128
  bench_case offload_gpu -ngl "$GEMMA_BENCH_GPU_LAYERS" -fa on -b 2048 -ub 512 -ctk f16 -ctv f16 -pg 512,128

  if [ "${DRY_RUN:-0}" != "1" ]; then
    printf 'results: %s\n' "$RESULT_DIR"
  fi
}

case "${1:-}" in
  dry-run)
    DRY_RUN=1
    run_suite
    ;;
  devices)
    "$BENCH_BIN" --list-devices
    ;;
  run)
    run_suite
    ;;
  -h|--help|help)
    usage
    ;;
  *)
    usage >&2
    exit 2
    ;;
esac
