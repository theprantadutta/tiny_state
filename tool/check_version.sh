#!/usr/bin/env bash
#
# Verifies that the release version is stated consistently in every place that
# matters. Run with no arguments in CI; pass a git tag to also check that.
#
#   tool/check_version.sh            # pubspec == CHANGELOG
#   tool/check_version.sh v2.0.0     # pubspec == CHANGELOG == tag
set -euo pipefail

pubspec_version="$(sed -nE 's/^version:[[:space:]]*([^[:space:]]+).*/\1/p' pubspec.yaml | head -1)"
changelog_version="$(sed -nE 's/^##[[:space:]]+\[?([0-9]+\.[0-9]+\.[0-9]+[^]]*)\]?.*/\1/p' CHANGELOG.md | head -1)"

if [ -z "$pubspec_version" ]; then
  echo "::error::could not read version from pubspec.yaml" >&2
  exit 1
fi
if [ -z "$changelog_version" ]; then
  echo "::error::could not read the top version heading from CHANGELOG.md" >&2
  exit 1
fi

echo "pubspec.yaml:  $pubspec_version"
echo "CHANGELOG.md:  $changelog_version"

status=0
if [ "$pubspec_version" != "$changelog_version" ]; then
  echo "::error::pubspec.yaml ($pubspec_version) and CHANGELOG.md ($changelog_version) disagree" >&2
  status=1
fi

if [ "$#" -ge 1 ] && [ -n "$1" ]; then
  tag_version="${1#v}"
  echo "git tag:       $tag_version"
  if [ "$pubspec_version" != "$tag_version" ]; then
    echo "::error::tag ($tag_version) does not match pubspec.yaml ($pubspec_version)" >&2
    status=1
  fi
fi

if [ "$status" -eq 0 ]; then
  echo "Version $pubspec_version is consistent."
fi
exit "$status"
