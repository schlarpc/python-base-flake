# {{ cookiecutter.project_name }}

## Development

This project uses [{{ cookiecutter.project_name }}](https://github.com/schlarpc/{{ cookiecutter.project_name }}) as its
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
reflected without rebuilding.

```shell
$ {{ cookiecutter.project_name }}
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

The project uses [pre-commit] to enforce code quality standards. While pre-commit hooks run
automatically on git commits, you can manually run all checks against the entire codebase
at any time.

```shell
$ pre-commit run --all
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

To run all flake checks including pre-commit rules, tests, and build verification,
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

## Keeping in sync with the base template

This project was generated from [{{ cookiecutter.project_name }}] and can receive updates from the
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
[pre-commit]: https://pre-commit.com/
[pytest]: https://docs.pytest.org/
[{{ cookiecutter.project_name }}]: https://github.com/schlarpc/{{ cookiecutter.project_name }}
[ruff]: https://docs.astral.sh/ruff/
[skopeo]: https://github.com/containers/skopeo
[uv]: https://docs.astral.sh/uv/
[uv2nix]: https://github.com/pyproject-nix/uv2nix
