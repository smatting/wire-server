#!/usr/bin/env bash
# Checks the inputs Concourse sends after a build of wire-server, run from the
# source checkout, and writes them to GITHUB_OUTPUT. The charts to publish are
# charts_to_release minus EXCLUDED_CHARTS (charts released by their own component),
# all of them to S3 when that channel is on, and those also in OCI_CHARTS (the
# deployable ones) to OCI. The version is the dev form of compute-version.sh,
# derived from a GA tag or from a pre-release tag.
set -euo pipefail

die() {
  echo "::error::$*"
  exit 1
}

[[ "${VERSION:-}" =~ ^[0-9]+\.[0-9]+\.[0-9]+-((alpha|beta|rc)\.[1-9][0-9]*\.)?[0-9]{14}\.g([0-9a-f]{7})$ ]] \
  || die "version '${VERSION:-}' is not X.Y.Z-<YYYYMMDDHHMMSS>.g<sha7> nor X.Y.Z-<pre>.N.<YYYYMMDDHHMMSS>.g<sha7>"
sha7=${BASH_REMATCH[3]}

[[ "${COMMIT:-}" =~ ^[0-9a-f]{40}$ ]] || die "commit '${COMMIT:-}' is not a full sha"
[[ "${COMMIT:0:7}" == "$sha7" ]] || die "the version names g${sha7} but the commit is ${COMMIT:0:7}"

[[ "${SOURCE_REF:-}" =~ ^[A-Za-z0-9._/-]+$ ]] || die "source_ref '${SOURCE_REF:-}' is not a branch name"
git rev-parse --verify --quiet "refs/remotes/origin/${SOURCE_REF}" >/dev/null \
  || die "branch '${SOURCE_REF}' not found"
git merge-base --is-ancestor "$COMMIT" "refs/remotes/origin/${SOURCE_REF}" \
  || die "commit ${COMMIT} is not on ${SOURCE_REF}"
[[ "$(git rev-parse HEAD)" == "$COMMIT" ]] || die "the source checkout is not at ${COMMIT}"

jq -e 'type == "array" and length > 0 and all(.[]; type == "string")' <<<"${CHARTS:-}" >/dev/null 2>&1 \
  || die "charts_to_release must be a JSON array of chart names, sent as a string"

charts=()
excluded=()
for chart in $(jq -r '.[]' <<<"$CHARTS"); do
  [[ "$chart" =~ ^[a-z0-9][a-z0-9-]*$ ]] || die "'${chart}' is not a chart name"
  if [[ " ${EXCLUDED_CHARTS:-} " == *" ${chart} "* ]]; then
    excluded+=("$chart")
    continue
  fi
  [[ -f "charts/${chart}/Chart.yaml" ]] || die "charts/${chart}/Chart.yaml not found at ${COMMIT}"
  charts+=("$chart")
done
for chart in wire-server wire-server-enterprise; do
  [[ " ${charts[*]} " == *" ${chart} "* ]] || die "charts_to_release does not list ${chart}"
done
if ((${#excluded[@]})); then
  echo "::notice::Left out (released by their own component): ${excluded[*]}"
fi
oci_charts=()
for chart in ${OCI_CHARTS:?}; do
  [[ " ${charts[*]} " == *" ${chart} "* ]] && oci_charts+=("$chart")
done
for chart in wire-server wire-server-enterprise; do
  [[ " ${oci_charts[*]} " == *" ${chart} "* ]] || die "OCI_CHARTS does not list ${chart}"
done
echo "::notice::${#charts[@]} charts to S3: ${charts[*]}"
echo "::notice::${#oci_charts[@]} charts to OCI: ${oci_charts[*]}"

{
  echo "version=${VERSION}"
  echo "commit=${COMMIT}"
  echo "source-ref=${SOURCE_REF}"
  echo "charts=${charts[*]}"
  echo "oci-charts=${oci_charts[*]}"
} >>"$GITHUB_OUTPUT"
