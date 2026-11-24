#!/bin/bash
# Starts Pinball Editor 2D. Needs Godot 4.7.2: set GODOT=/path/to/godot or have "godot" in your PATH.
cd "$(dirname "$0")"
exec "${GODOT:-godot}" --path . res://editor/editor.tscn "$@"
