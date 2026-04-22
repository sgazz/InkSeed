import Foundation

enum Player: Int, CaseIterable {
    case one
    case two

    var title: String {
        switch self {
        case .one: return "Player 1"
        case .two: return "Player 2"
        }
    }

    mutating func advance() {
        self = self == .one ? .two : .one
    }
}
