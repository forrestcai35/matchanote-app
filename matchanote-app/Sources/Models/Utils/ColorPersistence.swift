import SwiftUI
import UIKit

/// Utility class for persisting and loading Color objects to/from UserDefaults
class ColorPersistence {
  
  // MARK: - Color to Data Conversion
  
  /// Converts a SwiftUI Color to Data for storage
  static func colorToData(_ color: Color) -> Data {
    let uiColor = UIColor(color)
    var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
    uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
    let components = [red, green, blue, alpha]
    return try! JSONEncoder().encode(components)
  }
  
  /// Converts Data back to a SwiftUI Color
  static func dataToColor(_ data: Data) -> Color? {
    guard let components = try? JSONDecoder().decode([CGFloat].self, from: data),
          components.count == 4 else { return nil }
    return Color(red: components[0], green: components[1], blue: components[2], opacity: components[3])
  }
  
  // MARK: - UserDefaults Helpers
  
  /// Saves a single color to UserDefaults
  static func saveColor(_ color: Color, forKey key: String) {
    let colorData = colorToData(color)
    UserDefaults.standard.set(colorData, forKey: key)
  }
  
  /// Loads a single color from UserDefaults
  static func loadColor(forKey key: String) -> Color? {
    guard let colorData = UserDefaults.standard.data(forKey: key),
          let color = dataToColor(colorData) else { return nil }
    return color
  }
  
  /// Saves an array of colors to UserDefaults
  static func saveColorPalette(_ colors: [Color], forKey key: String) {
    let colorData = colors.map { colorToData($0) }
    UserDefaults.standard.set(colorData, forKey: key)
  }
  
  /// Loads an array of colors from UserDefaults
  static func loadColorPalette(forKey key: String) -> [Color]? {
    guard let colorDataArray = UserDefaults.standard.array(forKey: key) as? [Data] else { return nil }
    let colors = colorDataArray.compactMap { dataToColor($0) }
    return colors.isEmpty ? nil : colors
  }
}

