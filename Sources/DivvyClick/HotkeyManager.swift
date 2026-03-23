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

    // Double-tap tracking
    private var lastCommandTapTime: Date = .distantPast
    private var wasCommandPressed = false

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

    private enum KeyCode: Int64 {
        case y = 16, u = 32, i = 34
        case h = 4,  j = 38, k = 40, l = 37
        case n = 45, m = 46, comma = 43
        case semicolon = 41, escape = 53, clear = 71
        case a = 0, s = 1, d = 2, f = 3
        case space = 49
        case numpadMinus = 78, numpadPlus = 69
    }

    private func handleEvent(_ event: CGEvent, type: CGEventType) -> Unmanaged<CGEvent>? {
        let keyCodeRaw = event.getIntegerValueField(.keyboardEventKeycode)
        let keyCode = KeyCode(rawValue: keyCodeRaw)
        let flags = event.flags
        let isCommand = flags.contains(.maskCommand)

        // Activation via Double-Tap Command
        if type == .flagsChanged {
            if isCommand && !wasCommandPressed {
                // Command was just pressed
                let now = Date()
                if now.timeIntervalSince(lastCommandTapTime) < 0.3 {
                    // Double tap detected!
                    if engine.isActive { engine.stop() } else { engine.start() }
                    lastCommandTapTime = .distantPast // Prevent triple-tap triggering twice
                } else {
                    lastCommandTapTime = now
                }
            }
            wasCommandPressed = isCommand
        }

        // Activation / Reset (Clear = 71) -> REMOVED Cmd+Clear, keeping Reset on Clear
        if type == .keyDown && keyCode == .clear {
            engine.reset()
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
                case .numpadMinus: // Numpad - (Undo)
                    if engine.undo() { return nil }
                case .numpadPlus: // Numpad + (Redo)
                    engine.redo()
                    return nil
                default: break
                }
            }
            return Unmanaged.passUnretained(event)
        }

        // --- Navigation ACTIVE ---
        
        // Track Layers (A=0, S=1, D=2, F=3)
        if type == .keyUp {
            switch keyCode {
            case .a: isAHeld = false
            case .s: isSHeld = false
            case .d: isDHeld = false
            case .f: isFHeld = false
            case .escape: return nil // Esc keyUp
            case .y, .u, .i, .h, .j, .k, .n, .m, .comma, .l, .space: return nil // Grid/Action keyUp
            default: break
            }
            updateActiveLayer()
            return Unmanaged.passUnretained(event) // Pass other keyUps naturally
        }

        if type == .keyDown {
            // Layer key downs
            switch keyCode {
            case .a: isAHeld = true
            case .s: isSHeld = true
            case .d: isDHeld = true
            case .f: isFHeld = true
            default: break
            }
            updateActiveLayer()

            // Display Selection Overlay mode
            if engine.isSelectingDisplay {
                let indexMap: [KeyCode: Int] = [
                    .y:0, .u:1, .i:2, // Y, U, I
                    .h:3, .j:4, .k:5, // H, J, K
                    .n:6, .m:7        // N, M
                ]
                if let code = keyCode, let index = indexMap[code] {
                    engine.selectDisplay(at: index)
                }
                if keyCode == .escape { engine.stop() } // Esc
                return nil
            }

            // Universal Space -> Click and ; -> Displays for all layers
            if keyCode == .space {
                engine.execute(.click, flags: flags)
                return nil
            }
            if keyCode == .semicolon {
                engine.showDisplaySelection()
                return nil
            }

            // Action Layer: F (3) + HJKL
            if isFHeld {
                switch keyCode {
                case .h: engine.execute(.doubleClick, flags: flags) // F + H = Double Click
                case .j: engine.execute(.click, flags: flags)       // F + J = Left Click
                case .k: engine.execute(.middleClick, flags: flags) // F + K = Middle Click
                case .l: engine.execute(.rightClick, flags: flags)  // F + L = Right Click
                case .n: engine.execute(.mouseDown, flags: flags)   // F + N = Start Drag
                case .m: engine.execute(.mouseUp, flags: flags)     // F + M = Drop
                default: break
                }
                return nil
            }
            
            // Scroll Layer: D (2) + U(32), M(46), H(4), K(40)
            if isDHeld {
                switch keyCode {
                case .u: engine.execute(.scroll(.up), flags: flags)    // U = Scroll Up
                case .m: engine.execute(.scroll(.down), flags: flags)  // M = Scroll Down
                case .h: engine.execute(.scroll(.left), flags: flags)  // H = Scroll Left
                case .k: engine.execute(.scroll(.right), flags: flags) // K = Scroll Right
                default: break
                }
                return nil
            }
            
            // Management Layer: A (0) + HJKL
            if isAHeld {
                switch keyCode {
                case .h: if !engine.undo() { engine.showDisplaySelection() } // A + H = Undo
                case .j: engine.redo()                 // A + J = Redo
                case .k: engine.reset()                // A + K = Reset
                case .l: engine.showDisplaySelection() // A + L = Select Display
                default: break
                }
                return nil
            }
            
            // Fast Movement Layer: S (1) + Home Row Zoom (Double Move)
            if isSHeld {
                switch keyCode {
                case .y: engine.vennfurcate(.topLeft);     engine.vennfurcate(.topLeft)     // Y
                case .u: engine.vennfurcate(.up);          engine.vennfurcate(.up)          // U
                case .i: engine.vennfurcate(.topRight);    engine.vennfurcate(.topRight)    // I
                case .h: engine.vennfurcate(.left);        engine.vennfurcate(.left)        // H
                case .j: engine.vennfurcate(.center);      engine.vennfurcate(.center)      // J
                case .k: engine.vennfurcate(.right);       engine.vennfurcate(.right)       // K
                case .n: engine.vennfurcate(.bottomLeft);  engine.vennfurcate(.bottomLeft)  // N
                case .m: engine.vennfurcate(.down);        engine.vennfurcate(.down)        // M
                case .comma: engine.vennfurcate(.bottomRight); engine.vennfurcate(.bottomRight) // ,
                case .l: engine.undo()                                                      // L
                default: break
                }
                return nil
            }

            // Default Layer (Movement / Default Actions)
            switch keyCode {
            case .y: engine.vennfurcate(.topLeft)       // Y
            case .u: engine.vennfurcate(.up)            // U
            case .i: engine.vennfurcate(.topRight)      // I
            case .h: engine.vennfurcate(.left)          // H
            case .j: engine.vennfurcate(.center)        // J
            case .k: engine.vennfurcate(.right)         // K
            case .n: engine.vennfurcate(.bottomLeft)    // N
            case .m: engine.vennfurcate(.down)          // M
            case .comma: engine.vennfurcate(.bottomRight)   // ,
            case .l: engine.undo()                      // L = Undo
            case .escape: engine.stop()                      // Esc
            case .numpadMinus: if engine.undo() { return nil }    // Numpad - (Undo)
            case .numpadPlus: engine.redo()                      // Numpad + (Redo)
            default: break
            }

            // Consume all keys during navigation sequence to prevent accidental typing
            return nil
        }

        return Unmanaged.passUnretained(event)
    }

    private func updateActiveLayer() {
        if isFHeld { engine.activeLayer = .action }
        else if isDHeld { engine.activeLayer = .scroll }
        else if isSHeld { engine.activeLayer = .fastMove }
        else if isAHeld { engine.activeLayer = .management }
        else { engine.activeLayer = nil }
    }
}
