---title: Tools
type: reference
project: ForgeMonorepo
status: draft
owner: GoblinOS
description: "README"

---

Cross-repository scripts, generators, and utilities. Ownership per guild/goblin is tracked in `tools/AGENT_TOOLS.md` under the Guild Tool Ownership Matrix.

## Contents

- `lint_all.sh` - Run linters across all projects
- `smoke.sh` - Health check for all services
- `forge-new/` - Scaffolding tool for new packages
- `templates/` - Reusable templates
 - `vscode_cleanup.sh` - Helper to inspect/archive/remove local VS Code workspace/global storage and extensions (opt-in, conservative)

## Usage

Scripts should be run from the repository root:

```bash
bash tools/lint_all.sh
bash tools/smoke.sh
```
