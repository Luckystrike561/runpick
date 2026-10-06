# runpick

Pick a [devbox](https://www.jetify.com/devbox) script with
[fzf](https://github.com/junegunn/fzf) and run it.

One keystroke instead of remembering what a repo called its build command.
Reads the scripts `devbox.json` already declares, so there is nothing to
configure and nothing to keep in sync. The preview pane shows each script's
command.

```
$ devbox run pick

devbox run
  vial:launch
  layout:print
  keymap:toggle
  keymap:install
  keymap:update
  keymap:remove
  6/6 ───────────────────────────────────────────────
  scripts/keymap/install.sh
```

## Install

```json
{
  "include": ["github:Luckystrike561/runpick/tags/v3.0.0"]
}
```

That is the whole setup. The plugin brings its own `jq` and `fzf`, copies the
script into `.devbox/virtenv/runpick/`, and defines the script, so

```bash
devbox run pick
```

works with nothing installed globally and nothing else added to `devbox.json`.
Drop `tags/v3.0.0` for the tip of `main`, but a pinned tag is safer: an
included plugin runs in your shell.

If a project already has a script called `pick`, its own wins — devbox gives
the project's `devbox.json` precedence over an included plugin. The plugin
exports `$RUNPICK_BIN`, so claiming any other name is one line:

```json
{ "shell": { "scripts": { "runpick": ["bash \"$RUNPICK_BIN\""] } } }
```

runpick recognises that command as itself, so it never lists the picker among
the things you can pick.

## Use

```bash
devbox run pick                  # pick and run
```

Inside `devbox shell`:

```bash
bash "$RUNPICK_BIN" --print      # pick and print the command
bash "$RUNPICK_BIN" --list       # every candidate, for scripting
```

Works from any subdirectory: devbox resolves the project and exports
`DEVBOX_PROJECT_ROOT`, which runpick reads. Outside devbox it refuses to run.

`devbox.json` is parsed as JSONC, because devbox accepts `//` and `/* */`
comments. Comments are stripped with string contents respected, so the
`https://` in `$schema` survives. Trailing commas, which devbox also accepts,
are not supported yet.

## Notes on the plugin

Three things worth knowing if you fork it:

- `create_files` resolves its sources **relative to `plugin.json`**, not the
  repo root. That is why `plugin.json` sits at the top level here rather than in
  a `plugin/` subdirectory, which also means consumers need no `?dir=`.
- `create_files` copies without the executable bit, so both the plugin's script
  entry and the fzf preview command invoke the file as `bash <path>`.
- runpick reads the project's own `devbox.json`, not devbox's merged view.
  Scripts injected by a plugin are therefore not listed, including runpick's
  own entry, which is what you want.

## Development

```bash
bash test/smoke.sh
```

Needs `bash`, `jq` and `awk`. The run-mode checks also need `fzf` and are
skipped without it.

## Prior art

The fzf picker over devbox scripts started in a personal dotfiles repo. This is
that idea, packaged as a plugin and given a licence.

## Licence

Apache-2.0. See [`LICENSE`](LICENSE) and [`NOTICE`](NOTICE).
