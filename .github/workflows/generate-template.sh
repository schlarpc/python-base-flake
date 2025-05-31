#!/usr/bin/env bash

set -euo pipefail

PROJECT_NAME_PATTERN='s/python-base-flake/{{ cookiecutter.project_name }}/g'
MODULE_NAME_PATTERN='s/python_base_flake/{{ cookiecutter.module_name }}/g'
DEST=".template/{{ cookiecutter.project_name }}"
mkdir -p "$DEST"

if [[ -n "${GITHUB_REF-}" ]]; then
    # In Actions: strip refs/heads/ or refs/tags/ → branch|tag name
    FILE_CMD=(git ls-tree -r -z "${GITHUB_REF##*/}" --name-only)
else
    # Local run: include tracked *and* untracked files, honor .gitignore
    FILE_CMD=(git ls-files -z --cached --others --exclude-standard)
fi
while IFS= read -r -d '' entry; do
    NEW_NAME="$(sed "$MODULE_NAME_PATTERN;$PROJECT_NAME_PATTERN" <<< "$entry")"
    mkdir -p "$(dirname "$DEST/$NEW_NAME")"
    cp -pn -- "$entry" "$DEST/$NEW_NAME"
    sed -i "$MODULE_NAME_PATTERN;$PROJECT_NAME_PATTERN" "$DEST/$NEW_NAME"
done < <("${FILE_CMD[@]}")
rm -rf -- "$DEST/.template" "$DEST/.github/workflows/generate-template."{yml,sh}
