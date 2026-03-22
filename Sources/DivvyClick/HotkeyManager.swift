import AppKit
import CoreGraphics
import Foundation

@MainActor
class HotkeyManager {
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    let engine: NavigationEngine

    // Layer keys state tracking
    private var isAHeld = false
    private var isSHeld = false
    private var isDHeld = false
    private var isFHeld = false

    init(engine: NavigationEngine) {
        self.engine = engine
        setupEventTap()
    }

    deinit {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
            if let runLoopSource = runLoopSource {
                CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
            }
        }
    }

    private func setupEventTap() {
        // We need to listen to both keyDown and keyUp for layer toggles, plus flagsChanged for meta keys
        let eventMask = (1 << CGEventType.keyDown.rawValue) | (1 << CGEventType.keyUp.rawValue) | (1 << CGEventType.flagsChanged.rawValue)

        let callback: CGEventTapCallBack = { _, type, event, refcon -> Unmanaged<CGEvent>? in
            let hotkeyManager = Unmanaged<HotkeyManager>.fromOpaque(refcon!).takeUnretainedValue()
            return MainActor.assumeIsolated {
                hotkeyManager.handleEvent(event, type: type)
            }
        }

        eventTap = CGEvent.tapCreate(
            tap: .cghidEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(eventMask),
            callback: callback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        )

        guard let tap = eventTap else {
            print("Failed to create event tap. Ensure app has Accessibility / Input Monitoring permissions.")
            return
        }

        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    private func handleEvent(_ event: CGEvent, type: CGEventType) -> Unmanaged<CGEvent>? {
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        let flags = event.flags
        let isCommand = flags.contains(.maskCommand)

        // Activation / Reset (Clear = 71)
        if type == .keyDown && keyCode == 71 {
            if isCommand {
                if engine.isActive { engine.stop() } else { engine.start() }
            } else {
                engine.reset()
            }
            return nil
        }

        // Behavior when Navigation is INACTIVE
        if !engine.isActive {
            // Reset layers just in case they were held while deactivating
            isAHeld = false
            isSHeld = false
            isDHeld = false
            isFHeld = false
            
            // Allow Undo/Redo to bring back interface
            if type == .keyDown {
                switch keyCode {
                case 78: // Numpad - (Undo)
                    if engine.undo() { return nil }
                case 69: // Numpad + (Redo)
                    engine.redo()
                    return nil
                default: break
                }
            }
            return Unmanaged.passRetained(event)
        }

        // --- Navigation ACTIVE ---
        
        // Track Layers (A=0, S=1, D=2, F=3)
        if type == .keyUp {
            switch keyCode {
            case 0: isAHeld = false
            case 1: isSHeld = false
            case 2: isDHeld = false
            case 3: isFHeld = false
            case 53: return nil // Esc keyUp
            case 16, 32, 34, 4, 38, 40, 45, 46, 43, 37, 49: return nil // Grid/Action keyUp
            default: break
            }
            updateActiveLayer()
            return Unmanaged.passRetained(event) // Pass other keyUps naturally
        }

        if type == .keyDown {
            // Layer key downs
            switch keyCode {
            case 0: isAHeld = true
            case 1: isSHeld = true
            case 2: isDHeld = true
            case 3: isFHeld = true
            default: break
            }
            updateActiveLayer()

            // Display Selection Overlay mode
            if engine.isSelectingDisplay {
                let indexMap: [Int64: Int] = [
                    16:0, 32:1, 34:2, // Y, U, I
                    4:3,  38:4, 40:5, // H, J, K
                    45:6, 46:7        // N, M
                ]
                if let index = indexMap[keyCode] {
                    engine.selectDisplay(at: index)
                }
                if keyCode == 53 { engine.stop() } // Esc
                return nil
            }

            // Action Layer: F (3) + HJKL
            if isFHeld {
                switch keyCode {
                case 4:  engine.execute(.doubleClick, flags: flags) // F + H = Double Click
                case 38: engine.execute(.click, flags: flags)       // F + J = Left Click
                case 40: engine.execute(.middleClick, flags: flags) // F + K = Middle Click
                case 37: engine.execute(.rightClick, flags: flags)  // F + L = Right Click
                default: break
                }
                return nil
            }
            
            // Scroll Layer: D (2) + U(32), M(46), H(4), K(40)
            if isDHeld {
                switch keyCode {
                case 32: engine.execute(.scroll(.up), flags: flags)    // U = Scroll Up
                case 46: engine.execute(.scroll(.down), flags: flags)  // M = Scroll Down
                case 4:  engine.execute(.scroll(.left), flags: flags)  // H = Scroll Left
                case 40: engine.execute(.scroll(.right), flags: flags) // K = Scroll Right
                default: break
                }
                return nil
            }
            
            // Management Layer: A (0) + HJKL
            if isAHeld {
                switch keyCode {
                case 4:  if !engine.undo() { engine.showDisplaySelection() } // A + H = Undo
                case 38: engine.redo()                 // A + J = Redo
                case 40: engine.reset()                // A + K = Reset
                case 37: engine.showDisplaySelection() // A + L = Select Display
                default: break
                }
                return nil
            }
            
            // Fast Movement Layer: S (1) + HJKL
            if isSHeld {
                // S layer: Jump to screen edges using H, J, K, L
                switch keyCode {
                case 4:  engine.vennfurcate(.left)    // S + H = Left Jump
                case 38: engine.vennfurcate(.down)    // S + J = Down Jump
                case 40: engine.vennfurcate(.right)   // S + K = Right Jump
                case 37: engine.vennfurcate(.up)      // S + L = Up Jump
                default: break
                }
                return nil
            }

            // Default Layer (Movement / Default Actions)
            switch keyCode {
            case 16: engine.vennfurcate(.topLeft)       // Y
            case 32: engine.vennfurcate(.up)            // U
            case 34: engine.vennfurcate(.topRight)      // I
            case 4:  engine.vennfurcate(.left)          // H
            case 38: engine.vennfurcate(.center)        // J
            case 40: engine.vennfurcate(.right)         // K
            case 45: engine.vennfurcate(.bottomLeft)    // N
            case 46: engine.vennfurcate(.down)          // M
            case 43: engine.vennfurcate(.bottomRight)   // ,
            case 37: engine.undo()                      // L = Undo
            case 41: engine.showDisplaySelection()      // : (Shift + ;) = Show Displays
            case 49: engine.execute(.click, flags: flags) // Space = Default Click
            case 53: engine.stop()                      // Esc
            case 78: if engine.undo() { return nil }    // Numpad - (Undo)
            case 69: engine.redo()                      // Numpad + (Redo)
            default: break
            }

            // Consume all keys during navigation sequence to prevent accidental typing
            return nil
        }

        return Unmanaged.passRetained(event)
    }

    private func updateActiveLayer() {
        if isFHeld { engine.activeLayer = .action }
        else if isDHeld { engine.activeLayer = .scroll }
        else if isSHeld { engine.activeLayer = .fastMove }
        else if isAHeld { engine.activeLayer = .management }
        else { engine.activeLayer = nil }
    }
}
