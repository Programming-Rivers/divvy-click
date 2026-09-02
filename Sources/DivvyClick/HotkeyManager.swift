import AppKit
import Combine
import CoreGraphics
import Foundation

@MainActor
class HotkeyManager {
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var secureInputTimer: Timer?
    private var cancellables = Set<AnyCancellable>()

    // Layer keys state tracking
    private(set) var isAHeld = false
    private(set) var isSHeld = false
    private(set) var isDHeld = false
    private(set) var isFHeld = false

    // Double-tap tracking
    private(set) var lastCommandTapTime: ContinuousClock.Instant?
    private(set) var wasCommandPressed = false

    let coordinator: NavigationCoordinator
    var engine: NavigationEngine { coordinator.engine }

    init(coordinator: NavigationCoordinator) {
        self.coordinator = coordinator
        setupEventTap()
        setupStateSync()
    }

    private func setupStateSync() {
        engine.$isActive
            .sink { [weak self] active in
                if !active {
                    self?.resetHeldKeys()
                }
            }
            .store(in: &cancellables)
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

    /// Configures the low-level CGEventTap for keyboard input interception.
    ///
    /// ## Concurrency & Thread-Safety Invariant
    /// The event tap's run loop source is added directly to the Main Run Loop (`CFRunLoopGetMain()`) in `.commonModes`.
    /// In macOS CoreGraphics, attaching the tap's run loop source to the main run loop guarantees that
    /// the `CGEventTapCallBack` is invoked synchronously on the **Main Thread** during the main run loop's event cycle.
    ///
    /// Because callback execution is serialized on the Main Actor, all event processing, layer state tracking,
    /// and engine start/stop operations are executed synchronously without background thread synchronization
    /// or asynchronous dispatch hops. This eliminates TOCTOU race conditions between key interception/swallowing
    /// and navigation action execution.
    private func setupEventTap() {
        // Listen to keyDown, keyUp for layer toggles and navigational keys, plus flagsChanged for modifier double-taps.
        let eventMask = (1 << CGEventType.keyDown.rawValue) | (1 << CGEventType.keyUp.rawValue) | (1 << CGEventType.flagsChanged.rawValue)

        let callback: CGEventTapCallBack = { _, type, event, refcon -> Unmanaged<CGEvent>? in
            guard let refcon = refcon else { return Unmanaged.passUnretained(event) }
            let hotkeyManager = Unmanaged<HotkeyManager>.fromOpaque(refcon).takeUnretainedValue()
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

    /// Handles intercepted CGEvents synchronously on the MainActor.
    ///
    /// - Parameters:
    ///   - event: The intercepted `CGEvent`.
    ///   - type: The event type (e.g. `.keyDown`, `.keyUp`, `.flagsChanged`).
    /// - Returns: `Unmanaged.passUnretained(event)` to pass through, or `nil` to swallow/consume the event.
    func handleEvent(_ event: CGEvent, type: CGEventType) -> Unmanaged<CGEvent>? {
        MainActor.preconditionIsolated("HotkeyManager event processing must execute on the MainActor.")

        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap = eventTap { CGEvent.tapEnable(tap: tap, enable: true) }
            return Unmanaged.passUnretained(event)
        }

        let keyCodeRaw = event.getIntegerValueField(.keyboardEventKeycode)
        let keyCode = KeyCode(rawValue: keyCodeRaw)
        let flags = event.flags

        // Double-tap Command toggle check executed synchronously on MainActor
        let isToggleTriggered = checkDoubleTapCommand(type: type, flags: flags)

        if isToggleTriggered {
            if engine.isActive {
                engine.stop()
            } else {
                engine.start()
            }
        }

        if type == .keyDown {
            lastCommandTapTime = nil // Any regular key breaks the command double-tap sequence
        }

        // If navigation engine is inactive, pass through all events without swallowing.
        guard engine.isActive else {
            return Unmanaged.passUnretained(event)
        }

        // Synchronous key processing prevents TOCTOU windows between key-swallowing and handler execution
        if type == .keyUp {
            handleKeyUp(keyCode)
            if isSwallowedKey(keyCode) { return nil }
        }

        if type == .keyDown {
            if isSwallowedKey(keyCode) {
                _ = handleKeyDown(keyCode, flags: flags)
                return nil
            }
        }

        return Unmanaged.passUnretained(event)
    }

    func isSwallowedKey(_ keyCode: KeyCode?) -> Bool {
        guard let keyCode = keyCode else { return false }
        switch keyCode {
        case .a, .s, .d, .f, .u, .i, .o, .h, .j, .k, .l, .m, .comma, .period, .space, .semicolon, .escape, .slash:
            return true
        default:
            return false
        }
    }

    func checkDoubleTapCommand(type: CGEventType, flags: CGEventFlags) -> Bool {
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

    func handleKeyUp(_ keyCode: KeyCode?) {
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

    @discardableResult
    func handleKeyDown(_ keyCode: KeyCode?, flags: CGEventFlags) -> Bool {
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

    private func resetHeldKeys() {
        isAHeld = false
        isSHeld = false
        isDHeld = false
        isFHeld = false
        updateActiveLayer()
    }

    private func updateActiveLayer() {
        if isDHeld { engine.layerState.activeLayer = .action }
        else if isFHeld { engine.layerState.activeLayer = .scroll }
        else if isSHeld { engine.layerState.activeLayer = .fastMove }
        else if isAHeld { engine.layerState.activeLayer = .management }
        else { engine.layerState.activeLayer = nil }
    }
}
