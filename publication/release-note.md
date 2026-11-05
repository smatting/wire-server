## Overview

5.37.3 is a maintenance release of the 5.37 line, and the first wire-server release prepared with the Wire release standard: the version is tagged `v5.37.3`, the images promoted by digest from a dev build, the deployable charts also published to `oci://quay.io/wire/charts/stable`. The release note, the release declaration and the compatibility file of each version live in `publication/` and are attached to the GitHub release. The structured release declaration of this version is [`declaration.json`](declaration.json).

Nothing to do before deploying: no migration, no configuration change.

### Highlights

**Meeting join links**: a join link now carries the meeting key and its rotating code as query parameters, like a conversation join link. Refreshing a link invalidates every URL issued before. Two endpoints resolve a link: `GET /meeting/{domain}/{key}/{code}/code-check`, without authentication, returns the title, time and recurrence of the meeting, and `POST /meeting/{domain}/{key}/{code}/join` joins its conversation. They replace the pre-release `/meeting-join` routes.

**Meeting `link` field**: from client API version 19 the meeting object carries its join link, when the meeting has a live join code.

## API changes

- `profilePict`, deprecated, is removed from the user profile. Clients read the profile picture from `assets`.
- `GET /meeting/{domain}/{key}/{code}/code-check` and `POST /meeting/{domain}/{key}/{code}/join` are added; the pre-release `GET` and `POST /meeting-join` routes are gone.
- The meeting object exposes `link` from API version 19. Versions 15 to 18 are unchanged.
- The meeting `type` is no longer accepted on `PUT /meetings/{domain}/{id}`.
- `"recurrence": null` in a meeting update now unsets the recurrence on every API version, instead of a 400.
- The optional `password` of the join endpoints travels as a query parameter; nginz masks it in its access log.

## Maintenance

- Release files in `publication/`: compatibility, release note and release declaration, checked by the pull request workflow.
- `CODEOWNERS`: the release managers review `.github/` and `publication/`.

## Configuration

No configuration change.
