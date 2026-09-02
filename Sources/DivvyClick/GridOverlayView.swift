import SwiftUI

struct GridOverlayView: View {
    @ObservedObject var engine: NavigationEngine
    @ObservedObject var layerState: LayerState
    @ObservedObject var scrollState: ScrollState
    var keyMap: KeyMap = .default
    @State private var showCues = false


    var body: some View {
        ZStack {
            // 1. Grid Lines and Sniper Eyepiece
            gridLines
            
            // 2. Grid Key Cues (1s idle delay)
            if showCues {
                gridKeyCues
                    .transition(.opacity)
            }

            // 3. Display Selection Overlay
            if engine.isSelectingDisplay {
                displaySelectionOverlay
            }

            // 4. Layer HUD (Active Layer or 10s idle Default Layer)
            if let layer = layerState.activeLayer {
                layerHUD(for: layer)
            } else if engine.isActive && layerState.showHUD {
                layerHUD(for: .defaultNav)
            }

        }
        .ignoresSafeArea()
        .task(id: "\(String(describing: engine.currentTarget))-\(layerState.activeLayer == nil)-\(engine.isActive)-\(engine.isSelectingDisplay)-\(engine.activeLayout.id)") {
            showCues = false
            guard engine.isActive && layerState.activeLayer == nil && !engine.isSelectingDisplay else { return }
            
            // Wait for cues
            try? await Task.sleep(nanoseconds: AppConstants.cueIdleDelay)
            withAnimation { showCues = true }
        }

    }

    @ViewBuilder
    private var gridLines: some View {
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

            // 2. Polished Sniper Eyepiece centered on active region & fainter crosshairs for prospective tiles
            Canvas { context, size in
                // Convert region to local coordinates
                let localRegion = localRect(for: region, in: engine.activeScreenFrame)
                let midX = localRegion.midX
                let midY = localRegion.midY

                let neonColor = engine.isMouseDown ? Color.red : Color(red: 0.0, green: 1.0, blue: 1.0) // Cyan

                // 2a. Draw layout-specific boundary lines
                engine.activeLayout.drawGridLines(context: context, localRegion: localRegion, neonColor: neonColor)

                // 2b. Draw fainter crosshairs for prospective tile endpoints
                let prospectivePoints = engine.activeLayout.prospectiveTargetPoints(for: region, screenFrame: engine.activeScreenFrame)
                context.drawLayer { faintContext in
                    faintContext.addFilter(.shadow(color: neonColor.opacity(0.3), radius: 3, x: 0, y: 0))
                    for pt in prospectivePoints {
                        let localPt = localPoint(for: pt, in: engine.activeScreenFrame)
                        drawFaintCrosshair(context: faintContext, at: localPt, color: neonColor.opacity(0.45))
                    }
                }

                // 2c. Sniper Eyepiece centered on the active region
                context.drawLayer { sniperContext in
                    sniperContext.addFilter(.shadow(color: neonColor.opacity(0.6), radius: 4, x: 0, y: 0))
                    sniperContext.addFilter(.shadow(color: neonColor.opacity(0.4), radius: 8, x: 0, y: 0))

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
                        
                        sniperContext.stroke(arcPath, with: .color(neonColor), lineWidth: arcWidth)
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
                    
                    sniperContext.stroke(crosshairPath, with: .color(neonColor), lineWidth: 2.0)
                }
            }
            .animation(.spring(response: 0.06, dampingFraction: 0.9), value: region)
        }
    }

    @ViewBuilder
    private var gridKeyCues: some View {
        if engine.isActive, let region = engine.currentRegion {
            let localRegion = localRect(for: region, in: engine.activeScreenFrame)
            let cueItems = engine.activeLayout.keyCues(localRegion: localRegion)
            
            if !cueItems.isEmpty {
                ZStack {
                    ForEach(cueItems) { item in
                        Text(item.key)
                            .font(.system(size: 14, weight: .bold, design: .monospaced))
                            .foregroundColor(.white)
                            .frame(width: 32, height: 32)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(.ultraThinMaterial)
                                    .shadow(color: .black.opacity(0.4), radius: 3, x: 0, y: 2)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(.white.opacity(0.3), lineWidth: 1)
                            )
                            .position(x: item.x, y: item.y)
                    }
                }
                .animation(.spring(response: 0.06, dampingFraction: 0.9), value: region)

                // Help cue (?) in bottom right
                Text("?")
                    .font(.system(size: 16, weight: .black, design: .rounded))
                    .foregroundColor(.black)
                    .frame(width: 32, height: 32)
                    .background(Circle().fill(Color.cyan))
                    .shadow(color: .cyan.opacity(0.3), radius: 4)
                    .padding(20)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
            }
        }
    }


    private var displaySelectionOverlay: some View {
        ZStack {
            Rectangle()
                .fill(.ultraThinMaterial.opacity(0.85))
                .ignoresSafeArea()
            
            VStack(spacing: 40) {
                Text("Select Target Display")
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundColor(.cyan)
                    .shadow(color: .cyan.opacity(0.3), radius: 10)

                let mapping = engine.screenMapping()
                let keys: [[String]] = [["U", "I", "O"], ["J", "K", "L"], ["M", ",", "."]]
                
                Grid(horizontalSpacing: 20, verticalSpacing: 20) {
                    ForEach(0..<3) { row in
                        GridRow {
                            ForEach(0..<3) { col in
                                let index = row * 3 + col
                                if let screenRect = mapping[index] {
                                    let screen = NSScreen.screens.first { $0.frame == screenRect }
                                    displayTile(for: screen, rect: screenRect, key: keys[row][col])
                                } else {
                                    reservedTile(key: keys[row][col], isReserved: index == 8)
                                }
                            }
                        }
                    }
                }
                .padding(40)
                .background(Color.black.opacity(0.3))
                .clipShape(RoundedRectangle(cornerRadius: 32))
                .overlay(RoundedRectangle(cornerRadius: 32).stroke(.white.opacity(0.1), lineWidth: 1))
            }
        }
    }

    private func displayTile(for screen: NSScreen?, rect: CGRect, key: String) -> some View {
        VStack(spacing: 12) {
            Text(key)
                .font(.system(size: 24, weight: .black, design: .monospaced))
                .frame(width: 50, height: 50)
                .background(Circle().fill(Color.cyan))
                .foregroundColor(.black)
                .shadow(color: .cyan.opacity(0.5), radius: 8)

            VStack(spacing: 4) {
                Text(screen?.localizedName ?? "Unknown Display")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.center)
                Text("\(Int(rect.width))x\(Int(rect.height))")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundColor(.white.opacity(0.6))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 10)
        }
        .frame(width: 140, height: 140)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.white.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(.white.opacity(0.2), lineWidth: 1)
        )
    }

    private func reservedTile(key: String, isReserved: Bool) -> some View {
        VStack(spacing: 12) {
            Text(key)
                .font(.system(size: 20, weight: .bold, design: .monospaced))
                .foregroundColor(.white.opacity(0.3))
            
            Text(isReserved ? "RESERVED" : "EMPTY")
                .font(.system(size: 10, weight: .black, design: .rounded))
                .foregroundColor(.white.opacity(0.2))
                .tracking(2)
        }
        .frame(width: 140, height: 140)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .stroke(.white.opacity(0.1), lineWidth: 1)
                .background(Color.black.opacity(0.2))
        )
        .cornerRadius(20)
    }

    @ViewBuilder
    private func layerHUD(for layer: NavigationEngine.ActiveLayer) -> some View {
        let localRegion = localRect(for: engine.currentRegion ?? .zero, in: engine.activeScreenFrame)
        let screen = engine.activeScreenFrame.size
        
        // Determine safest quadrant (opposite of current region)
        let isRight = localRegion.midX > screen.width / 2
        let isBottom = localRegion.midY > screen.height / 2
        
        let alignment: Alignment = isBottom ? (isRight ? .topLeading : .topTrailing) : (isRight ? .bottomLeading : .bottomTrailing)
        
        ZStack(alignment: alignment) {
            // Semi-transparent dimming background
            Color.black.opacity(0.15)
                .ignoresSafeArea()
            
            VStack(spacing: 30) {
                Text(layerTitle(layer))
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(.cyan)
                    .tracking(2)
                    .shadow(color: .cyan.opacity(0.5), radius: 8)

                // Auto-Scroll Status
                if let dir = scrollState.autoScrollDirection {
                    HStack(spacing: 8) {
                        Image(systemName: dir == .up ? "chevron.up.circle.fill" : "chevron.down.circle.fill")
                        Text("AUTO-SCROLLING (\(dir == .up ? "UP" : "DOWN") - SPEED: \(scrollState.autoScrollSpeed))")
                            .font(.system(size: 14, weight: .black, design: .monospaced))
                    }
                    .foregroundColor(.orange)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 16)
                    .background(Capsule().fill(.orange.opacity(0.1)))
                    .overlay(Capsule().stroke(.orange.opacity(0.3), lineWidth: 1))
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .id("autoscroll-status")
                }

                // Keyboard Layout
                VStack(spacing: 25) {
                    Grid(horizontalSpacing: 15, verticalSpacing: 15) {
                        ForEach(0..<engine.activeLayout.hudStructure.rows.count, id: \.self) { rowIndex in
                            GridRow {
                                ForEach(0..<engine.activeLayout.hudStructure.rows[rowIndex].count, id: \.self) { colIndex in
                                    if let key = engine.activeLayout.hudStructure.rows[rowIndex][colIndex] {
                                        keyView(key: key, action: keyAction(layer, key))
                                    } else {
                                        Color.clear.frame(width: CGFloat(AppConstants.keyViewSize), height: CGFloat(AppConstants.keyViewSize))
                                    }
                                }
                            }
                        }
                    }

                    // Wide Space bar row below all keys
                    keyView(key: "␣", action: keyAction(layer, "Space"), width: CGFloat(AppConstants.keyViewSize * 5 + 60))
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
            .padding(AppConstants.hudCornerPadding) // Give it room in its corner
        }
        .transition(.scale(scale: 0.9).combined(with: .opacity))
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: "\(layer)-\(String(describing: engine.currentTarget))")
    }

    @ViewBuilder
    private func keyView(key: String, action: String?, width: CGFloat = CGFloat(AppConstants.keyViewSize)) -> some View {
        VStack(spacing: 6) {
            Text(key)
                .font(.system(size: CGFloat(AppConstants.keyLabelSize), weight: .bold, design: .monospaced))
                .foregroundColor(.white)
                .frame(width: width, height: CGFloat(AppConstants.keyViewSize))
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
                    .font(.system(size: CGFloat(AppConstants.actionLabelSize), weight: .medium, design: .rounded))
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
        if key == "Space" { return "Click" }
        if key == ";" { return "Displays" }
        
        guard let code = KeyCode.from(string: key) else { return nil }
        return KeyMap(layout: engine.activeLayout).label(for: layer, key: code)
    }

    private func layerTitle(_ layer: NavigationEngine.ActiveLayer) -> String {
        switch layer {
        case .action: return "ACTION LAYER (D)"
        case .scroll: return "SCROLL LAYER (F)"
        case .fastMove: return "FAST MOVE LAYER (S)"
        case .management: return "MANAGEMENT LAYER (A)"
        case .defaultNav: return "NAVIGATION"
        }
    }

    private func drawFaintCrosshair(context: GraphicsContext, at point: CGPoint, color: Color) {
        let radius: CGFloat = 6.0
        let innerGap: CGFloat = 2.0
        let outerArm: CGFloat = 7.0
        let lineWidth: CGFloat = 1.0

        // Subtle mini circle ring
        var circlePath = Path()
        circlePath.addArc(
            center: point,
            radius: radius,
            startAngle: .degrees(0),
            endAngle: .degrees(360),
            clockwise: false
        )
        context.stroke(circlePath, with: .color(color.opacity(0.5)), lineWidth: lineWidth)

        // Mini gapped crosshairs
        var crosshairPath = Path()
        // Top
        crosshairPath.move(to: CGPoint(x: point.x, y: point.y - innerGap))
        crosshairPath.addLine(to: CGPoint(x: point.x, y: point.y - outerArm))
        // Bottom
        crosshairPath.move(to: CGPoint(x: point.x, y: point.y + innerGap))
        crosshairPath.addLine(to: CGPoint(x: point.x, y: point.y + outerArm))
        // Left
        crosshairPath.move(to: CGPoint(x: point.x - innerGap, y: point.y))
        crosshairPath.addLine(to: CGPoint(x: point.x - outerArm, y: point.y))
        // Right
        crosshairPath.move(to: CGPoint(x: point.x + innerGap, y: point.y))
        crosshairPath.addLine(to: CGPoint(x: point.x + outerArm, y: point.y))

        context.stroke(crosshairPath, with: .color(color), lineWidth: lineWidth)
    }

    private func localPoint(for point: CGPoint, in screen: CGRect) -> CGPoint {
        CGPoint(
            x: point.x - screen.origin.x,
            y: screen.height - (point.y - screen.origin.y)
        )
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
