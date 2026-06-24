#!/usr/bin/sh

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
STACK_DIR=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)
. "$STACK_DIR/env.sh"

require_file "$LM_STUDIO_APPIMAGE"

"$LM_STUDIO_APPIMAGE" --no-sandbox
