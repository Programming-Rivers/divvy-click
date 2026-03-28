import AppKit
import CoreGraphics
import Foundation

@MainActor
class HotkeyManager {
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var secureInputTimer: Timer?

    // Layer keys state tracking
    private var isAHeld = false
    private var isSHeld = false
    private var isDHeld = false
    private var isFHeld = false

    // Double-tap tracking
    private var lastCommandTapTime: ContinuousClock.Instant?
    private var wasCommandPressed = false

    // We maintain a thread-safe atomic-like check for engine status to avoid main-thread sync blocks in the tap callback.
    // While the engine is @MainActor, we use a simple unfair lock or similar for the 'isActive' flag used by the tap.
    private static let lock = NSLock()
    private static var _isActiveCached: Bool = false
    static var isActiveCached: Bool {
        get {
            lock.lock()
            defer { lock.unlock() }
            return _isActiveCached
        }
        set {
            lock.lock()
            defer { lock.unlock() }
            _isActiveCached = newValue
        }
    }

    let coordinator: NavigationCoordinator
    var engine: NavigationEngine { coordinator.engine }

    init(coordinator: NavigationCoordinator) {
        self.coordinator = coordinator
        setupEventTap()
        setupStateSync()
    }

    private func setupStateSync() {
        // Sync the cached state with the engine state
        Self.isActiveCached = engine.isActive
    }

    deinit {
        secureInputTimer?.invalidate()
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
            guard let refcon = refcon else { return Unmanaged.passUnretained(event) }
            let hotkeyManager = Unmanaged<HotkeyManager>.fromOpaque(refcon).takeUnretainedValue()
            
            // CRITICAL: We avoid DispatchQueue.main.sync here to prevent system-wide input lag.
            // We use a cached thread-safe flag for the basic 'isActive' check.
            return hotkeyManager.handleEvent(event, type: type)
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
        CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        
        secureInputTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.checkSecureInput()
            }
        }
    }

    private func checkSecureInput() {
        guard let tap = eventTap else { return }
        if !CGEvent.tapIsEnabled(tap: tap) {
            // Re-enable if possible, fails if secure input is active
            CGEvent.tapEnable(tap: tap, enable: true)
            if !CGEvent.tapIsEnabled(tap: tap) && engine.isActive {
                engine.stop()
            }
        }
    }

    private func handleEvent(_ event: CGEvent, type: CGEventType) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap = eventTap { CGEvent.tapEnable(tap: tap, enable: true) }
            return Unmanaged.passUnretained(event)
        }

        let keyCodeRaw = event.getIntegerValueField(.keyboardEventKeycode)
        let keyCode = KeyCode(rawValue: keyCodeRaw)
        let flags = event.flags

        // Double-tap Command needs some logic that should technically be on MainActor for engine toggling.
        // We'll perform the timing check here and only jump to MainActor if a toggle is actually triggered.
        let isToggleTriggered = checkDoubleTapCommand(type: type, flags: flags)

        if isToggleTriggered {
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                if self.engine.isActive { self.engine.stop() } else { self.engine.start() }
            }
            // We don't necessarily consume the toggle flags here, but if we wanted to prevent them leaking, we'd return nil.
            // For now, let the system handle the CMD press as usual.
        }

        // Use the thread-safe cached flag for routing decisions in the callback.
        if !Self.isActiveCached {
            return Unmanaged.passUnretained(event)
        }

        // For actual key processing, we dispatch to main actor asynchronously to avoid blocking.
        // If we need to CONSUME the event (returning nil), we must decide synchronously.
        // This is why keyboard-driven utilities often require the engine state to be accessible synchronously.
        
        if type == .keyUp {
            // Processing keyUp asynchronously
            DispatchQueue.main.async { [weak self] in
                _ = self?.handleKeyUp(keyCode)
            }
            // Most keys are swallowed when active
            if isSwallowedKey(keyCode) { return nil }
        }

        if type == .keyDown {
            lastCommandTapTime = nil // Any regular key breaks the command double-tap sequence
            
            // To decide whether to swallow the event, we check if it's a navigational key.
            if isSwallowedKey(keyCode) {
                DispatchQueue.main.async { [weak self] in
                    _ = self?.handleKeyDown(keyCode, flags: flags)
                }
                return nil
            }
        }

        return Unmanaged.passUnretained(event)
    }

    private func checkSwallowedKey(_ keyCode: KeyCode?) -> Bool {
        guard let keyCode = keyCode else { return false }
        switch keyCode {
        case .a, .s, .d, .f, .u, .i, .o, .h, .j, .k, .l, .m, .comma, .period, .space, .semicolon, .escape, .slash:
            return true
        default:
            return false
        }
    }

    private func isSwallowedKey(_ keyCode: KeyCode?) -> Bool {
        return checkSwallowedKey(keyCode)
    }

    private func checkDoubleTapCommand(type: CGEventType, flags: CGEventFlags) -> Bool {
        let isCommand = flags.contains(.maskCommand)
        if type == .flagsChanged {
            if isCommand && !wasCommandPressed {
                let now = ContinuousClock.now
                let triggered = if let tapTime = lastCommandTapTime, tapTime.duration(to: now) < .seconds(AppConstants.doubleTapThreshold) {
                    true
                } else {
                    false
                }
                
                if triggered {
                    lastCommandTapTime = nil
                    wasCommandPressed = isCommand
                    return true
                } else {
                    lastCommandTapTime = now
                }
            }
            wasCommandPressed = isCommand
        }
        return false
    }

    private func handleKeyUp(_ keyCode: KeyCode?) {
        guard let keyCode = keyCode else { return }

        switch keyCode {
        case .a: isAHeld = false
        case .s: isSHeld = false
        case .d: isDHeld = false
        case .f: isFHeld = false
        default: break
        }

        updateActiveLayer()
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

        return false
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
            engine.layerState.showHUD.toggle()
            return true
        }
        return false
    }

    private func handleLayerActions(_ keyCode: KeyCode, flags: CGEventFlags) -> Bool {
        if KeyMap.shared.execute(for: engine.layerState.activeLayer ?? .defaultNav, key: keyCode, coordinator: coordinator, flags: flags) {
            return true
        }
        if keyCode == .escape {
            engine.stop()
            return true
        }
        return false
    }

    private func updateActiveLayer() {
        if isDHeld { engine.layerState.activeLayer = .action }
        else if isFHeld { engine.layerState.activeLayer = .scroll }
        else if isSHeld { engine.layerState.activeLayer = .fastMove }
        else if isAHeld { engine.layerState.activeLayer = .management }
        else { engine.layerState.activeLayer = nil }
    }
}
