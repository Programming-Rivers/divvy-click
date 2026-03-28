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

Vennfurcation is a method of dividing a region into nine overlapping parts (a 3x3 grid) that retain a shared, overlapping "Venn" zone. This reduces "pixel hunting" and provides a higher tolerance for error during navigation.

### The Algorithm

Unlike a simple binary split (bifurcation), DivvyClick uses a **3x3 Trifurcation** grid with an overlap factor to ensure sub-regions share boundaries.

1. **Overlap Factor**: DivvyClick uses an overlap factor of `1.1`.
2. **Dimension Calculation**:
   - `thirdWidth = (OriginalWidth / 3.0) * OverlapFactor`
   - `thirdHeight = (OriginalHeight / 3.0) * OverlapFactor`
3. **Region Positioning**:
   - The original region is divided into a 3x3 grid.
   - For each horizontal and vertical dimension (Left/Center/Right and Top/Center/Bottom), the new region is anchored to the respective edge or centered within the parent.
   - Because the sub-region is 110% of a strict third, it overlaps with its neighbors by 10% of the dimension, creating the "eyepiece" feel where the target pixel remains centered in the overlap zone.

### Mathematical Benefit
The overlapping "Venn" zone means that if the user's intended target is near the border of a segment, it remains reachable via multiple overlapping grid tiles. This eliminates the "one-pixel error" problem common in standard grid-based navigation. Any final region calculation is automatically clamped to the physical screen bounds to prevent drift.

---

## Visual Design: The Sniper Eyepiece

The visual overlay is designed to look like a high-tech sniper optic:
- **Neon Cyan**: Used for high visibility against both light and dark backgrounds.
- **Segmented Arcs**: Provide a clear "aperture" feel without obstructing the center.
- **Gapped Crosshair**: The crosshairs do not meet in the middle, ensuring the exact target pixel is always visible.
- **Dynamic Feedback**: The eyepiece turns **Red** when a drag operation is active.
