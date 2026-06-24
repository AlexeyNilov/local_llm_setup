#!/usr/bin/sh

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
STACK_DIR=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)
. "$STACK_DIR/env.sh"

mkdir -p "$QDRANT_STORAGE_DIR"

sudo docker run -p 6333:6333 -p 6334:6334 -v "$QDRANT_STORAGE_DIR:/qdrant/storage:z" qdrant/qdrant
