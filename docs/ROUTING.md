# Dextryx Images — Routing

Dextryx Images uses `go_router` as the application navigation boundary.

## Current foundation

The app shell is `MaterialApp.router` and reads the shared `GoRouter` from:

```text
lib/app/router/app_router.dart
```

The initial route remains the existing Studio workspace:

```text
/  -> StudioPage
```

This migration intentionally changes navigation infrastructure only. It does not change Workplace persistence, import behavior, catalog ownership, image processing, RAW behavior, or Studio UI behavior.

## Route ownership

Top-level application routes belong under `lib/app/router/`.

Feature screens remain owned by their feature modules. Route configuration may reference feature entry screens, but feature implementation should not move into the router layer.

Use named routes through `AppRoutes` instead of scattering literal path strings through widgets.

## Expansion order

Add routes only when a real screen/flow requires them. Expected future route families include Workplace/catalog navigation, settings, and external-editor handoff flows.

Do not introduce nested `Navigator` or `ShellRoute` structure until persistent multi-branch navigation is required. The current single Studio route deliberately keeps the router foundation minimal.

## Compatibility

`go_router` is pinned to `14.6.2` because the repository currently declares Dart `>=3.3.0 <4.0.0`. Newer go_router releases raise their minimum Dart SDK. A go_router upgrade should therefore be coupled to an explicit repository SDK-floor decision rather than silently raising compatibility.
