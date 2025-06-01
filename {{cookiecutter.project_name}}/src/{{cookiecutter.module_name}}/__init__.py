import importlib.metadata as _importlib_metadata

__all__ = ["__version__"]

__version__: str = _importlib_metadata.version(__package__ or __name__)
