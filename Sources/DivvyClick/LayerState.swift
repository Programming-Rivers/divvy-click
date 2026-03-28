import Foundation

@MainActor
class LayerState: ObservableObject {
    @Published var activeLayer: NavigationEngine.ActiveLayer? = nil
    @Published var showHUD: Bool = false
}
