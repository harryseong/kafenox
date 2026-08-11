# 0001. No local persistence layer

**Status:** accepted

## Context

The obvious default for a collection-browsing app is SwiftData or GRDB with a
local store, syncing to the backend. Kafenox does not have one: the catalog is
fetched from `GET /coffees` on appear and on pull-to-refresh, and held in
memory by `CatalogViewModel`.

The data has unusual properties for this kind of app. It is small (a few
hundred bags ever, one row each), single-user and single-device in practice,
and — critically — **the backend mutates it without the client's involvement**.
A scan's real content appears minutes after upload, written by a Step Functions
pipeline the app never sees. A local store would therefore be a cache of a
source of truth that changes behind its back.

## Decision

No local database. The server is the single source of truth; the app holds one
in-memory `CatalogViewModel` that every feature reads and mutates, and the
upload queue patches rows in place as extraction results land.

## Consequences

Cold launch requires the network and shows an empty collection offline, which
is the main cost. In exchange there is no schema, no migrations, no
sync-conflict logic, and no possibility of the local cache disagreeing with
what the extraction pipeline wrote.

Adding persistence later is a contained change: `CoffeeRepository` in `Core` is
already the seam, so a caching implementation can wrap or replace `APIClient`
without any feature knowing. Revisit if offline browsing is wanted, or if the
collection grows past the point where re-fetching everything is reasonable.
