import SwiftUI

enum BubbleState: String, Codable {
    case focused
    case active
    case dormant

    var ringColor: Color {
        switch self {
        case .focused: .green
        case .active: .blue
        case .dormant: .gray
        }
    }

    var opacity: Double {
        switch self {
        case .focused: 1.0
        case .active: 0.85
        case .dormant: 0.5
        }
    }
}
