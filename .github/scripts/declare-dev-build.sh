#!/usr/bin/env bash
# Declares the dev build to the release managers, one record per component, from
# the source checkout: wire-server first, with the release note built from
# changelog.d, then every other chart published to OCI that the release managers
# know as a component (all of CHARTS but wire-server-enterprise, which ships with
# wire-server), at the same version and tied to wire-server. NOTIFY_RM is the
# notify-rm script of wire-rm-actions, which does the POST (OIDC token, staging
# and prod); RM_* and REQUIRED go through to it.
set -euo pipefail

: "${VERSION:?}" "${COMMIT:?}" "${BRANCH:?}" "${CHARTS:?}" "${DIGESTS_FILE:?}" "${OCI_REPOSITORY:?}" "${NOTIFY_RM:?}"

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

echo "::notice::${#components[@]} components to declare: ${components[*]}"
for component in "${components[@]}"; do
  echo "::group::${component} ${VERSION}"
  if [[ "$component" == wire-server ]]; then
    meta="chart.wire-server-enterprise=${enterprise}"
    title=$VERSION
    description=$note
  else
    meta="follows=wire-server"
    title=""
    description=""
  fi
  COMPONENT=$component \
    KIND=dev \
    REPOSITORY="oci://${OCI_REPOSITORY}/${component}" \
    DIGEST="$(digest_of "$component")" \
    NOTE_TITLE=$title \
    NOTE_DESCRIPTION=$description \
    META=$meta \
    bash "$NOTIFY_RM"
  echo "::endgroup::"
done
