import SwiftUI

struct GridOverlayView: View {
    @ObservedObject var engine: NavigationEngine

    var body: some View {
        ZStack {
            // Liquid Glass Background (macOS 26+)
            Rectangle()
                .fill(.clear)
                .glassEffect()

            // Crosshair
            Canvas { context, size in
                let midX = size.width / 2
                let midY = size.height / 2

                var path = Path()

                // Vertical line
                path.move(to: CGPoint(x: midX, y: 0))
                path.addLine(to: CGPoint(x: midX, y: size.height))

                // Horizontal line
                path.move(to: CGPoint(x: 0, y: midY))
                path.addLine(to: CGPoint(x: size.width, y: midY))

                context.stroke(
                    path,
                    with: .color(.accentColor.opacity(0.8)),
                    lineWidth: 1.5
                )
            }
        }
        .animation(.spring(response: 0.15, dampingFraction: 0.8), value: engine.currentRegion)
        .ignoresSafeArea()
    }
}
