{
  inputs = {
    poetry2nix = {
      url = "github:nix-community/poetry2nix";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        flake-utils.follows = "flake-utils";
      };
    };
    pre-commit-hooks = {
      url = "github:cachix/pre-commit-hooks.nix";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        flake-utils.follows = "flake-utils";
      };
    };
  };

  outputs = { self, nixpkgs, flake-utils, poetry2nix, pre-commit-hooks, ... }:
    flake-utils.lib.eachSystem [ "x86_64-linux" "aarch64-linux" ] (system:
      let
        projectConfig = {
          python = pkgs.python3;
          dependencyOverrides = (final: prev: { });
        };
        pyProject = builtins.fromTOML (builtins.readFile (./. + "/pyproject.toml"));
        pkgs = import nixpkgs {
          config = { };
          system = system;
          overlays = [ poetry2nix.overlay ];
        };
        mkPoetryArgs = {
          overrides = pkgs.poetry2nix.overrides.withDefaults projectConfig.dependencyOverrides;
          python = projectConfig.python;
          projectDir = ./.;
        };
        # HACK work around a bug in poetry2nix where the .egg-info is named incorrectly
        pkgInfoFields = {
          Metadata-Version = "2.1";
          Name = pyProject.tool.poetry.name;
          Version = pyProject.tool.poetry.version;
          Summary = pyProject.tool.poetry.description;
        };
        pkgInfoFile = with pkgs.lib.generators; (
          builtins.toFile "${pyProject.tool.poetry.name}-PKG-INFO"
            (toKeyValue { mkKeyValue = mkKeyValueDefault { } ": "; } pkgInfoFields)
        );
        moduleNames = (
          pkgs.lib.attrNames
            (
              pkgs.lib.filterAttrs
                (n: v: v == "directory")
                (builtins.readDir srcDir)
            )
        );
        editableEggInfoFix = ps:
          (ps.toPythonModule (
            pkgs.runCommand "editable-egg-info-fix" { } ''
              mkdir -p "$out/${ps.python.sitePackages}"
              cd "$out/${ps.python.sitePackages}"
              ${
                pkgs.lib.concatMapStringsSep
                "\n"
                (pkg: ''mkdir "${pkg}.egg-info"; ln -s "${pkgInfoFile}" "${pkg}.egg-info/PKG-INFO"'')
                moduleNames
              }
            ''));
        # use impure flake in direnv to get live editing for mkPoetryEnv
        envProjectDir = builtins.getEnv "PROJECT_DIR";
        srcDir = (if envProjectDir == "" then ./src else "${envProjectDir}/src");
        mkPoetryEnvEditableArgs = {
          editablePackageSources.${pyProject.tool.poetry.name} = srcDir;
          extraPackages = (ps: [ (editableEggInfoFix ps) ]);
        };
      in
      rec {
        packages.default = (pkgs.poetry2nix.mkPoetryApplication mkPoetryArgs);
        apps.default = flake-utils.lib.mkApp { drv = packages.default; };
        devShells.default = (
          (pkgs.poetry2nix.mkPoetryEnv (mkPoetryArgs // mkPoetryEnvEditableArgs)).env.overrideAttrs (
            oldAttrs: {
              buildInputs = [ pkgs.poetry pkgs.poetry2nix.cli ];
              shellHook = ''
                ${checks.pre-commit-hooks.shellHook}
              '';
            }
          )
        );
        checks.pre-commit-hooks = pre-commit-hooks.lib.${pkgs.system}.run {
          src = ./.;
          hooks =
            let
              poetryPreCommit = name: text: (pkgs.writeShellApplication
                {
                  name = "pre-commit-${name}";
                  runtimeInputs = with devShells.default; (nativeBuildInputs ++ buildInputs);
                  text = text;
                } + "/bin/pre-commit-${name}");
            in
            {
              shellcheck.enable = true;
              black.enable = true;
              nixpkgs-fmt.enable = true;
              prettier = {
                enable = true;
                types_or = [ "markdown" "json" ];
              };
              isort = {
                enable = true;
                entry = pkgs.lib.mkForce (poetryPreCommit "isort" ''isort "$@"'');
              };
              mypy = {
                enable = true;
                name = "mypy";
                entry = poetryPreCommit "mypy" ''mypy "$@"'';
                pass_filenames = false;
              };
              pytest = {
                enable = true;
                name = "pytest";
                entry = poetryPreCommit "pytest" ''
                  # HACK force path to be in scope for flake evaluation
                  # ${ pkgs.poetry2nix.cleanPythonSources { src = ./.; } + "/src" }
                  pytest "$@"
                '';
                pass_filenames = false;
              };
            };
        };
      });
}


