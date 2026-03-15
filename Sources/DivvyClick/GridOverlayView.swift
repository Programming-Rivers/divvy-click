import SwiftUI

struct GridOverlayView: View {
    @ObservedObject var engine: NavigationEngine

    var body: some View {
        ZStack {
            if let region = engine.currentRegion {
                // 1. Blurred background for the "outside" area
                Rectangle()
                    .fill(.ultraThinMaterial)
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

                    // 3. Keep global crosshairs (clamped to region) but make them subtle
                    var globalPath = Path()
                    globalPath.move(to: CGPoint(x: midX, y: localRegion.minY))
                    globalPath.addLine(to: CGPoint(x: midX, y: midY - radius - 2))
                    globalPath.move(to: CGPoint(x: midX, y: midY + radius + 2))
                    globalPath.addLine(to: CGPoint(x: midX, y: localRegion.maxY))
                    
                    globalPath.move(to: CGPoint(x: localRegion.minX, y: midY))
                    globalPath.addLine(to: CGPoint(x: midX - radius - 2, y: midY))
                    globalPath.move(to: CGPoint(x: midX + radius + 2, y: midY))
                    globalPath.addLine(to: CGPoint(x: localRegion.maxX, y: midY))
                    
                    context.stroke(globalPath, with: .color(neonColor.opacity(0.3)), lineWidth: 1.0)
                }
                .animation(.spring(response: 0.06, dampingFraction: 0.9), value: region)
            }

            if engine.isSelectingDisplay {
                displaySelectionOverlay
            }
        }
        .ignoresSafeArea()
    }

    private var displaySelectionOverlay: some View {
        ZStack {
            Rectangle()
                .fill(.ultraThinMaterial)
            
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
