# runpick

Pick a project script with [fzf](https://github.com/junegunn/fzf) and run it.

One keystroke instead of remembering what a repo called its build command.
Reads the scripts the project already declares — nothing to configure, nothing
to keep in sync.

```
devbox run
  🎯 scripts
  ⌨️ vial
  🗺️ keyboard-layout
  👀 keymap
  📦 keymap-install
  4/7 ───────────────────────────────────────────────
  Install and enable the Omarchy plugin for the layer reference
  scripts/keymap/install.sh
```

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/Luckystrike561/runpick/main/bin/runpick \
  -o ~/.local/bin/runpick && chmod +x ~/.local/bin/runpick
```

Requires `bash`, `jq` and `fzf`. `awk` and `sed` come from any base system.

## Use

```bash
runpick                    # pick and run
runpick --print            # pick and print the command instead
runpick --backend npm      # force a backend
runpick --list             # every candidate, for scripting
runpick --preview <key>    # one script's description and command
```

Run it anywhere inside a repo: the project root is found by walking up from the
working directory.

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

## Wiring it into a project

Optional, since `runpick` already works from any directory. If you want it as a
script of its own:

```json
{ "shell": { "scripts": { "scripts": ["runpick"] } } }
```

runpick skips any entry whose command invokes runpick, so it never offers to
launch itself.

## Prior art

The fzf-and-`@description` pattern started as a devbox-only picker in a personal
dotfiles repo. This is that idea, generalised and given a licence.

## Licence

Apache-2.0. See [`LICENSE`](LICENSE) and [`NOTICE`](NOTICE).
