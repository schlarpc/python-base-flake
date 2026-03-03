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

      pyprojectToml = lib.importTOML ./pyproject.toml;
      hasRootProject = pyprojectToml ? project.name;

      projectName =
        if hasRootProject then
          pyprojectToml.project.name
        else
          lib.warn "No [project] section in pyproject.toml — using \"workspace\" as project name for venv naming." "workspace";

      projectVersion =
        if pyprojectToml ? project.version then
          pyprojectToml.project.version
        else
          self.shortRev or self.dirtyShortRev or "unknown";

      # Combine requires-python constraints from uv.lock and pyproject.toml so that
      # interpreter selection stays correct even when uv.lock is stale.
      # For workspace roots without a [project] section, only the uv.lock constraint applies.
      effectiveRequiresPython =
        workspace.requires-python
        ++ lib.optionals (pyprojectToml ? project.requires-python) (
          pyproject-nix.lib.pep440.parseVersionConds pyprojectToml.project.requires-python
        );

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

          # Select the lowest Python interpreter version that satisfies the combined constraints.
          matchingInterpreters = pyproject-nix.lib.util.filterPythonInterpreters {
            requires-python = effectiveRequiresPython;
            inherit (pkgs) pythonInterpreters;
          };
          python =
            if matchingInterpreters != [ ] then
              lib.head matchingInterpreters
            else
              let
                uvLockConstraint = (lib.importTOML ./uv.lock)."requires-python" or "(not set)";
                pyprojectConstraint = pyprojectToml.project.requires-python or "(not set)";
              in
              throw ''
                No Python interpreter in the flake's nixpkgs satisfies the requires-python constraints.
                  pyproject.toml: ${pyprojectConstraint}
                  uv.lock:        ${uvLockConstraint}
                If these constraints conflict, run `uv lock` to update the lockfile.
                If both look correct, try `nix flake update nixpkgs` to get newer Python versions.
                If uv lock fails due to a stale dev shell, try `rm uv.lock && uv lock` as a last resort.
              '';

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
              # Editable-mode build fixup for workspace packages:
              # Build systems (e.g. `hatchling`) have a dependency on the `editables` package.
              # Currently in uv2nix, build-system dependencies have to be explicitly modeled.
              (
                final: prev:
                lib.mapAttrs (
                  name: _:
                  prev.${name}.overrideAttrs (old: {
                    nativeBuildInputs =
                      old.nativeBuildInputs
                      ++ final.resolveBuildSystem {
                        editables = [ ];
                      };
                  })
                ) workspace.deps.default
              )
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

          # Build Sphinx documentation as a Nix output.
          venvDoc = pythonSet.mkVirtualEnv "${projectName}-doc-env" workspace.deps.all;
          doc = pkgs.runCommand "${projectName}-doc" { nativeBuildInputs = [ venvDoc ]; } ''
            cp -r ${./.} source
            chmod -R u+w source
            sphinx-build source/docs $out/share/doc/${projectName}/html
          '';

          # Build an "application" per workspace member that only exposes application binaries.
          memberApplications = lib.mapAttrs (
            name: _:
            (pkgs.callPackages pyproject-nix.build.util { }).mkApplication {
              venv = venvRelease;
              package = pythonSet.${name};
            }
          ) workspace.deps.default;

          # Build a container image per workspace member.
          makeContainerTag =
            name: pkg:
            let
              parts = lib.splitString "-" (lib.last (lib.splitString "/" pkg.outPath));
              hash = builtins.head parts;
            in
            "${name}-${projectVersion}-${hash}";

          memberContainers = lib.mapAttrs (
            name: app:
            nix2container.packages.${system}.nix2container.buildImage {
              inherit name;
              tag = makeContainerTag name app;
              config = {
                workingDir = app;
                entrypoint = [ (lib.getExe app) ];
              };
              # gives a fair amount for one-package-per-layer but leaves some headroom from max of 127
              maxLayers = 100;
            }
          ) memberApplications;
        in
        {
          packages =
            memberApplications
            // lib.mapAttrs' (name: value: {
              name = "${name}-container";
              inherit value;
            }) memberContainers
            // lib.optionalAttrs hasRootProject {
              default = memberApplications.${projectName};
              container = memberContainers.${projectName};
              inherit doc;
            };

          checks.git-hooks = git-hooks.lib.${system}.run {
            src = ./.;
            package = pkgs.prek;
            hooks = {
              shellcheck.enable = true;
              nixfmt.enable = true;
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
            ]
            ++ self.checks.${system}.git-hooks.enabledPackages;

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

              # Install git hooks
              ${self.checks.${system}.git-hooks.shellHook}
            '';
          };

          formatter = pkgs.nixfmt-tree.override {
            runtimeInputs = [
              venvDevelopment
              pkgs.prettier
            ];
            settings.formatter = {
              ruff-format = {
                command = "ruff";
                options = [ "format" ];
                includes = [
                  "*.py"
                  "*.pyi"
                ];
              };
              prettier = {
                command = "prettier";
                options = [ "--write" ];
                includes = [
                  "*.md"
                  "*.json"
                  "*.yaml"
                  "*.yml"
                ];
                excludes = [ ".template/*/.cruft.json" ];
              };
            };
          };
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
    flakeOutput
    // {
      overlays.default =
        let
          fullOverlay = overlay;
          memberNames = builtins.attrNames workspace.deps.default;
        in
        final: prev: lib.filterAttrs (name: _: builtins.elem name memberNames) (fullOverlay final prev);
    };
}
