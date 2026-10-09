<p align="center">
  <img src="assets/logo.png" alt="runpick" width="600">
</p>

Pick a [devbox](https://www.jetify.com/devbox) script with
[fzf](https://github.com/junegunn/fzf) and run it.

![runpick demo](demo/demo.gif)

## Example

A complete `devbox.json`. The `include` line is the only thing runpick needs:

```json
{
  "$schema": "https://raw.githubusercontent.com/jetify-com/devbox/main/.schema/devbox.schema.json",
  "include": ["github:Luckystrike561/runpick/tags/1.2.0"],
  "shell": {
    "scripts": {
      "build": "echo 'compiling...' && sleep 1 && echo 'built dist/app'",
      "test": ["echo 'running 42 tests'", "sleep 1", "echo 'all green'"],
      "lint": "echo 'no issues found'",
      "db:migrate": "echo 'applied 3 migrations'",
      "db:seed": "echo 'seeded 100 rows'",
      "release": ["echo 'tagging v1.2.0'", "echo 'pushed'"]
    }
  }
}
```

Then, from anywhere in the project:

```bash
devbox run pick
```

Type to filter, `Enter` to run, `Esc` to cancel. The preview pane shows the
selected script's command. The plugin brings its own `jq` and `fzf`.

## Options

Inside `devbox shell`, the plugin exports `$RUNPICK_BIN`:

```bash
bash "$RUNPICK_BIN" --args    # pick, then type arguments for the script
bash "$RUNPICK_BIN" --print   # pick, then print the command instead of running it
bash "$RUNPICK_BIN" --list    # list script names, one per line
bash "$RUNPICK_BIN" --npm     # pick from package.json scripts instead
```

If your project already has a script named `pick`, yours wins. Give the
picker another name with:

```json
"runpick": ["bash \"$RUNPICK_BIN\" \"$@\""]
```

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
`--list --format long names` (three words). The line is split by `xargs`:
quotes and backslashes group words, but inside double quotes a backslash is
kept as typed (`"C:\\dir"` stays `C:\\dir`, `"a \"b\""` is rejected), and
nothing is expanded: a typed `$HOME`, `$(...)` or `*` reaches the script as written.

devbox swallows one `--` after the script name, so runpick adds its own and any
`--` you type is passed on intact. devbox hands the arguments to a script as
`$@`, so a script only sees them if its command uses them, as `cli` does above.
With `--print`, the printed command carries the arguments, shell-quoted so it
can be pasted back.

### Picking npm scripts

With `--npm`, runpick lists the `scripts` of the `package.json` in the
directory you ran `devbox run` from, and runs the pick as `npm run <name>`
from that directory, inside the devbox environment. `--list`, `--print`,
`--preview` and `--args` work the same way on the npm scripts. Add it as a
script of its own:

```json
"pick:npm": ["bash \"$RUNPICK_BIN\" --npm \"$@\""]
```

```
$ cd web
$ devbox run pick:npm --print
  (pick build:prod)
npm run build:prod
```

![runpick picking npm scripts](demo/npm.gif)

`devbox run` executes scripts from the project root and exports the directory
you typed the command in as `DEVBOX_WD`; runpick reads `package.json` there,
falling back to the current directory when `DEVBOX_WD` is unset. Called
anywhere but the project root, runpick reads the current directory instead.
A printed `npm run` command targets that directory's `package.json`, so paste
it there.

Inside an active `devbox shell` or direnv environment, `DEVBOX_WD` stays where
the environment was entered and does not follow `cd`, so a nested
`devbox run pick:npm` reads that directory. Run `bash "$RUNPICK_BIN" --npm`
there instead, which reads the directory you are in.

Node is not part of the plugin: the project's own devbox config provides `npm`.
Only `npm run` is used, whatever the lockfile, and only the one `package.json`
is read: no parent directories, no workspaces.

## Limitations

- Only scripts in the project's own `devbox.json` are listed, not scripts
  added by other plugins.
- `//` and `/* */` comments are supported. Trailing commas are not yet.
- Pin a tag in `include`. An included plugin runs in your shell, so tracking
  `main` means running whatever lands there.

## Development

```bash
devbox run test   # smoke tests
devbox run demo   # re-record demo/demo.gif with vhs
devbox run demo:npm   # re-record demo/npm.gif with vhs
```

## Licence

Apache-2.0. See [`LICENSE`](LICENSE) and [`NOTICE`](NOTICE).
