import Combine
import Foundation

@MainActor
class LayoutRegistry: ObservableObject {
    static let shared = LayoutRegistry()

    private let userDefaultsKey = "DivvyClickSelectedLayoutId"

    @Published private(set) var registeredLayouts: [any NavigationLayout] = []
    @Published private(set) var activeLayout: any NavigationLayout

    init() {
        let defaultLayout = OverlappingPairsLayout()
        let gridLayout = Grid3x3Layout()

        let layouts: [any NavigationLayout] = [defaultLayout, gridLayout]
        self.registeredLayouts = layouts

        let savedId = UserDefaults.standard.string(forKey: userDefaultsKey)
        if let saved = layouts.first(where: { $0.id == savedId }) {
            self.activeLayout = saved
        } else {
            self.activeLayout = defaultLayout
        }
    }

    func register(_ layout: any NavigationLayout) {
        if !registeredLayouts.contains(where: { $0.id == layout.id }) {
            registeredLayouts.append(layout)
        }
    }

    func selectLayout(byId id: String) {
        guard let layout = registeredLayouts.first(where: { $0.id == id }) else { return }
        activeLayout = layout
        UserDefaults.standard.set(id, forKey: userDefaultsKey)
    }

    func selectLayout(_ layout: any NavigationLayout) {
        selectLayout(byId: layout.id)
    }
}
