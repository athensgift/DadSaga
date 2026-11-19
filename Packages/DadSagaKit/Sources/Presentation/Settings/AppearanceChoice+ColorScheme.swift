import SwiftUI

extension AppearanceChoice {
    /// `nil` follows the iPhone.
    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}
