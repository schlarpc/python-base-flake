import runpy

import pytest


@pytest.fixture
def module_name(pytestconfig):
    modules = [entry for entry in (pytestconfig.rootpath / "src").iterdir() if entry.is_dir()]
    assert len(modules) == 1
    return modules[0].name


def test_import_works(module_name):
    assert __import__(module_name).__version__


def test_cli_runs_when_main(module_name, capsys):
    try:
        runpy.run_module(module_name, run_name="__main__")
    except SystemExit:
        pass
    captured = capsys.readouterr()
    assert captured.out or captured.err


def test_cli_skipped_when_not_main(module_name, capsys):
    runpy.run_module(module_name)
    captured = capsys.readouterr()
    assert not (captured.out or captured.err)
