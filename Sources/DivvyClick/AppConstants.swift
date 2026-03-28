import Foundation

struct AppConstants {
    // Navigation & Zooming
    static let overlapFactor: Double = 1.1
    static let maxHistorySize: Int = 100
    
    // Timing and Delays
    static let clickDelay: Double = 0.05 // 50ms
    static let doubleTapThreshold: Double = 0.3 // 300ms
    static let autoScrollInterval: Double = 0.05
    
    // Grid & Movement
    static let autoScrollBaseDelta: Int32 = 20
    static let scrollStepDelta: Int32 = 100
    
    // UI - Overlay & HUD
    static let cueIdleDelay: UInt64 = 1_000_000_000 // 1 second in nanoseconds
    static let hudCornerPadding: Double = 40.0
    static let keyViewSize: Double = 55.0
    static let keyLabelSize: Double = 20.0
    static let actionLabelSize: Double = 11.0
}
