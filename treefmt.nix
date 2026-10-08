# Formatters and linters run by `just fmt`, the pre-commit hook and CI.
# Options: https://github.com/numtide/treefmt-nix/tree/main/programs
{ pkgs, config, ... }:
{
  projectRootFile = "flake.nix";

  programs = {
    nixfmt.enable = true; # *.nix
    deadnix.enable = true; # unused Nix bindings
    oxfmt.enable = true; # Markdown, YAML, JSON, JS/TS, CSS, HTML
    just.enable = true; # justfile
    shfmt.enable = true; # shell scripts
    actionlint.enable = true; # GitHub Actions workflows
    ruff-format.enable = true; # Python
    ruff-check.enable = true; # Python lint
  };

  # ComfyUI loads the repo as a package named after its folder, comfyui-keepawake, which isn't a valid Python module name.
  settings.formatter.ruff-check.options = [
    "--ignore"
    "N999"
  ];

  settings.formatter.shfmt.includes = [ ".envrc" ];

  # Copier templates: oxfmt picks its parser from the file extension, so format each
  # *.md.jinja file as a temporary .md copy and write the result back.
  settings.formatter.oxfmt-md-jinja = {
    command = pkgs.writeShellScriptBin "oxfmt-md-jinja" ''
      set -euo pipefail
      tmp="$(mktemp -d)"
      trap 'rm -rf "$tmp"' EXIT
      for file in "$@"; do
        cp "$file" "$tmp/file.md"
        ${config.programs.oxfmt.package}/bin/oxfmt "$tmp/file.md"
        cmp -s "$tmp/file.md" "$file" || cp "$tmp/file.md" "$file"
      done
    '';
    includes = [ "*.md.jinja" ];
  };

  settings.global.excludes = [
    ".copier-answers.yml" # written by copier; reformatting it causes update noise
  ];
}
