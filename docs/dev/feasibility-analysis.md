# Technical Feasibility Study: Divvy-click for macOS 26+

This document evaluates the technical feasibility of implementing **Divvy-click**, a keyboard-driven cursor navigation tool, as a personal project targeting **macOS 26 (Tahoe)** and later. 

### Project Scope & Target
- **Target OS**: macOS 26.0+ (Tahoe)
- **Deployment**: Personal Tool (Unsigned/Local-only)
- **Primary Goal**: High-precision, low-latency cursor control via binary search or quad-tree keyboard navigation.

---

### 1. Recommended Tech Stack

The following stack leverages the latest macOS 26 technologies to ensure a "native-first" feel with minimal development overhead:

- **SwiftUI**: Used for the primary UI overlay. macOS 26's improved window management and material APIs make SwiftUI the superior choice over AppKit for non-interactive, always-on-top overlays.
- **Core Graphics / Quartz**: The foundation for hardware-level cursor relocation and synthetic event posting.
- **Quartz Event Taps**: Low-level C-based APIs used to intercept and suppress global keyboard events (HJKL/Arrows) before they reach active applications.
- **Liquid Glass Materials**: Using `glassEffect` and related material modifiers to create a premium, translucent grid that matches the system aesthetic.
- **Swift 6 Concurrency**: Ensuring thread-safe event handling and UI updates.

---

### 2. Cursor Control & Screen Mapping

Relocating the cursor and simulating clicks are well-supported via the Core Graphics framework.

- **Movement**: `CGWarpMouseCursorPosition` allows for instantaneous jumps without triggering standard mouse-delta events, which is critical for discrete navigation.
- **Events**: `CGEvent` is used to post `.leftMouseDown` and `.leftMouseUp` events directly to the window server.
- **Coordinate Space**: macOS 26 maintains a consistent points-based coordinate system. Scaling for Retina and high-refresh-rate displays is handled natively by the OS, provided coordinates are calculated relative to the primary display's bottom-left origin.

### 3. Global Input Monitoring & Suppression

The core mechanic requires intercepting keys that would normally be handled by the foreground app.

- **Quartz Event Taps**: This is the only reliable method to suppress keystrokes. By creating an event tap at `.cghidEventTap`, we can "consume" specific keys during navigation mode.
- **Permissions**: The application requires **Accessibility** and **Input Monitoring** permissions. For a personal project, these are granted manually in System Settings, bypassing the need for complex sandbox-compliant alternatives.
- **Limitation (Secure Input)**: Per system security policy, event taps are disabled when a Secure Input field (e.g., a password box) is focused. The app will detect this via `CGEventTapIsEnabled` and provide visual feedback to the user.

### 4. UI Overlay & Aesthetics

The navigation grid is implemented as a borderless, non-interactive SwiftUI window.

- **Window Configuration**:
    - **Style**: `.plain` (borderless).
    - **Level**: `.floating` or `.status` (ensuring it stays above other app windows).
    - **Interaction**: `ignoresMouseEvents(true)` to ensure clicks pass through to the underlying UI.
    - **Focus**: `canBecomeKey(false)` to prevent the overlay from stealing keyboard focus from the target application.
- **Visuals**: Applying **Liquid Glass** material effects ensures the grid lines feel integrated into the OS workspace, adapting to light/dark modes and wallpaper colors dynamically.

---

### 5. Proof of Concept: Navigation Logic

The following snippet demonstrates the modern integration of cursor control within a Swift 6 environment.

```swift
import SwiftUI
import CoreGraphics

/// Manages synthetic mouse interactions
struct CursorEngine {
    /// Jumps the cursor to the center of a target region
    @discardableResult
    func jump(to rect: CGRect) -> Bool {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        
        // Convert AppKit (bottom-left) coordinates to CG (top-left)
        guard let screen = NSScreen.main else { return false }
        let cgLocation = CGPoint(x: center.x, y: screen.frame.height - center.y)
        
        CGWarpMouseCursorPosition(cgLocation)
        return true
    }
    
    /// Simulates a mouse click at the current location
    func click(button: CGMouseButton = .left, count: Int = 1) {
        let mouseLoc = NSEvent.mouseLocation
        guard let screen = NSScreen.main else { return }
        let cgLoc = CGPoint(x: mouseLoc.x, y: screen.frame.height - mouseLoc.y)
        
        let source = CGEventSource(stateID: .hidSystemState)
        
        let downType: CGEventType = (button == .left) ? .leftMouseDown : .rightMouseDown
        let upType: CGEventType = (button == .left) ? .leftMouseUp : .rightMouseUp
        
        let downEvent = CGEvent(mouseEventSource: source, mouseType: downType, mouseCursorPosition: cgLoc, mouseButton: button)
        let upEvent = CGEvent(mouseEventSource: source, mouseType: upType, mouseCursorPosition: cgLoc, mouseButton: button)
        
        if count > 1 {
            downEvent?.setIntegerValueField(.mouseEventClickState, value: Int64(count))
            upEvent?.setIntegerValueField(.mouseEventClickState, value: Int64(count))
        }
        
        downEvent?.post(tap: .cghidEventTap)
        upEvent?.post(tap: .cghidEventTap)
    }
}

/// The visual grid overlay
struct GridOverlayView: View {
    let region: CGRect
    
    var body: some View {
        Zview {
            // High-fidelity background material
            Rectangle()
                .fill(.clear)
                .glassEffect() 
            
            // Dynamic Grid lines
            Canvas { context, size in
                context.stroke(
                    Path { path in
                        // Drawing logic for recursive grid...
                    },
                    with: .color(.accentColor.opacity(0.8)),
                    lineWidth: 1.5
                )
            }
        }
        .ignoresSafeArea()
    }
}
```

---

### 6. Conclusion & Feasibility Verdict

**Verdict: Highly Feasible.**

Targeting macOS 26+ for personal use significantly simplifies the implementation. The combination of **SwiftUI** for high-end visuals and **Quartz Event Taps** for low-level control provides all the necessary primitives. The primary development effort will reside in the recursive logic for region subdivision and the management of the event tap lifecycle.
al boundaries.