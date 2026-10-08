# AGENTS.md

## Environment

- The dev shell is defined in `flake.nix` and loaded by direnv. Add tools to `devShells.default.packages` there; never install them globally.
- If a command is missing, run it through the shell: `nix develop --command <cmd>`.
- New files must be `git add`ed before Nix can see them (flakes only read tracked files).

## Tasks

- Use the `justfile` recipes rather than calling tools directly. Run `just` to list them.
- Run `just verify` before committing; the `verify` job in CI runs the same recipe.
- `verify` must stay read-only and need no secrets. Deploy, release and publish steps go in their own recipes (e.g. `just deploy`), run by separate CI jobs that depend on `verify`.
- Put the project's test command in the `test` recipe in `justfile`; `verify` runs it. Build steps that tests need go in their own recipe, as a dependency of `test`.
- Checks live in `checks.just`: `just fmt` (treefmt, config in `treefmt.nix`) and `just lint` (merge conflict markers, secrets via gitleaks). Both take file paths and default to the whole repo, except that gitleaks scans the staged changes when given files and every commit when not.
- The pre-commit hook runs `just fmt` and `just lint` on the staged files. Don't bypass it with `--no-verify`; `just verify` runs the same recipes over every file.
- To add a check, add a recipe to `checks.just` and to `verify`. If it should also run on commit, add a hook for it in `flake.nix` with `recipeHook`.
- In GitHub workflows, pin each action to a full commit SHA with the version as a comment (`uses: owner/action@<sha> # v1.2.3`). Tags can be moved to point at other code; Dependabot updates the SHA and the comment.

## Template

This project was generated from `gh:lukebarton/project-template` with Copier. `.copier-answers.yml` records the template version; don't edit it. Run `just update-template` to pull template changes; a weekly workflow also opens a PR with them.
