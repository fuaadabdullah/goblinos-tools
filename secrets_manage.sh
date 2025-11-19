#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Support a quick audit mode that runs the secrets scanner wrapper.
if [[ ${1:-} == "--audit" ]]; then
	if [[ -x "$REPO_ROOT/tools/secrets/secrets_scan.sh" || -f "$REPO_ROOT/tools/secrets/secrets_scan.sh" ]]; then
		echo "Running secrets audit via tools/secrets/secrets_scan.sh --full"
		bash "$REPO_ROOT/tools/secrets/secrets_scan.sh" --full
		exit 0
	else
		echo "secrets_scan.sh not found; please ensure tools/secrets/secrets_scan.sh exists" >&2
		exit 2
	fi
fi

cat <<'EOF'
This helper shows safe commands to add API keys to the repository's secrets manager (smithy).

IMPORTANT:
- Do NOT paste secret values into chat or commit them to git.
- If you pasted secrets into a public place, rotate them immediately.

Recommended secure steps (run locally, replace <VALUE> with your secret):

# 1) Set a secret with smithy (preferred):
#    smithy secrets set OPENAI_API_KEY "<VALUE>"
#    smithy secrets set GEMINI_API_KEY "<VALUE>"

# 2) Sync specific secrets into a local .env file (developer convenience):
#    smithy secrets sync-env .env --keys OPENAI_API_KEY,GEMINI_API_KEY,PINECONE_API_KEY

# 3) For CI: Add the same secrets to your CI provider (GitHub Actions -> Settings -> Secrets)

# 4) To list managed secrets (redacted):
#    smithy secrets list

# 5) To get a secret value locally (careful):
#    smithy secrets get OPENAI_API_KEY

EOF

echo "Helper created: use the commands above to securely add secrets to smithy or your CI."

exit 0

