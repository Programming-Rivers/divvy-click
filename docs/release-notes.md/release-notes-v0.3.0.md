# Release Notes: DivvyClick v0.3.0

We are thrilled to announce **DivvyClick v0.3.0**! 🚀

This release focuses on **robustness**, **drag-and-drop improvements**, and **installation efficiency**. We've revamped our distribution workflow, overhauled the core architecture for stability, and resolved several critical edge-case bugs.

## ✨ Highlights

### 📦 Seamless Standardized Installation
- **DMG Distribution:** DivvyClick is now officially distributed as a `.dmg`.

### 🖱️ Cursor Flow & Targeting Polish
- **Real-Time Drag & Drop:** When operating in drag-and-drop mode, the physical cursor now properly follows the target frame throughout the entire movement, rather than teleporting instantly at the final moment of the drop operation.
- **Root-Level Undo:** Fixed an edge case so that utilizing the **Undo** hotkey explicitly restores you all the way back to your initial anchor when the undo history stack.

### 🖥️ Native Display Adaptability
- **Smarter Display Allocation:** mproving the logic behind assigning macOS external displays to navigation grid.
- **Dynamic Configuration Handling:** Auto-stops active navigations gracefully if it detects the system's display configuration change (plugging/unplugging monitors). 

### 🔐 Security Integrations
- **Secure Input Protection:** DivvyClick now automatically steps aside and fully deactivates if macOS fires a "Secure Input" event notification (for example, when you focus a Password text-field).

### 🎨 Visual Polish
- **Menu Bar Refinements:** Cleaned up the status menu by getting rid of old or non-applicable shortcut indicators.

## 🛠️ Performance & Reliability
- **Smooth Event Tapping:** Eliminated synchronous main-thread blocking inside the Core Graphics hotkey event tap. macOS system keystrokes will never bottleneck when passing through DivvyClick logic.
- **Reliable Click Emulation:** Replaced inaccurate `Task.sleep` timing logic globally with rigorous, deterministic scheduling for click pacing.
- **Concurrent Click Safeties:** Implemented hard task cancellation overrides for trailing `NavigationCoordinator` bounds checks.
- **Double-Tap Stability:** Stabilized Command ⌘ key double-tap detections under high load systems.
- **Boundary Clamping:** System calculations for grid scaling are now strictly and cleanly clamped to their physical screen geometry, preventing out-of-bounds clipping.
- **Internal Architecture:** Centralized project "magic numbers" and configuration constants, laying out perfectly isolated abstractions.

---

**Full Changelog**: https://github.com/Programming-Rivers/divvy-click/compare/v0.2.0...v0.3.0