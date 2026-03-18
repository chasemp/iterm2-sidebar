import SwiftUI

enum BubbleState: String, Codable {
    case focused
    case active
    case min
    case dormant

    var ringColor: Color {
        switch self {
        case .focused: .green
        case .active: .blue
        case .min: .orange
        case .dormant: .gray
        }
    }

    var opacity: Double {
        switch self {
        case .focused: 1.0
        case .active: 0.85
        case .min: 0.6
        case .dormant: 0.5
        }
    }
}
