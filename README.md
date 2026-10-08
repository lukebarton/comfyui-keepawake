# comfyui-keepawake

## Development

Requires [Nix](https://nixos.org) with flakes enabled and [direnv](https://direnv.net) with [nix-direnv](https://github.com/nix-community/nix-direnv).

```sh
direnv allow   # loads the dev shell and installs the pre-commit hook
just           # lists available recipes
```

| Recipe                      | What it does                                                                       |
| --------------------------- | ---------------------------------------------------------------------------------- |
| `just fmt`                  | Format every file                                                                  |
| `just lint`                 | Check for merge conflict markers and secrets                                       |
| `just test`                 | Run the tests                                                                      |
| `just check`                | Check formatting and run flake checks                                              |
| `just verify`               | Everything that must pass before merging                                           |
| `just update-template`      | Pull in changes from the project template                                          |
| `just set-automation-token` | Store the automation token from 1Password as this repo's `AUTOMATION_TOKEN` secret |

After creating the GitHub repo, run `just set-automation-token` (needs the 1Password CLI, `op`). The weekly `flake.lock` and template-update workflows use the token to open PRs that trigger CI, and to clone the template. Rerun it whenever the token is regenerated.

`just fmt` and `just lint` run automatically on commit, on the staged files. If the hook reformats files, the commit stops; `git add` the changes and commit again.
