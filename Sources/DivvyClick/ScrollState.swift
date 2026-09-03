import Foundation

@MainActor
public class ScrollState: ObservableObject {
    public init() {}
    @Published public var autoScrollDirection: NavigationEngine.ScrollDirection? = nil
    @Published public var autoScrollSpeed: Int32 = 0
}
