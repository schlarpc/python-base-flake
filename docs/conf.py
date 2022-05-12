import pathlib

import tomli

extensions = [
    "autoapi.extension",
    "sphinx.ext.napoleon",
    "sphinx.ext.viewcode",
    "sphinx.ext.autodoc.typehints",
    "myst_parser",
]

with (pathlib.Path(__file__).parent.parent / "pyproject.toml").open("rb") as f:
    pyproject = tomli.load(f)

project = pyproject["tool"]["poetry"]["name"]
author = ", ".join(pyproject["tool"]["poetry"]["authors"])
version = pyproject["tool"]["poetry"]["version"]
copyright = author

autoapi_type = "python"
autoapi_dirs = ["../src"]
autodoc_typehints = "description"
html_theme = "haiku"
