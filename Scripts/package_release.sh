#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

dry_run=0
skip_build=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) dry_run=1 ;;
    --skip-build) skip_build=1 ;;
    *) echo "usage: Scripts/package_release.sh [--dry-run] [--skip-build]" >&2; exit 64 ;;
  esac
  shift
done

run() {
  if [[ "$dry_run" == "1" ]]; then
    printf '+'
    printf ' %q' "$@"
    printf '\n'
  else
    "$@"
  fi
}

if [[ "$skip_build" == "0" ]]; then
  run Scripts/build_app.sh
fi

app="dist/IdeaFermentationMachine.app"
pkg_dir="dist/release"
pkg="$pkg_dir/IdeaFermentationMachine-0.1.0.pkg"
identity="${IFM_INSTALLER_IDENTITY:-}"
notary_profile="${IFM_NOTARY_PROFILE:-}"

run mkdir -p "$pkg_dir"
if [[ -n "$identity" ]]; then
  run productbuild --component "$app" /Applications --identifier com.chrisdimarco.idea-fermentation-machine.pkg --version 0.1.0 --sign "$identity" "$pkg"
  run pkgutil --check-signature "$pkg"
else
  run productbuild --component "$app" /Applications --identifier com.chrisdimarco.idea-fermentation-machine.pkg --version 0.1.0 "$pkg"
fi

if [[ -n "$notary_profile" ]]; then
  run xcrun notarytool submit "$pkg" --keychain-profile "$notary_profile" --wait
  run xcrun stapler staple "$pkg"
fi

echo "$PWD/$pkg"
