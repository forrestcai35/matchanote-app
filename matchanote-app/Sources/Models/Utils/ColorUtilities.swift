import SwiftUI

// MARK: - Premium Gradients
extension LinearGradient {
    /// Premium gradient used for Chat/Study toggle and premium model names
    static let premiumGradient = LinearGradient(
        colors: [
            Color(red: 0.4, green: 0.7, blue: 0.3),  // Matcha green
            Color(red: 0.3, green: 0.6, blue: 0.9)   // Premium blue
        ],
        startPoint: .leading,
        endPoint: .trailing
    )
    
    /// Premium gradient background (with opacity for backgrounds)
    static let premiumGradientBackground = LinearGradient(
        colors: [
            Color(red: 0.4, green: 0.7, blue: 0.3).opacity(0.15),
            Color(red: 0.3, green: 0.6, blue: 0.9).opacity(0.15)
        ],
        startPoint: .leading,
        endPoint: .trailing
    )
    
    /// Quiz option gradient (green variant)
    static let quizGradient = LinearGradient(
        colors: [
            Color(red: 0.4, green: 0.7, blue: 0.3),   // Matcha green
            Color(red: 0.35, green: 0.65, blue: 0.28) // Darker green
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    /// Flashcards option gradient (blue variant)
    static let flashcardsGradient = LinearGradient(
        colors: [
            Color(red: 0.3, green: 0.6, blue: 0.9),   // Premium blue
            Color(red: 0.25, green: 0.55, blue: 0.85) // Darker blue
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

// MARK: - Premium Colors
extension Color {
    /// Matcha green color used in gradients
    static let matchaGreen = Color(red: 0.4, green: 0.7, blue: 0.3)
    
    /// Premium blue color used in gradients
    static let premiumBlue = Color(red: 0.3, green: 0.6, blue: 0.9)
}

// MARK: - Color Conversion Helpers

public func colorToHexString(_ color: Color) -> String {
  // Convert SwiftUI Color to UIColor and then to hex string
  let uiColor = UIColor(color)
  var red: CGFloat = 0
  var green: CGFloat = 0
  var blue: CGFloat = 0
  var alpha: CGFloat = 0
  
  uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
  
  let rgb = Int(red * 255) << 16 | Int(green * 255) << 8 | Int(blue * 255) << 0
  return String(format: "#%06x", rgb)
}

public func hexStringToColor(_ hexString: String) -> Color {
  let hex = hexString.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
  var int: UInt64 = 0
  Scanner(string: hex).scanHexInt64(&int)
  let a, r, g, b: UInt64
  switch hex.count {
  case 3: // RGB (12-bit)
    (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
  case 6: // RGB (24-bit)
    (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
  case 8: // ARGB (32-bit)
    (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
  default:
    return Color.white // Default fallback
  }
  
  return Color(
    red: Double(r) / 255,
    green: Double(g) / 255,
    blue: Double(b) / 255,
    opacity: Double(a) / 255
  )
}
