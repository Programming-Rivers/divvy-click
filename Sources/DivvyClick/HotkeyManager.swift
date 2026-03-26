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

        handleDoubleTapCommand(type: type, flags: flags)

        if !engine.isActive {
            resetLayerState()
            return Unmanaged.passUnretained(event)
        }

        if type == .keyUp {
            return handleKeyUp(keyCode, event: event)
        }

        if type == .keyDown {
            if handleKeyDown(keyCode, flags: flags) {
                return nil
            }
        }

        return Unmanaged.passUnretained(event)
    }

    private func handleDoubleTapCommand(type: CGEventType, flags: CGEventFlags) {
        let isCommand = flags.contains(.maskCommand)
        if type == .flagsChanged {
            if isCommand && !wasCommandPressed {
                let now = Date()
                if now.timeIntervalSince(lastCommandTapTime) < 0.3 {
                    if engine.isActive { engine.stop() } else { engine.start() }
                    lastCommandTapTime = .distantPast
                } else {
                    lastCommandTapTime = now
                }
            }
            wasCommandPressed = isCommand
        }
    }

    private func resetLayerState() {
        isAHeld = false
        isSHeld = false
        isDHeld = false
        isFHeld = false
    }

    private func handleKeyUp(_ keyCode: KeyCode?, event: CGEvent) -> Unmanaged<CGEvent>? {
        guard let keyCode = keyCode else { return Unmanaged.passUnretained(event) }

        switch keyCode {
        case .a: isAHeld = false
        case .s: isSHeld = false
        case .d: isDHeld = false
        case .f: isFHeld = false
        case .escape: return nil
        case .u, .i, .o, .h, .j, .k, .l, .m, .comma, .period, .space: return nil
        default: break
        }

        updateActiveLayer()
        return Unmanaged.passUnretained(event)
    }

    private func handleKeyDown(_ keyCode: KeyCode?, flags: CGEventFlags) -> Bool {
        guard let keyCode = keyCode else { return false }

        // Track Layers
        switch keyCode {
        case .a: isAHeld = true
        case .s: isSHeld = true
        case .d: isDHeld = true
        case .f: isFHeld = true
        default: break
        }
        updateActiveLayer()

        if handleDisplaySelection(keyCode) { return true }
        if handleUniversalKeys(keyCode, flags: flags) { return true }
        if handleLayerActions(keyCode, flags: flags) { return true }

        return true // Consume all keys during navigation
    }

    private func handleDisplaySelection(_ keyCode: KeyCode) -> Bool {
        guard engine.isSelectingDisplay else { return false }

        let indexMap: [KeyCode: Int] = [
            .u:0, .i:1, .o:2, // U, I, O
            .j:3, .k:4, .l:5, // J, K, L
            .m:6, .comma:7,   // M, ,
            .period:8         // .
        ]

        if let index = indexMap[keyCode] {
            engine.selectDisplay(at: index)
        }
        if keyCode == .escape { engine.stop() }
        return true
    }

    private func handleUniversalKeys(_ keyCode: KeyCode, flags: CGEventFlags) -> Bool {
        if keyCode == .space {
            coordinator.execute(.click, flags: flags)
            return true
        }
        if keyCode == .semicolon {
            engine.showDisplaySelection()
            return true
        }
        if keyCode == .slash && flags.contains(.maskShift) {
            engine.showHUD.toggle()
            return true
        }
        return false
    }

    private func handleLayerActions(_ keyCode: KeyCode, flags: CGEventFlags) -> Bool {
        if KeyMap.shared.execute(for: engine.activeLayer ?? .defaultNav, key: keyCode, coordinator: coordinator, flags: flags) {
            return true
        }
        if keyCode == .escape {
            engine.stop()
            return true
        }
        return false
    }

    private func updateActiveLayer() {
        if isDHeld { engine.activeLayer = .action }
        else if isFHeld { engine.activeLayer = .scroll }
        else if isSHeld { engine.activeLayer = .fastMove }
        else if isAHeld { engine.activeLayer = .management }
        else { engine.activeLayer = nil }
    }
}
