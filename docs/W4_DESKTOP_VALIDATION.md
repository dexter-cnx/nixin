# W4 Desktop Validation Checklist

This checklist records physical/manual validation for Dextryx Images W4 Desktop Catalog Hardening.

Do not mark a gate PASS without running it on a real desktop filesystem. CI coverage is necessary but does not substitute for removable-volume and UI-interaction evidence.

## Test environment

Record before testing:

```text
Date:
OS / version:
Machine:
Dextryx Images commit:
Flutter version:
External volume type / filesystem:
Managed root path:
Representative catalog size:
```

## D1 — Linked external-volume disconnect / reconnect

Setup:

1. Import at least 20 linked assets from an external/removable volume.
2. Confirm assets browse and open normally.

Disconnect gate:

1. Disconnect/unmount the volume.
2. Trigger availability rescan.
3. Confirm assets remain in the Workplace.
4. Confirm affected assets are marked missing.
5. Confirm selecting a missing asset does not hand it to Develop.
6. Confirm the Workplace remains responsive and does not become a catalog-load error.

Reconnect gate:

1. Reconnect/remount at the same path.
2. Trigger availability rescan.
3. Confirm missing state clears without creating duplicate catalog records.

Evidence:

```text
Status: NOT RUN
Notes:
Screenshots/logs:
```

## D2 — Missing managed destination before import

Setup:

1. Configure Managed / Copy to an external destination.
2. Exit import and unmount/disconnect the external volume.

Gate:

1. Start another managed import.
2. Confirm Dextryx Images does not recreate the stale mount/root path locally.
3. Confirm a replacement destination must be selected.
4. Cancel replacement selection and confirm no copy/catalog record is committed.

Evidence:

```text
Status: NOT RUN
Notes:
Screenshots/logs:
```

## D3 — Managed destination disappears during import

Setup:

1. Use a managed external destination.
2. Import enough/larger files to leave time for a controlled disconnect.

Gate:

1. Disconnect/unmount after import has started.
2. Confirm the old managed root is not silently recreated as a local directory.
3. Confirm the affected file is reported failed/recoverable.
4. Confirm no committed catalog record points at a nonexistent locally recreated mount path.
5. Confirm handled `.partial` output is not left behind in a still-accessible destination.
6. Confirm source originals remain untouched.

Evidence:

```text
Status: NOT RUN
Notes:
Screenshots/logs:
```

## D4 — Replacement managed destination

Gate:

1. Start with a stale/unavailable remembered managed root.
2. Select a new existing destination.
3. Complete a managed import.
4. Confirm the managed original exists under the replacement root.
5. Confirm later managed imports reuse the replacement preference while it remains available.
6. Confirm the stale root was not recreated.

Evidence:

```text
Status: NOT RUN
Notes:
Screenshots/logs:
```

## D5 — Restart recovery of interrupted import

Gate:

1. Begin an import batch with multiple files.
2. Terminate the app/process while the batch is active.
3. Relaunch Dextryx Images into the original Workplace.
4. Confirm the latest recoverable batch is surfaced.
5. Trigger Retry failed import.
6. Confirm already-successful source paths are not duplicated.
7. Confirm retry uses the original batch Linked/Managed storage mode.
8. Confirm the user's currently configured storage-mode preference is unchanged after retry.

Evidence:

```text
Status: NOT RUN
Notes:
Screenshots/logs:
```

## D6 — Thumbnail cache recovery

Raster gate:

1. Browse a Workplace containing raster assets without persisted thumbnails.
2. Confirm thumbnails populate lazily while the catalog remains interactive.
3. Relaunch and confirm generated cache is reused.

Corruption gate:

1. Corrupt/delete one generated thumbnail cache file while the app is closed.
2. Relaunch/browse that asset.
3. Confirm placeholder/cache recovery occurs without a catalog error.
4. Confirm source original is unchanged.

RAW boundary gate:

1. Browse RAW assets.
2. Confirm W4 raster cache does not attempt to treat RAW source bytes as raster decode input.
3. Confirm existing embedded/persisted RAW preview behavior remains unchanged.

Evidence:

```text
Status: NOT RUN
Notes:
Screenshots/logs:
```

## D7 — Representative large catalog

Recommended minimum: 5,000 catalog records where practical; use at least 1,000 real assets if source volume capacity is limited.

Gate:

1. Open/switch into the representative Workplace.
2. Scroll Grid continuously for at least 30 seconds.
3. Show/use Filmstrip and change selection repeatedly.
4. Trigger availability scan while browsing.
5. Allow raster thumbnails to populate while browsing.
6. Change sort order.
7. Confirm no UI lockup/crash and no unexpected catalog writes/duplicates.
8. Record subjective scroll responsiveness and any visible stalls.
9. Record process memory before/after the session if practical.

Evidence:

```text
Status: NOT RUN
Catalog assets:
Initial memory:
Peak/final memory:
Availability scan observation:
Scroll/UI observation:
Notes:
```

## D8 — Catalog-only removal safety regression

Gate:

1. Choose one linked asset and one managed asset.
2. Use Remove from Workplace on each.
3. Confirm catalog records disappear.
4. Confirm both physical originals remain on disk.

Evidence:

```text
Status: NOT RUN
Notes:
```

## Final W4 desktop validation result

```text
D1 Linked disconnect/reconnect:        NOT RUN
D2 Missing managed root before import: NOT RUN
D3 Managed root disappears mid-import: NOT RUN
D4 Replacement managed destination:    NOT RUN
D5 Restart import recovery:             NOT RUN
D6 Thumbnail cache recovery:            NOT RUN
D7 Representative large catalog:        NOT RUN
D8 Catalog-only removal safety:         NOT RUN

Overall: NOT VALIDATED
```

Allowed final labels:

- `PASS` — all required physical gates passed with evidence;
- `PASS WITH DEFERRED GATES` — explicitly approved deferred gates are listed with rationale;
- `FAIL` — at least one required gate failed;
- `NOT VALIDATED` — physical testing has not yet been performed.
