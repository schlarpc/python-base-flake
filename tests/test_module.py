import json
import runpy

import pytest

MODULE_NAME = "python_base_flake"


def test_import_works():
    assert __import__(MODULE_NAME).__version__


def test_cli_runs_when_main(capsys):
    try:
        runpy.run_module(MODULE_NAME, run_name="__main__")
    except SystemExit:
        pass
    captured = capsys.readouterr()
    assert captured.out or captured.err


def test_cli_skipped_when_not_main(capsys):
    runpy.run_module(MODULE_NAME)
    captured = capsys.readouterr()
    assert not (captured.out or captured.err)
