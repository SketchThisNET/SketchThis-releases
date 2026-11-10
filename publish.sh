#!/bin/bash
# Publish a signed RBZ: create a GitHub Release with the RBZ attached, then
# point manifest.json at it. Pushing the manifest is the go-live step; every
# installed SketchThis Updater offers the new version on its next check.
#
# Usage:
#   ./publish.sh [options] <plugin|updater> <version> <path-to-signed.rbz> "<release notes>"
#
# Options:
#   --min-updater X.Y.Z   (plugin only) oldest updater able to install this release
#   --allow-unsigned      publish an RBZ that has no .susig signature (testing only)
#   --dry-run             run every check and show the new manifest, change nothing
#
# Requires: gh (authenticated), ruby, unzip, shasum. Run from a clean checkout.

set -euo pipefail

REPO="SketchThisNET/SketchThis-releases"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
MANIFEST="$SCRIPT_DIR/manifest.json"

usage() { sed -n '2,15p' "$0" | sed 's/^# \{0,1\}//'; }
die() { echo "Error: $*" >&2; exit 1; }

ALLOW_UNSIGNED=0
DRY_RUN=0
MIN_UPDATER=""
ARGS=()
while [ $# -gt 0 ]; do
  case "$1" in
    --allow-unsigned) ALLOW_UNSIGNED=1; shift ;;
    --dry-run) DRY_RUN=1; shift ;;
    --min-updater) [ $# -ge 2 ] || die "--min-updater needs a version"; MIN_UPDATER="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    -*) die "unknown option $1" ;;
    *) ARGS+=("$1"); shift ;;
  esac
done
if [ "${#ARGS[@]}" -ne 4 ]; then usage >&2; exit 1; fi

PRODUCT="${ARGS[0]}"
VERSION="${ARGS[1]}"
RBZ="${ARGS[2]}"
NOTES="${ARGS[3]}"

case "$PRODUCT" in
  plugin)  BASENAME="SketchThis";        TITLE="SketchThis" ;;
  updater) BASENAME="SketchThisUpdater"; TITLE="SketchThis Updater" ;;
  *) die "product must be 'plugin' or 'updater', got '$PRODUCT'" ;;
esac

VERSION_RE='^[0-9]+(\.[0-9]+)*$'
[[ "$VERSION" =~ $VERSION_RE ]] || die "version must look like 1.2.3, got '$VERSION'"
if [ -n "$MIN_UPDATER" ]; then
  [ "$PRODUCT" = "plugin" ] || die "--min-updater only applies to the plugin"
  [[ "$MIN_UPDATER" =~ $VERSION_RE ]] || die "--min-updater must look like 1.2.3"
fi
[ -f "$RBZ" ] || die "no such file: $RBZ"

# --- check the RBZ is what it claims to be -----------------------------------
CONTENTS="$(unzip -Z1 "$RBZ")" || die "$RBZ is not a readable zip/RBZ"
LOADER="$BASENAME.rb"
if echo "$CONTENTS" | grep -qx "$LOADER"; then
  unzip -p "$RBZ" "$LOADER" | grep -Eq "VERSION[[:space:]]*=[[:space:]]*['\"]$VERSION['\"]" \
    || die "$LOADER inside the RBZ does not declare version $VERSION"
else
  die "$RBZ has no $LOADER at its root, so it is not a $TITLE package"
fi
if ! echo "$CONTENTS" | grep -q '\.susig$'; then
  if [ "$ALLOW_UNSIGNED" -eq 1 ]; then
    echo "Warning: publishing an UNSIGNED RBZ (no .susig inside)."
  else
    die "$RBZ is not signed (no .susig inside). Sign it in the Developer Center, or pass --allow-unsigned for testing."
  fi
fi

TAG="$PRODUCT-v$VERSION"
ASSET="${BASENAME}_v$VERSION.rbz"
URL="https://github.com/$REPO/releases/download/$TAG/$ASSET"
SHA256="$(shasum -a 256 "$RBZ" | awk '{print $1}')"

# --- write the new manifest ---------------------------------------------------
NEW_MANIFEST="$(PRODUCT="$PRODUCT" VERSION="$VERSION" URL="$URL" SHA256="$SHA256" NOTES="$NOTES" \
  MIN_UPDATER="$MIN_UPDATER" MANIFEST="$MANIFEST" ruby -rjson -e '
    manifest = JSON.parse(File.read(ENV["MANIFEST"]))
    entry = { "version" => ENV["VERSION"], "url" => ENV["URL"], "sha256" => ENV["SHA256"], "notes" => ENV["NOTES"] }
    entry["min_updater"] = ENV["MIN_UPDATER"] unless ENV["MIN_UPDATER"].empty?
    manifest[ENV["PRODUCT"]] = entry
    ordered = %w[updater plugin].select { |k| manifest.key?(k) }.map { |k| [k, manifest[k]] }.to_h
    puts JSON.pretty_generate(ordered)
  ')"

echo "Product : $TITLE $VERSION"
echo "Release : $TAG"
echo "Asset   : $ASSET"
echo "SHA-256 : $SHA256"
echo ""
echo "New manifest.json:"
echo "$NEW_MANIFEST"
echo ""

if [ "$DRY_RUN" -eq 1 ]; then
  echo "Dry run: nothing was published."
  exit 0
fi

# --- publish ------------------------------------------------------------------
cd "$SCRIPT_DIR"
[ -z "$(git status --porcelain)" ] || die "working tree is not clean; commit or stash first"
git pull --ff-only
if gh release view "$TAG" --repo "$REPO" >/dev/null 2>&1; then
  die "release $TAG already exists; bump the version instead of replacing a published file"
fi

STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT
cp "$RBZ" "$STAGE/$ASSET"

gh release create "$TAG" "$STAGE/$ASSET" --repo "$REPO" --title "$TITLE $VERSION" --notes "$NOTES"

echo "$NEW_MANIFEST" > "$MANIFEST"
git add manifest.json
git commit -m "$TITLE $VERSION"
git push

echo ""
echo "Published. Installed updaters will offer $TITLE $VERSION on their next check."
