# 0003. Scans are queued, and the client polls

**Status:** accepted

## Context

Label extraction takes seconds to minutes: S3 upload triggers a Step Functions
pipeline that resizes the image and calls Bedrock. The app originally held the
user on a "reading label" screen, polling every 1.5s for up to 30s, and showed
a review form only once extraction finished. Anything slower than 30s was
surfaced as a failure even though the pipeline was still running fine.

The backend was already asynchronous. The blocking wait was purely a client
choice.

## Decision

Upload hands off and returns. `POST /uploads` already creates a `PENDING` row,
so the catalog shows the coffee immediately as "Processing"; a `UploadQueueMonitor`
singleton polls `GET /uploads/{photoId}/status` every 4s for the photos it is
tracking, patches the catalog in place when results land, and posts a **local**
notification per completion or failure.

Review moved to the existing Catalog → Detail → Edit path. `ReviewView` was
deleted rather than kept, since it duplicated `EditCoffeeView`'s field set and
had nothing to display at upload time.

## Consequences

The user can scan several bags in a row without waiting. In-flight and failed
rows are pinned above the filters in the catalog, because a queued scan has no
roast level or searchable text yet and would otherwise vanish the moment the
user typed.

Notifications are local, not push. They only fire while the process is alive —
foreground, or the ~30s `beginBackgroundTask` grace window. If the app is
terminated mid-extraction, nothing fires and the coffee simply reads as "New"
next launch. Real push would mean APNs, device tokens, and backend fan-out;
that is a much larger commitment than the problem currently justifies.

Polling is O(tracked photos) requests per 4s tick, which is negligible at one
or two concurrent scans. If bulk scanning ever becomes normal, batch the status
check into a single endpoint before raising the interval.

The system calls the monitor needs (`UNUserNotificationCenter`,
`UIApplication.beginBackgroundTask`) sit behind `UploadQueueSystemServices`,
because both trap in a bare xctest process — without that seam the queue's
transition logic could not be tested at all.
