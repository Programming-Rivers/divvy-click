import Foundation

@MainActor
class ScrollState: ObservableObject {
    @Published var autoScrollDirection: NavigationEngine.ScrollDirection? = nil
    @Published var autoScrollSpeed: Int32 = 0
}
