# Nixin Studio Workspace Redesign — Handoff

> Status: UI-01 through UI-15 are complete. See **Section 22 — Final Implementation Status** for the current canonical state; earlier sections preserve the original design intent and implementation plan.

## 1. Objective

Redesign Nixin Studio into a dense, professional desktop photo-editing workspace while preserving the existing Rust/FFI image-processing behavior.

The first implementation milestone is structural rather than feature-heavy: establish a stable studio shell, move existing controls into clear workspace regions, and introduce reusable design tokens and compact editor controls before adding advanced editing tools.

## 2. Historical Baseline

At the start of this redesign, the Flutter application was concentrated in `lib/main.dart`.

Existing behavior already available from the UI included:

- RAW file selection
- RAW development through the Rust engine
- subject mask generation
- sky mask generation
- `.cube` LUT application
- JPEG export with quality control
- preview rendering from RGBA output
- engine status/error reporting

The redesign must preserve those capabilities while changing their presentation and component boundaries.

## 3. Non-Goals for the First Milestone

Do not implement these yet:

- local brush editing
- healing/clone tools
- AI object selection UI
- interactive histogram editing
- multi-monitor layouts
- virtual copies
- full rating/flagging workflow
- advanced catalog/database features
- destructive changes to the Rust API

These can be added only after the workspace foundation is stable.

## 4. Target Workspace Architecture

Desktop layout:

```text
┌──────────────────────────────────────────────────────────────────────────┐
│ NIXIN STUDIO             Library   Develop   Export            Settings │
├────────────────┬─────────────────────────────────────┬───────────────────┤
│ LEFT PANEL     │                                     │ RIGHT PANEL       │
│                │                                     │                   │
│ Navigator      │                                     │ Histogram         │
│ Presets        │          MAIN PREVIEW               │ Profile           │
│ History        │                                     │ Light             │
│ Collections    │                                     │ Color             │
│                │                                     │ Detail            │
│                │                                     │ Effects           │
├────────────────┴─────────────────────────────────────┴───────────────────┤
│                            FILMSTRIP                                     │
├──────────────────────────────────────────────────────────────────────────┤
│ file | zoom | profile | engine/GPU status | dimensions | ready/error     │
└──────────────────────────────────────────────────────────────────────────┘
```

Core regions:

1. Module bar
2. Left context panel
3. Center preview workspace
4. Right adjustment panel
5. Bottom filmstrip
6. Status bar

## 5. Design Principles

### 5.1 Image-first

The preview must remain the dominant visual element. Panels should support editing rather than compete with the image.

### 5.2 Dense desktop controls

Avoid default oversized Material spacing for editor controls. Use compact labels, values, sliders, toggles, and section headers.

### 5.3 Neutral workspace

Use dark neutral surfaces rather than saturated application chrome. The workspace should not bias visual perception of the edited image.

### 5.4 Reusable editor primitives

Do not build one-off controls inside each panel. Create common primitives for parameters, section headers, numeric values, dropdowns, and toggles.

### 5.5 Engine isolation

UI restructuring must not change Rust FFI contracts during the first milestone. Existing engine calls should move behind Flutter-side services/controllers before any native API redesign is considered.

## 6. Proposed Design Tokens

Create a dedicated studio design system.

Suggested token groups:

```text
StudioColors
StudioSpacing
StudioTypography
StudioRadius
StudioPanelMetrics
StudioDurations
StudioBreakpoints
```

Initial neutral palette target:

```text
Workspace background   #1B1B1B
Panel background       #242424
Elevated surface       #2C2C2C
Divider                #3A3A3A
Primary text           #E8E8E8
Secondary text         #A6A6A6
Disabled text          #666666
```

Accent, warning, success, and error colors should be defined separately and used sparingly.

Recommended desktop metrics:

```text
Module bar       44–52 px
Left panel       240–280 px
Right panel      280–340 px
Filmstrip        96–130 px
Status bar       24–28 px
Compact row      28–34 px
```

## 7. Target Flutter Structure

Move away from a monolithic `lib/main.dart` toward feature-oriented UI boundaries.

```text
lib/
  main.dart

  app/
    nixin_app.dart
    theme/
      studio_colors.dart
      studio_spacing.dart
      studio_typography.dart
      studio_metrics.dart
      studio_theme.dart

  engine/
    raw_engine.dart
    engine_image.dart
    engine_service.dart

  studio/
    studio_page.dart
    studio_controller.dart
    studio_state.dart

    shell/
      studio_shell.dart
      module_bar.dart
      status_bar.dart

    preview/
      preview_workspace.dart
      preview_toolbar.dart
      zoom_control.dart
      before_after_control.dart

    panels/
      studio_panel.dart
      panel_section.dart

      left/
        navigator_panel.dart
        presets_panel.dart
        history_panel.dart
        collections_panel.dart

      right/
        histogram_panel.dart
        profile_panel.dart
        light_panel.dart
        color_panel.dart
        detail_panel.dart
        effects_panel.dart

    controls/
      parameter_slider.dart
      numeric_value_field.dart
      compact_dropdown.dart
      compact_toggle.dart
      section_header.dart

    filmstrip/
      filmstrip.dart
      filmstrip_item.dart
```

Exact naming can evolve, but the ownership boundaries should remain clear.

## 8. State Separation

Before redesigning the controls, separate state that is currently embedded in the widget.

Minimum state model:

```text
engine availability/version
selected RAW path
selected asset metadata
preview image
preview mode
processing state
last operation/error
export quality
active module
panel visibility
zoom state
```

The UI should not call FFI directly once the extraction is complete.

Recommended flow:

```text
Widget
  -> StudioController / service boundary
      -> RawEngine
          -> Rust FFI
```

Do not introduce a large state-management migration solely for the redesign. A lightweight controller/state model is sufficient initially.

## 9. Right Adjustment Panel

Initial section order:

```text
Histogram
Profile
Light
Color
Detail
Effects
```

Future sections may include tone curve, transform, masking, and advanced color tools.

### Light

Initial conceptual parameters:

```text
Exposure
Contrast
Highlights
Shadows
Whites
Blacks
```

Only connect parameters that the engine actually supports. Unsupported controls must not be presented as functional.

### Color

Potential future parameters:

```text
Temperature
Tint
Vibrance
Saturation
```

Again, do not fake engine support.

## 10. Compact Parameter Control Contract

A reusable parameter slider should eventually support:

- label
- current numeric value
- min/max
- drag interaction
- keyboard adjustment
- double-click reset
- optional text entry
- disabled state
- reset/default value
- fine adjustment modifier

Conceptual layout:

```text
Exposure      ─────────●──────   +0.35
Contrast      ───────●────────    +12
Highlights    ───●────────────    -34
```

Avoid using a default Material slider unchanged for the final desktop UI.

## 11. Left Panel

First milestone sections:

```text
Navigator
Presets
History
```

`Collections` can remain a shell until the application has a persistent library/catalog model.

The preset section should be designed so LUTs and future native film profiles can use the same presentation model without coupling UI directly to file-picker operations.

## 12. Preview Workspace

The center workspace should provide:

### First milestone

- current image preview
- fit-to-window behavior
- neutral background
- loading/processing overlay
- empty state
- error state
- basic zoom indication

### Later milestone

- fit / fill / 1:1 / 2:1
- pan
- split comparison
- before/after
- clipping overlays
- mask visualization modes

The existing RGBA-to-preview rendering path should remain functional during the extraction.

## 13. Filmstrip

Implement after the shell and current editing actions are stable.

First version:

- horizontal thumbnail list
- selected state
- click/tap selection
- horizontal scrolling
- collapse/hide behavior

Design for virtualization from the beginning so the widget can later handle large image sets without rendering every thumbnail simultaneously.

## 14. Module Bar

Initial modules:

```text
Library
Develop
Export
```

The module bar represents workspace intent, not page-style mobile navigation.

During the first milestone, `Develop` can host the current RAW workflow while `Library` and `Export` may initially be lightweight shells where needed.

## 15. Keyboard and Panel Behavior

Desktop editor UX should eventually include:

```text
Tab         toggle side panels
Shift+Tab   toggle major chrome
```

Panel collapse controls should also be available with the mouse.

Do not make keyboard shortcuts the only way to access any feature.

## 16. Responsive Strategy

The professional desktop workspace is the primary target, but layout degradation must be controlled.

Suggested breakpoints:

```text
>= 1440 px     full workspace
1100–1439 px   narrower side panels
800–1099 px    collapsible left panel by default
< 800 px       alternate compact/tablet composition
```

Do not simply squeeze the three-column desktop layout into a phone-sized viewport.

## 17. Implementation Tasks

### UI-01 — Extract engine-facing Dart code

Goal: remove FFI implementation details from `main.dart` without changing behavior.

Work:

- move `EngineImage` to engine layer
- move `RawEngine` to engine layer
- move RGBA conversion helper to an appropriate engine/image utility
- keep all existing native symbols and behavior unchanged

Acceptance:

- app builds
- engine version/check still works
- RAW develop still works
- masks still work
- LUT still works
- JPEG export still works

### UI-02 — Extract application/studio state

Goal: stop storing all editor behavior directly inside `StudioPage`.

Work:

- define studio state
- define controller/service boundary
- expose processing/error state explicitly
- preserve all existing actions

Acceptance:

- widgets no longer call FFI directly
- state transitions are testable without rewriting Rust

### UI-03 — Add studio design tokens

Goal: establish neutral professional editor styling before panel implementation.

Work:

- colors
- spacing
- typography
- panel dimensions
- dividers
- compact control density

Acceptance:

- no important workspace component relies on scattered magic values

### UI-04 — Implement `StudioShell`

Goal: establish module bar + left/center/right + bottom/status regions.

Acceptance:

- shell adapts to desktop width
- center preview remains usable as panels resize/collapse
- no processing behavior regression

### UI-05 — Implement module bar and status bar

Goal: move global workspace navigation/status out of the current generic app bar and loose status text.

Status bar should be capable of showing:

- file name
- image dimensions
- engine status
- processing state
- error/ready state

### UI-06 — Move preview into `PreviewWorkspace`

Goal: make preview an independent component with explicit states.

Required states:

```text
empty
loading/processing
image ready
error
```

### UI-07 — Build collapsible left/right panels

Goal: create reusable panel containers and accordion sections.

Acceptance:

- panel sections can collapse independently
- complete side panels can be hidden
- layout remains stable

### UI-08 — Move existing actions into workspace panels

Map current behavior rather than inventing unsupported editing features.

Suggested mapping:

```text
Open RAW         -> Library/left context or module action
Develop          -> Develop workflow
Subject Mask     -> right-side tool/action section
Sky Mask         -> right-side tool/action section
Apply LUT        -> Presets/Profile section
Export JPEG      -> Export module/action
JPEG Quality     -> Export settings
```

Acceptance:

- every existing action remains accessible
- old top-level button strip can be removed

### UI-09 — Add compact editor controls

Create reusable editor primitives even if only a subset is connected initially.

Do not expose controls whose native processing path does not yet exist.

### UI-10 — Add filmstrip foundation

Goal: selected asset strip with future scalability.

### UI-11 — Add zoom and comparison toolbar foundation

First version may provide only fit/1:1 if implementation scope needs to remain small.

### UI-12 — Add desktop keyboard shortcuts

Implement after focus handling is stable.

### UI-13 — Responsive refinement

Validate at representative desktop and tablet widths.

### UI-14 — Tests

Add at minimum:

- studio shell widget test
- panel collapse test
- empty preview test
- ready preview test
- processing/error state test
- action availability test with/without selected RAW
- responsive layout test

Engine-facing tests should remain independent from visual widget tests where practical.

### UI-15 — Visual polish

Only after behavior and layout tests pass:

- spacing refinement
- typography refinement
- hover/focus states
- subtle transitions
- icons
- separators
- compact density tuning

## 18. First Delivery Milestone

The recommended first implementation batch is:

```text
UI-01
UI-02
UI-03
UI-04
UI-05
UI-06
UI-07
UI-08
```

Definition of done:

- current Rust-backed features still work
- `main.dart` is no longer the main owner of editor implementation
- application opens into the new studio workspace shell
- image preview is centered and dominant
- left/right panels are structurally present
- existing RAW/mask/LUT/export actions are available in their new locations
- workspace uses centralized design tokens
- analyze/tests pass

## 19. Validation Gate

Before moving to filmstrip and advanced editor interactions:

```bash
flutter pub get
flutter analyze
flutter test
```

Also manually validate on every currently supported desktop platform available to the development team:

- application launch
- native engine load
- RAW develop
- subject mask
- sky mask
- LUT application
- JPEG export
- panel collapse/restore
- resize behavior

Any native processing regression blocks further visual feature work.

## 20. Guardrails

1. Preserve the existing Rust API during the first milestone.
2. Do not fake controls that are not connected to processing logic.
3. Keep the center image preview as the primary visual surface.
4. Keep desktop controls compact and keyboard-friendly.
5. Avoid coupling panel widgets directly to file pickers or FFI.
6. Add new editor capabilities behind explicit interfaces.
7. Prefer incremental extraction over a full application rewrite.
8. Validate processing behavior after each structural move.

## 21. Historical Branch Workflow

Initial redesign branch:

```text
feature/studio-workspace-redesign
```

Initial implementation sequence:

```text
commit 1  refactor: extract raw engine from studio UI
commit 2  refactor: introduce studio state boundary
commit 3  feat: add studio design system
commit 4  feat: add studio workspace shell
commit 5  feat: add workspace panels and status bar
commit 6  refactor: migrate existing editor actions
commit 7  test: cover studio workspace states
```

The foundation batch was completed and merged before the UI-09 through UI-15 follow-up branch.

## 22. Final Implementation Status — 2026-08-13

This section is the canonical status for the completed workspace milestone.

### Delivery

- UI-01 through UI-08 were completed and merged to `main` via PR #1.
- PR #1 merge commit: `b40444467652d794d96a5891cb355fea718c2d3f`.
- UI-09 through UI-15 were completed on branch `feature/studio-editor-controls` in PR #2.
- Final implementation head before handoff-only documentation commits: `838b756cb52051caaa78345f443af5aeeaa63937`.
- The workspace milestone UI-01 through UI-15 is complete.

### Additional fixes completed during native validation

- macOS App Sandbox user-selected read/write entitlement added for file picking and export.
- source selection expanded from RAW-only to Open Image.
- standard raster images decode directly through the Rust image pipeline; RAW containers retain the embedded-preview fallback.
- PNG/JPEG selection populates the main preview immediately.
- filmstrip thumbnail selection reloads the current preview.
- Apply LUT is accessible from the right Tools panel so it remains available in medium layout.

### Automated validation

Latest CI on implementation head `838b756cb52051caaa78345f443af5aeeaa63937`:

- GitHub Actions run #93 (`31678940129`): passed.
- Rust check: passed.
- Rust tests: passed.
- Flutter analyze: passed.
- Flutter tests: passed.
- PNG standard-image loader regression coverage is included.

### Manual native validation

Developer-confirmed on macOS using the rebuilt native Rust library:

- application launch and native engine load: passed
- PNG/JPEG Open Image and immediate preview: passed
- RAW preview/develop: passed
- subject mask: passed
- sky mask: passed
- `.cube` LUT application: passed
- JPEG export: passed
- Fit / 1:1 preview modes and pan behavior: passed
- filmstrip collapse/show and current-item interaction: passed
- Tab side-panel toggle: passed
- Shift+Tab major-chrome toggle: passed
- responsive resize behavior across compact, medium, wide, and >=1440 px desktop widths: passed

### Remaining guardrails / follow-up scope

The completed milestone does not change these intentional constraints:

- RAW processing remains preview-based; full sensor debayer is a future engine milestone.
- no unsupported editor parameter should be presented as functional.
- persistent library/catalog, advanced history, virtual copies, brush/heal, advanced masking, and advanced comparison tools remain follow-up work.
- native processing behavior should continue to gate future structural UI changes.

### Merge gate

Automated and manual validation gates are complete. PR #2 is ready to leave Draft status and proceed through review. Merge remains an explicit separate action.