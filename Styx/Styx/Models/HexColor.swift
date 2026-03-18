import Foundation

enum HexColor {
    static func parse(_ hex: String) -> (r: Double, g: Double, b: Double) {
        let stripped = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        var int: UInt64 = 0
        Scanner(string: stripped).scanHexInt64(&int)
        switch stripped.count {
        case 6:
            return (
                r: Double((int >> 16) & 0xFF) / 255.0,
                g: Double((int >> 8) & 0xFF) / 255.0,
                b: Double(int & 0xFF) / 255.0
            )
        default:
            return (r: 0.5, g: 0.5, b: 0.5)
        }
    }
}
