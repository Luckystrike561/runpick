<p align="center">
  <img src="assets/logo.png" alt="runpick" width="600">
</p>

Pick a [devbox](https://www.jetify.com/devbox) script with
[fzf](https://github.com/junegunn/fzf) and run it.
[Try it in your browser](https://luckystrike561.github.io/runpick/).

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

### Picking npm scripts

`--npm` lists the `scripts` of the `package.json` in the directory you ran
`devbox run` from and runs the pick as `npm run <name>`. Add it as a script of
its own:

```json
"pick:npm": ["bash \"$RUNPICK_BIN\" --npm \"$@\""]
```

![runpick picking npm scripts](demo/npm.gif)

How `--args` splits what you type, which directory `--npm` reads, and the
known limits are on the [website](https://luckystrike561.github.io/runpick/).

## Development

```bash
devbox run test   # smoke tests
devbox run demo   # re-record demo/demo.gif with vhs
devbox run demo:npm   # re-record demo/npm.gif with vhs
```

## Licence

Apache-2.0. See [`LICENSE`](LICENSE) and [`NOTICE`](NOTICE).
