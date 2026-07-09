#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

fail() {
  echo "clean-repo check failed: $*" >&2
  exit 1
}

if ! command -v rg >/dev/null 2>&1; then
  fail "ripgrep is required"
fi

if [[ -d .git ]]; then
  tracked_paths="$(git ls-files | grep -v '^scripts/check_clean_repo.sh$')"
  for path in \
    "data/" \
    "output/" \
    "dist/" \
    "macos/dist/" \
    "macos/.build/" \
    "node_modules/" \
    ".env"; do
    if grep -q "^$path" <<<"$tracked_paths"; then
      fail "tracked runtime or generated path: $path"
    fi
  done
  scan_args=(--files-with-matches --hidden --glob '!scripts/check_clean_repo.sh')
  while IFS= read -r file; do
    scan_args+=("$file")
  done <<<"$tracked_paths"
else
  scan_args=(
    --files-with-matches
    --hidden
    --glob '!scripts/check_clean_repo.sh'
    --glob '!.git/**'
    --glob '!node_modules/**'
    --glob '!dist/**'
    --glob '!macos/.build/**'
    --glob '!macos/dist/**'
    --glob '!data/**'
    --glob '!output/**'
    .
  )
fi

for pattern in \
  "Alvin" \
  "Stark" \
  "Medela" \
  "McKinsey" \
  "QuantumBlack" \
  "Dialectic" \
  "Rodolphe" \
  "Adil" \
  "Marauder" \
  "Smaug" \
  "PEKTOPROP" \
  "OPEKTUM" \
  "V-ZUG" \
  "Werkstudent" \
  "Balllvin" \
  "/Users/alvin" \
  "/Users/Alvin" \
  "marauder-main.up.railway.app" \
  "smaug.up.railway.app" \
  "quant-lab-production.up.railway.app"; do
  if rg -n -S "$pattern" "${scan_args[@]}" >/tmp/jobmaxxing-clean-check-matches 2>/dev/null; then
    cat /tmp/jobmaxxing-clean-check-matches >&2
    fail "forbidden personal or private reference matched: $pattern"
  fi
done

if [[ -d .git ]]; then
  if git log --all --format='%H %s' | rg -n -S "(Alvin|Stark|Medela|McKinsey|QuantumBlack|Dialectic|Rodolphe|Adil|Marauder|Smaug|PEKTOPROP|OPEKTUM|V-ZUG|Werkstudent|Balllvin|marauder-main|smaug\\.up|quant-lab-production)" >/tmp/jobmaxxing-clean-check-history 2>/dev/null; then
    cat /tmp/jobmaxxing-clean-check-history >&2
    fail "forbidden personal or private reference exists in Git history"
  fi
fi

echo "clean-repo check passed"
