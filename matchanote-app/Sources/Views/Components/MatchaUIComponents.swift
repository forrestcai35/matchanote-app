import SwiftUI

// MARK: - Matcha UI Constants
struct MatchaUI {
    // Animation constants
    struct Animation {
        static let springResponse: Double = 0.4
        static let springDamping: Double = 0.8
        static let enterDelay: Double = 0.1
        static let staggerDelay: Double = 0.1

        static var spring: SwiftUI.Animation {
            .spring(response: springResponse, dampingFraction: springDamping)
        }

        static func springWithDelay(_ delay: Double) -> SwiftUI.Animation {
            spring.delay(delay)
        }
    }

    // Styling constants
    struct Style {
        static let cardCornerRadius: Double = 16
        static let itemCornerRadius: Double = 12
        static let cardPadding: Double = 20
        static let sectionSpacing: Double = 32
        static let itemSpacing: Double = 16
    }
}
