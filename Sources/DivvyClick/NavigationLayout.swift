import AppKit
import CoreGraphics
import SwiftUI

struct LayoutTileBinding: Sendable {
    let tileId: String
    let label: String
    let fastRepeatCount: Int

    init(tileId: String, label: String, fastRepeatCount: Int = 1) {
        self.tileId = tileId
        self.label = label
        self.fastRepeatCount = fastRepeatCount
    }
}

struct LayoutKeyCue: Sendable, Identifiable {
    var id: String { key }
    let key: String
    let x: CGFloat
    let y: CGFloat

    init(key: String, x: CGFloat, y: CGFloat) {
        self.key = key
        self.x = x
        self.y = y
    }
}

struct LayoutHUDStructure: Sendable {
    let rows: [[String?]]
    let spaceBarAction: String?

    init(rows: [[String?]], spaceBarAction: String? = "Click") {
        self.rows = rows
        self.spaceBarAction = spaceBarAction
    }
}

protocol NavigationLayout: Sendable {
    var id: String { get }
    var name: String { get }
    var description: String { get }

    var defaultNavBindings: [KeyCode: LayoutTileBinding] { get }
    var fastMoveBindings: [KeyCode: LayoutTileBinding] { get }

    func subdivide(region: CGRect, tileId: String, screenFrame: CGRect) -> CGRect
    func drawGridLines(context: GraphicsContext, localRegion: CGRect, neonColor: Color)
    func keyCues(localRegion: CGRect) -> [LayoutKeyCue]
    var hudStructure: LayoutHUDStructure { get }
    func prospectiveTargetPoints(for region: CGRect, screenFrame: CGRect) -> [CGPoint]
}

extension NavigationLayout {
    func prospectiveTargetPoints(for region: CGRect, screenFrame: CGRect) -> [CGPoint] {
        let uniqueTileIds = Set(defaultNavBindings.values.map(\.tileId))
        var points: [CGPoint] = []
        let currentCenter = CGPoint(x: region.midX, y: region.midY)

        for tileId in uniqueTileIds {
            let nextRegion = subdivide(region: region, tileId: tileId, screenFrame: screenFrame)
            let center = CGPoint(x: nextRegion.midX, y: nextRegion.midY)
            // Filter out targets that match current center
            if hypot(center.x - currentCenter.x, center.y - currentCenter.y) > 1.0 {
                if !points.contains(where: { hypot($0.x - center.x, $0.y - center.y) < 1.0 }) {
                    points.append(center)
                }
            }
        }
        return points
    }
}

