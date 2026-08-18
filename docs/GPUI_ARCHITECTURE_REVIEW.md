# Dextryx Images — GPUI Architecture Review

Date: 2026-08-18

Branch: `agent/gpui-desktop-spike`

## Decision

**Recommendation: CONTINUE MIGRATION — incrementally, desktop-only, with S4 as the next hard gate.**

This is **not** approval for a full rewrite and is **not** approval to move production persistence yet.

S0-S3 provide enough positive evidence that GPUI is a credible long-term desktop shell for Dextryx Images. The strongest evidence is architectural rather than cosmetic: the desktop UI can call the existing Rust image engine directly, large Filmstrip/catalog interaction can remain bounded and responsive, and catalog semantics can be kept outside GPUI through a framework-neutral Rust repository contract.

The remaining material uncertainty is platform/maintenance risk, especially Windows validation and GPUI's pre-1.0 API churn. S4 exists specifically to resolve that uncertainty before any production migration commitment.

## Evidence reviewed

### S0 — native desktop foundation — PASS

Physical macOS validation established:

- native GPUI application launches;
- Metal renderer/toolchain works;
- system text renders with the required font feature;
- the existing Rust engine links in-process;
- production Flutter remains untouched.

### S1 — image viewport / engine path — PASS

Physical macOS validation established:

- raster and current RAW embedded-preview flow works;
- `raw_engine::develop_preview()` is called directly as Rust-to-Rust API;
- the engine-owned RGBA buffer becomes GPUI `RenderImage` without Dart/C FFI and without a temporary encoded-image round trip;
- Fit / 1:1 / bounded zoom, mouse pan, trackpad pan and pinch/Cmd-Ctrl-scroll zoom work.

This is a material architectural simplification over a Flutter desktop shell for engine-heavy interaction.

### S2 — catalog scale / background work — PASS

Physical macOS validation established:

- 5,000 catalog-like assets;
- Filmstrip visible-range virtualization with overscan;
- maximum four thumbnail jobs in flight;
- bounded 128-entry completed-thumbnail cache;
- off-screen queued work is superseded before execution;
- scrolling and selection remain responsive while jobs run.

This demonstrates that the likely desktop workload can be expressed without constructing the full catalog in the live GPUI tree or starting unbounded image work.

### S3 — catalog state and repository boundary — PASS

Physical validation plus contract tests establish:

- All photos / Missing / Recent imports state switching;
- stable asset identity across filters;
- linked vs managed storage semantics;
- `effective_path` behavior;
- relink preserving identity and updating the correct path;
- missing-state recovery;
- recent-import ordering/membership;
- catalog-only removal semantics;
- active Workplace selection;
- a framework-neutral `CatalogRepository` independent from GPUI and from a concrete database.

The S3 test repository is synthetic only. It is evidence that the boundary is viable, not a replacement persistence implementation.

## Architecture scorecard

Scores use 10 = strong fit / low concern.

| Area | Score | Assessment |
|---|---:|---|
| Native image viewport fit | 9.5/10 | Direct Rust engine integration and desktop interaction model are a strong fit. |
| Rust engine integration | 9.5/10 | Removes the Dart/C ABI from the native desktop hot path while retaining it for Flutter. |
| Catalog / Filmstrip scalability | 9/10 | S2 demonstrated bounded virtualization and thumbnail work at 5,000 assets. |
| State-management ergonomics | 8.5/10 | GPUI entity/context model is sufficient for desktop application state; repository semantics remain separable. |
| Catalog/domain boundary cleanliness | 9/10 | S3 proves GPUI need not own storage semantics or know Hive. |
| Desktop UX suitability | 9/10 | Keyboard/mouse/trackpad editor workflows align naturally with GPUI. |
| Migration complexity | 6.5/10 | Existing Flutter desktop UI is substantial; incremental replacement is mandatory. |
| Ecosystem maturity | 6/10 | GPUI is pre-1.0 and API churn must be expected. |
| macOS confidence | 9/10 | S0-S3 are physically validated on macOS. |
| Windows confidence | 5/10 | Upstream backend exists, but this project has not yet compiled/launched the spike on Windows. |
| Linux confidence | 6/10 | Useful as a compile/smoke target; not yet validated for this spike. |
| Long-term ownership | 7.5/10 | Rust consolidation is attractive, but more UI/platform code becomes project-owned. |

**Weighted architectural confidence: approximately 8.3/10 before S4.**

The score is high enough to continue the experiment, but not high enough to declare a production migration complete or inevitable.

## Why CONTINUE instead of STOP

STOP is not supported by the evidence. S0-S3 did not reveal a fundamental GPUI blocker. Instead, the spike demonstrated advantages precisely in the expensive parts of this product:

```text
image engine
viewport interaction
thumbnail scheduling
large Filmstrip/catalog UI
native desktop state
```

Keeping Flutter desktop solely because it already exists would preserve a bridge boundary in the area where Dextryx Images is most Rust-heavy.

## Why CONTINUE instead of HYBRID as the target architecture

A permanent Flutter shell plus embedded/specialized GPUI viewport would reduce migration work, but it would also create two desktop UI runtimes and a coordination boundary around focus, shortcuts, windowing, state, input and resource ownership.

That may still become the fallback if S4 reveals platform blockers, but the current S0-S3 evidence does not justify choosing permanent dual-runtime complexity yet.

Therefore HYBRID remains the fallback, not the preferred target.

## Approved next step — S4 only

S4 should validate desktop compatibility without moving product persistence or porting additional feature families.

Required S4 gates:

1. **macOS packaging**
   - release build;
   - app bundle behavior;
   - file dialogs;
   - launch outside `cargo run`;
   - basic filesystem access.

2. **Windows**
   - compile the pinned GPUI spike;
   - launch a real window;
   - text rendering;
   - file dialog;
   - direct raw-engine viewport;
   - Filmstrip interaction smoke.

3. **Linux**
   - compile;
   - launch/smoke where runner/environment permits;
   - record required native dependencies.

4. **Maintenance check**
   - document all GPUI patches/features required by the spike;
   - estimate effort to move one pinned upstream revision forward;
   - do not continuously chase upstream during S4.

## Persistence decision remains deferred

Production Flutter currently owns persistence through:

```text
application/domain
   ↓
WorkplaceRepository / AssetRepository / ImportRepository
   ↓
repository adapters
   ↓
KeyValueStore / AppStorage
   ↓
Hive backend
```

The GPUI experiment now owns only a native catalog contract:

```text
GPUI state
   ↓
CatalogRepository
   ↓
future authoritative adapter/core
```

Do **not** connect GPUI directly to Hive.

Do **not** create a second durable catalog format.

A production persistence transition should happen only after the authoritative storage architecture is decided. A future shared Rust storage/catalog core — potentially using the planned Rust-native Dxtr_Box frontend — is architecturally compatible, but it is a separate milestone and must not be smuggled into the GPUI spike.

## Proposed production architecture if S4 passes

```text
Dextryx Images
│
├── Desktop UI
│   └── GPUI
│       ├── App / command state
│       ├── Workplace/catalog state
│       ├── virtualized Grid / Filmstrip
│       ├── viewport
│       └── inspector
│
├── Shared Rust application/core
│   ├── catalog contracts
│   ├── import orchestration boundary
│   ├── thumbnail scheduling/cache policy
│   ├── metadata
│   └── image engine
│
├── Storage
│   └── one authoritative backend / durable format
│
└── Flutter
    └── retained only where mobile/companion UI is required
```

The desktop GPUI layer should remain presentation/application-shell code. Core catalog rules, storage semantics and image processing should not become GPUI-specific.

## Migration policy after S4

If S4 passes, migrate in vertical slices rather than by copying screens:

```text
M1 desktop bootstrap + command/state shell
M2 read-only authoritative Workplace/catalog adapter
M3 real Grid/Filmstrip catalog browsing
M4 import/catalog mutations
M5 Develop controls around existing Rust engine
M6 desktop export/settings/polish
M7 retire Flutter desktop only after parity gates
```

Each slice must keep the Flutter production desktop path buildable until the corresponding GPUI behavior is validated.

## Stop conditions

Reconsider CONTINUE and choose HYBRID or STOP if S4 shows any of these:

- Windows requires project-local GPUI forks or invasive patches merely to launch reliably;
- platform packaging/signing creates disproportionate ongoing maintenance;
- pinned GPUI upgrades repeatedly require broad rewrites;
- native accessibility/input/text behavior is materially insufficient for required desktop UX;
- embedding authoritative storage requires duplicating durable semantics;
- the migration starts forcing image-processing or catalog-domain logic into GPUI widgets/state.

## Final review result

```text
S0  PASS  native macOS build/launch/font/Rust linkage
S1  PASS  direct Rust image viewport + pan/zoom
S2  PASS  5,000-asset virtualized Filmstrip + bounded thumbnails
S3  PASS  Catalog state + framework-neutral repository contract

ARCHITECTURE REVIEW
     CONTINUE MIGRATION — incremental desktop-only

NEXT
S4   desktop compatibility / packaging / Windows-Linux gates

NOT AUTHORIZED YET
     production persistence migration
     Flutter desktop removal
     Big Bang feature port
     RAW demosaic/debayer expansion
```
