#!/usr/bin/env bash
set -euo pipefail

# Simple heuristic RLS audit for Supabase migrations.
# Usage: supabase_rls_check.sh [SUPABASE_DIR]

SUPABASE_DIR="${1:-apps/forge-lite/supabase}"

echo "🔎 Supabase RLS audit"
echo "📁 Target: ${SUPABASE_DIR}"

if ! command -v sed >/dev/null 2>&1; then
  echo "❌ sed not found; please install basic Unix tools." >&2
  exit 2
fi

if [ ! -d "$SUPABASE_DIR" ]; then
  echo "⚠️  Supabase dir not found: $SUPABASE_DIR" >&2
  echo "   Create it or pass the correct path (e.g., apps/forge-lite/supabase)." >&2
  exit 0
fi

MIGRATIONS_DIR="$SUPABASE_DIR/migrations"
if [ ! -d "$MIGRATIONS_DIR" ]; then
  echo "⚠️  No migrations directory at: $MIGRATIONS_DIR" >&2
  echo "   Tip: supabase migration new <name> and commit SQL files." >&2
  exit 0
fi

if ! command -v rg >/dev/null 2>&1; then
  GREP_CMD="grep -RIn"
else
  GREP_CMD="rg -n"
fi

echo
echo "— Collecting tables created in migrations —"
tables=$(\
  $GREP_CMD -i "^\\s*create\\s+table" "$MIGRATIONS_DIR" | \
  sed -E 's/.*create\s+table\s+(if\s+not\s+exists\s+)?//I' | \
  sed -E 's/\s*\(.*$//' | \
  sed -E 's/;.*$//' | \
  sed -E 's/"//g' | \
  awk '{print $1}' | \
  sed -E 's/^public\.//' | \
  sort -u
)

if [ -z "$tables" ]; then
  echo "No CREATE TABLE statements found in migrations."
else
  echo "$tables" | sed 's/^/ • /'
fi

echo
echo "— Checking RLS enablement for each table —"
missing_rls=()
while IFS= read -r tbl; do
  [ -z "$tbl" ] && continue
  if ! $GREP_CMD -i "alter\\s+table(\\s+if\\s+exists)?\\s+(public\\.)?\"?$tbl\"?\\s+enable\\s+row\\s+level\\s+security" "$MIGRATIONS_DIR" >/dev/null 2>&1; then
    missing_rls+=("$tbl")
  fi
done <<< "$tables"

if [ ${#missing_rls[@]} -eq 0 ]; then
  echo "✅ All created tables appear to enable Row Level Security."
else
  echo "⚠️  Tables missing explicit RLS enablement:"
  for t in "${missing_rls[@]}"; do echo " • $t"; done
  echo "   Add: ALTER TABLE public.<table> ENABLE ROW LEVEL SECURITY;"
fi

echo
echo "— Listing CREATE POLICY statements —"
if ! $GREP_CMD -i "create\\s+policy" "$MIGRATIONS_DIR" >/dev/null 2>&1; then
  echo "⚠️  No CREATE POLICY statements found in migrations."
  echo "   Ensure policies exist for tables with RLS enabled."
else
  # Print file:line and the policy line content
  $GREP_CMD -in "create\\s+policy" "$MIGRATIONS_DIR"
fi

echo
echo "— Extra checks —"
if $GREP_CMD -i "disable\\s+row\\s+level\\s+security" "$MIGRATIONS_DIR" >/dev/null 2>&1; then
  echo "⚠️  Found DISABLE RLS statements. Verify they are intentional."
fi

echo
echo "✅ RLS audit complete. Review warnings above if any."

exit 0

