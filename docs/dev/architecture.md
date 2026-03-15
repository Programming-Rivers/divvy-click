# DivvyClick Architecture

DivvyClick is a macOS utility designed for fast and precise mouse navigation using keyboard-driven regional division. This document outlines the core architecture and the mathematical principles behind its "Vennfurcation" navigation system.

## Core Components

### 1. NavigationEngine
The central state manager (ObservableObject) that orchestrates the navigation flow.
- **State**: Tracks `currentRegion` (the active target area), `isActive` status, and `isMouseDown` state.
- **Vennfurcation**: Implements the recursive logic for dividing the screen area.
- **Actions**: Coordinates cursor relocation via `CursorEngine` and triggers simulated mouse events.

### 2. HotkeyManager
Handles system-wide keyboard events using an Event Tap (`CGEventTap`).
- Intercepts directional keys (Arrows, JKL, Numpad) when navigation is active.
- Maps specific keys to `NavigationEngine` commands (vennfurcate, click, move, drag).

### 3. CursorEngine
The low-level interface for simulating macOS mouse events.
- Uses `CGEvent` and `CGWarpMouseCursorPosition` to bypass native cursor acceleration for consistent "jumping".
- Handles complex interactions like dragging by managing separate `mouseDown` and `mouseUp` events.

### 4. OverlayWindowController & GridOverlayView
The visual feedback system.
- **OverlayWindowController**: Manages a transparent, non-activating `NSPanel` at the `.floating` level.
- **GridOverlayView**: A SwiftUI view that renders a blurred "fieldstop" (the background) and a clear "eyepiece" (the target). It utilizes a custom `InvertedRectangle` shape to mask the blur effect to the current target region.

## The Vennfurcation Process

Vennfurcation is a method of dividing a region into multiple parts that retain a shared, overlapping zone, similar how a Venn diagram shows overlapping parts. This reduces "pixel hunting" and provides a higher tolerance for error during navigation.

### The Algorithm

Unlike a binary split (bifurcation), Vennfurcation uses an **Expansion Factor** to ensure the two halves overlap.

1. **Overlap Constant**: DivvyClick uses a constant overlap factor (typically `0.33` or 1/3).
2. **Expansion Factor**: Calculated as `(1.0 + Overlap) / 2.0`.
   - With 1/3 overlap, the factor is approximately `0.666`.
3. **Region Contraction**:
   - **Left/Up Split**: The new dimension becomes `OriginalSize * ExpansionFactor`. The origin remains the same.
   - **Right/Down Split**: The new dimension becomes `OriginalSize * ExpansionFactor`. The origin is shifted to ensure the new region aligns with the opposite edge.

### Diagonal Vennfurcation (Corners)
When a corner direction (e.g., Top-Left) is triggered, the engine applies the horizontal and vertical contraction independently in a single step. This allows for rapid diagonal narrowing.

### Mathematical Benefit
The overlapping "Venn" zone means that if the user's intended target is near the border of a split, it remains present in both potential sub-regions. This eliminates the "one-pixel error" problem common in standard binary search navigation.

---

## Visual Design: The Sniper Eyepiece

The visual overlay is designed to look like a high-tech sniper optic:
- **Neon Cyan**: Used for high visibility against both light and dark backgrounds.
- **Segmented Arcs**: Provide a clear "aperture" feel without obstructing the center.
- **Gapped Crosshair**: The crosshairs do not meet in the middle, ensuring the exact target pixel is always visible.
- **Dynamic Feedback**: The eyepiece turns **Red** when a drag operation is active.
