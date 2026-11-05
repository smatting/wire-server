#!/usr/bin/env bash
# Checks the inputs Concourse sends after a build of wire-server, run from the
# source checkout, and writes them to GITHUB_OUTPUT. The charts come from the
# Makefile of the built commit (make echo-release-charts, the same list a release
# reads), minus EXCLUDED_CHARTS (charts released by their own component): all of
# them to S3 when that channel is on, and the deployable ones (make
# echo-oci-charts) to OCI. A charts_to_release input is compared to that list and
# ignored: a difference is a warning, never a failure. The version is the dev
# form of compute-version.sh, derived from a GA tag or from a pre-release tag.
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

release_charts=$(make -s echo-release-charts)
[[ -n "$release_charts" ]] || die "make echo-release-charts printed nothing at ${COMMIT}"
oci_list=$(make -s echo-oci-charts)
[[ -n "$oci_list" ]] || die "make echo-oci-charts printed nothing at ${COMMIT}"

if [[ -n "${CHARTS_INPUT:-}" ]]; then
  if sent=$(jq -r 'if type == "array" and all(.[]; type == "string") then join(" ") else error("not a list") end' <<<"$CHARTS_INPUT" 2>/dev/null); then
    if [[ "$(tr ' ' '\n' <<<"$sent" | sort)" == "$(tr ' ' '\n' <<<"$release_charts" | sort)" ]]; then
      echo "charts_to_release matches the Makefile of ${COMMIT:0:7}; the Makefile is the source either way."
    else
      echo "::warning::charts_to_release differs from make echo-release-charts at ${COMMIT:0:7} and is ignored. Sent: ${sent}. Makefile: ${release_charts}"
    fi
  else
    echo "::warning::charts_to_release is not a JSON array of chart names and is ignored: ${CHARTS_INPUT}"
  fi
fi

charts=()
excluded=()
for chart in $release_charts; do
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
for chart in $oci_list; do
  [[ " ${charts[*]} " == *" ${chart} "* ]] || die "echo-oci-charts lists ${chart}, which echo-release-charts does not"
  oci_charts+=("$chart")
done
for chart in wire-server wire-server-enterprise; do
  [[ " ${oci_charts[*]} " == *" ${chart} "* ]] || die "echo-oci-charts does not list ${chart}"
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
