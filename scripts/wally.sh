#!/bin/sh
# Builds the Wally package from the pesde one, and publishes it with `publish`.
#
#   scripts/wally.sh            build into a temp dir, list its files, test-install its dependencies
#   scripts/wally.sh publish    the same, then `wally publish` (run `wally login` once first)
#
# pesde.toml stays the only manifest: name, version, metadata and the wally dependencies
# are read from it. Two things differ in the Wally build:
#   - The code goes under src/ next to a generated wally.toml and default.project.json.
#   - Wally puts a package's dependencies next to the package, not in its roblox_packages
#     folder, so every `<Loom root>.roblox_packages` becomes `<Loom root>.Parent`.
#
# Wally clones its index with libgit2, which can't authenticate over SSH. A global
# `url.git@github.com:.insteadOf https://github.com/` rule makes it fail with "failed to
# start SSH session"; drop the rule while publishing.
set -eu

ROOT=$(cd "$(dirname "$0")/.." && pwd)
cd "$ROOT"

command -v wally > /dev/null || { echo "wally not found (rokit add --global UpliftGames/wally)" >&2; exit 1; }

# The first `key = "value"` line before any [section].
field() {
	awk -v key="$1" '/^\[/ { exit } $1 == key { sub(/^[^=]*= */, ""); gsub(/^"|"$/, ""); print; exit }' pesde.toml
}

NAME=$(field name)
VERSION=$(field version)
DESCRIPTION=$(field description)
LICENSE=$(field license)
AUTHORS=$(awk '/^\[/ { exit } $1 == "authors" { sub(/^[^=]*= */, ""); print; exit }' pesde.toml)

# Lines like `bytenet = { wally = "ffrostflame/bytenet", version = "^0.4.6" }` become
# `bytenet = "ffrostflame/bytenet@^0.4.6"`. Aliases stay the same, so the Vendors keep working.
DEPENDENCIES=$(awk '
	/^\[/ { section = $0; next }
	section == "[dependencies]" && /wally *=/ {
		alias = $1
		match($0, /wally *= *"[^"]*"/); pkg = substr($0, RSTART, RLENGTH); sub(/^wally *= *"/, "", pkg); sub(/"$/, "", pkg)
		match($0, /version *= *"[^"]*"/); ver = substr($0, RSTART, RLENGTH); sub(/^version *= *"/, "", ver); sub(/"$/, "", ver)
		printf "%s = \"%s@%s\"\n", alias, pkg, ver
	}
' pesde.toml)

if awk '/^\[/ { section = $0; next } section == "[dependencies]" && NF && !/wally *=/ { found = 1 } END { exit !found }' pesde.toml; then
	echo "pesde.toml has a dependency that isn't from Wally; it can't go in the Wally package" >&2
	exit 1
fi

OUT=$(mktemp -d "${TMPDIR:-/tmp}/loom-wally.XXXXXX")
trap 'rm -rf "$OUT"' EXIT

mkdir -p "$OUT/src"
cp -r Core Decorators Enums Types Vendors Middleware init.luau "$OUT/src/"
cp README.md CHANGELOG.md "$OUT/"

find "$OUT/src" -name '*.luau' -exec sed -i 's/\.roblox_packages\b/.Parent/g' {} +
if grep -rq roblox_packages "$OUT/src"; then
	echo "src still refers to roblox_packages after the rewrite:" >&2
	grep -rn roblox_packages "$OUT/src" >&2
	exit 1
fi

cat > "$OUT/wally.toml" << EOF
[package]
name = "$NAME"
version = "$VERSION"
description = "$DESCRIPTION"
license = "$LICENSE"
authors = $AUTHORS
realm = "shared"
registry = "https://github.com/UpliftGames/wally-index"
exclude = ["Packages", "wally.lock"]

[dependencies]
$DEPENDENCIES
EOF

cat > "$OUT/default.project.json" << EOF
{
	"name": "loom",
	"tree": {
		"\$path": "src"
	}
}
EOF

echo "== $NAME@$VERSION =="
cat "$OUT/wally.toml"
echo
wally package --project-path "$OUT" --list
echo
echo "== resolving dependencies =="
wally install --project-path "$OUT"
rm -rf "$OUT/Packages" "$OUT/wally.lock"

if [ "${1:-}" = "publish" ]; then
	wally publish --project-path "$OUT"
fi
