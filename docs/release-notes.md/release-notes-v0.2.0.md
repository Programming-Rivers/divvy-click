# Release Notes: DivvyClick v0.2.0

We are thrilled to announce **DivvyClick v0.2.0**! 🚀

This release focuses on **ergonomics**, **real-time responsiveness**, and **multi-monitor fluidity**, moving away from shortcuts on the Numpad keys toward a  home-row-centered layout.

## ✨ Highlights

### ⌨️ Ergonomic Home-Row Layout (K-Centered)
The entire shortcut system has been migrated from the Numpad to the home row, centered around your dominant index finger (**K**).
- **Navigation Grid:** `U-I-O` (Top), `J-K-L` (Middle), `M-,-.` (Bottom).
- **Universal Undo:** **H** is now the dedicated, universal "Undo" key across all navigation and action layers.
- **Layering System:** Ergonomic layer toggles using your left hand (**A, S, D, F**).

### 🖱️ Active Mouse Sync & Targeting
- **Real-Time Following:** The physical macOS cursor now follows the eyepiece/crosshair in real-time as you navigate. No more "pre-jump" lag before clicking.
- **Initial Location Recovery:** DivvyClick now remembers where your mouse started. Use **Undo** at the top level to jump back to your original starting point.
- **Improved Targeting:** Fixed scroll targeting to ensure events are always sent to the exact UI element under the crosshair.

### 📜 Advanced Scroll Layer (F)
The Scroll Layer has been completely redesigned into a dedicated "Reading Mode."
- **Incremental Auto-Scroll:** Press **I** (Auto Up) or **comma** (Auto Down) to start continuous scrolling. Press repeatedly to increase speed (up to 10x).
- **Stop Control:** **K** acts as a dedicated "Emergency Stop" for auto-scrolling.
- **Discrete Movement:** **U** and **M** remain for precise, discrete vertical scrolls.

### 🖥️ Physical Multi-Monitor Mapping
Selecting displays is now intuitive. Displays are automatically mapped to the **UIO/JKL/M,.** grid based on their **physical arrangement** in your macOS Display Settings. If your monitor is on the left, it's on the left of the grid.

### 🎨 HUD & Visual Refinements
- **Glassmorphic HUD:** A Heads-Up Display that appears automatically when holding layer keys.
- **Auto-Scroll Indicator:** A new dynamic visual status bar showing active scroll direction and speed level.
- **Unicode UI:** Cleaner directional cues using modern typography and symbols.

## 🛠️ Performance & Reliability
- **Memory Fixes:** Resolved a critical memory leak in the hotkey event tap.
- **Architecture:** Major refactoring for testability, including a new `ScreenProviding` abstraction and a comprehensive unit test suite.
- **Stability:** Migrated to `Task.sleep` for actor-safe concurrency and UI smoothness.
- **Bazel Optimizations:** Streamlined build targets and improved Apple Developer Certificate signing support.

---

### 🕹️ Updated Layer Quick-Reference
| Layer Key | Function | Key Shortcuts |
| :--- | :--- | :--- |
| **D** | **Action** | J: Double / K: Middle / L: Left Click / M: Drag / ,: Drop |
| **F** | **Scroll** | I: Auto Up / ,: Auto Down / K: STOP / U: Up / M: Down |
| **S** | **Fast Move** | 2x Zoom/Subdivision across the 3x3 grid |
| **A** | **Management**| H: Undo / J: Redo / K: Reset / L: Display Grid |

---
*DivvyClick v0.2.0 is a massive leap forward in making the keyboard the ultimate mouse. We can't wait to see how it changes your workflow!*

**Full Changelog**: https://github.com/Programming-Rivers/divvy-click/compare/v0.1.0...v0.2.0
