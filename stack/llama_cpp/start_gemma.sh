#!/usr/bin/sh

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
STACK_DIR=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)
. "$STACK_DIR/env.sh"

require_dir "$LLAMA_CPP_BACKEND_DIR"
require_file "$GEMMA_MODEL"

cd "$LLAMA_CPP_BACKEND_DIR" || exit 1

./llama-server \
  -m "$GEMMA_MODEL" \
  --ctx-size 16384 \
  --n-gpu-layers 99 \
  --no-mmap -fa on \
  --jinja \
  --temp 1.0 --top-p 0.95 --top-k 64 \
  --host 127.0.0.1 --port 12345
