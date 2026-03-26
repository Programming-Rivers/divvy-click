# Divvy-click

**Divvy-click** is a premium, keyboard-driven mouse emulation utility designed for power users who want to navigate their screen without ever lifting their hands from the home row.

By leveraging a **recursive 3x3 grid (Vennfurcation) algorithm**, Divvy-click allows you to "zero in" on any pixel on your display through a series of rapid, logarithmic screen subdivisions.

## 🚀 Activation

The overlay is designed to be completely transparent until needed.

- **Double-tap `⌘ Command`**: Instantly activate or deactivate the overlay.
- **`Escape`**: Exit the overlay without performing an action (Cursor remains at the last target).
- **Menu Bar Icon**: Toggle the utility status directly from the macOS menu bar.

## 🕹️ How It Works

Instead of dragging a cursor across physical space, Divvy-click treats your screen as a 3x3 grid. By repeatedly dividing the screen into 9 smaller tiles, you can reach any pixel in just a few keystrokes.

1. **Vennfurcate**: Use the 3x3 grid keys (centered on **K**) to select one of the 9 tiles to dive into.
   - `U` `I` `O` - Top Left / Top / Top Right
   - `J` `K` `L` - Left / **Center** / Right
   - `M` `,` `.` - Bottom Left / Bottom / Bottom Right
2. **Refine**: The active area shrinks by 2/3 with each keystroke. Precision increases exponentially.
3. **Active Mouse Sync**: The physical mouse cursor follows the eyepiece in real-time as you navigate.
4. **Execute**: Once positioned, use the **Action Layer** or **Scroll Layer** to interact.

## ✨ Features & Layers

Divvy-click uses a sophisticated layering system. **Hold a layer key** (Home row fingers: **A, S, D, F**) to change the grid function.

### 🏠 Global & HUD Keys
- **`H`**: Universal Undo (Available in all layers)
- **`Space`**: Primary Left Click
- **`?`**: Show physical display selection grid

### ⚡ Action & Scroll Layers (Hold key + Shortcut)

| Layer Key | Layer Name | `U` | `I` | `O` | `J` | `K` | `L` | `M` | `,` | `.` |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **`D`** | **Action** | - | - | - | Double | Middle | **Left Click** | Drag | Drop | - |
| **`F`** | **Scroll** | **Scroll Up** | **Auto Up** | - | Left | **STOP** | Right | **Scroll Down** | **Auto Down**| - |
| **`S`** | **Fast Move** | ↖ (2x) | ↑ (2x) | ↗ (2x) | ← (2x) | ○ (2x) | → (2x) | ↙ (2x) | ↓ (2x) | ↘ (2x) |
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
