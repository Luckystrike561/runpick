#!/usr/bin/env bash
# Exercises runpick against fixtures without a TTY. Run-mode checks drive fzf
# with --filter and stand in a fake `devbox`, so nothing real is executed.
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
      "multi": ["scripts/multi.sh --flag", "echo after"],
      "release": "scripts/build.sh --release",
      "deploy prod": ["echo deploying"],
      "docs": ["echo https://example.com/a//b and done"],
      "pick": ["runpick"],
      "alias": ["bash \"$RUNPICK_BIN\""]
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
cat >"$work/dbx/scripts/multi.sh" <<'EOF'
#!/usr/bin/env bash
# @emoji 🧩
# @description Two steps
EOF
chmod +x "$work/dbx/scripts"/*.sh

export DEVBOX_PROJECT_ROOT=$work/dbx
cd "$DEVBOX_PROJECT_ROOT"

listing="build	🔨 build
inline	inline
multi	🧩 multi
release	🔨 release
deploy prod	deploy prod
docs	docs"

check "devbox: hides @ignore, and the picker under either spelling" \
  "$listing" "$("$runpick" --list)"

check "devbox: preview shows description then command" \
  "Build the thing
scripts/build.sh" \
  "$("$runpick" --preview build)"

check "devbox: preview of an inline command has no description" \
  "echo hi && echo there" \
  "$("$runpick" --preview inline)"

# Array scripts are joined with newlines, so the first token must stop at the
# line break, not run on into the next line.
check "devbox: multi-line script still resolves its file" \
  "Two steps
scripts/multi.sh --flag
echo after" \
  "$("$runpick" --preview multi)"

# A naive `//` strip would truncate this to `echo https:`, and stripping inside
# the manifest's own "$schema" value would stop the file parsing at all.
check "devbox: // inside a string is not treated as a comment" \
  "echo https://example.com/a//b and done" \
  "$("$runpick" --preview docs)"

cd "$work/dbx/scripts/deep/nested"
check "root comes from DEVBOX_PROJECT_ROOT, not the working directory" \
  "$listing" "$("$runpick" --list)"

# --- run mode: fzf --filter picks non-interactively, fake devbox records argv ---

if command -v fzf >/dev/null; then
  mkdir -p "$work/bin"
  cat >"$work/bin/devbox" <<'EOF'
#!/usr/bin/env bash
printf 'cwd=%s argv=%s\n' "$PWD" "$*"
EOF
  chmod +x "$work/bin/devbox"
  pick() { FZF_DEFAULT_OPTS="--filter=$(printf %q "$1")" PATH="$work/bin:$PATH" "$runpick" "${@:2}" </dev/null; }

  check "run: execs devbox run <key> from the project root" \
    "cwd=$work/dbx argv=run release" "$(pick release)"

  check "print: shell-quotes a key with a space" \
    'devbox run deploy\ prod' "$(pick 'deploy prod' --print)"
else
  printf 'skip run mode: fzf not on PATH\n'
fi

# --- error paths -------------------------------------------------------------

mkdir -p "$work/empty"
echo '{"shell":{"scripts":{}}}' >"$work/empty/devbox.json"
check "empty manifest is rejected" "1" \
  "$(DEVBOX_PROJECT_ROOT=$work/empty "$runpick" >/dev/null 2>&1; echo $?)"

check "unknown argument is rejected" "1" \
  "$("$runpick" --nope >/dev/null 2>&1; echo $?)"

mkdir -p "$work/npm"
echo '{ "scripts": { "test": "vitest" } }' >"$work/npm/package.json"
check "package.json alone is not a devbox project" "1" \
  "$(DEVBOX_PROJECT_ROOT=$work/npm "$runpick" --list >/dev/null 2>&1; echo $?)"

check "running outside devbox is rejected" "1" \
  "$(env -u DEVBOX_PROJECT_ROOT "$runpick" --list >/dev/null 2>&1; echo $?)"

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[[ $fail -eq 0 ]]
