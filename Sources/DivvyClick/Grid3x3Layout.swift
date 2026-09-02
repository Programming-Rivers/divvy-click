import AppKit
import CoreGraphics
import SwiftUI

struct Grid3x3Layout: NavigationLayout {
    let id: String = "grid_3x3"
    let name: String = "3x3 Grid (UIO/JKL/M,.)"
    let description: String = "Classic 9-tile grid layout navigated with U, I, O, J, K, L, M, ,, ."

    init() {}

    var defaultNavBindings: [KeyCode: LayoutTileBinding] {
        [
            .u: LayoutTileBinding(tileId: "topLeft", label: "↖"),
            .i: LayoutTileBinding(tileId: "up", label: "↑"),
            .o: LayoutTileBinding(tileId: "topRight", label: "↗"),
            .j: LayoutTileBinding(tileId: "left", label: "←"),
            .k: LayoutTileBinding(tileId: "center", label: "○"),
            .l: LayoutTileBinding(tileId: "right", label: "→"),
            .m: LayoutTileBinding(tileId: "bottomLeft", label: "↙"),
            .comma: LayoutTileBinding(tileId: "down", label: "↓"),
            .period: LayoutTileBinding(tileId: "bottomRight", label: "↘")
        ]
    }

    var fastMoveBindings: [KeyCode: LayoutTileBinding] {
        [
            .u: LayoutTileBinding(tileId: "topLeft", label: "Fast ↖", fastRepeatCount: 2),
            .i: LayoutTileBinding(tileId: "up", label: "Fast ↑", fastRepeatCount: 2),
            .o: LayoutTileBinding(tileId: "topRight", label: "Fast ↗", fastRepeatCount: 2),
            .j: LayoutTileBinding(tileId: "left", label: "Fast ←", fastRepeatCount: 2),
            .k: LayoutTileBinding(tileId: "center", label: "Fast ○", fastRepeatCount: 2),
            .l: LayoutTileBinding(tileId: "right", label: "Fast →", fastRepeatCount: 2),
            .m: LayoutTileBinding(tileId: "bottomLeft", label: "Fast ↙", fastRepeatCount: 2),
            .comma: LayoutTileBinding(tileId: "down", label: "Fast ↓", fastRepeatCount: 2),
            .period: LayoutTileBinding(tileId: "bottomRight", label: "Fast ↘", fastRepeatCount: 2)
        ]
    }

    func subdivide(region: CGRect, tileId: String, screenFrame: CGRect) -> CGRect {
        let overlapFactor: CGFloat = CGFloat(AppConstants.overlapFactor)
        let thirdWidth = (region.size.width / 3.0) * overlapFactor
        let thirdHeight = (region.size.height / 3.0) * overlapFactor

        let xStep = (region.size.width - thirdWidth) / 2.0
        let yStep = (region.size.height - thirdHeight) / 2.0

        var newRegion = region
        newRegion.size.width = thirdWidth
        newRegion.size.height = thirdHeight

        // Horizontal component
        switch tileId {
        case "left", "topLeft", "bottomLeft":
            newRegion.origin.x = region.origin.x
        case "right", "topRight", "bottomRight":
            newRegion.origin.x = region.origin.x + region.size.width - thirdWidth
        case "center", "up", "down":
            newRegion.origin.x = region.origin.x + xStep
        default:
            return region
        }

        // Vertical component (macOS origin is bottom-left)
        switch tileId {
        case "up", "topLeft", "topRight":
            newRegion.origin.y = region.origin.y + region.size.height - thirdHeight
        case "down", "bottomLeft", "bottomRight":
            newRegion.origin.y = region.origin.y
        case "center", "left", "right":
            newRegion.origin.y = region.origin.y + yStep
        default:
            return region
        }

        return newRegion.intersection(screenFrame)
    }

    func drawGridLines(context: GraphicsContext, localRegion: CGRect, neonColor: Color) {
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

    func keyCues(localRegion: CGRect) -> [LayoutKeyCue] {
        let thirdW = localRegion.width / 3.0
        let thirdH = localRegion.height / 3.0
        guard thirdW > 72 && thirdH > 72 else { return [] }

        let keys: [[String]] = [
            ["U", "I", "O"],
            ["J", "K", "L"],
            ["M", ",", "."]
        ]

        var cues: [LayoutKeyCue] = []
        for row in 0..<3 {
            for col in 0..<3 {
                let x = localRegion.minX + CGFloat(col) * thirdW + thirdW / 2.0
                let y = localRegion.minY + CGFloat(row) * thirdH + thirdH / 2.0
                cues.append(LayoutKeyCue(key: keys[row][col], x: x, y: y))
            }
        }
        return cues
    }

    var hudStructure: LayoutHUDStructure {
        LayoutHUDStructure(rows: [
            [nil, "U", "I", "O", nil],
            ["H", "J", "K", "L", ";"],
            [nil, "M", ",", ".", nil]
        ])
    }
}
