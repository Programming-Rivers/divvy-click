# Divvy-click

**Divvy-click** is a premium, keyboard-driven mouse emulation utility designed for power users who want to navigate their screen without ever lifting their hands from the home row.

By leveraging a **recursive 3x3 grid (Vennfurcation) algorithm**, Divvy-click allows you to "zero in" on any pixel on your display through a series of rapid, logarithmic screen subdivisions.

## 🚀 Activation

The overlay is designed to be completely transparent until needed.

- **Double-tap `⌘ Command`**: Instantly activate or deactivate the overlay.
- **Menu Bar Icon**: Toggle the utility status directly from the macOS menu bar.

## 🕹️ How It Works

Instead of dragging a cursor across physical space, Divvy-click treats your screen as a 3x3 grid, where tiles have some overlap with each other.

DivvyClick allows the user to repeatedly divide the screen into 9 tiles,
making the tiles smaller on each step.
This allows the user to zero in a very small area of the screen, down to a pixel,
very quickly only with a few keystrokes.
Adjacent tiles have some overlap to allow room for error.

1. **Bifurcate/Vennfurcate**: Use the keys in and around the home row to select one of the 9 tiles to dive into.
   - `Y` `U` `I` - Top Left / Top / Top Right
   - `H` `J` `K` - Left / Center / Right
   - `N` `M` `,` - Bottom Left / Bottom / Bottom Right
2. **Refine**: The active area shrinks by 2/3 with each keystroke.
3. **Execute**: Once positioned, use the **Action Layer** or **Universal Keys** to interact.

Each keystroke exponentially increases precision. A 4K screen can be navigated with pixel-perfect accuracy in just a few taps.

## ✨ Features & Layers

Divvy-click uses a sophisticated layering system to maximize productivity. **Hold a layer key** to change the function of the navigation keys.

### 🏠 Default Layer (Navigation)
- **`L`**: Undo last move
- **`Space`**: Left Click
- **`?` (Shift + `/`)**: Toggle the Heads-Up Display (HUD)
- **`;`**: Show Display Selection tiles

### ⚡ Action Layers (Hold key + Shortcut)
| Layer Key | Layer Name | `H` | `J` | `K` | `L` | `N` | `M` | `U` |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **`F`** | **Action** | Double | Click | Middle | Right | Drag Start | Drop | - |
| **`D`** | **Scroll** | ← Left | - | → Right | - | - | ↓ Down | ↑ Up |
| **`S`** | **Fast Move** | ← (2x) | ○ (2x) | → (2x) | Undo | ↙ (2x) | ↓ (2x) | ↑ (2x) |
| **`A`** | **Management**| Undo | Redo | Reset | Display | - | - | - |

- **HUD Integration**: A visual cue overlay (Heads-Up Display) appears automatically if you are idle or holding a layer key, guiding you through the available shortcuts.
- **Multi-Monitor Support**: Select active displays through a visual tile grid. If history is empty, `Undo` will jump to display selection.
- **Universal Binary**: Fully optimized for Intel and Apple Silicon Macs.

## 🛠 Installation

Divvy-click is built using **Bazel**. 

1. **Clone the repository**:
   ```bash
   git clone https://github.com/your-repo/divvy-click.git
   ```
2. **Build the application**:
   ```bash
   bazel build //Sources/DivvyClick:DivvyClick
   ```
3. **Run the app**:
   ```bash
   bazel run //Sources/DivvyClick:DivvyClick
   ```
> [!IMPORTANT]
> Divvy-click requires **Accessibility** and **Input Monitoring** permissions in System Settings to capture hotkeys and move the cursor.

## ⌨️ Configuration

Currently, configurations are hardcoded for consistent usage patterns.
Upcoming versions will introduce custom key mappings.

## 🤝 Contributing

Divvy-click is currently open for use, but closed for outside contributions while we establish governance and contribution guidelines. Stay tuned for updates!
