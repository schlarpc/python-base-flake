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
      systems,
      ...
    }:
    let
      inherit (nixpkgs) lib;

      workspace = uv2nix.lib.workspace.loadWorkspace { workspaceRoot = ./.; };
      pyproject = pyproject-nix.lib.project.loadPyproject { projectRoot = ./.; };
      projectName = pyproject.pyproject.project.name;
      projectVersion = pyproject.pyproject.project.version;

      # Load Python dependencies from uv workspace into a package overlay.
      overlay = workspace.mkPyprojectOverlay {
        # By default, we set the preference to `wheel`, letting most packages "just work".
        # If you want to build everything from source, use `sdist`, but you will likely need
        # to implement dependency fixups below.
        sourcePreference = "wheel";
      };

      perSystem =
        system:
        let
          pkgs = nixpkgs.legacyPackages."${system}";

          # By default, we use the current "stable" version of Python selected by `nixpkgs`.
          python = pkgs.python3;

          # This contains any build fixups needed for Python packages.
          dependencyFixups = (
            _final: _prev: {
              # Implement project-specific build fixups for dependencies here.
              # See https://pyproject-nix.github.io/uv2nix/patterns/patching-deps.html for details.
              # Note that uv2nix is _not_ using Nixpkgs buildPythonPackage.
              # It's using https://pyproject-nix.github.io/pyproject.nix/build.html
              # If you need to build everything from sdists, you should consider reusing existing
              # build system fixups, like https://github.com/TyberiusPrime/uv2nix_hammer_overrides
            }
          );

          # Constuct complete Python package set based on workspace and overrides.
          pythonSet =
            (pkgs.callPackage pyproject-nix.build.packages {
              inherit python;
            }).overrideScope
              (
                lib.composeManyExtensions [
                  pyproject-build-systems.overlays.default
                  overlay
                  dependencyFixups
                ]
              );

          # Override previous Python set with an overlay to make the current package editable.
          editablePythonSet = pythonSet.overrideScope (
            lib.composeManyExtensions [
              # Create an overlay enabling editable mode for all local dependencies.
              (workspace.mkEditablePyprojectOverlay {
                # Use environment variable that gets expanded in the .pth handler;
                # not during flake evaluation.
                root = "$REPO_ROOT";
              })
              # Editable-mode build fixup for this package:
              # `hatchling` (our build system) has a dependency on the `editables` package.
              # Currently in uv2nix, build-system dependencies have to be explicitly modeled.
              (final: prev: {
                "${projectName}" = prev."${projectName}".overrideAttrs (old: {
                  nativeBuildInputs =
                    old.nativeBuildInputs
                    ++ final.resolveBuildSystem {
                      editables = [ ];
                    };
                });
              })
            ]
          );

          # Apply any fixups that apply at the virtualenv level, not to specific packages.
          applyVirtualenvFixups =
            env:
            lib.pipe env [
              # Ignore a configured list of colliding files (semi-common in namespace packages)
              (
                env:
                env.overrideAttrs (old: {
                  venvIgnoreCollisions = [ ];
                })
              )
              # Add a metadata element so that things like `nix run` point at the main script
              (env: lib.addMetaAttrs { mainProgram = projectName; } env)
            ];

          # Build the "release" virtualenv, used for `nix run` or container builds.
          venvRelease = applyVirtualenvFixups (
            pythonSet.mkVirtualEnv "${projectName}-env" workspace.deps.default
          );

          # Build the "development" virtualenv, used for `nix develop` and `direnv`.
          venvDevelopment = applyVirtualenvFixups (
            editablePythonSet.mkVirtualEnv "${projectName}-dev-env" workspace.deps.all
          );

          # Build an "application" that only exposes the application binaries.
          application = (
            (pkgs.callPackages pyproject-nix.build.util { }).mkApplication {
              venv = venvRelease;
              package = pythonSet."${projectName}";
            }
          );
        in
        {
          packages = {
            default = application;
            container =
              let
                # shuffle around the output path to make an easy-to-read container image tag
                makeContainerTag =
                  pkg:
                  let
                    parts = lib.splitString "-" (lib.last (lib.splitString "/" pkg.outPath));
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
                  entrypoint = [ (lib.getExe self.packages.${system}.default) ];
                };
                # gives a fair amount for one-package-per-layer but leaves some headroom from max of 127
                maxLayers = 100;
              });
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

          formatter = pkgs.nixfmt-tree;
        };

      eachSystem = lib.genAttrs (import systems);
      applySystemToAttrs =
        attrNames: lib.genAttrs attrNames (attrName: eachSystem (system: (perSystem system)."${attrName}"));
      flakeOutput = applySystemToAttrs [
        "packages"
        "devShells"
        "checks"
        "formatter"
      ];
    in
    flakeOutput;
}
