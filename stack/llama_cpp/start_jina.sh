#!/usr/bin/sh

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
STACK_DIR=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)
. "$STACK_DIR/env.sh"

require_dir "$LLAMA_CPP_BACKEND_DIR"
require_file "$JINA_EMBEDDING_MODEL"

cd "$LLAMA_CPP_BACKEND_DIR" || exit 1

./llama-server \
  -m "$JINA_EMBEDDING_MODEL" \
  --host 127.0.0.1 \
  --port 12346 \
  --embedding \
  --pooling last \
  -ub 32768
