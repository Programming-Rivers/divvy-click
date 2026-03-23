# DivvyClick — Code Critique

A review of the ~850-line Swift codebase across 7 source files.

---

## Overall Impression

DivvyClick is a well-scoped, focused utility. The architecture is clean with a sensible separation of concerns: input handling, navigation state, cursor control, and overlay rendering are each in their own file. For a project of this size, readability is good and the code is easy to follow from end to end.

That said, there are several areas—ranging from correctness risks to maintainability concerns—worth tightening up.

---

## 🔴 Correctness & Safety Issues

### 1. Memory Leak in Event Handling — `passRetained` without Matching Release
[HotkeyManager.swift:112, 129, 245](file:///Users/meisam/workspce/divvy-click/Sources/DivvyClick/HotkeyManager.swift#L112-L245)

Every time an event passes through unmodified, the code returns `Unmanaged.passRetained(event)`. This **increments the retain count** on the `CGEvent` each time. The correct API for "return Event unchanged, I don't own it" is:

```swift
return Unmanaged.passUnretained(event)
```

> [!CAUTION]
> `passRetained` leaks every event that isn't consumed. Over time, this will continually grow process memory. This is the most critical bug in the codebase.

### 2. `MainActor.assumeIsolated` in `CGEventTapCallBack` is Fragile
[HotkeyManager.swift:42-44](file:///Users/meisam/workspce/divvy-click/Sources/DivvyClick/HotkeyManager.swift#L42-L44)

The event tap callback runs on whichever run loop it's added to. While you add it to the main run loop (so it *should* fire on the main thread), `MainActor.assumeIsolated` is a contract assertion — if a future refactor moves the run loop source, it will crash at runtime with no compiler warning.

### 3. Unbounded History Stack
[NavigationEngine.swift:16](file:///Users/meisam/workspce/divvy-click/Sources/DivvyClick/NavigationEngine.swift#L16)

`history` and `redoStack` grow unboundedly. In a long session of fast-move (which pushes 2 entries per keystroke), this could accumulate thousands of `CGRect` values. Consider capping to a reasonable limit (e.g. 100).

### 4. `DispatchQueue.main.asyncAfter` in `@MainActor` Class
[NavigationEngine.swift:151-154](file:///Users/meisam/workspce/divvy-click/Sources/DivvyClick/NavigationEngine.swift#L151-L154)

Inside a `@MainActor` class, using `DispatchQueue.main.asyncAfter` re-enters the actor asynchronously. While it works today, Swift concurrency doesn't guarantee this is actor-safe. Prefer `Task { @MainActor in ... }` with `try? await Task.sleep(for:)` for consistency with the modern concurrency model you already use in `GridOverlayView`.

---

## 🟡 Architecture & Design Concerns

### 5. Magic Numbers Everywhere in `HotkeyManager`
[HotkeyManager.swift:88-238](file:///Users/meisam/workspce/divvy-click/Sources/DivvyClick/HotkeyManager.swift#L88-L238)

Key codes like `16`, `32`, `34`, `4`, `38`, `40`, `45`, `46`, `43`, `37`, `53`, `41`, `71`, `78`, `69` are used as raw integers without named constants. This makes the file hard to audit and error-prone to modify. Consider an enum or a constants namespace:

```swift
private enum KeyCode: Int64 {
    case y = 16, u = 32, i = 34
    case h = 4,  j = 38, k = 40, l = 37
    case n = 45, m = 46, comma = 43
    case semicolon = 41, escape = 53, clear = 71
    case a = 0, s = 1, d = 2, f = 3
    case space = 49
    case numpadMinus = 78, numpadPlus = 69
}
```

### 6. `HotkeyManager.handleEvent` is a 180-line God Method
[HotkeyManager.swift:66-245](file:///Users/meisam/workspce/divvy-click/Sources/DivvyClick/HotkeyManager.swift#L66-L245)

This is the most complex method in the project. It handles:
- Double-tap command detection
- Layer state tracking
- Display selection routing
- Universal key bindings (Space, `;`)
- Four separate layer dispatch tables
- Default layer dispatch

Each of these responsibilities could be extracted into its own method (e.g. `handleLayerKeys`, `handleDisplaySelection`, `handleDefaultNavigation`) for clarity.

### 7. `NavigationEngine` Mixes State Management with Side Effects
[NavigationEngine.swift](file:///Users/meisam/workspce/divvy-click/Sources/DivvyClick/NavigationEngine.swift)

`NavigationEngine` is both a state machine (managing `currentRegion`, `history`, `isActive`) and an executor of mouse events (via `cursorEngine.click`, `.jump`, `.mouseDown`, etc.). This conflation makes it harder to test the navigation logic in isolation. Ideally, `execute()` would be in a separate coordinator or the engine would emit *intents* that another object fulfills.

### 8. README is Stale
[README.md](file:///Users/meisam/workspce/divvy-click/README.md)

The README describes "binary search" and "bifurcation" (halving), but the actual implementation uses a **3×3 grid (trifurcation)** with an overlap factor. The keystroke estimate ("11 to 21 keystrokes") is also based on the binary model and doesn't match the current code.

---

## 🟢 Style & Maintainability

### 9. Duplicated Coordinate Conversion
[GridOverlayView.swift:447-454](file:///Users/meisam/workspce/divvy-click/Sources/DivvyClick/GridOverlayView.swift#L447-L454) vs [InvertedRectangle](file:///Users/meisam/workspce/divvy-click/Sources/DivvyClick/GridOverlayView.swift#L467-L472)

The `localRect(for:in:)` method and `InvertedRectangle.path(in:)` both contain the same AppKit-to-SwiftUI coordinate conversion logic:

```swift
y: outerRect.height - (innerRect.origin.y - outerRect.origin.y) - innerRect.height
```

Extract this into a single shared helper to maintain a single source of truth.

### 10. `GridOverlayView` is a 478-line Monolith
[GridOverlayView.swift](file:///Users/meisam/workspce/divvy-click/Sources/DivvyClick/GridOverlayView.swift)

This single file contains: grid line rendering (with Canvas), key cue badges, display selection UI, layer HUD, and coordinate conversion. Breaking these into separate `View` types (e.g. `SniperEyepiece`, `DisplaySelectionView`, `LayerHUDView`) would improve navigability and reuse.

### 11. `keyAction` Has Implicit Coupling to Key Layout
[GridOverlayView.swift:374-435](file:///Users/meisam/workspce/divvy-click/Sources/DivvyClick/GridOverlayView.swift#L374-L435)

The key-to-action mapping in the View layer (for HUD labels) is a separate and parallel definition to the key-to-behavior mapping in `HotkeyManager`. If a key binding is changed in one place, the other must be updated manually. Consider defining bindings in a single shared data structure.

### 12. `dead` `resetToFullScreen` Method
[NavigationEngine.swift:226-231](file:///Users/meisam/workspce/divvy-click/Sources/DivvyClick/NavigationEngine.swift#L226-L231)

`resetToFullScreen()` is defined but never called anywhere. It's dead code and should be removed.

### 13. Unused Import: `Foundation` in Multiple Files
[CursorEngine.swift](file:///Users/meisam/workspce/divvy-click/Sources/DivvyClick/CursorEngine.swift) and [HotkeyManager.swift](file:///Users/meisam/workspce/divvy-click/Sources/DivvyClick/HotkeyManager.swift) both import `Foundation` but don't use anything from it beyond what `AppKit` already re-exports.

### 14. No Tests
There are no test files or test targets. `CursorEngine` and `NavigationEngine` (particularly `vennfurcate` and undo/redo logic) are highly testable units. Even basic unit tests for the grid subdivision math would catch regressions quickly.

---

## Summary — Priority Actions

| Priority | Status  | Effort | Issue                                          |
|----------|---------|--------|------------------------------------------------|
|    P0    | Fixed   |  5 min | Fix `passRetained` → `passUnretained` memory leak |
|    P0    | Fixed   | 10 min | Cap `history`/`redoStack` size |
|    P1    | Fixed   | 30 min | Extract key code constants enum |
|    P1    | Pending |   1 hr | Break up `handleEvent` god method |
|    P1    | Pending | 20 min | Update README to match implementation |
|    P2    | Fixed   |   1 hr | Unify key binding definitions (View ↔ HotkeyManager) |
|    P2    | Pending |   1 hr | Split `GridOverlayView` into focused sub-views |
|    P2    | Pending |   2 hr | Add unit tests for `NavigationEngine` |
|    P2    | Pending |  5 min | Remove dead code (`resetToFullScreen`, unused imports) |
