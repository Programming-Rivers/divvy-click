import AppKit
import CoreGraphics
import Foundation

@MainActor
class HotkeyManager {
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    // Layer keys state tracking
    private var isAHeld = false
    private var isSHeld = false
    private var isDHeld = false
    private var isFHeld = false

    // Double-tap tracking
    private var lastCommandTapTime: Date = .distantPast
    private var wasCommandPressed = false

    let coordinator: NavigationCoordinator
    var engine: NavigationEngine { coordinator.engine }

    init(coordinator: NavigationCoordinator) {
        self.coordinator = coordinator
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

        // Behavior when Navigation is INACTIVE
        if !engine.isActive {
            // Reset layers just in case they were held while deactivating
            isAHeld = false
            isSHeld = false
            isDHeld = false
            isFHeld = false
            
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
                coordinator.execute(.click, flags: flags)
                return nil
            }
            if keyCode == .semicolon {
                engine.showDisplaySelection()
                return nil
            }

            // Action, Scroll, Management, Fast Movement, and Default Layers
            if let code = keyCode {
                if KeyMap.shared.execute(for: engine.activeLayer ?? .defaultNav, key: code, coordinator: coordinator, flags: flags) {
                    return nil
                }
                
                // Special cases like Esc or keys that don't have actions in KeyMap but should stop/undo
                if code == .escape { engine.stop(); return nil }
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
