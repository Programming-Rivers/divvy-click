import AppKit
import CoreGraphics
import DivvyClickCore
import SwiftUI

public struct LayoutTileBinding: Sendable {
    public let tileId: String
    public let label: String
    public let fastRepeatCount: Int

    public init(tileId: String, label: String, fastRepeatCount: Int = 1) {
        self.tileId = tileId
        self.label = label
        self.fastRepeatCount = fastRepeatCount
    }
}

public struct LayoutKeyCue: Sendable, Identifiable {
    public var id: String { key }
    public let key: String
    public let x: CGFloat
    public let y: CGFloat

    public init(key: String, x: CGFloat, y: CGFloat) {
        self.key = key
        self.x = x
        self.y = y
    }
}

public struct LayoutHUDStructure: Sendable {
    public let rows: [[String?]]
    public let spaceBarAction: String?

    public init(rows: [[String?]], spaceBarAction: String? = "Click") {
        self.rows = rows
        self.spaceBarAction = spaceBarAction
    }
}

public protocol NavigationLayout: Sendable {
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

public extension NavigationLayout {
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

