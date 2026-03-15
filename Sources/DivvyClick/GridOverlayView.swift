import SwiftUI

struct GridOverlayView: View {
    @ObservedObject var engine: NavigationEngine

    var body: some View {
        ZStack {
            // Blurred background for the "outside" area
            if let region = engine.currentRegion {
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

                // Crosshair centered on the active region
                Canvas { context, size in
                    // Convert region to local coordinates
                    let localRegion = localRect(for: region, in: engine.activeScreenFrame)
                    let midX = localRegion.midX
                    let midY = localRegion.midY

                    var path = Path()
                    // Vertical line (clamped to region)
                    path.move(to: CGPoint(x: midX, y: localRegion.minY))
                    path.addLine(to: CGPoint(x: midX, y: localRegion.maxY))

                    // Horizontal line (clamped to region)
                    path.move(to: CGPoint(x: localRegion.minX, y: midY))
                    path.addLine(to: CGPoint(x: localRegion.maxX, y: midY))

                    context.stroke(
                        path,
                        with: .color(.accentColor.opacity(0.8)),
                        lineWidth: 1.5
                    )
                }
                .animation(.spring(response: 0.06, dampingFraction: 0.9), value: region)
            }
        }
        .ignoresSafeArea()
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

