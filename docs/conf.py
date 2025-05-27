import pathlib

import tomllib

extensions = [
    "autoapi.extension",
    "sphinx.ext.napoleon",
    "sphinx.ext.viewcode",
    "sphinx.ext.autodoc.typehints",
    "myst_parser",
]

with (pathlib.Path(__file__).parent.parent / "pyproject.toml").open("rb") as f:
    pyproject = tomllib.load(f)

project = pyproject["project"]["name"]
version = pyproject["project"]["version"]
if "authors" in pyproject["project"]:
    author = ", ".join(author.get("name") or author["email"] for author in pyproject["project"]["authors"])
    copyright = f'%Y, {author}'

autoapi_type = "python"
autoapi_dirs = ["../src"]
autodoc_typehints = "description"
html_theme = "haiku"
