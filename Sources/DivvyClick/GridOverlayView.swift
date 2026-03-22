import SwiftUI

struct GridOverlayView: View {
    @ObservedObject var engine: NavigationEngine

    var body: some View {
        ZStack {
            if engine.isActive, let region = engine.currentRegion {
                // 1. Blurred background for the "outside" area
                Rectangle()
                    .fill(.ultraThinMaterial.opacity(0.6))
                    .mask(
                        InvertedRectangle(
                            innerRect: region,
                            outerRect: engine.activeScreenFrame
                        )
                        .fill(style: FillStyle(eoFill: true))
                    )
                    .animation(.spring(response: 0.06, dampingFraction: 0.9), value: region)

                // 2. Polished Sniper Eyepiece centered on the active region
                Canvas { context, size in
                    // Convert region to local coordinates
                    let localRegion = localRect(for: region, in: engine.activeScreenFrame)
                    let midX = localRegion.midX
                    let midY = localRegion.midY

                    let neonColor = engine.isMouseDown ? Color.red : Color(red: 0.0, green: 1.0, blue: 1.0) // Cyan
                    
                    context.addFilter(.shadow(color: neonColor.opacity(0.6), radius: 4, x: 0, y: 0))
                    context.addFilter(.shadow(color: neonColor.opacity(0.4), radius: 8, x: 0, y: 0))

                    // Arcs (Segmented Circle)
                    let radius: CGFloat = 20.0
                    let gapAngle: Angle = .degrees(10)
                    let arcWidth: CGFloat = 1.5
                    
                    for i in 0..<4 {
                        let startAngle = Angle.degrees(Double(i) * 90 + gapAngle.degrees)
                        let endAngle = Angle.degrees(Double(i + 1) * 90 - gapAngle.degrees)
                        
                        var arcPath = Path()
                        arcPath.addArc(center: CGPoint(x: midX, y: midY),
                                       radius: radius,
                                       startAngle: startAngle,
                                       endAngle: endAngle,
                                       clockwise: false)
                        
                        context.stroke(arcPath, with: .color(neonColor), lineWidth: arcWidth)
                    }

                    // Gapped Crosshairs
                    let innerGap: CGFloat = 4.0
                    let outerGap: CGFloat = 6.0
                    
                    var crosshairPath = Path()
                    // Top
                    crosshairPath.move(to: CGPoint(x: midX, y: midY - innerGap))
                    crosshairPath.addLine(to: CGPoint(x: midX, y: midY - radius + outerGap))
                    // Bottom
                    crosshairPath.move(to: CGPoint(x: midX, y: midY + innerGap))
                    crosshairPath.addLine(to: CGPoint(x: midX, y: midY + radius - outerGap))
                    // Left
                    crosshairPath.move(to: CGPoint(x: midX - innerGap, y: midY))
                    crosshairPath.addLine(to: CGPoint(x: midX - radius + outerGap, y: midY))
                    // Right
                    crosshairPath.move(to: CGPoint(x: midX + innerGap, y: midY))
                    crosshairPath.addLine(to: CGPoint(x: midX + radius - outerGap, y: midY))
                    
                    context.stroke(crosshairPath, with: .color(neonColor), lineWidth: 2.0)

                    // 3. Draw 3x3 grid lines (tic-tac-toe)
                    var globalPath = Path()
                    let thirdW = localRegion.width / 3.0
                    let thirdH = localRegion.height / 3.0
                    
                    let leftLineX = localRegion.minX + thirdW
                    let rightLineX = localRegion.minX + 2.0 * thirdW
                    let bottomLineY = localRegion.minY + thirdH
                    let topLineY2 = localRegion.minY + 2.0 * thirdH
                    
                    // Vertical lines
                    globalPath.move(to: CGPoint(x: leftLineX, y: localRegion.minY))
                    globalPath.addLine(to: CGPoint(x: leftLineX, y: localRegion.maxY))
                    
                    globalPath.move(to: CGPoint(x: rightLineX, y: localRegion.minY))
                    globalPath.addLine(to: CGPoint(x: rightLineX, y: localRegion.maxY))
                    
                    // Horizontal lines
                    globalPath.move(to: CGPoint(x: localRegion.minX, y: bottomLineY))
                    globalPath.addLine(to: CGPoint(x: localRegion.maxX, y: bottomLineY))
                    
                    globalPath.move(to: CGPoint(x: localRegion.minX, y: topLineY2))
                    globalPath.addLine(to: CGPoint(x: localRegion.maxX, y: topLineY2))
                    
                    context.stroke(globalPath, with: .color(neonColor.opacity(0.3)), lineWidth: 1.0)
                }
                .animation(.spring(response: 0.06, dampingFraction: 0.9), value: region)
            }

            if engine.isSelectingDisplay {
                displaySelectionOverlay
            }

            if let activeLayer = engine.activeLayer {
                layerHUD(for: activeLayer)
            }
        }
        .ignoresSafeArea()
    }

    private var displaySelectionOverlay: some View {
        ZStack {
            Rectangle()
                .fill(.ultraThinMaterial.opacity(0.8))
            
            VStack(spacing: 20) {
                Text("Select Display")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .shadow(radius: 10)

                let screens = NSScreen.screens
                ForEach(0..<screens.count, id: \.self) { index in
                    displayRow(for: screens[index], index: index)
                }

                Text("Press 1, 2, 3... to select")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
                    .padding(.top, 10)
            }
            .padding(40)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color.black.opacity(0.6))
                    .shadow(radius: 20)
            )
        }
    }

    private func displayRow(for screen: NSScreen, index: Int) -> some View {
        HStack(spacing: 15) {
            Text("\(index + 1)")
                .font(.system(size: 24, weight: .black, design: .monospaced))
                .frame(width: 40, height: 40)
                .background(Circle().fill(Color.blue))
                .foregroundColor(.white)

            VStack(alignment: .leading) {
                Text(screen.localizedName)
                    .font(.headline)
                Text("\(Int(screen.frame.width)) x \(Int(screen.frame.height))")
                    .font(.caption)
            }
            .foregroundColor(.white)
        }
        .padding()
        .frame(width: 300, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.1)))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.2), lineWidth: 1)
        )
    }

    @ViewBuilder
    private func layerHUD(for layer: NavigationEngine.ActiveLayer) -> some View {
        ZStack {
            // Semi-transparent dimming background
            Color.black.opacity(0.15)
                .ignoresSafeArea()
            
            VStack(spacing: 30) {
                Text(layerTitle(layer))
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(.cyan)
                    .tracking(2)
                    .shadow(color: .cyan.opacity(0.5), radius: 8)

                // Keyboard Layout (3x3 grid + L on the right)
                HStack(alignment: .center, spacing: 40) {
                    VStack(spacing: 15) {
                        // Row 1: Y U I
                        HStack(spacing: 15) {
                            keyView(key: "Y", action: keyAction(layer, "Y"))
                            keyView(key: "U", action: keyAction(layer, "U"))
                            keyView(key: "I", action: keyAction(layer, "I"))
                        }
                        // Row 2: H J K
                        HStack(spacing: 15) {
                            keyView(key: "H", action: keyAction(layer, "H"))
                            keyView(key: "J", action: keyAction(layer, "J"))
                            keyView(key: "K", action: keyAction(layer, "K"))
                        }
                        // Row 3: N M ,
                        HStack(spacing: 15) {
                            keyView(key: "N", action: keyAction(layer, "N"))
                            keyView(key: "M", action: keyAction(layer, "M"))
                            keyView(key: ",", action: keyAction(layer, ","))
                        }
                    }

                    // Separate column for 'L' and 'Space'
                    VStack(spacing: 15) {
                        keyView(key: "L", action: keyAction(layer, "L"))
                        // Optional: Space bar representation
                        keyView(key: "␣", action: keyAction(layer, "Space"), width: 60)
                    }
                }
                .padding(40)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 32, style: .continuous)
                        .stroke(.white.opacity(0.2), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.3), radius: 30, x: 0, y: 15)
            }
        }
        .transition(.scale(scale: 0.9).combined(with: .opacity))
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: layer)
    }

    @ViewBuilder
    private func keyView(key: String, action: String?, width: CGFloat = 55) -> some View {
        VStack(spacing: 6) {
            Text(key)
                .font(.system(size: 20, weight: .bold, design: .monospaced))
                .foregroundColor(.white)
                .frame(width: width, height: 55)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.white.opacity(0.15))
                        .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(.white.opacity(0.3), lineWidth: 1)
                )

            if let action = action, !action.isEmpty {
                Text(action)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.8))
                    .frame(width: width + 10)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text("-")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.2))
            }
        }
    }

    private func keyAction(_ layer: NavigationEngine.ActiveLayer, _ key: String) -> String? {
        switch layer {
        case .action:
            switch key {
            case "H": return "Left Click"
            case "J": return "Double"
            case "K": return "Right Click"
            case "L": return "Middle"
            case "Space": return "Click"
            default: return nil
            }
        case .scroll:
            switch key {
            case "U": return "Scroll Up"
            case "M": return "Scroll Down"
            case "H": return "Scroll Left"
            case "K": return "Scroll Right"
            default: return nil
            }
        case .fastMove:
            switch key {
            case "H": return "Jump Left"
            case "J": return "Jump Down"
            case "K": return "Jump Right"
            case "L": return "Jump Up"
            default: return nil
            }
        case .management:
            switch key {
            case "H": return "Undo"
            case "J": return "Redo"
            case "K": return "Reset"
            case "L": return "Display"
            default: return nil
            }
        }
    }

    private func layerTitle(_ layer: NavigationEngine.ActiveLayer) -> String {
        switch layer {
        case .action: return "ACTION LAYER (F)"
        case .scroll: return "SCROLL LAYER (D)"
        case .fastMove: return "FAST MOVE LAYER (S)"
        case .management: return "MANAGEMENT LAYER (A)"
        }
    }

    private func localRect(for region: CGRect, in screen: CGRect) -> CGRect {
        CGRect(
            x: region.origin.x - screen.origin.x,
            y: screen.height - (region.origin.y - screen.origin.y) - region.height,
            width: region.width,
            height: region.height
        )
    }
}

struct InvertedRectangle: Shape {
    let innerRect: CGRect
    let outerRect: CGRect

    func path(in rect: CGRect) -> Path {
        var path = Path()
        // Outer boundary (the whole view/screen)
        path.addRect(rect)

        // Inner boundary (the clear region)
        let localInner = CGRect(
            x: innerRect.origin.x - outerRect.origin.x,
            y: outerRect.height - (innerRect.origin.y - outerRect.origin.y) - innerRect.height,
            width: innerRect.width,
            height: innerRect.height
        )
        path.addRect(localInner)

        return path
    }
}
