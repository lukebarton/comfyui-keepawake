{
  description = "Development environment";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    treefmt-nix.url = "github:numtide/treefmt-nix";
    treefmt-nix.inputs.nixpkgs.follows = "nixpkgs";
    git-hooks.url = "github:cachix/git-hooks.nix";
    git-hooks.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs =
    {
      self,
      nixpkgs,
      treefmt-nix,
      git-hooks,
    }:
    let
      systems = [
        "aarch64-darwin"
        "aarch64-linux"
        "x86_64-linux"
      ];
      forAllSystems = f: nixpkgs.lib.genAttrs systems (system: f nixpkgs.legacyPackages.${system});
      system = pkgs: pkgs.stdenv.hostPlatform.system;

      # One treefmt config drives `nix fmt`, `just fmt`, the pre-commit hook and CI.
      treefmt = forAllSystems (pkgs: treefmt-nix.lib.evalModule pkgs ./treefmt.nix);
      treefmtWrapper = pkgs: treefmt.${system pkgs}.config.build.wrapper;

      # Tools the justfile recipes call.
      tools = pkgs: [
        pkgs.just
        pkgs.copier
        pkgs.gh
        pkgs.gitleaks
        pkgs.python3Packages.pre-commit-hooks # check-merge-conflict
        (treefmtWrapper pkgs)
      ];

      # A git hook that runs a just recipe on the staged files. It puts the tools on PATH itself,
      # so it also works when committing from an editor that hasn't loaded the dev shell.
      # require_serial passes all the files to one run: prek otherwise splits them into batches
      # run in parallel, and parallel treefmt runs time out waiting for treefmt's cache.
      recipeHook = pkgs: recipe: {
        enable = true;
        name = recipe;
        require_serial = true;
        entry = toString (
          pkgs.writeShellScript "just-${recipe}" ''
            export PATH=${pkgs.lib.makeBinPath (tools pkgs)}:$PATH
            exec just ${recipe} "$@"
          ''
        );
      };

      hooks = forAllSystems (
        pkgs:
        git-hooks.lib.${system pkgs}.run {
          src = self;
          package = pkgs.prek;
          hooks = {
            fmt = recipeHook pkgs "fmt";
            lint = recipeHook pkgs "lint";
          };
        }
      );
    in
    {
      formatter = forAllSystems treefmtWrapper;

      checks = forAllSystems (pkgs: {
        formatting = treefmt.${system pkgs}.config.build.check self;
      });

      devShells = forAllSystems (pkgs: {
        default = pkgs.mkShell {
          packages = tools pkgs ++ [
            # Tests for the custom node (pytest) and the Windows script (pwsh).
            (pkgs.python3.withPackages (ps: [
              ps.aiohttp
              ps.pytest
              ps.pytest-aiohttp
            ]))
            pkgs.powershell
          ];
          # Installs the git pre-commit hook each time the shell loads.
          inherit (hooks.${system pkgs}) shellHook;
        };
      });
    };
}
