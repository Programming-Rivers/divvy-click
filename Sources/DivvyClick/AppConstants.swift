import Foundation

public struct AppConstants: Sendable {
    // Navigation & Zooming
    public static let overlapFactor: Double = 1.1
    public static let maxHistorySize: Int = 100
    
    // Timing and Delays
    public static let clickDelay: Double = 0.05 // 50ms
    public static let doubleTapThreshold: Double = 0.3 // 300ms
    public static let autoScrollInterval: Double = 0.05
    
    // Grid & Movement
    public static let autoScrollBaseDelta: Int32 = 20
    public static let scrollStepDelta: Int32 = 100
    
    // UI - Overlay & HUD
    public static let cueIdleDelay: UInt64 = 1_000_000_000 // 1 second in nanoseconds
    public static let hudCornerPadding: Double = 40.0
    public static let keyViewSize: Double = 55.0
    public static let keyLabelSize: Double = 20.0
    public static let actionLabelSize: Double = 11.0
}
