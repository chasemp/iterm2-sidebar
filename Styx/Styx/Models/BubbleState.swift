import SwiftUI

enum BubbleState: String, Codable {
    case focused
    case active
    case min
    case disconnected
    case dormant

    var ringColor: Color {
        switch self {
        case .focused: .green
        case .active: .blue
        case .min: .orange
        case .disconnected: .gray
        case .dormant: .gray
        }
    }

    var opacity: Double {
        switch self {
        case .focused: 1.0
        case .active: 0.85
        case .min: 0.6
        case .disconnected: 0.4
        case .dormant: 0.5
        }
    }
}
