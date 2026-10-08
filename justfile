set positional-arguments

import 'checks.just'

# List recipes
default:
    @just --list

# Everything that must pass before a change is accepted. Read-only; needs no secrets.
# Deploy and publish steps get their own recipes and CI jobs.
verify: check lint test

# Run the tests. Empty until the project has some; replace the body with the test command.
test:

# Pull in changes from the project template
update-template:
    copier update --trust --defaults --conflict inline

# Store the automation token from 1Password as this repo's AUTOMATION_TOKEN secret. Rerun after regenerating it.
set-automation-token:
    #!/usr/bin/env bash
    set -euo pipefail
    command -v op >/dev/null || { echo "needs the 1Password CLI (op)" >&2; exit 1; }
    op read "op://dev/github-automation-token/token" | gh secret set AUTOMATION_TOKEN
