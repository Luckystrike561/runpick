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

### As a devbox plugin (devbox projects)

```json
{
  "include": ["github:Luckystrike561/runpick/tags/v1.2.0"]
}
```

That is the whole setup. The plugin brings its own `jq` and `fzf`, copies the
script into `.devbox/virtenv/runpick/`, and defines a `runpick` script, so
`devbox run runpick` works with nothing installed globally and nothing else
added to `devbox.json`. Drop `tags/v1.2.0` for the tip of `main`.

The script is named after the plugin rather than something generic like
`scripts`, so it cannot collide with a script a project already has. If you
want a shorter name, the plugin exports `$RUNPICK_BIN`, so an alias is one
line — and runpick recognises it as itself, so it never lists the picker among
the things you can pick:

```json
{ "shell": { "scripts": { "pick": ["bash \"$RUNPICK_BIN\""] } } }
```

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
