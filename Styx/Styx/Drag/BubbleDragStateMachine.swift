import Foundation

struct BubbleDragStateMachine {
    enum Phase: Equatable {
        case idle
        case pending(bubbleId: String)
        case active(bubbleId: String)
    }

    private(set) var phase: Phase = .idle

    private let pendingThreshold: CGFloat = 8
    private let activeThreshold: CGFloat = 20

    mutating func dragChanged(bubbleId: String, translation: CGSize) {
        let distance = hypot(translation.width, translation.height)

        switch phase {
        case .idle:
            if distance > pendingThreshold {
                phase = .pending(bubbleId: bubbleId)
            }
        case .pending(let id):
            if distance > activeThreshold {
                phase = .active(bubbleId: id)
            }
        case .active:
            break
        }
    }

    @discardableResult
    mutating func dragEnded() -> String? {
        let result: String?
        if case .active(let id) = phase {
            result = id
        } else {
            result = nil
        }
        phase = .idle
        return result
    }

    mutating func cancel() {
        phase = .idle
    }
}
