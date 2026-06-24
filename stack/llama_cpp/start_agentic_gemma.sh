#!/usr/bin/sh

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
STACK_DIR=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)
. "$STACK_DIR/env.sh"

require_dir "$LLAMA_CPP_BACKEND_DIR"
require_file "$AGENTIC_GEMMA_MODEL"

cd "$LLAMA_CPP_BACKEND_DIR" || exit 1

: "${AGENTIC_GEMMA_CTX_SIZE:=150000}"
: "${AGENTIC_GEMMA_GPU_LAYERS:=all}"
: "${AGENTIC_GEMMA_DEVICE:=Vulkan0}"
: "${AGENTIC_GEMMA_THREADS:=8}"
: "${AGENTIC_GEMMA_THREADS_BATCH:=8}"
: "${AGENTIC_GEMMA_BATCH_SIZE:=2048}"
: "${AGENTIC_GEMMA_UBATCH_SIZE:=512}"
: "${AGENTIC_GEMMA_PARALLEL:=1}"
: "${AGENTIC_GEMMA_CACHE_TYPE_K:=f16}"
: "${AGENTIC_GEMMA_CACHE_TYPE_V:=f16}"
: "${AGENTIC_GEMMA_FLASH_ATTN:=on}"
: "${AGENTIC_GEMMA_MODEL_ALIAS:=gemma-4-12b}"
: "${AGENTIC_GEMMA_HOST:=127.0.0.1}"
: "${AGENTIC_GEMMA_PORT:=12345}"
: "${AGENTIC_GEMMA_SPEC_TYPE:=draft-mtp}"
: "${AGENTIC_GEMMA_SPEC_DRAFT_N_MAX:=4}"
: "${AGENTIC_GEMMA_SPEC_DRAFT_DEVICE:=$AGENTIC_GEMMA_DEVICE}"
: "${AGENTIC_GEMMA_SPEC_DRAFT_GPU_LAYERS:=$AGENTIC_GEMMA_GPU_LAYERS}"

SPEC_ARGS=
if [ "$AGENTIC_GEMMA_SPEC_TYPE" != "none" ]; then
  require_file "$AGENTIC_GEMMA_MTP_MODEL"
  SPEC_ARGS="
    --spec-type $AGENTIC_GEMMA_SPEC_TYPE
    --spec-draft-model $AGENTIC_GEMMA_MTP_MODEL
    --spec-draft-n-max $AGENTIC_GEMMA_SPEC_DRAFT_N_MAX
    --spec-draft-device $AGENTIC_GEMMA_SPEC_DRAFT_DEVICE
    --spec-draft-ngl $AGENTIC_GEMMA_SPEC_DRAFT_GPU_LAYERS"
fi

# shellcheck disable=SC2086
./llama-server \
  -m "$AGENTIC_GEMMA_MODEL" \
  --alias "$AGENTIC_GEMMA_MODEL_ALIAS" \
  --ctx-size "$AGENTIC_GEMMA_CTX_SIZE" \
  --n-gpu-layers "$AGENTIC_GEMMA_GPU_LAYERS" \
  --device "$AGENTIC_GEMMA_DEVICE" \
  --threads "$AGENTIC_GEMMA_THREADS" \
  --threads-batch "$AGENTIC_GEMMA_THREADS_BATCH" \
  --batch-size "$AGENTIC_GEMMA_BATCH_SIZE" \
  --ubatch-size "$AGENTIC_GEMMA_UBATCH_SIZE" \
  --parallel "$AGENTIC_GEMMA_PARALLEL" \
  --cache-type-k "$AGENTIC_GEMMA_CACHE_TYPE_K" \
  --cache-type-v "$AGENTIC_GEMMA_CACHE_TYPE_V" \
  --mmap \
  --flash-attn "$AGENTIC_GEMMA_FLASH_ATTN" \
  --cache-reuse 256 \
  --jinja \
  --temp 1.0 --top-p 0.95 --top-k 64 \
  --host "$AGENTIC_GEMMA_HOST" --port "$AGENTIC_GEMMA_PORT" \
  $SPEC_ARGS
