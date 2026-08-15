# Dxtr Segment — MobileSAM ONNX Handoff

> Status: planned architecture. This track is intentionally independent from RAW development and should not block the Workplaces/Import UX roadmap.

## 1. Objective

Extract local AI segmentation into a reusable Flutter plugin package named `dxtr_segment`.

The package will provide a model-agnostic segmentation API. The first backend is MobileSAM running through ONNX Runtime.

Nixin must consume the package through a small adapter rather than own ONNX Runtime, MobileSAM preprocessing, encoder/decoder execution, tensor handling, or embedding cache logic directly.

Primary first product capability:

```text
User identifies an object with a point or box
        ↓
Local MobileSAM inference
        ↓
Editable mask
```

The first release is object selection/masking only. It is not a general AI editing suite.

## 2. Why this should be a package

MobileSAM has a clean boundary from the photo editor:

```text
Image
Prompt
Embedding
Mask
```

The segmentation engine does not need to know about:

- StudioController
- Workplaces
- DevelopSettings
- Exposure/contrast/color controls
- film profiles
- RAW development internals
- Nixin panel layout

Separating this work provides:

- reuse in Nixin and other Flutter applications
- independent benchmarking and testing
- isolation of ONNX Runtime/native lifecycle complexity
- the ability to swap MobileSAM for another segmentation backend later
- a standalone example application that proves the package works without Nixin

## 3. Package identity

Recommended package name:

```text
dxtr_segment
```

Do not name the public package `nixin_mobile_sam`.

Do not make MobileSAM part of the long-term public API contract.

MobileSAM is the first backend implementation:

```text
dxtr_segment
    │
    ├── MobileSAM backend — first implementation
    ├── future SAM/SAM2-compatible backend
    └── future segmentation backend
```

## 4. Target architecture

```text
Nixin
  │
  └── dxtr_segment
        │
        ├── Flutter public API
        │
        └── Rust/native core
              │
              ├── ONNX Runtime
              ├── MobileSAM image encoder
              ├── MobileSAM prompt/mask decoder
              ├── preprocessing
              ├── postprocessing
              └── embedding cache
```

Nixin owns the editing UX and persistent mask model. `dxtr_segment` owns inference.

## 5. Proposed package structure

```text
packages/
  dxtr_segment/
    pubspec.yaml
    lib/
      dxtr_segment.dart
      src/
        segmentation_engine.dart
        segmentation_prompt.dart
        segmentation_result.dart
        prepared_image.dart
        mobile_sam_engine.dart
        mobile_sam_config.dart

    rust/
      Cargo.toml
      src/
        lib.rs
        api.rs
        runtime.rs
        encoder.rs
        decoder.rs
        preprocess.rs
        postprocess.rs
        cache.rs
        error.rs

    models/
      README.md

    example/
      lib/
        main.dart

    test/
```

If the Rust implementation grows, split the native side further:

```text
rust/
  crates/
    segment-core/
    mobile-sam/
    flutter-bridge/
```

Preferred dependency direction:

```text
Flutter
   ↓
Flutter plugin API
   ↓
Rust bridge
   ↓
segment-core
   ↓
MobileSAM + ONNX Runtime
```

The core segmentation logic should remain testable without starting Flutter.

## 6. Public API direction

The public API should be model-agnostic.

Conceptual interface:

```dart
abstract interface class SegmentationEngine {
  Future<PreparedImage> prepareImage(Uint8List imageBytes);

  Future<SegmentationResult> segment({
    required PreparedImage image,
    required List<SegmentationPrompt> prompts,
    SegmentationResult? previousResult,
  });

  Future<void> disposePreparedImage(PreparedImage image);
  Future<void> dispose();
}
```

MobileSAM implementation:

```dart
final engine = MobileSamEngine();

await engine.initialize(
  MobileSamConfig(
    encoderModelPath: encoderPath,
    decoderModelPath: decoderPath,
  ),
);

final prepared = await engine.prepareImage(imageBytes);

final result = await engine.segment(
  image: prepared,
  prompts: [
    SegmentationPoint.foreground(x: 420, y: 280),
  ],
);
```

Refinement should reuse the prepared image and prior low-resolution mask when supported:

```dart
final refined = await engine.segment(
  image: prepared,
  prompts: [
    positivePoint,
    negativePoint,
  ],
  previousResult: result,
);
```

## 7. Prepared image / embedding is a first-class concept

Do not design the API as:

```text
segment(image, point)
segment(image, point)
segment(image, point)
```

That risks repeating the expensive image encoder for every interaction.

The intended flow is:

```text
Image
  ↓
prepareImage()
  ↓
MobileSAM image embedding
  ↓
PreparedImage
  ├── prompt #1 → decoder → mask
  ├── prompt #2 → decoder → refined mask
  └── prompt #3 → decoder → refined mask
```

Image encoding should occur once per image revision whenever possible.

## 8. MobileSAM ONNX model contract

Do not assume one exported `mobile_sam.onnx` file is an end-to-end MobileSAM pipeline.

The MobileSAM ONNX export path for the SAM prompt/mask side consumes precomputed `image_embeddings` together with prompt inputs. Therefore `dxtr_segment` must explicitly own both stages:

```text
Stage 1
Image
  ↓
TinyViT / MobileSAM image encoder
  ↓
Image embedding

Stage 2
Image embedding
+ point/box prompts
+ optional previous mask
  ↓
Prompt encoder + mask decoder
  ↓
Mask + score + low-resolution mask
```

Treat encoder and decoder model contracts as explicit versioned assets.

## 9. Prompt model

First supported prompts:

```text
positive point
negative point
box
```

Suggested Dart model:

```dart
sealed class SegmentationPrompt {}

final class SegmentationPoint extends SegmentationPrompt {
  final double x;
  final double y;
  final SegmentationPointType type;
}

final class SegmentationBox extends SegmentationPrompt {
  final Rect rect;
}
```

Do not expose ONNX tensor details to application code.

Coordinate conversion between editor image space and MobileSAM input space belongs inside the package.

## 10. Nixin responsibilities

Nixin owns:

- Mask panel UI
- object-selection cursor/tool state
- mouse click and drag interaction
- overlay rendering
- mask visualization color
- feather
- invert
- opacity
- mask layer ordering
- persistence in the Workplace/project model
- connection between masks and Develop adjustments

Nixin should use an adapter such as:

```text
MobileSamMaskService
      ↓
dxtr_segment
```

The adapter converts Nixin asset/mask concepts to the generic package API.

## 11. Package responsibilities

`dxtr_segment` owns:

- ONNX Runtime initialization/lifecycle
- execution provider selection
- model loading and validation
- MobileSAM image encoder
- prompt/mask decoder
- preprocessing
- normalization/resizing
- coordinate transforms
- point prompts
- negative prompts
- box prompts
- previous-mask refinement
- mask postprocessing
- prepared-image lifecycle
- embedding cache
- asynchronous inference boundary
- cancellation/latest-request-wins behavior
- model metadata/version checks
- native error mapping
- CPU and accelerator backend abstraction

## 12. Model distribution

Do not hardcode the inference engine to a Flutter asset path.

Configuration should accept model paths:

```dart
MobileSamConfig(
  encoderModelPath: ...,
  decoderModelPath: ...,
)
```

This keeps the package compatible with:

- bundled models
- downloaded-on-demand models
- FP32 reference models
- FP16 variants
- quantized variants
- platform-optimized model variants

Suggested model directory when bundled by an application:

```text
models/
  mobilesam/
    encoder_fp32.onnx
    decoder_fp32.onnx
    manifest.json
```

Suggested manifest fields:

```text
model family
model version
encoder version
decoder version
sha256
input size
opset
precision
license/source metadata
```

Model files should be validated before a session is exposed as ready.

## 13. Precision strategy

Start from FP32 reference inference.

Order:

```text
FP32 baseline
      ↓
correctness/golden validation
      ↓
benchmark
      ↓
FP16 experiment
      ↓
INT8 experiment
```

Do not make quantization part of the first integration milestone.

Segmentation edge quality is more important than reducing model size before baseline correctness is established.

## 14. Async and latest-request-wins

Inference must never block Flutter's UI thread.

Target execution path:

```text
Flutter UI
   │
   ├── user prompt
   │
   ▼
async FFI boundary
   │
Rust/native worker
   │
ONNX Runtime inference
   │
mask result
   │
   ▼
Flutter compositor
```

Interactive prompt refinement needs request sequencing:

```text
request #41
request #42
request #43
```

If #41 completes after #43, #41 must not overwrite the newer result.

Use a request/generation identifier or explicit cancellation strategy.

## 15. Embedding cache

Cache prepared image embeddings separately from decoded masks.

Conceptual key:

```text
PreparedImageCacheKey {
  asset identity,
  image revision,
  model version,
  preprocessing version,
}
```

A cached embedding is valid only while the model and image-space transform remain compatible.

Invalidate when the source revision changes in a way that changes encoder input, including relevant crop/rotation/source changes.

Do not make application code manage ONNX tensor buffers directly.

## 16. Nixin masking UX — first release

Do not expose the term `MobileSAM` in the editor UI.

User-facing tool:

```text
Masks
  ↓
Create Mask
  ↓
Select Object
```

Interaction:

```text
Select Object
  ↓
cursor/tool becomes active
  ↓
click object
  ↓
mask appears
```

Initial refinement:

```text
+ Add
- Remove
Reset
```

Then add box prompting:

```text
Select Area
  ↓
drag box around object
  ↓
segmentation result
```

The UX should behave like a photo-editing selection tool, not an AI demo.

## 17. Persistent mask model

Nixin should not store only a rendered PNG mask.

Suggested application-level model:

```text
MaskLayer
  id
  name
  source
  prompts
  mask data/reference
  feather
  opacity
  inverted
```

For AI-generated masks, persist enough information to regenerate/refine when practical:

```text
source: segmentation
backend/model metadata
positive points
negative points
box prompt
```

This model belongs to Nixin, not `dxtr_segment`.

## 18. Performance strategy

Baseline first:

```text
CPU reference
```

Then benchmark platform acceleration instead of assuming it is faster:

```text
CPU baseline
    ↓
XNNPACK where appropriate
    ↓
CoreML — macOS/iOS candidate
    ↓
NNAPI — Android candidate
```

Execution-provider support must remain behind package internals.

Nixin should request a capability/performance policy, not construct ONNX sessions itself.

Suggested first performance budgets for investigation:

```text
Desktop image embedding
  target: < 500 ms
  acceptable first spike: < 1 s

Prompt → mask after embedding
  target: < 100 ms
  acceptable first version: < 200 ms
```

These are engineering targets, not correctness gates until representative-device benchmarks exist.

The key UX requirement is that repeated prompt refinement does not rerun the image encoder unnecessarily.

## 19. Package implementation roadmap

### P1 — Rust/ONNX core

Goal: establish native model execution independent of Nixin.

Work:

- ONNX Runtime integration
- model/session lifecycle
- explicit encoder and decoder model contracts
- error model
- deterministic test harness

Acceptance:

```text
input image
→ encoder
→ embedding
→ decoder with test prompt
→ output mask
```

### P2 — Complete segmentation pipeline

Work:

- image preprocessing
- encoder output handling
- point coordinate mapping
- decoder inputs
- mask postprocessing
- score/result model

Add golden/reference tests against known inputs.

### P3 — Flutter plugin API

Work:

- Flutter-facing package API
- async FFI/native boundary
- `PreparedImage`
- foreground point prompt
- lifecycle/disposal
- typed error mapping

Acceptance:

The package example app can load an image, click a point, and display a mask without importing Nixin code.

### P4 — Interactive refinement

Work:

- positive points
- negative points
- previous low-resolution mask refinement
- box prompts
- latest-request-wins
- prepared-image reuse

Acceptance:

Repeated prompts update the mask without recomputing the image embedding when the source image has not changed.

### P5 — Production hardening

Work:

- embedding cache
- memory-pressure behavior
- session disposal
- cancellation
- model manifest validation
- corrupt/missing model errors
- repeated open/close reliability tests

### P6 — Acceleration and footprint

Only after correctness is stable:

- benchmark CPU baseline
- test XNNPACK where applicable
- test CoreML on macOS/iOS
- test NNAPI on Android
- investigate FP16
- investigate INT8
- measure model size, binary size, memory, latency, and power impact

Do not keep an accelerator merely because it is available; keep it only if benchmarked behavior is better on supported devices.

### P7 — Nixin integration

Work:

- `MobileSamMaskService`/segmentation adapter
- `Select Object` tool
- mask overlay
- positive/negative refinement UI
- box selection
- persistent `MaskLayer`
- undo/history integration where applicable

This phase should be small because inference complexity already lives inside `dxtr_segment`.

## 20. Standalone example requirement

The package is not considered successfully extracted until `example/` can demonstrate the core workflow independently:

```text
Open image
→ prepare image
→ click foreground point
→ display mask
→ add positive/negative prompt
→ refined mask
```

The example must not depend on Nixin's `StudioController`, Workplace database, Develop settings, or UI components.

## 21. Tests

Minimum coverage:

### Rust/core

- preprocessing dimensions and normalization
- coordinate conversion
- encoder model input/output contract
- decoder model input/output contract
- known-image known-prompt golden/reference mask
- previous-mask refinement contract
- invalid model handling
- repeated session creation/disposal

### Flutter/plugin

- initialization states
- `PreparedImage` lifecycle
- foreground prompt request
- typed error propagation
- latest-request-wins/stale-result prevention
- dispose safety

### Nixin adapter

- source coordinate → segmentation coordinate mapping
- stale result cannot replace newer mask
- mask survives UI/controller state transitions

## 22. Guardrails

1. Keep the public package API model-agnostic where practical.
2. MobileSAM is the first backend, not the product identity.
3. Do not couple the package to Nixin UI or Workplace state.
4. Do not rerun the image encoder for every point prompt.
5. Do not block the Flutter UI thread with ONNX inference.
6. Do not let stale inference results overwrite newer prompts.
7. Establish FP32 correctness before quantization.
8. Keep accelerator selection internal to the package.
9. Do not expose ONNX tensor details through the Flutter public API.
10. Do not make MobileSAM work block Workplaces/Import UX development.
11. Full RAW sensor debayer remains a separate future engine milestone.
12. No cloud inference is required for this milestone.

## 23. Explicit non-goals for the first MobileSAM package milestone

Do not implement yet:

- automatic full-image semantic labeling
- face recognition
- people database
- generative fill
- object removal
- AI relighting
- video segmentation
- SAM2 video workflow
- model training/fine-tuning
- cloud inference
- advanced brush/heal editing

The first product contract remains:

> Given an image and user prompt, generate a fast local editable object mask.

## 24. Recommended project ordering

This track should be parallel-capable but not blocking for current UX work:

```text
Workplaces Foundation
        │
        ├── Import/Workplace UX modernization
        │
        └── continue independent product UX work

Parallel engineering spike
        │
        └── dxtr_segment P1/P2 reference pipeline

After the package contract is stable
        │
        ├── dxtr_segment P3/P4
        └── Nixin mask UX design

Then
        │
        └── P7 Nixin integration

Later
        │
        └── full RAW / advanced Develop milestones
```

The recommended immediate next action for the MobileSAM track is **P1 — prove the complete encoder → embedding → prompt decoder → mask pipeline in Rust/ONNX without Nixin UI dependencies**.