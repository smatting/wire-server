#!/usr/bin/env bash
# Resolves the digest of every image of the release at the version of its dev
# build on quay.io: the build Concourse made of the source commit. A single
# missing image means there is no complete dev build of that commit, and the
# release cannot be prepared from it. Writes {"<repository>": "<digest>"} to
# DIGESTS_FILE.
set -euo pipefail

: "${IMAGES:?}" "${DEV_VERSION:?}" "${DIGESTS_FILE:?}"

command -v crane >/dev/null || { echo "::error::crane is not installed"; exit 1; }

read -ra images <<<"$IMAGES"
missing=()
echo '{}' >"$DIGESTS_FILE"
for image in "${images[@]}"; do
  if digest=$(crane digest "${image}:${DEV_VERSION}" 2>/dev/null) && [[ "$digest" =~ ^sha256:[0-9a-f]{64}$ ]]; then
    echo "${image}:${DEV_VERSION} ${digest}"
    jq --arg i "$image" --arg d "$digest" '.[$i] = $d' "$DIGESTS_FILE" >"${DIGESTS_FILE}.tmp"
    mv "${DIGESTS_FILE}.tmp" "$DIGESTS_FILE"
  else
    missing+=("$image")
  fi
done
if ((${#missing[@]})); then
  echo "::error::no dev build ${DEV_VERSION} for ${#missing[@]} of ${#images[@]} images: ${missing[*]}. Concourse must have built the source commit before a release is prepared from it."
  exit 1
fi
echo "::notice::${#images[@]} images resolved at ${DEV_VERSION}"
echo "file=${DIGESTS_FILE}" >>"$GITHUB_OUTPUT"
