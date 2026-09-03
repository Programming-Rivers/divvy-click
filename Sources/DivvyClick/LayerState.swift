import Foundation

@MainActor
public class LayerState: ObservableObject {
    public init() {}
    @Published public var activeLayer: NavigationEngine.ActiveLayer? = nil
    @Published public var showHUD: Bool = false
}
