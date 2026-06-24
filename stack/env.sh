#!/usr/bin/sh

if [ -z "${STACK_DIR:-}" ]; then
  echo "STACK_DIR must be set before sourcing stack/env.sh" >&2
  exit 1
fi

if [ -f "$STACK_DIR/env.local.sh" ]; then
  . "$STACK_DIR/env.local.sh"
fi

: "${LLM_HOME:=$HOME}"
: "${LLM_DOWNLOADS:=$LLM_HOME/Downloads}"
: "${LMSTUDIO_HOME:=$LLM_HOME/.lmstudio}"
: "${LLM_MODELS_DIR:=$LLM_DOWNLOADS/models}"
: "${LLM_BACKENDS_DIR:=$LLM_DOWNLOADS/backends}"
: "${QDRANT_STORAGE_DIR:=$LLM_HOME/qdrant_storage}"
: "${LLAMA_CPP_BACKEND_DIR:=$LMSTUDIO_HOME/extensions/backends/llama.cpp-linux-x86_64-vulkan-avx2-2.22.0}"
# : "${LLAMA_CPP_BACKEND_DIR:=$LMSTUDIO_HOME/Downloads/backends/llama-cpp-vulkan-full}"
: "${JINA_EMBEDDING_MODEL:=$LMSTUDIO_HOME/models/jinaai/jina-embeddings-v5-text-small-retrieval/v5-small-retrieval-Q8_0.gguf}"
: "${GEMMA_MODEL:=$LMSTUDIO_HOME/models/lmstudio-community/gemma-4-12B-it-QAT-GGUF/gemma-4-12B-it-QAT-Q4_0.gguf}"
# : "${GEMMA_MODEL:=$LLM_MODELS_DIR/llama-cpp/models/gemma-4-12B-agentic-fable5-composer2.5-v2-3.5x-tau2-GGUF/gemma4-v2-Q4_K_M.gguf}"
: "${LM_STUDIO_APPIMAGE:=$LLM_DOWNLOADS/LM-Studio-0.4.16-1-x64.AppImage}"

require_dir() {
  if [ ! -d "$1" ]; then
    echo "Missing directory: $1" >&2
    exit 1
  fi
}

require_file() {
  if [ ! -f "$1" ]; then
    echo "Missing file: $1" >&2
    exit 1
  fi
}
