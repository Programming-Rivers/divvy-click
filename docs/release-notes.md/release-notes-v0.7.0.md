# Release Notes: DivvyClick v0.7.0

We are thrilled to announce **DivvyClick v0.7.0**! 🚀

This release is a major architectural and functional milestone. It introduces **dynamic grid layout switching** from the macOS menu bar, a brand-new **2-Tile Bifurcation (JK)** layout, a continuous **Nudge & Accelerated Glide** layer for pixel-precision targeting, and a decomposed **modular Swift package architecture** built with Bazel.

---

## ✨ Highlights

### 🔄 Dynamic Layout Switching & Layout Registry
DivvyClick now supports multiple pluggable navigation layouts that can be switched on the fly from the macOS Menu Bar:
- **Menu Bar Selection:** Easily switch active navigation styles via the new `Layout` submenu in the menu bar. Your selection persists across app restarts.
- **Multiple Layout Strategies:**
  - **`2x2 Overlapping (IJKL)` (Default):** Rapid navigation via overlapping Top/Bottom and Left/Right tile pairs.
  - **`3x3 Grid (UIO/JKL/M,.)`:** Classic 9-tile grid layout covering all cardinal and ordinal directions.
  - **`2-Tile Bifurcation (JK)`:** Self-similar alternating binary split layout (see below).
- **Extensible `NavigationLayout` Protocol:** Completely decoupled grid generation, key bindings, HUD structures, and targeting logic.

### 🌗 2-Tile Binary Bifurcation Layout (`J` / `K`)
A streamlined navigation mode based on recursive binary space partitioning:
- **Aspect-Ratio Preserving:** Alternates between horizontal (side-by-side) and vertical (stacked) splits at each step to maintain tiles matching the display's aspect ratio.
- **Two-Key Flow:**
  - **Horizontal Split:** `J` selects Left, `K` selects Right.
  - **Vertical Split:** `J` selects Top, `K` selects Bottom.

### 🎯 Nudge & Accelerated Glide Layer (`S`)
Hold **`S`** to access the Nudge & Glide Layer for micro-adjustments and smooth cursor travel:
- **Discrete Micro-Steps (1px):** Tap any directional key (`U, I, O, J, K, L, M, .` or physical arrow keys) to nudge the active tile and cursor by exactly 1 pixel.
- **Continuous 60 FPS Glide:** Holding any direction key for more than 180ms begins a smooth, continuous glide accelerating from 1 px/tick up to 10 px/tick (~500 px/s).
- **Zero-Drift Instant Stop:** Releasing the key stops motion immediately.
- **Coalesced Undo (`H`):** Reverting after a continuous glide restores the pre-nudge position in a single undo step.

### 📜 Auto-Scroll Enhancements & HUD Status
- **Dynamic Speed Controls:** Refined auto-scroll interval and speed controls (1x to 10x) with dedicated `Auto Up` (`I`) and `Auto Down` (`,`) keys.
- **Status Indicator:** Dedicated HUD badge shows live auto-scroll direction and active speed.
- **Stop Control:** Dedicated emergency stop (`K`) immediately halts auto-scrolling.

### 🖱️ Action Layer Refinements
- **Right Click Restoration:** Restored `Right Click` (`L`) on the Action Layer (`D`), alongside `Double Click` (`J`), `Middle Click` (`K`), `Start Drag` (`M`), and `Drop` (`,`).

---

## 🛠️ Architecture & Under the Hood

### 🏗️ Layered Modular Swift Architecture
Decomposed the monolithic codebase into focused, decoupled Bazel modules:
- **`DivvyClickCore`**: Fundamental domain models, KeyCodes, and configuration constants.
- **`DivvyClickEngine`**: State management, coordinate calculation, and undo/redo history.
- **`DivvyClickLayouts`**: Modular layout strategies and layout registry.
- **`DivvyClickCoordination`**: Event tap synchronization, gesture coordination, and hardware timers.
- **`DivvyClickUI`**: SwiftUI overlays, Heads-Up Display (HUD), reticles, and menu bar management.

### 🔒 Concurrency & Thread-Safety Hardening
- **Immutable Struct `KeyMap`:** Migrated `KeyMap` from a mutable MainActor singleton into an immutable, `Sendable` value type with dependency injection support.
- **Race Condition Elimination:** Removed error-prone lock caches in `HotkeyManager`; all hotkey and layout event handling is now strictly isolated and deterministically dispatched on the `MainActor`.
- **State Integrity:** Resolved edge cases where layer resets locked navigation or leaked drag/glide states.

### 🧪 Comprehensive Test Coverage
- Modularized Bazel test suites into individual test targets.
- Added comprehensive unit tests for `NavigationCoordinator`, `HotkeyManager`, `BinaryBifurcationLayout`, `KeyMap`, and `NavigationEngine`.

---

**Full Changelog**: https://github.com/Programming-Rivers/divvy-click/compare/v0.6.0...v0.7.0
