#!/usr/bin/env bash
# Declares the dev build to the release managers, one record per component, from
# the source checkout: wire-server first, with the release note built from
# changelog.d, then every other chart published to OCI that the release managers
# know as a component (all of CHARTS but wire-server-enterprise, which ships with
# wire-server), at the same version and tied to wire-server. NOTIFY_RM is the
# notify-rm script of wire-rm-actions, which does the POST (OIDC token, staging
# and prod); RM_* and REQUIRED go through to it. The wire-server record carries a
# dev manifest with publication/compatibility.yaml, read by COMPATIBILITY_SH (the
# compatibility script of wire-rm-actions): the release managers only learn the
# interfaces a version provides from a manifest.
set -euo pipefail

: "${VERSION:?}" "${COMMIT:?}" "${BRANCH:?}" "${CHARTS:?}" "${DIGESTS_FILE:?}" "${OCI_REPOSITORY:?}" "${NOTIFY_RM:?}"
: "${COMPATIBILITY_SH:?}" "${SOURCE_REPOSITORY:?}" "${RUN_URL:?}"

die() {
  echo "::error::$*"
  exit 1
}

[[ -f "$NOTIFY_RM" ]] || die "notify-rm script not found at ${NOTIFY_RM}"
[[ -x changelog.d/mk-changelog.sh ]] || die "changelog.d/mk-changelog.sh not found in the source checkout"

read -ra charts <<<"$CHARTS"
components=(wire-server)
for chart in "${charts[@]}"; do
  case $chart in
    wire-server | wire-server-enterprise) ;;
    *) components+=("$chart") ;;
  esac
done

digest_of() {
  local digest
  digest=$(jq -r --arg c "$1" '.[$c] // empty' "$DIGESTS_FILE")
  [[ "$digest" =~ ^sha256:[0-9a-f]{64}$ ]] || die "no digest for ${1} in ${DIGESTS_FILE}"
  echo "$digest"
}

changelog=$(./changelog.d/mk-changelog.sh)
note="Dev build of \`${BRANCH}\` at ${COMMIT}."
if [[ -n "$changelog" ]]; then
  note+=$'\n\n'"Unreleased changes (changelog.d):"$'\n\n'"$changelog"
fi
enterprise="oci://${OCI_REPOSITORY}/wire-server-enterprise@$(digest_of wire-server-enterprise)"

# The dev manifest of wire-server: the charts of the build and what
# publication/compatibility.yaml provides and requires. A file the compatibility
# script refuses only warns: the build is then declared without a manifest, and
# the release managers see no interface served by this version.
manifest=""
compat_dir=$(mktemp -d)
if [[ ! -f publication/compatibility.yaml ]]; then
  echo "::warning::no publication/compatibility.yaml at ${COMMIT}: wire-server ${VERSION} is declared without a manifest"
elif ! GITHUB_OUTPUT="" FILE=publication/compatibility.yaml OUTPUT_DIR="$compat_dir" bash "$COMPATIBILITY_SH" >&2; then
  echo "::warning::publication/compatibility.yaml was refused: wire-server ${VERSION} is declared without a manifest"
else
  manifest="${compat_dir}/dev-manifest.json"
  jq -n \
    --arg version "$VERSION" --arg repository "$SOURCE_REPOSITORY" --arg ref "$BRANCH" --arg commit "$COMMIT" \
    --arg oci "$OCI_REPOSITORY" --arg charts "$CHARTS" \
    --arg workflow "${GITHUB_WORKFLOW:-}" --arg run_id "${GITHUB_RUN_ID:-}" --arg run_url "$RUN_URL" \
    --arg created_at "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    --slurpfile digests "$DIGESTS_FILE" --slurpfile compatibility "${compat_dir}/manifest-compatibility.json" '
    {
      schemaVersion: "wire.component-release-manifest/v1alpha1",
      component: "wire-server",
      version: $version,
      kind: "dev",
      source: {repository: $repository, ref: $ref, commit: $commit},
      inputs: [],
      artifacts: [$charts | split(" ")[] | select(. != "")
                  | {type: "chart", repository: ("oci://" + $oci + "/" + .), version: $version, digest: $digests[0][.]}],
      compatibility: {
        provides: $compatibility[0].provides,
        requires: $compatibility[0].requires,
        includes: ($compatibility[0].includes // [])
      },
      build: {workflow: $workflow, run_id: $run_id, run_url: $run_url, created_at: $created_at},
      request_id: null,
      rm_origin: null,
      documents: {}
    }' >"$manifest"
  echo "::notice::wire-server manifest: $(jq -c '[.compatibility.provides[] | "\(.interface) \(.supported)"]' "$manifest")"
fi

echo "::notice::${#components[@]} components to declare: ${components[*]}"
for component in "${components[@]}"; do
  echo "::group::${component} ${VERSION}"
  if [[ "$component" == wire-server ]]; then
    meta="chart.wire-server-enterprise=${enterprise}"
    title=$VERSION
    description=$note
    manifest_file=$manifest
  else
    meta="follows=wire-server"
    title=""
    description=""
    manifest_file=""
  fi
  COMPONENT=$component \
    KIND=dev \
    REPOSITORY="oci://${OCI_REPOSITORY}/${component}" \
    DIGEST="$(digest_of "$component")" \
    NOTE_TITLE=$title \
    NOTE_DESCRIPTION=$description \
    META=$meta \
    MANIFEST_FILE=$manifest_file \
    bash "$NOTIFY_RM"
  echo "::endgroup::"
done
