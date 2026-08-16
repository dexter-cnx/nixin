# Dextryx Images — Code Walkthrough

This document describes the current code structure of `dexter-cnx/nixin` after the completed Studio workspace milestones and W1 Workplace Core foundation. It distinguishes implemented code from behavior that is actually reachable through the live application.

## 1. Application bootstrap

`lib/main.dart` initializes:

```text
WidgetsFlutterBinding
EasyLocalization
Hive
  ├─ studio_settings
  ├─ workplaces
  └─ assets
ProviderScope
EasyLocalization
NixinApp
```

Opening Hive boxes does not initialize Riverpod providers by itself.

## 2. Current live application root

`lib/app/nixin_app.dart` currently builds:

```text
MaterialApp
  → StudioPage
```

This is important: the live app does **not** currently watch `workplaceControllerProvider`.

Because Riverpod providers are lazy, merely defining `workplaceControllerProvider` does not instantiate `WorkplaceController`, and therefore does not run `WorkplaceController.initialize()` during a normal app launch.

That wiring gap is the first implementation item in W2.

## 3. Top-level structure

```text
lib/
  main.dart
  app/
  engine/
  studio/
  workplaces/
```

Responsibilities:

```text
app/         application shell, theme, localization root
engine/      native image-processing boundary and FFI implementation
studio/      current live workspace and existing processing interactions
workplaces/  catalog domain, repositories, persistence, controller foundation
```

## 4. Native processing path

The existing processing dependency direction is:

```text
Studio UI
  → StudioController
    → StudioEngine
      → RawEngine
        → Rust C ABI
```

Widgets must not call native functions directly.

The current Rust/Studio path supports the already-existing embedded RAW preview/raster decode, adjustments, masks, LUT, and JPEG export behavior. Real sensor RAW development remains deferred.

## 5. FFI ownership

```text
Dart UTF-8 input
  → calloc
  → Rust call
  → Dart frees with calloc.free()

Rust string output
  → CString::into_raw()
  → Dart converts
  → free_string_rust()

Rust ImageBuffer
  → Dart reads metadata/data
  → Dart copies RGBA bytes
  → free_image_buffer()
```

Dart validates:

```text
len == width * height * 4
```

before accepting returned RGBA data.

## 6. Studio layer

`lib/studio/` is still the live UI root today.

It owns existing:

- Studio state/controller
- preview surface
- responsive workspace composition
- Develop actions
- Subject/Sky mask actions
- LUT flow
- JPEG export
- existing Filmstrip behavior

W2–W4 should preserve this path as a regression boundary while progressively making catalog state authoritative.

## 7. Workplaces domain

Current domain files:

```text
lib/workplaces/domain/
  workplace.dart
  asset_record.dart
  repositories/
    workplace_repository.dart
    asset_repository.dart
```

### `Workplace`

Logical catalog/container identity. It is not a physical-folder alias.

### `AssetRecord`

Catalog identity and storage metadata for an image/RAW asset. It is distinct from runtime Studio preview/editor state.

## 8. Repository boundary

The dependency direction is:

```text
application/controller
  → repository interface
    → Hive implementation
```

Concrete implementations:

```text
lib/workplaces/data/hive/
  hive_workplace_repository.dart
  hive_asset_repository.dart
```

Widgets should not read/write Hive directly.

Current Hive boxes:

```text
studio_settings
workplaces
assets
```

## 9. WorkplaceController

`lib/workplaces/application/workplace_controller.dart` defines:

```text
WorkplaceState
WorkplaceController
workplaceControllerProvider
workplaceRepositoryProvider
assetRepositoryProvider
```

`WorkplaceState` owns:

```text
workplaces
currentWorkplaceId
loading
errorMessage
```

The controller implements:

```text
initialize()
createWorkplace(name)
switchWorkplace(id)
renameWorkplace(id, name)
deleteWorkplace(id)
```

`initialize()` implements this logic:

```text
load Workplaces
  → if empty, create "My workplace"
  → restore current Workplace ID
  → repair invalid/missing current ID
  → persist current ID
  → publish state
```

Important invariant:

```text
At least one Workplace must remain.
```

Deleting a Workplace removes its catalog records through `AssetRepository`; it does not imply deleting original files.

## 10. Implemented foundation vs live behavior

The following are implemented/testable through `WorkplaceController` and repositories:

- default Workplace creation logic
- persistence/restoration logic
- Workplace CRUD commands
- last-Workplace invariant
- Asset persistence boundary

They are **not yet live end-user behavior**, because the current `NixinApp → StudioPage` tree does not consume `workplaceControllerProvider`.

Current reality:

```text
Live app
  → StudioPage
  → studioControllerProvider

Workplace foundation
  → workplaceControllerProvider
  → not yet mounted/consumed by live app
```

Any documentation or test plan must preserve this distinction until W2 wires the provider into the real application.

## 11. W2.0 target — live Workplace wiring

First W2 step:

```text
Live application/workspace
  → watch workplaceControllerProvider
  → initialize WorkplaceController
  → expose current Workplace context
```

Required outcomes:

- real fresh launch creates `My workplace`
- restart restores the active Workplace
- current Workplace is observable by the live UI
- Workplace CRUD/switching is reachable through the application
- current Studio behavior does not regress

Add widget/integration tests that mount the real provider path; controller-only tests are not sufficient for this acceptance gate.

## 12. W2.1 target — Import System

Once Workplace state is live, add import orchestration above repository boundaries:

```text
Import UI
  → ImportController / ImportService
    → source discovery
    → supported-format filtering
    → duplicate checks
    → optional managed copy
    → metadata/catalog creation
    → AssetRepository
```

Durable flow:

```text
Select source
  → discover candidates
  → filter supported types
  → normalize paths
  → check duplicates
  → copy when managed mode is selected
  → read basic metadata
  → create AssetRecord
  → generate/cache preview when appropriate
  → publish into current Workplace
```

Expected W2 concepts:

```text
ImportBatch
ImportState
ImportController / ImportService
linked/add mode
managed/copy mode
progress
cancellation
partial-failure handling
```

File picker and filesystem work belong in application/service boundaries, not leaf widgets.

## 13. W3 target — shared Browser/Filmstrip state

The target relationship is:

```text
Current Workplace
       ↓
Ordered Asset Query
       ├─ Workplace Grid
       └─ Filmstrip

selectedAssetId
       ├─ Grid highlight
       ├─ Filmstrip highlight
       └─ Develop current asset
```

Do not create separate asset collections or independent selection truth for Grid and Filmstrip.

The existing Filmstrip should be evolved rather than duplicated.

## 14. Preview boundary

Workplaces should not depend directly on future RAW processing internals.

Conceptual boundary:

```dart
abstract interface class AssetPreviewProvider {
  Future<Uint8List?> thumbnail(AssetRecord asset);
}
```

During W2–W4:

- RAW previews may continue using embedded JPEGs
- raster images may use existing raster decode
- caching may evolve independently
- real RAW demosaic/debayer remains out of scope

## 15. Removal semantics

Keep catalog removal and filesystem deletion separate:

```text
Remove from Workplace
```

is not equivalent to:

```text
Move Original to Trash
```

No Workplace/catalog operation should silently delete source originals.

## 16. Localization

Visible UI strings use `easy_localization` with:

```text
assets/translations/en.json
assets/translations/th.json
```

New Workplace/import UI strings should be translation keys.

## 17. Test strategy

Current seams:

```text
Widget tests
  → application/UI wiring

Controller/service tests
  → repository fakes

Repository tests
  → Hive persistence

Rust tests
  → native processing/core behavior
```

W2.0 specifically requires tests proving the real live app/provider path initializes Workplace state.

W2.1 should add tests for:

- import state transitions
- duplicate rules
- path normalization
- linked/managed decisions
- cancellation
- partial failures
- restart persistence

## 18. Validation gate

```bash
flutter pub get
flutter analyze
flutter test

cd rust
cargo check
cargo test
```

Manual regression coverage during W2–W4:

- launch/localization
- real fresh-launch Workplace initialization once W2.0 lands
- Workplace create/switch/rename/delete once wired
- embedded RAW preview
- raster preview
- Develop
- Subject Mask
- Sky Mask
- LUT
- JPEG export
- responsive workspace behavior

## 19. Current execution order

```text
DONE     W1 Workplace Core foundation
CURRENT  W2.0 Live Workplace wiring
THEN     W2.1 Import System
NEXT     W3 Workplace Browser + Filmstrip
THEN     W4 Desktop Catalog Hardening
FUTURE   PixelCraft external-editor contract
```

See `docs/PROJECT_HANDOFF.md` for canonical status and `docs/WORKPLACES_HANDOFF.md` for the detailed Workplaces/import specification.
