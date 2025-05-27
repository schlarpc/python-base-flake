# {{ cookiecutter.project_name }}

## Development

### Loading the environment

```shell
$ direnv allow
```

```shell
$ {{ cookiecutter.project_name }}
```

```shell
$ direnv reload
```

### Maintaining Python dependencies

```shell
$ uv add some-package
```

```shell
$ uv sync --upgrade
```

### Testing and linting

```shell
$ pre-commit run --all
```

### Using the Nix build system

```shell
$ nix run .
```

```shell
$ nix run '.#container.copyToDockerDaemon'
```

```shell
$ nix flake check
```

```shell
$ nix flake update
```

## Updating the base template

```shell
$ cruft update --checkout template
```
