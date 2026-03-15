import AppKit
import CoreGraphics
import Foundation

@MainActor
class HotkeyManager {
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    let engine: NavigationEngine

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
        // We need to listen to keyDown to catch the activation hotkey and navigation keys
        let eventMask = (1 << CGEventType.keyDown.rawValue)

        let callback: CGEventTapCallBack = { _, _, event, refcon -> Unmanaged<CGEvent>? in
            let hotkeyManager = Unmanaged<HotkeyManager>.fromOpaque(refcon!).takeUnretainedValue()
            return MainActor.assumeIsolated {
                hotkeyManager.handleEvent(event)
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



    private func handleEvent(_ event: CGEvent) -> Unmanaged<CGEvent>? {
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        let flags = event.flags

        // Activation Hotkey: Ctrl + Shift + Space
        // Space keycode: 49, Flags check: Control (0x40000) and Shift (0x20000)
        let isControl = flags.contains(.maskControl)
        let isShift = flags.contains(.maskShift)

        if keyCode == 49, isControl, isShift {
            if self.engine.isActive {
                self.engine.stop()
            } else {
                self.engine.start()
            }
            return nil // Consume event
        }

        // If navigation is active, intercept H,J,K,L, arrows, Enter, Escape
        if engine.isActive {
            let handled = true

            switch keyCode {
            case 123, 4: // Left Arrow or 'H'
                self.engine.vennfurcate(.left)
            case 124, 37: // Right Arrow or 'L'
                self.engine.vennfurcate(.right)
            case 126, 40: // Up Arrow or 'K'
                self.engine.vennfurcate(.up)
            case 125, 38: // Down Arrow or 'J'
                self.engine.vennfurcate(.down)
            case 36: // Enter/Return
                self.engine.executeClick()
            case 53: // Escape
                self.engine.stop()
            default:
                // If not a navigation key, we still want to block it from hitting other apps
                // so the user doesn't accidentally type while in nav mode
                break
            }

            if handled {
                return nil // Consume event
            }
        }

        return Unmanaged.passRetained(event)
    }
}
