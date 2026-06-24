#!/usr/bin/sh

set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
STACK_DIR=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)
. "$STACK_DIR/env.sh"

: "${GEMMA_HF_REPO:=unsloth/gemma-4-12B-it-qat-GGUF}"
: "${GEMMA_HF_LOCAL_DIR:=$LLM_MODELS_DIR/llama-cpp/models/unsloth/gemma-4-12B-it-qat-GGUF}"
: "${AGENTIC_GEMMA_HF_REPO:=yuxinlu1/gemma-4-12B-agentic-fable5-composer2.5-v2-3.5x-tau2-GGUF}"
: "${AGENTIC_GEMMA_HF_LOCAL_DIR:=$LLM_MODELS_DIR/llama-cpp/models/yuxinlu1/gemma-4-12B-agentic-fable5-composer2.5-v2-3.5x-tau2-GGUF}"

if ! command -v hf >/dev/null 2>&1; then
  echo "Missing command: hf" >&2
  echo "Install it with: pip install -U huggingface_hub" >&2
  exit 1
fi

download_if_missing() {
  repo=$1
  local_dir=$2
  path=$3

  if [ -f "$local_dir/$path" ]; then
    echo "Already exists: $local_dir/$path"
    return 0
  fi

  hf download "$repo" "$path" --local-dir "$local_dir"
}

download_if_missing "$GEMMA_HF_REPO" "$GEMMA_HF_LOCAL_DIR" \
  gemma-4-12B-it-qat-UD-Q4_K_XL.gguf
download_if_missing "$GEMMA_HF_REPO" "$GEMMA_HF_LOCAL_DIR" \
  mmproj-BF16.gguf
download_if_missing "$GEMMA_HF_REPO" "$GEMMA_HF_LOCAL_DIR" \
  mtp-gemma-4-12B-it.gguf

download_if_missing "$AGENTIC_GEMMA_HF_REPO" "$AGENTIC_GEMMA_HF_LOCAL_DIR" \
  gemma4-v2-Q4_K_M.gguf
download_if_missing "$AGENTIC_GEMMA_HF_REPO" "$AGENTIC_GEMMA_HF_LOCAL_DIR" \
  MTP/gemma-4-12B-it-MTP-BF16.gguf
