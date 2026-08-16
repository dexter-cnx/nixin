# Dextryx Images — W2 Import System Implementation

> Branch implementation note for `feature/workplaces-import`.

W2 closes the W1 live-wiring gap and introduces the first durable catalog import pipeline.

Implemented in this branch:

- live `workplaceControllerProvider` consumption through Studio import controls
- real fresh-launch `My workplace` initialization once Studio UI mounts
- current Workplace switch/create/rename/delete controls
- primary multi-select Import
- secondary folder import, recursive by default
- current-folder-only folder import option
- supported RAW/raster filtering
- `ImportBatch` domain model and Hive persistence
- asynchronous per-file catalog loop with UI yielding
- progress and cancellation state
- baseline duplicate prevention by normalized source path within the active Workplace
- linked/add mode
- desktop managed/copy mode with remembered destination
- safe per-file failure accounting
- imported asset persistence into the active Workplace
- automatic handoff of the most recently imported asset to the existing Studio preview/Develop path

The existing Rust processing path is unchanged. Real RAW demosaic/debayer remains deferred.
