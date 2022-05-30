import re
import sys

REGEX_CHECKS = {
    "project_name": {
        "value": "{{ cookiecutter.project_name }}",
        "pattern": r"^[A-Za-z0-9-]+$",
    },
}


def main():
    for check_name, check in REGEX_CHECKS.items():
        if not re.match(check["pattern"], check["value"]):
            print(
                f"ERROR: {check['value']} is not a valid {check_name}, "
                f"must match {check['pattern']!r}",
                file=sys.stderr,
            )
            sys.exit(1)


if __name__ == "__main__":
    main()
