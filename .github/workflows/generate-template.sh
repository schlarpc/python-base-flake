#!/usr/bin/env bash

set -euo pipefail

PROJECT_NAME_PATTERN='s/python-base-flake/{{cookiecutter.project_name}}/g'
MODULE_NAME_PATTERN='s/python_base_flake/{{cookiecutter.module_name}}/g'
REPO="$(git rev-parse --show-toplevel)"
DEST="$REPO/.template/{{cookiecutter.project_name}}"
mkdir --parents "$DEST"

# Remove existing template generation output
git clean --force --quiet -X -d -- "$DEST"

if [[ -n "${GITHUB_REF-}" ]]; then
    # In Actions: strip refs/heads/ or refs/tags/ → branch|tag name
    FILE_CMD=(git ls-tree -r -z "${GITHUB_REF##*/}" --name-only)
else
    # Local run: include tracked *and* untracked files, honor .gitignore
    FILE_CMD=(git ls-files -z --cached --others --exclude-standard)
fi
while IFS= read -r -d '' entry; do
    NEW_NAME="$(sed "$MODULE_NAME_PATTERN;$PROJECT_NAME_PATTERN" <<< "$entry")"
    ENTRY_DEST="$DEST/$NEW_NAME"
    mkdir --parents "$(dirname "$ENTRY_DEST")"
    if [ ! -e "$ENTRY_DEST" ]; then
        cp --preserve=mode,ownership,timestamps --no-clobber -- "$entry" "$ENTRY_DEST"
        sed --in-place "$MODULE_NAME_PATTERN;$PROJECT_NAME_PATTERN" "$DEST/$NEW_NAME"
    fi
done < <("${FILE_CMD[@]}")

# Remove files only needed for template generation
rm --recursive --force -- "$DEST/.template" "$DEST/.github/workflows/generate-template."{yml,sh}
