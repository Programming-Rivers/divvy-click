# Release Notes: DivvyClick v0.1.0

We are excited to announce the first release of **DivvyClick (v0.1.0)**! 🚀

DivvyClick is a keyboard-driven mouse emulation utility designed to help you navigate your screen with precision and speed, without leaving your keyboard.

## ✨ Highlights

### 🕹️ Logarithmic Navigation (The "Divvy" Logic)
The core of DivvyClick is a **recursive binary search algorithm**. Use your Numpad to divide your screen space in half repeatedly until you've precision-targeted your destination.
- **Numpad Keys:** Use directional input to drill down into the active area.
- **Vennfurcation:** Implemented a unique 1/3 overlap logic for smoother transitions between areas.

### 🖱️ Full Mouse Emulation
Once you've "divvied" down to the target, execute any mouse action:
- **Click:** Standard click on navigation completion.
- **Right-Click & Middle-Click:** Dedicated keys for secondary actions (including Numpad 5 for middle-click).
- **Double-Click:** Quick execution with Numpad 0.
- **Drag-and-Drop:** Persistent state support allows you to pick up an item and drop it at a new "divvied" location seamlessly.

### ⌨️ Keyboard-First Power
- **Global Hotkey:** Toggle the overlay instantly with `Cmd + NumLock`.
- **Numpad Optimized:** Primary controls are mapped to the Numpad for one-handed operation.
- **Modifier Support:** Modifiers are respected when executing clicks, allowing for `Shift + Click` or `Cmd + Click` workflows.
- **Scrolling:** Vertical and horizontal scrolling directly via Numpad (8/9 for up/down, 4/6 for left/right).

### 🖥️ Display & History Management
- **Multi-Monitor Support:** Select specific displays to start your navigation.
- **Navigation History:** Full undo/redo support to jump back to previous area divisions if you over-refined.
- **Automatic Display Fallback:** If you undo past the first step, the app intelligently shows display selection again.

### 🎨 Visual & Performance Polish
- **Blur Overlay:** A sleek "invert" visual style that blurs the screen outside your active target area, keeping your focus sharp.
- **Eyepiece HUD:** Enhanced targeting reticle for pixel-perfect precision.
- **Fast Animations:** Optimized transitions to keep the interface feeling responsive and "snappy."
- **Status Menu:** A dedicated menu bar icon to track app state.

## 🛠️ Under the Hood
- **Universal Binary:** Optimized for both Apple Silicon and Intel Macs.
- **Bazel Build System:** Robust and reproducible builds.
- **Safety First:** Core UI logic is pinned to the `MainActor` for macOS stability.

---
*DivvyClick is currently in early release. We'd love to hear your feedback as we refine the "Keyboard vs Mouse" experience!*

**Full Changelog**: https://github.com/Programming-Rivers/divvy-click/commits/v0.1.0
