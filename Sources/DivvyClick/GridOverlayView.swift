import SwiftUI

struct GridOverlayView: View {
    @ObservedObject var engine: NavigationEngine
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
            if let layer = engine.activeLayer {
                layerHUD(for: layer)
            } else if engine.isActive && engine.showHUD {
                layerHUD(for: .defaultNav)
            }

        }
        .ignoresSafeArea()
        .task(id: "\(String(describing: engine.currentRegion))-\(engine.activeLayer == nil)-\(engine.isActive)-\(engine.isSelectingDisplay)") {
            showCues = false
            guard engine.isActive && engine.activeLayer == nil && !engine.isSelectingDisplay else { return }
            
            // Wait 1 second for cues
            try? await Task.sleep(nanoseconds: 1_000_000_000)
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
    }

    @ViewBuilder
    private var gridKeyCues: some View {
        if engine.isActive, let region = engine.currentRegion {
            let localRegion = localRect(for: region, in: engine.activeScreenFrame)
            let thirdW = localRegion.width / 3.0
            let thirdH = localRegion.height / 3.0
            
            // Only show cues if they fit comfortably (32x32 cue + 20px padding)
            if thirdW > 72 && thirdH > 72 {
                let keys: [[String]] = [["U", "I", "O"], ["J", "K", "L"], ["M", ",", "."]]
                
                ZStack(alignment: .topLeading) {
                    ForEach(0..<3) { row in
                        ForEach(0..<3) { col in
                            let x = localRegion.minX + CGFloat(col) * thirdW + 8
                            let y = localRegion.minY + CGFloat(row) * thirdH + 8
                        
                        Text(keys[row][col])
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
                            .position(x: x + 16, y: y + 16) // center of the 32x32 box
                        }
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

                // Keyboard Layout (5 columns: _UIO_ / HJKL; / _M,._)
                VStack(spacing: 25) {
                    Grid(horizontalSpacing: 15, verticalSpacing: 15) {
                        // Row 1: _ U I O _
                        GridRow {
                            Color.clear.frame(width: 55, height: 55)
                            keyView(key: "U", action: keyAction(layer, "U"))
                            keyView(key: "I", action: keyAction(layer, "I"))
                            keyView(key: "O", action: keyAction(layer, "O"))
                            Color.clear.frame(width: 55, height: 55)
                        }

                        // Row 2: H J K L ;
                        GridRow {
                            keyView(key: "H", action: keyAction(layer, "H"))
                            keyView(key: "J", action: keyAction(layer, "J"))
                            keyView(key: "K", action: keyAction(layer, "K"))
                            keyView(key: "L", action: keyAction(layer, "L"))
                            keyView(key: ";", action: keyAction(layer, ";"))
                        }

                        // Row 3: _ M , . _
                        GridRow {
                            Color.clear.frame(width: 55, height: 55)
                            keyView(key: "M", action: keyAction(layer, "M"))
                            keyView(key: ",", action: keyAction(layer, ","))
                            keyView(key: ".", action: keyAction(layer, "."))
                            Color.clear.frame(width: 55, height: 55)
                        }
                    }

                    // Wide Space bar row below all keys
                    keyView(key: "␣", action: keyAction(layer, "Space"), width: 335)
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
            .padding(40) // Give it room in its corner
        }
        .transition(.scale(scale: 0.9).combined(with: .opacity))
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: "\(layer)-\(String(describing: engine.currentRegion))")
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
        if key == "Space" { return "Click" }
        if key == ";" { return "Displays" }
        
        guard let code = KeyCode.from(string: key) else { return nil }
        return KeyMap.shared.label(for: layer, key: code)
    }

    private func layerTitle(_ layer: NavigationEngine.ActiveLayer) -> String {
        switch layer {
        case .action: return "ACTION LAYER (F)"
        case .scroll: return "SCROLL LAYER (D)"
        case .fastMove: return "FAST MOVE LAYER (S)"
        case .management: return "MANAGEMENT LAYER (A)"
        case .defaultNav: return "NAVIGATION"
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
