# wire-server 5.36.32

Maintenance release of the 5.36 line, for operators running 5.36.0. It is the first 5.36 version published with the Wire release standard, so it brings everything merged on the line since 5.36.0. Two checks before upgrading; most installations need neither.

## Before upgrading

- If you run the `wire-ingress` chart: the gateway now accepts TLS 1.3 only, on the HTTPS listeners and on the federation listener. If some clients or federation peers still need TLS 1.2, set `gateway.tls.minVersion: "1.2"`.
- brig no longer starts when the domain of `emailSMS.general.emailSender` ends with a label that starts with a digit (SES rejects such senders anyway). Check that address in your brig configuration.

## What's new

- Channels get the same protection as groups against losing their last admin, including the automatic promotion of a new one.
- The block list and the password reset codes can move from Cassandra to PostgreSQL. It is opt-in and follows the same steps as the other stores.
- `wire-ingress` offers post-quantum key exchange by default, a `FIPS_202205_tls_profile` switch that helps with BSI TR-02102-2, and settings to attach to an existing Gateway.
- `nginx-ingress-services` accepts extra `connect-src` entries in the Content Security Policy of multi-ingress setups, for example to reach third-party SFT servers from the webapp.
- Several fixes: an IdP can be deleted again after its issuer was changed, users removed from a team leave the MLS groups of its conversations, and an activation email to an invalid domain no longer ends in a server error.

---

## Details

### Breaking

- `wire-ingress`: TLS 1.3 only by default on the HTTPS and federation listeners, post-quantum key exchange (`X25519MLKEM768`) offered. Set `gateway.tls.minVersion: "1.2"` to keep TLS 1.2 clients or peers. The separate ALPN and PROXY protocol ClientTrafficPolicies become one policy per target, handled by `helm upgrade`. [#5480](https://github.com/wireapp/wire-server/pull/5480), [`d7abd795a3`](https://github.com/wireapp/wire-server/commit/d7abd795a3)
- brig refuses an `emailSMS.general.emailSender` whose domain has a last label starting with a digit. [#5550](https://github.com/wireapp/wire-server/pull/5550), [`d63a416573`](https://github.com/wireapp/wire-server/commit/d63a416573), WPB-20524

### Added

- PostgreSQL storage for the block list and the password reset codes, opt-in, with background-worker backfills. [#5409](https://github.com/wireapp/wire-server/pull/5409), [`13b15b72a2`](https://github.com/wireapp/wire-server/commit/13b15b72a2), WPB-22965; [#5412](https://github.com/wireapp/wire-server/pull/5412), [`9d883c32a3`](https://github.com/wireapp/wire-server/commit/9d883c32a3), WPB-22969
- `wire-ingress`: `FIPS_202205_tls_profile`, configurable `gateway.tls`, listener section names, extra HTTPS listeners and certificate names. See the chart README. [#5480](https://github.com/wireapp/wire-server/pull/5480), [`d7abd795a3`](https://github.com/wireapp/wire-server/commit/d7abd795a3)
- `nginx-ingress-services`: `config.cspExtraConnectSrc`, read when `renderCSPInIngress` is true. [#5236](https://github.com/wireapp/wire-server/pull/5236), [`cbb67a3f1b`](https://github.com/wireapp/wire-server/commit/cbb67a3f1b), WPB-25750
- Development API version 19: meetings carry a `type` (`immediate` or `scheduled`, required on creation) and, when they have a live join code, a join `link`. Versions 15 to 18 are unchanged. [#5556](https://github.com/wireapp/wire-server/pull/5556), [`2743b9d9c3`](https://github.com/wireapp/wire-server/commit/2743b9d9c3), WPB-28985; [#5558](https://github.com/wireapp/wire-server/pull/5558), [`b40ef2c65e`](https://github.com/wireapp/wire-server/commit/b40ef2c65e), WPB-28987

### Changed

- Adminless-group protection and automatic admin promotion apply to channels too. [#5579](https://github.com/wireapp/wire-server/pull/5579), [`c57beb2a7d`](https://github.com/wireapp/wire-server/commit/c57beb2a7d), WPB-29162
- Clients receive `meeting.delete` before the deletion of the meeting's conversation. [#5571](https://github.com/wireapp/wire-server/pull/5571), [`ecbcb377dd`](https://github.com/wireapp/wire-server/commit/ecbcb377dd), WPB-29046
- galley publishes team events to the FIFO queue with the team as message group: one team's events stay in order, different teams are processed in parallel. [#5580](https://github.com/wireapp/wire-server/pull/5580), [`0d7c139e6e`](https://github.com/wireapp/wire-server/commit/0d7c139e6e), WPB-29185

### Removed

- Development API version 19: user profiles no longer carry the deprecated `picture` field. Version 18 and older still return it. [#5538](https://github.com/wireapp/wire-server/pull/5538), [`b6ebb98102`](https://github.com/wireapp/wire-server/commit/b6ebb98102), WPB-20532

### Fixes

- IdP deletion works again after the issuer was updated. [#5548](https://github.com/wireapp/wire-server/pull/5548), [`de23b558e4`](https://github.com/wireapp/wire-server/commit/de23b558e4), WPB-20407
- Removing a user from a team sends the MLS remove proposals, so re-adding a collaborator to a conversation works. [#5555](https://github.com/wireapp/wire-server/pull/5555), [`a056d28ea3`](https://github.com/wireapp/wire-server/commit/a056d28ea3), WPB-28977
- An activation email to a domain SES rejects returns an invalid-email error instead of a 500. [#5550](https://github.com/wireapp/wire-server/pull/5550), [`d63a416573`](https://github.com/wireapp/wire-server/commit/d63a416573), WPB-20524
- Login checks the length of passwords set before the 8-character minimum. [#5543](https://github.com/wireapp/wire-server/pull/5543), [`38cd8f0037`](https://github.com/wireapp/wire-server/commit/38cd8f0037), WPB-11756
- The migration of users to PostgreSQL skips invalid assets instead of failing. [#5569](https://github.com/wireapp/wire-server/pull/5569), [`bf5398bd2f`](https://github.com/wireapp/wire-server/commit/bf5398bd2f)

### Migrations

- Automatic, at startup: SQL migrations create the block list and password reset tables (unused until you opt in) and add the meeting type column.
- Optional, after upgrading: set `postgresMigration.blockList` or `.passwordReset` to `migration-to-postgresql`, start the backfill with `migrateBlockList` or `migratePasswordReset`, then switch to `postgresql`, as described in the [configuration options documentation](https://docs.wire.com/latest/developer/reference/config-options.html).

### Configuration

| Value | Change | Required | Default |
|---|---|---|---|
| `galley.config.postgresMigration.blockList`, `.passwordReset` | added; rendered by the chart into brig, galley and background-worker | yes | `cassandra` |
| `background-worker.config.migrateBlockList`, `.migratePasswordReset` | added | no | `false` |
| `nginx-ingress-services` `config.cspExtraConnectSrc` | added | no | empty |
| `wire-ingress` `gateway.tls` | added: `enabled`, `minVersion`, `maxVersion`, `ecdhCurves`, `ciphers`, `signatureAlgorithms` | no | TLS 1.3 only |
| `wire-ingress` `FIPS_202205_tls_profile` | added | no | `false` |
| `wire-ingress` `gateway.patchPolicies.xdsNameSchemeV2`, `.xdsListenerName` | added; `xdsNameSchemeV2` mandatory with the FIPS profile | no | unset |
| `wire-ingress` `gateway.listeners.https.sectionName`, `gateway.listeners.federator.sectionName` | added | no | `https`, `federator` |
| `wire-ingress` `gateway.extraHttpsListeners`, `tls.extraDnsNames` | added | no | `[]` |
