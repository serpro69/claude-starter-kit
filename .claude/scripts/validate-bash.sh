#!/bin/bash

# Read JSON input from stdin
INPUT=$(cat)

# Extract the command from JSON - correct path
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')

# If no command found, allow it
if [ -z "$COMMAND" ]; then
  exit 0
fi

# Define forbidden patterns
FORBIDDEN_PATTERNS=(
  "\.env"
  "\.ansible/"
  "\.terraform/"
  "build/"
  "dist/"
  "node_modules"
  "__pycache__"
  "\.git/"
  "venv/"
  "\.pyc$"
  "\.csv$"
  "\.log$"
)

# Check if command contains any forbidden patterns
for pattern in "${FORBIDDEN_PATTERNS[@]}"; do
  if echo "$COMMAND" | grep -qE "$pattern"; then
    echo "ERROR: Access to '$pattern' is blocked by security policy" >&2
    exit 2 # Exit code 2 = blocking error
  fi
done

# Command is clean, allow it
exit 0
