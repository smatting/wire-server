#!/usr/bin/env bash
# Pushes the packaged charts to oci://OCI_REPOSITORY/<chart>, refusing to overwrite
# a version already published with different content (a pinned digest would stop
# resolving), and writes the digest of each chart to DIGESTS_FILE (JSON object).
set -euo pipefail

: "${VERSION:?}" "${CHARTS:?}" "${CHART_DIR:?}" "${OCI_REPOSITORY:?}" "${DIGESTS_FILE:?}"
registry=${OCI_REPOSITORY%%/*}

printf '%s' "${QUAY_PASSWORD:?}" | helm registry login "$registry" --username "${QUAY_USERNAME:?}" --password-stdin
printf '%s' "$QUAY_PASSWORD" | oras login "$registry" --username "$QUAY_USERNAME" --password-stdin >/dev/null

strip_lock_timestamp() {
  local lock
  for lock in "$1/requirements.lock" "$1/Chart.lock"; do
    [[ -f "$lock" ]] && sed -i -e 's/^generated: .*//' "$lock"
  done
  return 0
}

digest_of() {
  oras manifest fetch --descriptor "${OCI_REPOSITORY}/$1:${VERSION}" | jq -r '.digest'
}

echo '{}' >"$DIGESTS_FILE"
read -ra charts <<<"$CHARTS"
for chart in "${charts[@]}"; do
  tgz="${CHART_DIR}/${chart}-${VERSION}.tgz"
  work=$(mktemp -d)
  if helm pull "oci://${OCI_REPOSITORY}/${chart}" --version "$VERSION" --destination "$work/published" >/dev/null 2>&1; then
    mkdir -p "$work/ours" "$work/theirs"
    tar -C "$work/ours" -xzf "$tgz"
    tar -C "$work/theirs" -xzf "$work"/published/*.tgz
    strip_lock_timestamp "$work/ours/${chart}"
    strip_lock_timestamp "$work/theirs/${chart}"
    if ! diff -r "$work/ours" "$work/theirs" >/dev/null; then
      echo "::error::${chart}:${VERSION} is already in oci://${OCI_REPOSITORY} with different content"
      exit 1
    fi
    echo "${chart}:${VERSION} already published and identical"
  else
    helm push "$tgz" "oci://${OCI_REPOSITORY}"
  fi
  rm -rf "$work"
  digest=$(digest_of "$chart")
  [[ "$digest" =~ ^sha256:[0-9a-f]{64}$ ]] || {
    echo "::error::no digest for ${OCI_REPOSITORY}/${chart}:${VERSION}"
    exit 1
  }
  jq --arg c "$chart" --arg d "$digest" '.[$c] = $d' "$DIGESTS_FILE" >"${DIGESTS_FILE}.tmp"
  mv "${DIGESTS_FILE}.tmp" "$DIGESTS_FILE"
done

{
  echo "repository=oci://${OCI_REPOSITORY}/wire-server"
  echo "digest=$(jq -r '.["wire-server"]' "$DIGESTS_FILE")"
  echo "enterprise=oci://${OCI_REPOSITORY}/wire-server-enterprise@$(jq -r '.["wire-server-enterprise"]' "$DIGESTS_FILE")"
} >>"$GITHUB_OUTPUT"
