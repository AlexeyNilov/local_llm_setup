#!/usr/bin/sh

set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
STACK_DIR=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)
. "$STACK_DIR/env.sh"

: "${GEMMA_HF_REPO:=unsloth/gemma-4-12B-it-qat-GGUF}"
: "${GEMMA_HF_LOCAL_DIR:=$LLM_MODELS_DIR/llama-cpp/models/unsloth/gemma-4-12B-it-qat-GGUF}"

if ! command -v hf >/dev/null 2>&1; then
  echo "Missing command: hf" >&2
  echo "Install it with: pip install -U huggingface_hub" >&2
  exit 1
fi

hf download "$GEMMA_HF_REPO" \
  gemma-4-12B-it-qat-UD-Q4_K_XL.gguf \
  mmproj-BF16.gguf \
  mtp-gemma-4-12B-it.gguf \
  --local-dir "$GEMMA_HF_LOCAL_DIR"
