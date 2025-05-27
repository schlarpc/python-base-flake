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

      # file collisions to ignore
      ignoreCollisions = [ ];

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
        in
        {
          packages = {
            default = (pythonSet.mkVirtualEnv "${projectName}-env" workspace.deps.default).overrideAttrs (old: {
              venvIgnoreCollisions = ignoreCollisions;
            });
            container =
              let
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
                name = self.packages.${system}.default.name;
                tag = makeContainerTag self.packages.${system}.default;
                config = {
                  workingDir = self.packages.${system}.default;
                };
                maxLayers = 100;
              });
            nix-direnv = pkgs.nix-direnv;
          };

          checks = {
            git-hooks = git-hooks.lib.${pkgs.system}.run {
              src = ./.;
              hooks = { };
            };
          };

          devShells.default =
            let
              # Create an overlay enabling editable mode for all local dependencies.
              editableOverlay = workspace.mkEditablePyprojectOverlay {
                # Use environment variable
                root = "$REPO_ROOT";
              };

              # Override previous set with our overrideable overlay.
              editablePythonSet = pythonSet.overrideScope (
                lib.composeManyExtensions [
                  editableOverlay

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

              # Build virtual environment, with local packages being editable.
              #
              # Enable all optional dependencies for development.
              virtualenv =
                (editablePythonSet.mkVirtualEnv "${projectName}-dev-env" workspace.deps.all).overrideAttrs
                  (old: {
                    venvIgnoreCollisions = ignoreCollisions;
                  });
            in
            pkgs.mkShell {
              packages = [
                virtualenv
                pkgs.uv
                pkgs.nixfmt-rfc-style
                pkgs.act
              ];

              env = {
                # Don't create venv using uv
                UV_NO_SYNC = "1";

                # Force uv to use Python interpreter from venv
                UV_PYTHON = "${virtualenv}/bin/python";

                # Prevent uv from downloading managed Python
                UV_PYTHON_DOWNLOADS = "never";
              };

              shellHook = ''
                # Undo some nixpkgs env vars
                unset PYTHONPATH SOURCE_DATE_EPOCH

                # Get repository root using git. This is expanded at runtime by the editable `.pth` machinery.
                export REPO_ROOT=$(git rev-parse --show-toplevel)
                
                # Install pre-commit hooks
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
