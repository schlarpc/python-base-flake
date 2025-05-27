# python-base-flake

`python-base-flake` is an opinionated Python package template based on
[uv2nix]. It aims to provide an instant feedback loop during development
while staying reproducible and interoperable with the [Nix] ecosystem.

## Features

- Reproducible builds with [Nix] and [uv2nix]
- Shell environment management with [direnv]
- Python dependency management with [uv]
- Dependency management for anything else with [nixpkgs]
- Fast container builds with [nix2container]
- Unit testing with [pytest]
- Type checking with [mypy]
- Code formatting with [ruff], [Prettier], and [nixfmt]
- Code coverage with [Coverage.py]
- Documentation with [Sphinx] and [MyST]
- Automatic API documentation with [Sphinx AutoAPI] and [napoleon]
- Linting enforcement with [pre-commit] and [git-hooks.nix]
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

[cookiecutter]: https://cookiecutter.readthedocs.io/
[coverage.py]: https://coverage.readthedocs.io/
[cruft]: https://cruft.github.io/cruft/
[dependabot]: https://github.com/dependabot
[direnv]: https://direnv.net/
[flakes enabled]: https://nixos.wiki/wiki/Flakes#Enable_flakes_permanently_in_NixOS
[git]: https://git-scm.com/
[git-hooks.nix]: https://github.com/cachix/git-hooks.nix
[github actions]: https://github.com/features/actions
[myst]: https://myst-parser.readthedocs.io/
[mypy]: https://mypy.readthedocs.io/
[napoleon]: https://www.sphinx-doc.org/en/master/usage/extensions/napoleon.html
[nix]: https://nixos.org/
[nix2container]: https://github.com/nlewo/nix2container
[nixfmt]: https://github.com/NixOS/nixfmt
[nixpkgs]: https://github.com/NixOS/nixpkgs
[poetry2nix]: https://github.com/nix-community/poetry2nix
[pre-commit]: https://pre-commit.com/
[prettier]: https://prettier.io/
[pytest]: https://docs.pytest.org/
[ruff]: https://docs.astral.sh/ruff/
[sphinx autoapi]: https://sphinx-autoapi.readthedocs.io/
[sphinx]: https://www.sphinx-doc.org/
[uv]: https://docs.astral.sh/uv/
[uv2nix]: https://github.com/pyproject-nix/uv2nix
[visual studio code]: https://code.visualstudio.com/
