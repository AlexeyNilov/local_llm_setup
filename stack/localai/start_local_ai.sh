#!/usr/bin/sh

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
STACK_DIR=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)
. "$STACK_DIR/env.sh"

require_dir "$LLM_MODELS_DIR"
require_dir "$LLM_BACKENDS_DIR"

sudo docker run -e REBUILD=true -ti --name local-ai-vulkan -p 8080:8080 \
--device=/dev/kfd --device=/dev/dri \
-v "$LLM_MODELS_DIR:/models" -v "$LLM_BACKENDS_DIR:/backends" \
localai/localai:latest-gpu-vulkan
