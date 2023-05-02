# python-base-flake

`python-base-flake` is an opinionated Python package template based on
[poetry2nix]. It aims to provide an instant feedback loop during development
while staying reproducible and interoperable with the [Nix] ecosystem.

## Features

- Reproducible builds with [Nix] and [poetry2nix]
- Shell environment management with [direnv]
- Python dependency management with [Poetry] and [poetry-plugin-up]
- Dependency management for anything else with [nixpkgs]
- Unit testing with [pytest]
- Type checking with [mypy]
- Code formatting with [Black], [isort], [Prettier], and [nixpkgs-fmt]
- Code coverage with [Coverage.py]
- Documentation with [Sphinx] and [MyST]
- Automatic API documentation with [Sphinx AutoAPI] and [napoleon]
- Linting enforcement with [pre-commit] and [pre-commit-hooks.nix]
- Template updates with [cruft]
- Package updates with [Dependabot]
- Continuous integration with [GitHub Actions]
- Common tasks preconfigured with [Visual Studio Code]
- No opinionation on the package's runtime code

## Prerequisites

You must have the following already installed to use this:

- [Nix] with [flakes enabled]
- [direnv] integrated into your shell
- [cookiecutter] or [cruft]
- [git] with name and email configured globally

## Getting started

```shell
$ cookiecutter https://github.com/schlarpc/python-base-flake --checkout template
# or
$ cruft create https://github.com/schlarpc/python-base-flake --checkout template
```

[black]: https://black.readthedocs.io/
[cookiecutter]: https://cookiecutter.readthedocs.io/
[coverage.py]: https://coverage.readthedocs.io/
[cruft]: https://cruft.github.io/cruft/
[dependabot]: https://github.com/dependabot
[direnv]: https://direnv.net/
[flakes enabled]: https://nixos.wiki/wiki/Flakes#Installing_flakes
[git]: https://git-scm.com/
[github actions]: https://github.com/features/actions
[isort]: https://pycqa.github.io/isort/
[mypy]: https://mypy.readthedocs.io/
[myst]: https://myst-parser.readthedocs.io/
[napoleon]: https://www.sphinx-doc.org/en/master/usage/extensions/napoleon.html
[nix]: https://nixos.org/
[nixpkgs-fmt]: https://github.com/nix-community/nixpkgs-fmt
[nixpkgs]: https://github.com/NixOS/nixpkgs
[poetry]: https://python-poetry.org/
[poetry-plugin-up]: https://github.com/MousaZeidBaker/poetry-plugin-up
[poetry2nix]: https://github.com/nix-community/poetry2nix
[pre-commit-hooks.nix]: https://github.com/cachix/pre-commit-hooks.nix
[pre-commit]: https://pre-commit.com/
[prettier]: https://prettier.io/
[pytest]: https://docs.pytest.org/
[sphinx autoapi]: https://sphinx-autoapi.readthedocs.io/
[sphinx]: https://www.sphinx-doc.org/
[visual studio code]: https://code.visualstudio.com/
