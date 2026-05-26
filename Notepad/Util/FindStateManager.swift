import Foundation

class FindStateManager {
    static let shared = FindStateManager()
    
    private init() {}
    
    // State persistence for the lifetime of the app
    var searchTerm: String = ""
    var matchCase: Bool = false
    var wrapAround: Bool = true
    var direction: InlineFindEngine.Direction = .forward
    
    func updateState(searchTerm: String, matchCase: Bool, wrapAround: Bool, direction: InlineFindEngine.Direction) {
        self.searchTerm = searchTerm
        self.matchCase = matchCase
        self.wrapAround = wrapAround
        self.direction = direction
    }
}