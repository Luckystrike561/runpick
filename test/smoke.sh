#!/usr/bin/env bash
# Exercises every non-interactive path against fixtures. No fzf, no TTY.
set -euo pipefail

here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
runpick=$here/../bin/runpick
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

pass=0
fail=0

check() { # name expected actual
  if [[ $2 == "$3" ]]; then
    pass=$((pass + 1))
    printf 'ok   %s\n' "$1"
  else
    fail=$((fail + 1))
    printf 'FAIL %s\n       want: %s\n       got:  %s\n' "$1" "$2" "$3"
  fi
}

# --- fixture: devbox with JSONC comments, a described script and an @ignore ---

mkdir -p "$work/dbx/scripts/deep/nested"
cat >"$work/dbx/devbox.json" <<'EOF'
{
  "$schema": "https://example.com/devbox.schema.json",
  "shell": {
    // A comment devbox accepts and jq does not.
    "scripts": {
      "build": ["scripts/build.sh"],
      /* block comment */
      "danger": ["scripts/danger.sh"],
      "inline": ["echo hi && echo there"],
      "docs": ["echo https://example.com/a//b and done"],
      "pick": ["runpick"]
    }
  }
}
EOF
cat >"$work/dbx/scripts/build.sh" <<'EOF'
#!/usr/bin/env bash
# @emoji 🔨
# @description Build the thing
EOF
cat >"$work/dbx/scripts/danger.sh" <<'EOF'
#!/usr/bin/env bash
# @ignore needs sudo
EOF
chmod +x "$work/dbx/scripts"/*.sh

cd "$work/dbx"

check "devbox: lists described, inline; hides @ignore and self" \
  "build	🔨 build
inline	inline
docs	docs" \
  "$("$runpick" --list)"

check "devbox: preview shows description then command" \
  "Build the thing
scripts/build.sh" \
  "$("$runpick" --preview build)"

check "devbox: preview of an inline command has no description" \
  "echo hi && echo there" \
  "$("$runpick" --preview inline)"

# A naive `//` strip would truncate this to `echo https:`, and stripping inside
# the manifest's own "$schema" value would stop the file parsing at all.
check "devbox: // inside a string is not treated as a comment" \
  "echo https://example.com/a//b and done" \
  "$("$runpick" --preview docs)"

cd "$work/dbx/scripts/deep/nested"
check "root is found by walking up" \
  "build	🔨 build
inline	inline
docs	docs" \
  "$("$runpick" --list)"

# --- fixture: package.json, lockfile picks the runner ------------------------

mkdir -p "$work/npm"
cat >"$work/npm/package.json" <<'EOF'
{ "name": "fix", "scripts": { "test": "vitest", "build": "tsc" } }
EOF
touch "$work/npm/pnpm-lock.yaml"
cd "$work/npm"

check "npm: lists scripts" \
  "test	test
build	build" \
  "$("$runpick" --list)"

check "npm: preview shows the command" "vitest" "$("$runpick" --preview test)"

# --- error paths -------------------------------------------------------------

mkdir -p "$work/empty"
echo '{"shell":{"scripts":{}}}' >"$work/empty/devbox.json"
cd "$work/empty"
check "empty manifest is rejected" "1" \
  "$("$runpick" >/dev/null 2>&1; echo $?)"

cd "$work/dbx"
check "unknown backend is rejected" "1" \
  "$("$runpick" --backend bogus --list >/dev/null 2>&1; echo $?)"

check "unknown argument is rejected" "1" \
  "$("$runpick" --nope >/dev/null 2>&1; echo $?)"

mkdir -p "$work/bare"
cd "$work/bare"
check "no manifest anywhere is rejected" "1" \
  "$("$runpick" --list >/dev/null 2>&1; echo $?)"

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[[ $fail -eq 0 ]]
