# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Development Commands

This is a Python project using Nix flakes and modern Python tooling. Use these commands for development:

### Environment Setup

- `direnv allow` - Load the development environment (required first step)

### Python Development

- `{{cookiecutter.project_name}}` - Run the CLI application directly
- `python -m {{cookiecutter.project_name}}` - Run the module as a script
- `uv add package-name` - Add runtime dependencies
- `uv add --dev package-name` - Add development dependencies
- `uv sync --upgrade` - Update all dependencies to latest compatible versions

### Testing and Code Quality

- `pytest` - Run unit tests (configured with coverage reporting)
- `ruff check` - Lint Python code for style issues and bugs
- `ruff format` - Format Python code automatically
- `mypy` - Perform static type checking
- `pre-commit run --all` - Run all code quality checks

### Nix Commands

- `nix run` - Build and run the application with Nix
- `nix flake check` - Run all flake checks (tests, pre-commit, build verification)
- `nix flake update` - Update Nix dependencies
- `nix run .#container.copyToDockerDaemon` - Build container image
- `nix run .#container.copyTo -- docker-daemon:{{cookiecutter.project_name}}:latest` - Copy container using Skopeo

## Architecture

This project is built from the [python-base-flake](https://github.com/schlarpc/python-base-flake) template and follows these architectural patterns:

### Project Structure

- **src/{{cookiecutter.project_name}}/**: Main package source code
- **tests/**: Test suite built with pytest
- **docs/**: Sphinx documentation configuration

### Key Technologies

- **Python 3.12+**: Minimum required Python version
- **Nix Flakes**: Reproducible development environment and builds
- **uv**: Fast Python package manager for dependency management
- **pyproject.toml**: Modern Python project configuration
- **ruff**: Fast Python linting and formatting
- **mypy**: Static type checking
- **pytest**: Testing framework with coverage reporting
- **pre-commit**: Git hooks for code quality enforcement
- **Sphinx**: Documentation generation
- **nix2container**: Efficient container image building

### Development Workflow

The project uses direnv for automatic environment loading and pre-commit hooks for code quality. All Python packages are managed through uv and built using Nix's reproducible build system. The CLI is a simple application that can be extended by modifying `_cli.py:main()`.

### Container Support

The project includes efficient container builds using nix2container, with multi-layer optimization and automatic tagging based on the build hash.
