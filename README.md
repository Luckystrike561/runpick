# runpick

Pick a project script with [fzf](https://github.com/junegunn/fzf) and run it.

One keystroke instead of remembering what a repo called its build command.
Reads the scripts the project already declares — nothing to configure, nothing
to keep in sync.

```
$ devbox run pick

devbox run
  ⌨️ vial:launch
  🗺️ layout:print
  👀 keymap:toggle
  📦 keymap:install
  ♻️ keymap:update
  🗑️ keymap:remove
  6/6 ───────────────────────────────────────────────
  Install and enable the Omarchy plugin for the layer reference
  scripts/keymap/install.sh
```

## Install

### As a devbox plugin (devbox projects)

```json
{
  "include": ["github:Luckystrike561/runpick/tags/v1.4.0"]
}
```

That is the whole setup. The plugin brings its own `jq` and `fzf`, copies the
script into `.devbox/virtenv/runpick/`, and defines the script, so

```bash
devbox run pick
```

works with nothing installed globally and nothing else added to `devbox.json`.
Drop `tags/v1.4.0` for the tip of `main`.

If a project already has a script called `pick`, its own wins — devbox gives
the project's `devbox.json` precedence over an included plugin. The plugin
exports `$RUNPICK_BIN`, so claiming any other name is one line:

```json
{ "shell": { "scripts": { "runpick": ["bash \"$RUNPICK_BIN\" \"$@\""] } } }
```

runpick recognises that command as itself, so it never lists the picker among
the things you can pick.

### On `PATH` (anywhere else)

```bash
curl -fsSL https://raw.githubusercontent.com/Luckystrike561/runpick/main/bin/runpick \
  -o ~/.local/bin/runpick && chmod +x ~/.local/bin/runpick
```

Needed for repos without devbox — a `package.json`-only project, or someone
else's repo you have just cloned. Requires `bash`, `jq` and `fzf` on `PATH`;
`awk` and `sed` come from any base system.

## Use

```bash
runpick                    # pick and run
runpick --args             # pick, then type arguments for the script
runpick --print            # pick and print the command instead
runpick --backend npm      # force a backend
runpick --list             # every candidate, for scripting
runpick --preview <key>    # one script's description and command
```

Run it anywhere inside a repo: the project root is found by walking up from the
working directory.

### Passing arguments to the picked script

Add `--args` and, once you have picked a script, runpick asks for the
arguments to run it with. The prompt shows the command so far, with readline
editing. Enter on an empty line runs with no arguments, and Ctrl-D or Ctrl-C
cancels without running anything. Without `--args` nothing is asked, and the
script runs exactly as before.

Say the project wraps a CLI it builds, and the wrapper hands its arguments on:

```json
{
  "shell": {
    "scripts": {
      "cli": ["cargo run \"$@\""]
    }
  }
}
```

Pick `cli`, then type what the binary should get, including the `--` that
keeps cargo from reading `--list` itself:

```
$ devbox run pick --args
  (pick cli)
devbox run cli -- --list --format 'long names'
```

That runs `cargo run -- --list --format 'long names'`, so the binary sees
`--list --format long names` (three words). The line is split like a shell
command (quotes and backslashes group words) but nothing is expanded: a typed
`$HOME`, `$(...)` or `*` reaches the script as written.

runpick adds a `--` of its own for runners that swallow one (devbox, npm, bun,
yarn 1), so any `--` you type is passed on intact. pnpm and yarn 2+ get none,
because they would pass it to the script as an argument.

devbox hands the arguments to a script as `$@`, so a devbox script only sees
them if its command uses them, as `cli` does above. With `--print`, the printed
command carries the arguments, shell-quoted so it can be pasted back.

## Backends

Detected in this order, first match wins:

| Manifest | Reads | Runs |
|---|---|---|
| `devbox.json` | `.shell.scripts` | `devbox run <key>` |
| `package.json` | `.scripts` | `<pm> run <key>` |

The package manager comes from the lockfile: `bun.lockb`/`bun.lock` → `bun`,
`pnpm-lock.yaml` → `pnpm`, `yarn.lock` → `yarn`, otherwise `npm`.

`devbox.json` is parsed as JSONC, because devbox accepts `//` and `/* */`
comments. Comments are stripped with string contents respected, so the
`https://` in `$schema` survives.

## Descriptions

Optional. When a script's command is a file in the repo, runpick reads three
headers from it:

```bash
#!/usr/bin/env bash
# @emoji 📦
# @description Install and enable the plugin
```

- `@emoji` — prefixes the entry in the list
- `@description` — first line of the preview pane
- `@ignore` — hides the entry, for anything too destructive to sit one
  keystroke away, such as a command that needs `sudo`

Only the first token of the command is examined, so `scripts/build.sh --release`
resolves to a file and `npm ci && tsc` does not. Repos using none of this still
work; the preview shows the raw command.

## Notes on the plugin

Three things worth knowing if you fork it:

- `create_files` resolves its sources **relative to `plugin.json`**, not the
  repo root. That is why `plugin.json` sits at the top level here rather than in
  a `plugin/` subdirectory, which also means consumers need no `?dir=`.
- `create_files` copies without the executable bit, so both the plugin's script
  entry and the fzf preview command invoke the file as `bash <path>`.
- runpick reads the project's own `devbox.json`, not devbox's merged view, since
  that is where the commands and their script files are. Scripts injected by a
  plugin are therefore not listed — including runpick's own entry, which is
  what you want.

## Prior art

The fzf-and-`@description` pattern started as a devbox-only picker in a personal
dotfiles repo. This is that idea, generalised and given a licence.

## Licence

Apache-2.0. See [`LICENSE`](LICENSE) and [`NOTICE`](NOTICE).
