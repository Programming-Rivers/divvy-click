import AppKit
import CoreGraphics
import DivvyClickCore
import SwiftUI

public struct BinaryBifurcationLayout: NavigationLayout {
    public let id: String = "binary_bifurcation"
    public let name: String = "2-Tile Bifurcation (JK)"
    public let description: String = "Two-tile alternating split layout (horizontal/vertical) navigated with J and K."

    public init() {}

    public enum BifurcationOrientation: Sendable, Equatable {
        case horizontal // Side-by-side tiles (vertical line splitting left & right)
        case vertical   // Stacked tiles (horizontal line splitting top & bottom)
    }

    /// Determines the orientation of the next bifurcation based on the reduction factor
    /// relative to the screen frame.
    public func orientation(for region: CGRect, screenFrame: CGRect) -> BifurcationOrientation {
        if screenFrame.width > 0 && screenFrame.height > 0 {
            let ratioW = screenFrame.width / max(region.width, 1.0)
            let ratioH = screenFrame.height / max(region.height, 1.0)
            return ratioW <= ratioH ? .horizontal : .vertical
        }
        return region.width >= region.height ? .horizontal : .vertical
    }

    public var defaultNavBindings: [KeyCode: LayoutTileBinding] {
        [
            .j: LayoutTileBinding(tileId: "first", label: "Left / Top"),
            .k: LayoutTileBinding(tileId: "second", label: "Right / Bottom")
        ]
    }

    public var nudgeBindings: [KeyCode: LayoutTileBinding] {
        [
            .i: LayoutTileBinding(tileId: "up", label: "Nudge ↑"),
            .k: LayoutTileBinding(tileId: "down", label: "Nudge ↓"),
            .j: LayoutTileBinding(tileId: "left", label: "Nudge ←"),
            .l: LayoutTileBinding(tileId: "right", label: "Nudge →"),
            .u: LayoutTileBinding(tileId: "topLeft", label: "Nudge ↖"),
            .o: LayoutTileBinding(tileId: "topRight", label: "Nudge ↗"),
            .m: LayoutTileBinding(tileId: "bottomLeft", label: "Nudge ↙"),
            .period: LayoutTileBinding(tileId: "bottomRight", label: "Nudge ↘"),
            .upArrow: LayoutTileBinding(tileId: "up", label: "Nudge ↑"),
            .downArrow: LayoutTileBinding(tileId: "down", label: "Nudge ↓"),
            .leftArrow: LayoutTileBinding(tileId: "left", label: "Nudge ←"),
            .rightArrow: LayoutTileBinding(tileId: "right", label: "Nudge →")
        ]
    }

    public var fastMoveBindings: [KeyCode: LayoutTileBinding] {
        nudgeBindings
    }

    public func subdivide(region: CGRect, tileId: String, screenFrame: CGRect) -> CGRect {
        let orient = orientation(for: region, screenFrame: screenFrame)
        var newRegion = region

        switch orient {
        case .horizontal:
            let halfWidth = region.size.width / 2.0
            newRegion.size.width = halfWidth
            newRegion.size.height = region.size.height

            switch tileId {
            case "first", "j", "left", "topLeft", "bottomLeft":
                newRegion.origin.x = region.origin.x
                newRegion.origin.y = region.origin.y
            case "second", "k", "right", "topRight", "bottomRight":
                newRegion.origin.x = region.origin.x + halfWidth
                newRegion.origin.y = region.origin.y
            default:
                return region
            }

        case .vertical:
            let halfHeight = region.size.height / 2.0
            newRegion.size.width = region.size.width
            newRegion.size.height = halfHeight

            switch tileId {
            case "first", "j", "top", "up", "topLeft", "topRight":
                // macOS bottom-left origin: top tile is located at origin.y + halfHeight
                newRegion.origin.x = region.origin.x
                newRegion.origin.y = region.origin.y + halfHeight
            case "second", "k", "bottom", "down", "bottomLeft", "bottomRight":
                newRegion.origin.x = region.origin.x
                newRegion.origin.y = region.origin.y
            default:
                return region
            }
        }

        return newRegion.intersection(screenFrame)
    }

    public func drawGridLines(context: GraphicsContext, localRegion: CGRect, neonColor: Color) {
        drawGridLines(context: context, localRegion: localRegion, neonColor: neonColor, screenFrame: .zero)
    }

    public func drawGridLines(context: GraphicsContext, localRegion: CGRect, neonColor: Color, screenFrame: CGRect) {
        let orient = orientation(for: localRegion, screenFrame: screenFrame)
        var path = Path()

        switch orient {
        case .horizontal:
            path.move(to: CGPoint(x: localRegion.midX, y: localRegion.minY))
            path.addLine(to: CGPoint(x: localRegion.midX, y: localRegion.maxY))
        case .vertical:
            path.move(to: CGPoint(x: localRegion.minX, y: localRegion.midY))
            path.addLine(to: CGPoint(x: localRegion.maxX, y: localRegion.midY))
        }

        context.stroke(path, with: .color(neonColor.opacity(0.4)), lineWidth: 1.0)
    }

    public func keyCues(localRegion: CGRect) -> [LayoutKeyCue] {
        keyCues(localRegion: localRegion, screenFrame: .zero)
    }

    public func keyCues(localRegion: CGRect, screenFrame: CGRect) -> [LayoutKeyCue] {
        let orient = orientation(for: localRegion, screenFrame: screenFrame)

        switch orient {
        case .horizontal:
            guard (localRegion.width / 2.0) > 40 && localRegion.height > 40 else { return [] }
            return [
                LayoutKeyCue(key: "J", x: localRegion.minX + localRegion.width * 0.25, y: localRegion.midY),
                LayoutKeyCue(key: "K", x: localRegion.minX + localRegion.width * 0.75, y: localRegion.midY)
            ]
        case .vertical:
            guard localRegion.width > 40 && (localRegion.height / 2.0) > 40 else { return [] }
            return [
                // In SwiftUI Canvas, localRegion.minY is the visual top
                LayoutKeyCue(key: "J", x: localRegion.midX, y: localRegion.minY + localRegion.height * 0.25),
                LayoutKeyCue(key: "K", x: localRegion.midX, y: localRegion.minY + localRegion.height * 0.75)
            ]
        }
    }

    public var hudStructure: LayoutHUDStructure {
        LayoutHUDStructure(rows: [
            [nil, "U", "I", "O", nil],
            ["H", "J", "K", "L", ";"],
            [nil, "M", ",", ".", nil]
        ])
    }

    public func prospectiveTargetPoints(for region: CGRect, screenFrame: CGRect) -> [CGPoint] {
        let orient = orientation(for: region, screenFrame: screenFrame)
        switch orient {
        case .horizontal:
            return [
                CGPoint(x: region.minX + region.width * 0.25, y: region.midY),
                CGPoint(x: region.minX + region.width * 0.75, y: region.midY)
            ]
        case .vertical:
            return [
                CGPoint(x: region.midX, y: region.origin.y + region.height * 0.75), // Top
                CGPoint(x: region.midX, y: region.origin.y + region.height * 0.25)  // Bottom
            ]
        }
    }
}
