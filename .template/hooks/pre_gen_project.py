import json
import re
import sys

REGEX_CHECKS = {
    "project_name": {
        "value": r""" {{ cookiecutter.project_name | jsonify }} """,
        "pattern": r"^[A-Za-z0-9-]+$",
    },
    "module_name": {
        "value": r""" {{ cookiecutter.module_name | jsonify }} """,
        "pattern": r"^[A-Za-z_][A-Za-z0-9_]+$",
    },
}


def main():
    for check_name, check in REGEX_CHECKS.items():
        if not re.match(check["pattern"], json.loads(check["value"])):
            print(
                f"ERROR: {check['value']!r} is not a valid {check_name}, "
                f"must match {check['pattern']!r}",
                file=sys.stderr,
            )
            sys.exit(1)


if __name__ == "__main__":
    main()
