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

        // Activation Hotkey: Cmd + Num Lock (Keypad Clear)
        // Num Lock (Keypad Clear) keycode: 71, Flags check: Command
        let isCommand = flags.contains(.maskCommand)

        if keyCode == 71, isCommand {
            if self.engine.isActive {
                self.engine.stop()
            } else {
                self.engine.start()
            }
            return nil // Consume event
        }

        // If navigation is active, intercept keys
        if engine.isActive {
            if engine.isSelectingDisplay {
                switch keyCode {
                case 18...21, 23, 22, 26, 28, 25, 29: // 1-9, 0 (Row)
                    let indexMap: [Int64: Int] = [18:0, 19:1, 20:2, 21:3, 23:4, 22:5, 26:6, 28:7, 25:8, 29:9]
                    if let index = indexMap[keyCode] {
                        self.engine.selectDisplay(at: index)
                    }
                case 82...92: // Numpad 0-9
                    let indexMap: [Int64: Int] = [83:0, 84:1, 85:2, 86:3, 87:4, 88:5, 89:6, 91:7, 92:8, 82:9]
                    if let index = indexMap[keyCode] {
                        self.engine.selectDisplay(at: index)
                    }
                case 53: // Escape
                    self.engine.stop()
                default:
                    break
                }
                return nil // Consume all keys in selection mode
            }

            switch keyCode {
            case 123, 4: // Left Arrow or 'H'
                self.engine.vennfurcate(.left)
            case 124, 37: // Right Arrow or 'L'
                self.engine.vennfurcate(.right)
            case 126, 40: // Up Arrow or 'K'
                self.engine.vennfurcate(.up)
            case 125, 38: // Down Arrow or 'J'
                self.engine.vennfurcate(.down)
            case 83, 18: // Numpad 1 or '1' (Bottom-Left)
                self.engine.vennfurcate(.bottomLeft)
            case 85, 20: // Numpad 3 or '3' (Bottom-Right)
                self.engine.vennfurcate(.bottomRight)
            case 89, 26: // Numpad 7 or '7' (Top-Left)
                self.engine.vennfurcate(.topLeft)
            case 92, 25: // Numpad 9 or '9' (Top-Right)
                self.engine.vennfurcate(.topRight)
            case 87, 23: // Numpad 5 or '5' (Middle Click)
                self.engine.execute(.middleClick)
            case 36, 76: // Enter/Return or Numpad Enter
                self.engine.execute(.click)
            case 46: // 'M'
                self.engine.execute(.move)
            case 15: // 'R'
                self.engine.execute(.rightClick)
            case 1:  // 'S' (Start Drag)
                self.engine.execute(.mouseDown)
            case 3:  // 'F' (Finish Drag)
                self.engine.execute(.mouseUp)
            case 2:  // 'D' (Select Display)
                self.engine.showDisplaySelection()
            case 78: // Numpad - (Undo)
                if !self.engine.undo() {
                    self.engine.showDisplaySelection()
                }
            case 69: // Numpad + (Redo)
                self.engine.redo()
            case 84: // Numpad 2 (Scroll Down)
                self.engine.execute(.scroll(.down))
            case 86: // Numpad 4 (Scroll Right). I know it's counterintuitive, but it is correct.
                self.engine.execute(.scroll(.right))
            case 88: // Numpad 6 (Scroll Left). I know it's counterintuitive, but it is correct.
                self.engine.execute(.scroll(.left))
            case 91: // Numpad 8 (Scroll Up)
                self.engine.execute(.scroll(.up))
            case 53: // Escape
                self.engine.stop()
            default:
                break
            }

            return nil // Consume event
        }

        return Unmanaged.passRetained(event)
    }
}
