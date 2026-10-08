# Checks shared by `just verify` and the git hooks. The hooks pass the staged files;
# run by hand with no arguments, each recipe covers the whole repo.

# Format files (default: every file)
fmt *files:
    treefmt "$@"

# Reject merge conflict markers (default: every tracked file) and secrets (staged changes if files are given, else every commit)
lint *files:
    #!/usr/bin/env bash
    set -euo pipefail
    files=()
    if [ $# -eq 0 ]; then
        while IFS= read -r -d '' file; do
            if [ -f "$file" ]; then files+=("$file"); fi
        done < <(git ls-files -z)
    else
        files=("$@")
    fi
    if [ ${#files[@]} -eq 0 ]; then exit 0; fi
    status=0
    # --assume-in-merge also catches markers left outside a merge, e.g. by `copier update --conflict inline`.
    check-merge-conflict --assume-in-merge "${files[@]}" || status=1
    # Secrets. The hook passes the staged files, so scan the staged changes; with no files, scan
    # every commit. (`gitleaks dir` would also scan gitignored files, such as .direnv/.)
    scope=()
    if [ $# -gt 0 ]; then scope=(--staged); fi
    gitleaks git ${scope[@]+"${scope[@]}"} --redact --no-banner --log-level warn --verbose || status=1
    exit $status

# Check formatting and run flake checks
check:
    nix flake check
