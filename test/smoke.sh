#!/usr/bin/env bash
# Exercises every path against fixtures, with no TTY: fzf and the script
# runners are replaced by stubs, so the run path can be checked too.
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
chmod +x "$work/dbx/scripts"/*.sh

cd "$work/dbx"

check "devbox: hides @ignore, and the picker under either spelling" \
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

# --- forwarding through the picker -------------------------------------------

stubs=$work/stubs
mkdir -p "$stubs"
cat >"$stubs/fzf" <<'EOF'
#!/usr/bin/env bash
cat >/dev/null
printf '%s\n' "$PICK"
EOF
cat >"$stubs/runner" <<'EOF'
#!/usr/bin/env bash
printf '%s' "$(basename "$0")"
printf ' [%s]' "$@"
echo
EOF
chmod +x "$stubs/fzf" "$stubs/runner"
for runner in devbox npm pnpm yarn bun; do ln -s runner "$stubs/$runner"; done

pick() { # key runpick-args... (stdin: the line typed at the --args prompt)
  PICK=$1 PATH=$stubs:$PATH "$runpick" "${@:2}"
}

cd "$work/dbx"

check "no --args: runs the picked script with no arguments, reading nothing" \
  "devbox [run] [build]" \
  "$(echo '--release' | pick build)"

check "no --args: --print is unchanged" \
  "devbox run build" \
  "$(pick build --print </dev/null)"

check "--args: typed words reach the script in order, quoted but unexpanded" \
  "devbox [run] [build] [--] [--] [--list] [--help] [two words] [a b] [\$HOME] [\$(date)] [*]" \
  "$(printf '%s\n' "-- --list --help 'two words' a\\ b '\$HOME' \$(date) *" | pick build --args)"

check "--args: an empty line runs with no arguments" \
  "devbox [run] [build]" \
  "$(echo '  ' | pick build --args)"

check "--args: Ctrl-D cancels without running" \
  "0:" \
  "$(out=$(pick build --args </dev/null); echo "$?:$out")"

check "--args: an unmatched quote is rejected" \
  "1" \
  "$(echo "it's" | pick build --args >/dev/null 2>&1; echo $?)"

check "--args --print: prints the arguments shell-quoted" \
  'devbox run build -- --list two\ words' \
  "$(echo "--list 'two words'" | pick build --args --print)"

check "--args --print: the output, pasted back, runs the same arguments" \
  "devbox [run] [build] [--] [--help] [it's] [\$HOME] [a;b]" \
  "$(PATH=$stubs:$PATH eval "$(echo "--help \"it's\" '\$HOME' 'a;b'" | pick build --args --print)")"

runner_gets() { # dir lockfiles...: runs the picker there with `-- --list` typed
  mkdir -p "$work/$1"
  cp "$work/npm/package.json" "$work/$1/"
  (cd "$work/$1" && touch package.json "${@:2}" && echo '-- --list' | pick test --args)
}

check "pnpm: no separator, which pnpm would pass on as an argument" \
  "pnpm [run] [test] [--] [--list]" \
  "$(cd "$work/npm" && echo '-- --list' | pick test --args)"

check "npm: a separator of its own, so npm does not read the flags" \
  "npm [run] [test] [--] [--] [--list]" \
  "$(runner_gets npm-plain)"

check "bun: a separator of its own, which bun swallows" \
  "bun [run] [test] [--] [--] [--list]" \
  "$(runner_gets bun bun.lock)"

check "yarn 1: a separator of its own, which yarn 1 swallows" \
  "yarn [run] [test] [--] [--] [--list]" \
  "$(runner_gets yarn1 yarn.lock)"

check "yarn 2+: no separator, which yarn 2+ would pass on as an argument" \
  "yarn [run] [test] [--] [--list]" \
  "$(runner_gets yarn4 yarn.lock .yarnrc.yml)"

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
