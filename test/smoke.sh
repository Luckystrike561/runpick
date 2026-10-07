#!/usr/bin/env bash
# Exercises runpick against fixtures without a TTY. Run-mode checks drive fzf
# with --filter, forwarding checks replace it with a stub, and both stand in a
# fake `devbox`, so nothing real is executed.
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

# --- fixture: devbox.json with JSONC comments, string and array scripts ------

mkdir -p "$work/dbx/deep/nested"
cat >"$work/dbx/devbox.json" <<'EOF'
{
  "$schema": "https://example.com/devbox.schema.json",
  "shell": {
    // A comment devbox accepts and jq does not.
    "scripts": {
      "build": ["make build"],
      /* block comment */
      "inline": "echo hi && echo there",
      "multi": ["make one", "echo after"],
      "deploy prod": ["echo deploying"],
      "docs": ["echo https://example.com/a//b and done"],
      "pick": ["runpick"],
      "alias": ["bash \"$RUNPICK_BIN\""]
    }
  }
}
EOF
export DEVBOX_PROJECT_ROOT=$work/dbx
cd "$DEVBOX_PROJECT_ROOT"

listing="build
inline
multi
deploy prod
docs"

check "devbox: lists scripts in file order, hiding the picker under either spelling" \
  "$listing" "$("$runpick" --list)"

check "devbox: preview shows a string script's command" \
  "echo hi && echo there" \
  "$("$runpick" --preview inline)"

check "devbox: preview joins an array script one line per entry" \
  "make one
echo after" \
  "$("$runpick" --preview multi)"

# A naive `//` strip would truncate this to `echo https:`, and stripping inside
# the manifest's own "$schema" value would stop the file parsing at all.
check "devbox: // inside a string is not treated as a comment" \
  "echo https://example.com/a//b and done" \
  "$("$runpick" --preview docs)"

cd "$work/dbx/deep/nested"
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
    "cwd=$work/dbx argv=run build" "$(pick build)"

  check "print: shell-quotes a key with a space" \
    'devbox run deploy\ prod' "$(pick 'deploy prod' --print)"
else
  printf 'skip run mode: fzf not on PATH\n'
fi

# --- forwarding through the picker -------------------------------------------

stubs=$work/stubs
mkdir -p "$stubs"
cat >"$stubs/fzf" <<'EOF'
#!/usr/bin/env bash
cat >/dev/null
printf '%s\n' "$PICK"
EOF
cat >"$stubs/devbox" <<'EOF'
#!/usr/bin/env bash
printf 'devbox'
printf ' [%s]' "$@"
echo
EOF
chmod +x "$stubs/fzf" "$stubs/devbox"

stub_pick() { # key runpick-args... (stdin: the line typed at the --args prompt)
  PICK=$1 PATH=$stubs:$PATH "$runpick" "${@:2}"
}

cd "$work/dbx"

check "no --args: runs the picked script with no arguments, reading nothing" \
  "devbox [run] [build]" \
  "$(echo '--release' | stub_pick build)"

check "no --args: --print is unchanged" \
  "devbox run build" \
  "$(stub_pick build --print </dev/null)"

# devbox swallows one `--`, so the typed one must arrive behind runpick's own.
check "--args: typed words reach the script in order, quoted but unexpanded" \
  "devbox [run] [build] [--] [--] [--list] [--help] [two words] [a b] [\$HOME] [\$(date)] [*]" \
  "$(printf '%s\n' "-- --list --help 'two words' a\\ b '\$HOME' \$(date) *" | stub_pick build --args)"

check "--args: an empty line runs with no arguments" \
  "devbox [run] [build]" \
  "$(echo '  ' | stub_pick build --args)"

check "--args: Ctrl-D cancels without running" \
  "0:" \
  "$(out=$(stub_pick build --args </dev/null); echo "$?:$out")"

check "--args: an unmatched quote is rejected" \
  "1" \
  "$(echo "it's" | stub_pick build --args >/dev/null 2>&1; echo $?)"

check "--args --print: prints the arguments shell-quoted" \
  'devbox run build -- --list two\ words' \
  "$(echo "--list 'two words'" | stub_pick build --args --print)"

check "--args --print: the output, pasted back, runs the same arguments" \
  "devbox [run] [build] [--] [--help] [it's] [\$HOME] [a;b]" \
  "$(PATH=$stubs:$PATH eval "$(echo "--help \"it's\" '\$HOME' 'a;b'" | stub_pick build --args --print)")"

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
