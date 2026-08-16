# Divvy-click

**Control your mouse without lifting your fingers from the keyboard.**

**Divvy-click** is a keyboard-driven mouse emulation utility for power users who want to navigate their screen without ever lifting their hands from the keyboard.

Divvy-click allows you to "zero in" on any pixel on your display through a series of rapid, screen subdivisions.
Divvy-click repeatedly tiles the entire screen with a semi-transparent overlay
and allows the user to select a tile using single key keyboard shortcuts to move the mouse pointer to the center of the selected tile.

Once the pointer reaches the desired location, the user can use the action keys to perform actions such as clicking, dragging, or scrolling.

## 🚀 Activation

The overlay is transparent until activated.
Activation is done by double-tapping `⌘ Command`.

- **Double-tap `⌘ Command`**: Activates or deactivates the overlay.
- **`Escape`**: Deactivates the overlay without performing an action (Cursor remains at the last target).
- **Menu Bar Icon**: Toggle the utility status directly from the macOS menu bar.

## 🕹️ How It Works

Instead of dragging a cursor across physical space, Divvy-click repeatedly subdivides the active region of your display into smaller tiles (Top/Bottom and Left/Right).
By repeatedly narrowing down the active region using home-row navigation keys, you can reach any pixel in just a few keystrokes.

1. **Vennfurcate**: Use the primary navigation keys to select an overlapping tile:
   - `I`: **Top** tile
   - `K`: **Bottom** tile
   - `J`: **Left** tile
   - `L`: **Right** tile
2. **Refine**: The active region shrinks by ~50% in height or width with each keystroke. Precision increases exponentially.
3. **Active Mouse Sync**: The physical mouse cursor follows the eyepiece in real-time as you navigate.
4. **Execute**: Once positioned, use the **Action Layer** or **Scroll Layer** to interact.

## ✨ Features & Layers

Divvy-click uses a sophisticated layering system. **Hold a layer key** (Home row fingers: **A, S, D, F**) to change the grid function.

### 🏠 Global & HUD Keys
- **`H`**: Universal Undo (Available in all layers)
- **`Space`**: Primary Left Click
- **`;`**: Show physical display selection grid
- **`?` (Shift + `/`)**: Toggle the Heads-Up Display (HUD) manually

### ⚡ Action & Scroll Layers (Hold key + Shortcut)

| Layer Key | Layer Name | `U` | `I` | `O` | `J` | `K` | `L` | `M` | `,` | `.` |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **`D`** | **Action** | - | - | - | Double | Middle | **Left Click** | Drag | Drop | - |
| **`F`** | **Scroll** | **Scroll Up** | **Auto Up** | - | Left | **STOP** | Right | **Scroll Down** | **Auto Down**| - |
| **`S`** | **Fast Move** | - | ↑ (2x) | - | ← (2x) | ↓ (2x) | → (2x) | - | - | - |
| **`A`** | **Management**| - | - | - | Redo | Reset | Displays | - | - | - |

- **Auto-Scroll (Incremental)**: Pressing **I** (Auto Up) or **,** (Auto Down) repeatedly increases the scrolling speed (1x to 10x). Press **K** to stop.
- **Physical Screen Mapping**: Displays are automatically mapped to the 3x3 grid (**UIO/JKL/M,.**) based on their physical arrangement in macOS settings.
- **HUD Integration**: A glassmorphic Heads-Up Display appears automatically if you are holding a layer key, guiding you through the available shortcuts.

## 🛠 Installation

Divvy-click is built using **Bazel**. 

1. **Clone the repository**:
   ```bash
   git clone https://github.com/your-repo/divvy-click.git
   ```
2. **Build & Run**:
   ```bash
   bazel run //Sources/DivvyClick
   ```

> [!IMPORTANT]
> Divvy-click requires **Accessibility** and **Input Monitoring** permissions in System Settings to capture hotkeys and move the cursor.

# Building a Universal Binary

```bash
bazel build //Sources/DivvyClick --config=universal
```

The resulting binary will be located at
* `bazel-bin/DivvyClick_archive-root/DivvyClick.app`.

## ⌨️ Configuration

Currently, configurations are hardcoded for consistent ergonomic usage.
Upcoming versions will introduce custom key mappings via a config file.

## 🤝 Contributing

Divvy-click is currently open for use, but closed for outside contributions while we establish governance and contribution guidelines. Stay tuned for updates!
