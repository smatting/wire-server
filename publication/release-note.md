## Overview

5.38.14 is a maintenance release of the 5.38 line for operators running 5.38.0. The structured release declaration of this version is [`declaration.json`](declaration.json).

Coming from 5.37.x (5.37.2 or 5.37.18), also read the [5.38.0 section of `CHANGELOG.md`](https://github.com/wireapp/wire-server/blob/develop/CHANGELOG.md) first: it has the release notes of 5.38.0, including the nginz `oauth_scope` deprecation.

The jump from 5.38.0 comes from the move to the release standard: no GA between 5.38.0 and 5.38.14 was released.

### Highlights

**Mandatory meeting join links**: every meeting has a join link, backed by a join code stored in PostgreSQL. This needs action, see below.

**More data on PostgreSQL**: custom backends, login budgets, DPoP nonces and connections can move from Cassandra to PostgreSQL, with the same opt-in migration pattern as the other stores.

**Resend verification emails**: team admins can resend the verification email of a member whose email address is still unverified.

## Before upgrading

If `galley.config.postgresMigration.conversationCodes` is still `cassandra` (the chart default), move it to `migration-to-postgresql` before upgrading ([#5597](https://github.com/wireapp/wire-server/pull/5597)). In dual-write mode, guest links stay on Cassandra. Meeting join codes only live in PostgreSQL. Without this change, creating a meeting or refreshing its link fails with `500 link-unavailable`, and so does reading a meeting that has no live join code, on every API version. A join-link URI must stay configured in galley: `settings.conversationCodeURI`, or the user's domain in `settings.multiIngress`.

```yaml
galley:
  config:
    postgresMigration:
      conversationCodes: migration-to-postgresql
```

At startup, a one-off SQL data migration gives every existing meeting without a live join code a canonical one. Existing codes and links are never rotated. Other SQL migrations create the PostgreSQL tables of the new stores; they stay unused until you opt in.

## API changes

- From API version 19 every meeting carries its `link`. Refreshing a meeting link reports `has_password` according to the password supplied with the refresh. ([#5597](https://github.com/wireapp/wire-server/pull/5597))
- `PUT /teams/{tid}/members/{uid}/verification-email` resends the verification email of a team member with a pending unverified email address, for team admins: `202` when an email is sent, `204` when there is nothing to verify. ([#5681](https://github.com/wireapp/wire-server/pull/5681))
- Mock endpoints for TOTP second factors, from API version 19: `POST /self/totp`, `POST /self/totp/{id}/activate`, `GET /self/totp`, `PUT /self/totp/{id}`, `DELETE /self/totp/{id}`. They return generated data and store nothing; they exist for client development. ([#5653](https://github.com/wireapp/wire-server/pull/5653))
- Federation error responses include `federation_domain` and, when an SRV target is known, `srv_target` and `srv_target_domain`. The `domain` and `path` fields are unchanged. ([#5651](https://github.com/wireapp/wire-server/pull/5651))

## Federation

- The federator ingress of `nginx-ingress-services` only exposes paths under `/federation`. ([#5355](https://github.com/wireapp/wire-server/pull/5355))

## Fixes

- Re-joining an MLS group with an external commit could drop the client from the backend's member list, silently stopping message delivery to it. ([#5677](https://github.com/wireapp/wire-server/pull/5677))
- Legacy team 1:1 conversations are excluded from the prevention of admin-less groups. ([#5686](https://github.com/wireapp/wire-server/pull/5686))

## Configuration

PostgreSQL storage for more data ([#5633](https://github.com/wireapp/wire-server/pull/5633), [#5619](https://github.com/wireapp/wire-server/pull/5619), [#5675](https://github.com/wireapp/wire-server/pull/5675), [#5626](https://github.com/wireapp/wire-server/pull/5626)) follows the migration pattern of the [configuration options documentation](https://docs.wire.com/latest/developer/reference/config-options.html): `migration-to-postgresql`, then the background-worker backfill, then `postgresql`. Login budgets have no backfill: keep `budget` on `migration-to-postgresql` for at least the longest `limitFailedLogins.timeout` before switching.

| Value | Change | Default |
|---|---|---|
| `galley.config.postgresMigration.conversationCodes` | must leave `cassandra`, see above | `cassandra` |
| `galley.config.postgresMigration.customBackend`, `.budget`, `.nonce`, `.connections` | added; mandatory in the brig, galley and background-worker configuration, rendered by the chart | `cassandra` |
| `background-worker.config.migrateCustomBackend`, `.migrateNonce`, `.migrateConnections` | added | `false` |

## Monitoring

- Gundeck exports new Prometheus metrics on stored pushes (`wire_push_stored_*`), notification fetches (`wire_notification_fetch*`) and websocket deliveries (`wire_push_ws_delivered_presences*`). ([#5683](https://github.com/wireapp/wire-server/pull/5683))
