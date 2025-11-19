#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

echo "[guild_ownership_validator] validating guild ownership assignments"

# Check if yq is available for YAML parsing
if ! command -v yq >/dev/null 2>&1; then
  echo "[guild_ownership_validator] error: yq is required for YAML parsing. Install with: brew install yq" >&2
  exit 1
fi

# Check if jq is available for JSON parsing
if ! command -v jq >/dev/null 2>&1; then
  echo "[guild_ownership_validator] error: jq is required for JSON parsing. Install with: brew install jq" >&2
  exit 1
fi

GOBLINS_YAML="${REPO_ROOT}/goblins.yaml"
TASKS_JSON="${REPO_ROOT}/.vscode/tasks.json"

echo "[guild_ownership_validator] checking goblins.yaml structure..."

# Validate goblins.yaml has required structure
if [ ! -f "$GOBLINS_YAML" ]; then
  echo "[guild_ownership_validator] error: goblins.yaml not found" >&2
  exit 1
fi

# Check that all guilds have toolbelts
guild_count=$(yq '.guilds | length' "$GOBLINS_YAML")
if [ "$guild_count" -eq 0 ]; then
  echo "[guild_ownership_validator] error: no guilds found in goblins.yaml" >&2
  exit 1
fi

echo "[guild_ownership_validator] found $guild_count guilds"

# Check for tool ownership conflicts
echo "[guild_ownership_validator] checking for tool ownership conflicts..."

# Use a temporary file to track tool owners
temp_file=$(mktemp)
trap 'rm -f "$temp_file"' EXIT

# Extract all tools and their owners
for guild_idx in $(seq 0 $((guild_count - 1))); do
  guild_id=$(yq ".guilds[$guild_idx].id" "$GOBLINS_YAML")
  guild_name=$(yq ".guilds[$guild_idx].name" "$GOBLINS_YAML")

  toolbelt_count=$(yq ".guilds[$guild_idx].toolbelt | length" "$GOBLINS_YAML")
  for tool_idx in $(seq 0 $((toolbelt_count - 1))); do
    tool_id=$(yq ".guilds[$guild_idx].toolbelt[$tool_idx].id" "$GOBLINS_YAML")
    tool_owner=$(yq ".guilds[$guild_idx].toolbelt[$tool_idx].owner" "$GOBLINS_YAML")

    # Check if tool is already owned
    if grep -q "^$tool_id:" "$temp_file"; then
      existing_owner=$(grep "^$tool_id:" "$temp_file" | cut -d: -f2-)
      echo "[guild_ownership_validator] error: tool '$tool_id' owned by multiple guilds: $existing_owner and $guild_name ($guild_id)" >&2
      exit 1
    fi

    echo "$tool_id:$guild_name ($guild_id)" >> "$temp_file"
  done
done

tool_count=$(wc -l < "$temp_file")
echo "[guild_ownership_validator] no tool ownership conflicts found ($tool_count tools validated)"

# Check VS Code tasks alignment
echo "[guild_ownership_validator] checking VS Code tasks alignment..."

if [ ! -f "$TASKS_JSON" ]; then
  echo "[guild_ownership_validator] warning: .vscode/tasks.json not found, skipping task validation"
else
  # Count tasks with guild ownership indicators
  guild_task_count=$(jq '[.tasks[].label | select(test("^(🔨|🎨|⚙️|🚀|🧰|🎯|🛡️|🔮|🎛️|🔥)"))] | length' "$TASKS_JSON")
  total_task_count=$(jq '.tasks | length' "$TASKS_JSON")

  echo "[guild_ownership_validator] found $guild_task_count guild-owned tasks out of $total_task_count total tasks"

  if [ "$guild_task_count" -lt 5 ]; then
    echo "[guild_ownership_validator] warning: fewer than 5 guild-owned tasks found, may indicate missing guild assignments"
  fi
fi

# Check for orphaned tools (tools in toolbelt but no corresponding script)
echo "[guild_ownership_validator] checking for orphaned tools..."

while IFS=: read -r tool_id owner; do
  # Find the tool definition
  tool_command=$(yq ".guilds[].toolbelt[] | select(.id == \"$tool_id\") | .command" "$GOBLINS_YAML" | head -1)

  if [[ "$tool_command" == tools/* ]]; then
    tool_script="${REPO_ROOT}/${tool_command}"
    if [ ! -f "$tool_script" ]; then
      echo "[guild_ownership_validator] warning: tool '$tool_id' references missing script: $tool_script"
    fi
  fi
done < "$temp_file"

echo "[guild_ownership_validator] guild ownership validation completed successfully"
echo "[guild_ownership_validator] summary:"
echo "  - $guild_count guilds validated"
echo "  - $tool_count tools with proper ownership"
echo "  - no ownership conflicts detected"
