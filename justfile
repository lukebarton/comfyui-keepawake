set positional-arguments

import 'checks.just'

# List recipes
default:
    @just --list

# Everything that must pass before a change is accepted. Read-only; needs no secrets.
# Deploy and publish steps get their own recipes and CI jobs.
verify: check lint test

# Run the tests: the custom node's HTTP routes, then the Windows script's keep-awake decision.
# --rootdir stops pytest importing the repo-root __init__.py, which only loads inside ComfyUI.
test:
    python -m pytest -q -p no:cacheprovider -o asyncio_mode=auto --rootdir tests tests
    pwsh -NoProfile -NonInteractive -File tests/keepawake.Tests.ps1

# Pull in changes from the project template
update-template:
    copier update --trust --defaults --conflict inline

# Store the automation token from 1Password as this repo's AUTOMATION_TOKEN secret. Rerun after regenerating it.
set-automation-token:
    #!/usr/bin/env bash
    set -euo pipefail
    command -v op >/dev/null || { echo "needs the 1Password CLI (op)" >&2; exit 1; }
    op read "op://dev/github-automation-token/token" | gh secret set AUTOMATION_TOKEN
