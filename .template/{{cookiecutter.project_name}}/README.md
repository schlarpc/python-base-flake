# {{ cookiecutter.project_name }}

## Development

This project uses [python-base-flake](https://github.com/schlarpc/python-base-flake) as its
foundation, providing a reproducible development environment with [Nix] and modern Python tooling.

### Setting up the development environment

The project uses [direnv] to automatically load the development environment. When you enter the
project directory, direnv will activate a shell environment with all dependencies available,
and it will automatically refresh when you modify the Nix flake or Python dependencies.

```shell
$ direnv allow
```

Once the environment is loaded, you can run the project directly using its command-line interface.
The package is installed in editable mode, so changes to the source code in `src/` are immediately
reflected without rebuilding. Additionally, `PYTHONPATH` is set automatically, so you can interact
with the module naturally using the Python executable.

```shell
$ {{ cookiecutter.project_name }}
$ python -m {{ cookiecutter.project_name }}
```

### Managing Python dependencies

Python dependencies are managed with [uv], a fast Python package manager. You can add packages to
either runtime dependencies or development dependencies.

```shell
$ uv add some-package
$ uv add --dev some-dev-package
```

To update all Python packages to their latest compatible versions according to the constraints
in `pyproject.toml`, use the upgrade command.

```shell
$ uv sync --upgrade
```

### Running tests and code quality checks

The project uses [prek] to enforce code quality standards. While hooks run
automatically on git commits, you can manually run all checks against the entire codebase
at any time.

```shell
$ prek run --all-files
```

You can also run individual tools directly:

Run unit tests with [pytest], which is configured to discover and run all tests in
the `tests/` directory.

```shell
$ pytest
```

Check Python code for style issues and potential bugs using [ruff]'s linting capabilities.

```shell
$ ruff check
```

Format Python code automatically according to the project's style guidelines
using [ruff]'s formatter.

```shell
$ ruff format
```

Perform static type checking with [mypy] to catch type-related errors before runtime.

```shell
$ mypy
```

### Working with Nix

#### Building and running with Nix

[Nix] provides reproducible builds and deployment options.
You can build and run the application using Nix's pure build system.

```shell
$ nix run
```

#### Building container images

The project includes [nix2container] for efficient container builds.
You can build and load the container image directly into your local Docker daemon,
or copy it to any destination using [skopeo].

```shell
$ nix run .#container.copyToDockerDaemon
$ nix run .#container.copyTo -- docker-daemon:{{ cookiecutter.project_name }}:latest
```

#### Running quality checks

To run all flake checks including linting, tests, and build verification,
use the check command. This is automatically run on GitHub pushes and pull requests.

```shell
$ nix flake check
```

#### Updating Nix dependencies

Keep your Nix dependencies up to date by updating the flake lock file, which
includes [nixpkgs], [uv2nix], and other flake inputs.

```shell
$ nix flake update
```

#### Using as a library overlay

The flake exports `overlays.default`, an overlay for the [uv2nix]/[pyproject.nix] Python
package set (not a nixpkgs overlay — the Python package building machinery is different
from nixpkgs `buildPythonPackage`). It contains only the workspace member packages, not
transitive dependencies from `uv.lock`. This lets other uv2nix-based projects consume
your packages as library dependencies.

> **Note:** uv and Nix are separate dependency resolution systems. The overlay makes
> packages available to the Nix build, but uv still needs its own source for the
> dependency. You'll need to declare the library in both places: as a flake input (for
> Nix) and as a uv source (for `uv add` / `uv lock`). Typically this means adding a
> `[tool.uv.sources]` entry pointing at the library's git repository.

In the downstream consumer's `flake.nix`, add this flake as an input and compose the
overlay into the consumer's `pyproject.nix` Python package set:

```nix
# consumer flake.nix (relevant parts)
{
  inputs.{{ cookiecutter.project_name }}.url = "github:owner/{{ cookiecutter.project_name }}";

  outputs = { self, nixpkgs, {{ cookiecutter.project_name }}, ... }:
  let
    pkgs = nixpkgs.legacyPackages.x86_64-linux;
    pythonSet = (pkgs.callPackage pyproject-nix.build.packages { inherit python; }).overrideScope
      (lib.composeManyExtensions [
        pyproject-build-systems.overlays.default
        consumerOverlay
        {{ cookiecutter.project_name }}.overlays.default   # <-- library overlay (last, to override uv source)
      ]);
  in { /* ... */ };
}
```

The library overlay must be composed **after** the consumer's workspace overlay. The
consumer's `uv.lock` contains its own source entry for the library package (e.g. a git
or directory source from `[tool.uv.sources]`), and the library overlay overrides it with
the Nix derivation from the flake input.

## Project layout

This flake supports several [uv] project layouts out of the box. No changes to `flake.nix`
are needed when adding workspace members.

**Single package** — A standalone project with a `[project]` and `[build-system]` in the root
`pyproject.toml`. This is the default layout created by `uv init --package`. `nix build` produces
an application binary, and `nix run .#container.copyToDockerDaemon` builds a container image.
See [Creating projects][uv-init] in the uv docs.

**Workspace with a root package** — A root `pyproject.toml` that has both a `[project]` section
and a `[tool.uv.workspace]` table, with additional packages as [workspace members][uv-workspaces].
Each member is exposed as `nix build .#<member-name>` and `nix run .#<member-name>-container.copyToDockerDaemon`.
The root package is also available as `nix build` (the default).

**Virtual workspace** — A root `pyproject.toml` with `[tool.uv.workspace]` but _no_ `[project]`
section. The root is not itself a package; it only defines the workspace. There is no default
`nix build` target — use `nix build .#<member-name>` to build a specific member. See
[Workspaces][uv-workspaces] in the uv docs.

In all layouts, `nix develop` (or [direnv]) provides a development shell with all workspace
members installed in editable mode.

## Keeping in sync with the base template

This project was generated from [python-base-flake] and can receive updates from the
upstream template using [cruft]. This command will attempt to apply the latest template
changes while preserving your project-specific modifications.

```shell
$ cruft update --checkout template
```

[cruft]: https://cruft.github.io/cruft/
[direnv]: https://direnv.net/
[mypy]: https://mypy.readthedocs.io/
[nix]: https://nixos.org/
[nix2container]: https://github.com/nlewo/nix2container
[nixpkgs]: https://github.com/NixOS/nixpkgs
[prek]: https://github.com/jdx/prek
[pytest]: https://docs.pytest.org/
[pyproject.nix]: https://github.com/pyproject-nix/pyproject.nix
[python-base-flake]: https://github.com/schlarpc/python-base-flake
[ruff]: https://docs.astral.sh/ruff/
[skopeo]: https://github.com/containers/skopeo
[uv]: https://docs.astral.sh/uv/
[uv-init]: https://docs.astral.sh/uv/concepts/projects/init/
[uv-workspaces]: https://docs.astral.sh/uv/concepts/projects/workspaces/
[uv2nix]: https://github.com/pyproject-nix/uv2nix
