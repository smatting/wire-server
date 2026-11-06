## Overview

5.37.18 is a maintenance release of the 5.37 line for operators running 5.37.2, and the first wire-server release published with the Wire release standard: the version is tagged `v5.37.18`, the images promoted by digest from a dev build, the deployable charts also published to `oci://quay.io/wire/charts/stable`. The release note, the release declaration and the compatibility file of each version live in `publication/` and are attached to the GitHub release. The structured release declaration of this version is [`declaration.json`](declaration.json).

The jump from 5.37.2 comes from the move to the release standard: no GA between 5.37.2 and 5.37.18 was released, and the 5.37.3 alpha pre-releases are superseded by this version.

### Highlights

**Meeting join links**: a join link carries the meeting key and its rotating code as query parameters, like a conversation join link, and can be password-protected at creation. Refreshing a link invalidates every URL issued before.

**Targeted MLS messages**: persistent and transient MLS messages addressed to some members of a conversation, local or federated.

**coturn native TURN credentials**: `GET /calls/config/v3` serves credentials coturn validates with its own `static-auth-secret`, once brig is given that secret.

**wire-ingress on ListenerSets**, with an Envoy fleet of 3 replicas spread across zones by default. This one needs action, see below.

## Before upgrading

Only if you deploy the `wire-ingress` chart ([#5591](https://github.com/wireapp/wire-server/pull/5591)). The application listeners and traffic policies move from the Gateway to a `ListenerSet` owned by the release. Before `helm upgrade`:

- run Envoy Gateway 1.9 or later on Kubernetes 1.33 or later (the chart now declares `kubeVersion: >=1.33.0-0`);
- install the [Gateway API 1.6.1 standard CRDs](https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.6.1/standard-install.yaml) and the matching Envoy Gateway extension CRDs;
- with federation, set `extensionApis.enableLua: true` in the Envoy Gateway controller configuration;
- with `gateway.create: false`, let the existing Gateway accept ListenerSets from the release namespace;
- with the legacy xDS name scheme and `gateway.patchPolicies.xdsListenerName` set, check the name: it now includes the ListenerSet.

Also check the new defaults of the Envoy fleet before upgrading: 3 replicas, and zone-aware routing on. Zone-aware routing needs nodes labelled `topology.kubernetes.io/zone` and Envoy Gateway's topology injector. Set `gateway.envoyProxy.replicas` and `gateway.zoneAwareRouting.enabled` if these don't fit your cluster. The [wire-ingress README](https://github.com/wireapp/wire-server/blob/develop/charts/wire-ingress/README.md) has the details.

Nothing to do for the other charts: no database migration, and every new setting has a default.

## API changes

- `GET /meeting/{domain}/{key}/{code}/code-check` (without authentication) and `POST /meeting/{domain}/{key}/{code}/join` resolve a meeting join link. They replace the pre-release `GET` and `POST /meeting-join` routes. The optional `password` travels as a query parameter; nginz masks it in its access log. ([#5560](https://github.com/wireapp/wire-server/pull/5560))
- From API version 19, `POST /meetings` accepts an optional `password`, and meeting responses carry `has_password`. ([#5588](https://github.com/wireapp/wire-server/pull/5588), [#5595](https://github.com/wireapp/wire-server/pull/5595))
- The meeting `type` is no longer accepted on `PUT /meetings/{domain}/{id}`. `"recurrence": null` in an update now unsets the recurrence on every API version instead of a 400, and an update that omits `recurrence` leaves it unchanged instead of clearing it. ([#5577](https://github.com/wireapp/wire-server/pull/5577))
- From API version 19, `POST /mls/messages/targeted` and `POST /mls/messages/transient-targeted` send targeted MLS messages. ([#5570](https://github.com/wireapp/wire-server/pull/5570), [#5599](https://github.com/wireapp/wire-server/pull/5599))
- `GET /calls/config/v3` serves coturn native long-term TURN credentials (`username` `<unix-expiry>:<uid>`, `credential` the HMAC-SHA1 of the username with the coturn `static-auth-secret`). It answers 500 until `brig.secrets.turn.coturnSecret` is set. `/calls/config` and `/calls/config/v2` are unchanged. ([#5590](https://github.com/wireapp/wire-server/pull/5590))
- Backoffice: `GET /teams/{tid}/members/csv` exports the members of a team. ([#5594](https://github.com/wireapp/wire-server/pull/5594))

## Federation

- Federation API version 5 is a development version, disabled by default. A disabled version is left out of version negotiation and requests using it are rejected. Versions 0 and 1 cannot be disabled. ([#5582](https://github.com/wireapp/wire-server/pull/5582))

## Fixes

- Stealth users are no longer returned by exact-handle searches, including federated search and `POST /list-users` with `qualified_handles`. ([#5596](https://github.com/wireapp/wire-server/pull/5596))
- `fake-aws-s3` pulls minio and mc from `quay.io/wire/mirror-images/minio`, and the postgresql subchart of `legalhold` pulls `bitnamilegacy/postgresql:11.10.0`, as the original images are gone. ([#5592](https://github.com/wireapp/wire-server/pull/5592))

## Configuration

| Chart | Value | Change | Default |
|---|---|---|---|
| wire-server | `apiVersions.disabledFederationAPIVersions` | added | `[development]`; rendered into brig, galley and cargohold, where the key is mandatory |
| wire-server | `brig.secrets.turn.coturnSecret` | added | unset; enables `GET /calls/config/v3` |
| wire-ingress | `gateway.listeners.placeholder.port` | added | `65535` |
| wire-ingress | `gateway.envoyProxy.replicas` | added | `3`, with a PodDisruptionBudget unless 1 |
| wire-ingress | `gateway.envoyProxy.topologySpreadKeys` | added | hostname and zone, advisory |
| wire-ingress | `gateway.zoneAwareRouting.enabled`, `.minEndpointsThreshold` | added | `true`, `3` |
| wire-ingress | `gateway.annotations`, `gateway.infrastructure.labels` | added | `{}` |
| fake-aws-s3 | `minio.image`, `minio.mcImage` | changed | `quay.io/wire/mirror-images/minio/{minio,mc}` |
| legalhold | `postgresql.image` | changed | `bitnamilegacy/postgresql:11.10.0` |

## Maintenance

- Email templates updated to v1.0.160. ([#5572](https://github.com/wireapp/wire-server/pull/5572))
- Release files in `publication/`: compatibility, release note and release declaration, checked by the pull request workflow. The compatibility file lists federation API version 5 as a development version.
- `CODEOWNERS`: the release managers review `.github/` and `publication/`.
