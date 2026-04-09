import SwiftUI

// MARK: - Consolidated App Icon
struct AppIcon: View {
  let name: String
  var color: Color? = nil
  var size: CGFloat? = nil

  @ViewBuilder
  var body: some View {
    let base = Image(name)
      .renderingMode(.template)
      .resizable()
      .aspectRatio(contentMode: .fit)

    if let size = size, let color = color {
      base
        .frame(width: size, height: size)
        .foregroundColor(color)
    } else if let size = size {
      base
        .frame(width: size, height: size)
    } else if let color = color {
      base
        .foregroundColor(color)
    } else {
      base
    }
  }
}

// Convenience function
@ViewBuilder
func appIcon(_ name: String, color: Color? = nil, size: CGFloat? = nil) -> some View {
  AppIcon(name: name, color: color, size: size)
}


