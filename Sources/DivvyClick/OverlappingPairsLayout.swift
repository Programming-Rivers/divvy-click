import AppKit
import CoreGraphics
import DivvyClickCore
import SwiftUI

public struct OverlappingPairsLayout: NavigationLayout {
    public let id: String = "overlapping_pairs"
    public let name: String = "2x2 Overlapping (IJKL)"
    public let description: String = "Overlapping Top/Bottom and Left/Right tile pairs navigated with I, K, J, L"

    public init() {}

    public var defaultNavBindings: [KeyCode: LayoutTileBinding] {
        [
            .i: LayoutTileBinding(tileId: "up", label: "↑"),
            .k: LayoutTileBinding(tileId: "down", label: "↓"),
            .j: LayoutTileBinding(tileId: "left", label: "←"),
            .l: LayoutTileBinding(tileId: "right", label: "→")
        ]
    }

    public var fastMoveBindings: [KeyCode: LayoutTileBinding] {
        [
            .i: LayoutTileBinding(tileId: "up", label: "Fast ↑", fastRepeatCount: 2),
            .k: LayoutTileBinding(tileId: "down", label: "Fast ↓", fastRepeatCount: 2),
            .j: LayoutTileBinding(tileId: "left", label: "Fast ←", fastRepeatCount: 2),
            .l: LayoutTileBinding(tileId: "right", label: "Fast →", fastRepeatCount: 2)
        ]
    }

    public func subdivide(region: CGRect, tileId: String, screenFrame: CGRect) -> CGRect {
        let overlapFactor: CGFloat = CGFloat(AppConstants.overlapFactor)
        var newRegion = region

        switch tileId {
        case "up":
            let halfHeight = (region.size.height / 2.0) * overlapFactor
            newRegion.size.width = region.size.width
            newRegion.size.height = halfHeight
            newRegion.origin.x = region.origin.x
            newRegion.origin.y = region.origin.y + region.size.height - halfHeight
        case "down":
            let halfHeight = (region.size.height / 2.0) * overlapFactor
            newRegion.size.width = region.size.width
            newRegion.size.height = halfHeight
            newRegion.origin.x = region.origin.x
            newRegion.origin.y = region.origin.y
        case "left":
            let halfWidth = (region.size.width / 2.0) * overlapFactor
            newRegion.size.width = halfWidth
            newRegion.size.height = region.size.height
            newRegion.origin.x = region.origin.x
            newRegion.origin.y = region.origin.y
        case "right":
            let halfWidth = (region.size.width / 2.0) * overlapFactor
            newRegion.size.width = halfWidth
            newRegion.size.height = region.size.height
            newRegion.origin.x = region.origin.x + region.size.width - halfWidth
            newRegion.origin.y = region.origin.y
        default:
            return region
        }

        return newRegion.intersection(screenFrame)
    }

    public func drawGridLines(context: GraphicsContext, localRegion: CGRect, neonColor: Color) {
        var globalPath = Path()
        let overlapFactor: CGFloat = CGFloat(AppConstants.overlapFactor)
        let halfW = (localRegion.width / 2.0) * overlapFactor
        let halfH = (localRegion.height / 2.0) * overlapFactor

        let leftTileRightX = localRegion.minX + halfW
        let rightTileLeftX = localRegion.maxX - halfW
        let topTileBottomY = localRegion.minY + halfH
        let bottomTileTopY = localRegion.maxY - halfH

        // Vertical boundary lines (Left / Right overlap)
        globalPath.move(to: CGPoint(x: leftTileRightX, y: localRegion.minY))
        globalPath.addLine(to: CGPoint(x: leftTileRightX, y: localRegion.maxY))

        globalPath.move(to: CGPoint(x: rightTileLeftX, y: localRegion.minY))
        globalPath.addLine(to: CGPoint(x: rightTileLeftX, y: localRegion.maxY))

        // Horizontal boundary lines (Top / Bottom overlap)
        globalPath.move(to: CGPoint(x: localRegion.minX, y: topTileBottomY))
        globalPath.addLine(to: CGPoint(x: localRegion.maxX, y: topTileBottomY))

        globalPath.move(to: CGPoint(x: localRegion.minX, y: bottomTileTopY))
        globalPath.addLine(to: CGPoint(x: localRegion.maxX, y: bottomTileTopY))

        context.stroke(globalPath, with: .color(neonColor.opacity(0.3)), lineWidth: 1.0)
    }

    public func keyCues(localRegion: CGRect) -> [LayoutKeyCue] {
        guard localRegion.width > 72 && localRegion.height > 72 else { return [] }
        return [
            LayoutKeyCue(key: "I", x: localRegion.midX, y: localRegion.minY + 20),
            LayoutKeyCue(key: "K", x: localRegion.midX, y: localRegion.maxY - 20),
            LayoutKeyCue(key: "J", x: localRegion.minX + 20, y: localRegion.midY),
            LayoutKeyCue(key: "L", x: localRegion.maxX - 20, y: localRegion.midY)
        ]
    }

    public var hudStructure: LayoutHUDStructure {
        LayoutHUDStructure(rows: [
            [nil, "U", "I", "O", nil],
            ["H", "J", "K", "L", ";"],
            [nil, "M", ",", ".", nil]
        ])
    }
}
