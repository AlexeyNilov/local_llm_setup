#!/usr/bin/sh

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
STACK_DIR=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)
. "$STACK_DIR/env.sh"

require_dir "$LLAMA_CPP_BACKEND_DIR"
require_file "$GEMMA_MODEL"

cd "$LLAMA_CPP_BACKEND_DIR" || exit 1

: "${GEMMA_CTX_SIZE:=8192}"
: "${GEMMA_GPU_LAYERS:=all}"
: "${GEMMA_THREADS:=8}"
: "${GEMMA_THREADS_BATCH:=8}"
: "${GEMMA_BATCH_SIZE:=2048}"
: "${GEMMA_UBATCH_SIZE:=512}"
: "${GEMMA_PARALLEL:=1}"
: "${GEMMA_CACHE_TYPE_K:=f16}"
: "${GEMMA_CACHE_TYPE_V:=f16}"

./llama-server \
  -m "$GEMMA_MODEL" \
  --ctx-size "$GEMMA_CTX_SIZE" \
  --n-gpu-layers "$GEMMA_GPU_LAYERS" \
  --threads "$GEMMA_THREADS" \
  --threads-batch "$GEMMA_THREADS_BATCH" \
  --batch-size "$GEMMA_BATCH_SIZE" \
  --ubatch-size "$GEMMA_UBATCH_SIZE" \
  --parallel "$GEMMA_PARALLEL" \
  --cache-type-k "$GEMMA_CACHE_TYPE_K" \
  --cache-type-v "$GEMMA_CACHE_TYPE_V" \
  --mmap \
  -fa on \
  --cache-reuse 256 \
  --jinja \
  --temp 1.0 --top-p 0.95 --top-k 64 \
  --host 127.0.0.1 --port 12345
