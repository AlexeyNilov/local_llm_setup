#!/usr/bin/sh

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
STACK_DIR=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)
. "$STACK_DIR/env.sh"

require_dir "$LLAMA_CPP_BACKEND_DIR"
require_file "$GEMMA_MODEL"

cd "$LLAMA_CPP_BACKEND_DIR" || exit 1

: "${GEMMA_CTX_SIZE:=8192}"
: "${GEMMA_GPU_LAYERS:=all}"
: "${GEMMA_DEVICE:=Vulkan0}"
: "${GEMMA_THREADS:=8}"
: "${GEMMA_THREADS_BATCH:=8}"
: "${GEMMA_BATCH_SIZE:=2048}"
: "${GEMMA_UBATCH_SIZE:=512}"
: "${GEMMA_PARALLEL:=1}"
: "${GEMMA_CACHE_TYPE_K:=f16}"
: "${GEMMA_CACHE_TYPE_V:=f16}"
: "${GEMMA_FLASH_ATTN:=on}"
: "${GEMMA_MODEL_ALIAS:=gemma-4-12b}"
: "${GEMMA_SPEC_TYPE:=draft-mtp}"
: "${GEMMA_SPEC_DRAFT_N_MAX:=4}"
: "${GEMMA_SPEC_DRAFT_DEVICE:=$GEMMA_DEVICE}"
: "${GEMMA_SPEC_DRAFT_GPU_LAYERS:=$GEMMA_GPU_LAYERS}"

SPEC_ARGS=
if [ "$GEMMA_SPEC_TYPE" != "none" ]; then
  require_file "$GEMMA_MTP_MODEL"
  SPEC_ARGS="
    --spec-type $GEMMA_SPEC_TYPE
    --spec-draft-model $GEMMA_MTP_MODEL
    --spec-draft-n-max $GEMMA_SPEC_DRAFT_N_MAX
    --spec-draft-device $GEMMA_SPEC_DRAFT_DEVICE
    --spec-draft-ngl $GEMMA_SPEC_DRAFT_GPU_LAYERS"
fi

# shellcheck disable=SC2086
./llama-server \
  -m "$GEMMA_MODEL" \
  --alias "$GEMMA_MODEL_ALIAS" \
  --ctx-size "$GEMMA_CTX_SIZE" \
  --n-gpu-layers "$GEMMA_GPU_LAYERS" \
  --device "$GEMMA_DEVICE" \
  --threads "$GEMMA_THREADS" \
  --threads-batch "$GEMMA_THREADS_BATCH" \
  --batch-size "$GEMMA_BATCH_SIZE" \
  --ubatch-size "$GEMMA_UBATCH_SIZE" \
  --parallel "$GEMMA_PARALLEL" \
  --cache-type-k "$GEMMA_CACHE_TYPE_K" \
  --cache-type-v "$GEMMA_CACHE_TYPE_V" \
  --mmap \
  --flash-attn "$GEMMA_FLASH_ATTN" \
  --cache-reuse 256 \
  --jinja \
  --temp 1.0 --top-p 0.95 --top-k 64 \
  --host 127.0.0.1 --port 12345 \
  $SPEC_ARGS
