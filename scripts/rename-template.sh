#!/usr/bin/env bash
# Replace template placeholders in the working tree.
# Usage: scripts/rename-template.sh <AppName> <BundleID> <TeamID>
# Example: scripts/rename-template.sh MyApp com.example.myapp ABCDE12345
# Pass YOUR_TEAM_ID as TeamID to keep the team placeholder.
set -euo pipefail

usage() {
  echo "Usage: $0 <AppName> <BundleID> <TeamID>" >&2
  echo "Example: $0 MyApp com.example.myapp ABCDE12345" >&2
}

# Rewriting this file while bash is still reading it corrupts the rest of
# the script. Run from a temp copy, then update the copy in the repo.
if [[ -z "${RENAME_TEMPLATE_REEXEC:-}" ]]; then
  if [[ $# -ne 3 ]]; then
    usage
    exit 1
  fi
  root="$(cd "$(dirname "$0")/.." && pwd)"
  script_path="$(cd "$(dirname "$0")" && pwd)/$(basename "$0")"
  tmp="$(mktemp)"
  cp "$script_path" "$tmp"
  RENAME_TEMPLATE_REEXEC=1 \
    RENAME_TEMPLATE_ROOT="$root" \
    bash "$tmp" "$@"
  status=$?
  rm -f "$tmp"
  exit "$status"
fi

if [[ $# -ne 3 ]]; then
  usage
  exit 1
fi

NEW_NAME="$1"
NEW_BUNDLE_ID="$2"
NEW_TEAM_ID="$3"

OLD_NAME="AppTemplate"
OLD_BUNDLE_ID="com.example.apptemplate"
OLD_TEAM_ID="YOUR_TEAM_ID"

if [[ ! "$NEW_NAME" =~ ^[A-Za-z][A-Za-z0-9]*$ ]]; then
  echo "App name must be an ASCII identifier, such as MyApp." >&2
  exit 1
fi

if [[ ! "$NEW_BUNDLE_ID" =~ ^[a-zA-Z0-9][a-zA-Z0-9.-]*[a-zA-Z0-9]$ ]]; then
  echo "Bundle ID must look like com.example.myapp." >&2
  exit 1
fi

if [[ "$NEW_TEAM_ID" != "YOUR_TEAM_ID" && ! "$NEW_TEAM_ID" =~ ^[A-Z0-9]{10}$ ]]; then
  echo "Team ID must be 10 letters or digits, or the placeholder YOUR_TEAM_ID." >&2
  exit 1
fi

ROOT="${RENAME_TEMPLATE_ROOT:?}"
cd "$ROOT"

python3 - "$ROOT" "$OLD_NAME" "$NEW_NAME" "$OLD_BUNDLE_ID" "$NEW_BUNDLE_ID" "$OLD_TEAM_ID" "$NEW_TEAM_ID" <<'PY'
import pathlib
import sys

root, old_name, new_name, old_bundle, new_bundle, old_team, new_team = sys.argv[1:]
skip_dirs = {".git", "build", "DerivedData", ".bundle", "vendor"}
suffixes = {
    ".swift", ".yml", ".yaml", ".plist", ".rb", ".md", ".sh",
    ".json", ".xcprivacy", ".gitignore",
}
named = {".ruby-version", ".gitignore", "Gemfile", "Appfile", "Matchfile", "Fastfile"}

def should_visit(path: pathlib.Path) -> bool:
    return not any(part in skip_dirs or part.endswith(".xcodeproj") for part in path.parts)

replacements = (
    (old_bundle, new_bundle),
    (old_team, new_team),
    (old_name, new_name),
)

for path in pathlib.Path(root).rglob("*"):
    if not path.is_file() or not should_visit(path):
        continue
    if path.name not in named and path.suffix not in suffixes:
        continue
    text = path.read_text(encoding="utf-8")
    updated = text
    for old, new in replacements:
        updated = updated.replace(old, new)
    if updated != text:
        path.write_text(updated, encoding="utf-8")
        print(f"updated {path.relative_to(root)}")
PY

SOURCE_FILE="Sources/${OLD_NAME}App.swift"
TARGET_FILE="Sources/${NEW_NAME}App.swift"
if [[ "$OLD_NAME" != "$NEW_NAME" && -f "$SOURCE_FILE" ]]; then
  git mv "$SOURCE_FILE" "$TARGET_FILE" 2>/dev/null || mv "$SOURCE_FILE" "$TARGET_FILE"
  echo "renamed $SOURCE_FILE -> $TARGET_FILE"
fi

echo "Placeholders replaced. Review the diff, then commit."
