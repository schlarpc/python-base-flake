{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    pyproject-nix = {
      url = "github:pyproject-nix/pyproject.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    uv2nix = {
      url = "github:pyproject-nix/uv2nix";
      inputs.pyproject-nix.follows = "pyproject-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    pyproject-build-systems = {
      url = "github:pyproject-nix/build-system-pkgs";
      inputs.pyproject-nix.follows = "pyproject-nix";
      inputs.uv2nix.follows = "uv2nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    git-hooks = {
      url = "github:cachix/git-hooks.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix2container = {
      url = "github:nlewo/nix2container";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-std.url = "github:chessai/nix-std";

    systems.url = "github:nix-systems/default";
  };

  outputs =
    {
      self,
      nixpkgs,
      uv2nix,
      git-hooks,
      pyproject-nix,
      pyproject-build-systems,
      nix2container,
      nix-std,
      systems,
      ...
    }:
    let
      inherit (nixpkgs) lib;

      pyproject = pyproject-nix.lib.project.loadPyproject { projectRoot = ./.; };

      projectName = pyproject.pyproject.project.name;
      projectVersion = pyproject.pyproject.project.version;

      workspace = uv2nix.lib.workspace.loadWorkspace { workspaceRoot = ./.; };

      # packages from workspace
      overlay = workspace.mkPyprojectOverlay {
        sourcePreference = "wheel";
      };

      # build fixup overlay
      pyprojectOverrides = _final: _prev: {
        # Implement build fixups here.
        # Note that uv2nix is _not_ using Nixpkgs buildPythonPackage.
        # It's using https://pyproject-nix.github.io/pyproject.nix/build.html
      };

      eachSystem = lib.genAttrs (import systems);

      perSystem =
        system:
        let
          pkgs = nixpkgs.legacyPackages."${system}";

          python = pkgs.python3;

          # full package set
          pythonSet =
            (pkgs.callPackage pyproject-nix.build.packages {
              inherit python;
            }).overrideScope
              (
                lib.composeManyExtensions [
                  pyproject-build-systems.overlays.default
                  overlay
                  pyprojectOverrides
                ]
              );

          # Override previous set with an overlay to make the current package editable
          editablePythonSet = pythonSet.overrideScope (
            lib.composeManyExtensions [
              # Create an overlay enabling editable mode for all local dependencies.
              (workspace.mkEditablePyprojectOverlay {
                # Use environment variable that gets expanded in the .pth handler
                root = "$REPO_ROOT";
              })

              # Apply fixups for building an editable package of your workspace packages
              (final: prev: {
                "${projectName}" = prev."${projectName}".overrideAttrs (old: {
                  # Hatchling (our build system) has a dependency on the `editables` package when building editables.
                  #
                  # In normal Python flows this dependency is dynamically handled, and doesn't need to be explicitly declared.
                  # This behaviour is documented in PEP-660.
                  #
                  # With Nix the dependency needs to be explicitly declared.
                  nativeBuildInputs =
                    old.nativeBuildInputs
                    ++ final.resolveBuildSystem {
                      editables = [ ];
                    };
                });
              })
            ]
          );

          customizeVenv =
            env:
            pkgs.lib.addMetaAttrs { mainProgram = projectName; } (
              env.overrideAttrs (old: {
                # file collisions to ignore
                venvIgnoreCollisions = [ ];
              })
            );

          venvRelease = customizeVenv (pythonSet.mkVirtualEnv "${projectName}-env" workspace.deps.default);

          venvDevelopment = customizeVenv (
            editablePythonSet.mkVirtualEnv "${projectName}-dev-env" workspace.deps.all
          );
        in
        {
          packages = {
            default = venvRelease;
            container =
              let
                # shuffle around the output path to make an easy-to-read container image tag
                makeContainerTag =
                  pkg:
                  let
                    parts = pkgs.lib.splitString "-" (pkgs.lib.last (pkgs.lib.splitString "/" pkg.outPath));
                    hash = builtins.head parts;
                    name = builtins.concatStringsSep "-" (builtins.tail parts);
                  in
                  "${projectName}-${projectVersion}-${hash}";
              in
              (nix2container.packages.${system}.nix2container.buildImage {
                name = projectName;
                tag = makeContainerTag self.packages.${system}.default;
                config = {
                  workingDir = self.packages.${system}.default;
                  entrypoint = [ (pkgs.lib.getExe self.packages.${system}.default) ];
                };
                # gives a fair amount for one-package-per-layer but leaves some headroom from max of 127
                maxLayers = 100;
              });
            nix-direnv = pkgs.nix-direnv;
          };

          checks.git-hooks = git-hooks.lib.${pkgs.system}.run {
            src = ./.;
            hooks = {
              shellcheck.enable = true;
              nixfmt-rfc-style.enable = true;
              prettier = {
                enable = true;
                types_or = [
                  "markdown"
                  "json"
                  "yaml"
                ];
                excludes = [ "^\\.template/.+/\\.cruft\\.json$" ];
              };
              mypy = {
                enable = true;
                package = venvDevelopment;
              };
              ruff = {
                enable = true;
                package = venvDevelopment;
              };
              ruff-format = {
                enable = true;
                package = venvDevelopment;
              };
              pytest = rec {
                enable = true;
                name = "pytest";
                package = venvDevelopment;
                entry = "${pkgs.bash}/bin/bash -c 'REPO_ROOT=\"\${REPO_ROOT:=$PWD}\" ${package}/bin/pytest'";
                pass_filenames = false;
                files = "^(src|tests)/";
              };
              sphinx = rec {
                enable = true;
                name = "sphinx";
                package = venvDevelopment;
                entry = "${package}/bin/sphinx-build docs/ docs/generated/";
                pass_filenames = false;
                files = "^(src|docs)/";
              };
              # cruft produces these merge reject files when an automatic merge fails
              check-no-merge-rejects = rec {
                enable = true;
                name = "check-no-merge-rejects";
                package = (
                  pkgs.writeShellApplication {
                    name = "pre-commit-check-no-merge-rejects";
                    text = ''
                      for filename in "$@"; do
                        echo "Rejected merge file exists: $filename"
                      done
                      exit 1
                    '';
                  }
                );
                entry = "${package}/bin/${package.meta.mainProgram}";
                files = "\\.rej$";
              };
            };
          };

          devShells.default = pkgs.mkShellNoCC {
            packages = [
              venvDevelopment
              pkgs.uv
              pkgs.act
            ] ++ self.checks.${system}.git-hooks.enabledPackages;

            env = {
              # Don't create venv using uv
              UV_NO_SYNC = "1";

              # Force uv to use Python interpreter from venv
              UV_PYTHON = "${venvDevelopment}/bin/python";

              # Prevent uv from downloading managed Python
              UV_PYTHON_DOWNLOADS = "never";
            };

            shellHook = ''
              # Undo nixpkgs default dependency propagation
              unset PYTHONPATH

              # Undo nixpkgs default of reproducible timestamps, affects Sphinx docs
              unset SOURCE_DATE_EPOCH

              # Get repository root using git. This is expanded at runtime by the editable `.pth` machinery.
              export REPO_ROOT="$(git rev-parse --show-toplevel)"

              # Install pre-commit hooks to be installed into git
              ${self.checks.${system}.git-hooks.shellHook}
            '';
          };
        };
    in
    {
      packages = eachSystem (system: (perSystem system).packages);
      devShells = eachSystem (system: (perSystem system).devShells);
      checks = eachSystem (system: (perSystem system).checks);
    };
}
