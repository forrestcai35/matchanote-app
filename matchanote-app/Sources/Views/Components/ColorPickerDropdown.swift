import SwiftUI

// MARK: - Color Picker Dropdown Component
struct ColorPickerDropdown: View {
  @Binding var selectedColor: Color
  @Binding var customColors: [Color]
  var onColorSelected: (Color) -> Void
  @Environment(\.colorScheme) private var colorScheme
  @State private var currentPage: Int = 0
  @State private var isExpanded: Bool = false

  // Track which button opened the picker
  enum PickerSource {
    case paintpalette  // Adds to toolbar
    case plusButton    // Adds to dropdown palette
  }
  @State private var pickerSource: PickerSource = .plusButton

  // Custom color picker state (HSB values)
  @State private var hue: Double = 0.5
  @State private var saturation: Double = 1.0
  @State private var brightness: Double = 1.0

  // Define predefined color pages
  private let predefinedColors: [Color] = [
    // Row 1
    .yellow, .orange, .red, Color(red: 1.0, green: 0.0, blue: 1.0), // magenta
    Color(red: 0.5, green: 1.0, blue: 0.0), // lime
    .green, .purple, Color(red: 0.5, green: 0.0, blue: 0.5), // dark purple
    // Row 2
    Color(red: 0.0, green: 0.5, blue: 0.5), // teal
    .blue, Color(red: 0.25, green: 0.41, blue: 0.88), // royal blue
    Color(red: 0.0, green: 0.0, blue: 0.5), // navy
    .white, .gray, .black, Color(red: 0.6, green: 0.4, blue: 0.2) // brown
  ]

  // Computed property to combine predefined and custom colors into pages
  private var colorPages: [[Color]] {
    var pages: [[Color]] = []
    var allColors = predefinedColors + customColors

    while !allColors.isEmpty {
      let pageColors = Array(allColors.prefix(15))
      pages.append(pageColors)
      allColors = Array(allColors.dropFirst(15))
    }

    return pages.isEmpty ? [[]] : pages
  }

  private var customColor: Color {
    Color(hue: hue, saturation: saturation, brightness: brightness)
  }

  var body: some View {
    VStack(spacing: 12) {
      // Header with title and icon
      HStack(spacing: 8) {
        Text("Colors")
          .font(.jost(.subheadline()))
          .foregroundColor(colorScheme == .dark ? .white : .black)

        Spacer()

        Button(action: {
          pickerSource = .paintpalette
          withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            isExpanded.toggle()
          }
        }) {
          Image(systemName: "paintpalette.fill")
            .font(.system(size: 18))
            .foregroundColor(.matchalight_dark)
            .rotationEffect(.degrees(isExpanded ? 180 : 0))
            .frame(width: 44, height: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
      }
      .padding(.horizontal, 16)
      .padding(.top, 16)

      // Color grid - two rows with smooth paging
      TabView(selection: $currentPage) {
        ForEach(0..<colorPages.count, id: \.self) { pageIndex in
          VStack(spacing: 12) {
            // Row 1
            HStack(spacing: 12) {
              ForEach(0..<8, id: \.self) { col in
                colorSwatch(at: col, page: pageIndex)
              }
            }

            // Row 2 (7 colors + plus button)
            HStack(spacing: 12) {
              ForEach(8..<15, id: \.self) { col in
                colorSwatch(at: col, page: pageIndex)
              }

              // Plus button to expand custom color picker
              Button(action: {
                pickerSource = .plusButton
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                  isExpanded.toggle()
                }
              }) {
                ZStack {
                  Circle()
                    .stroke(Color.matchalight_dark, style: StrokeStyle(lineWidth: 2, dash: [4, 4]))
                    .frame(width: 32, height: 32)

                  Image(systemName: isExpanded ? "minus" : "plus")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.matchalight_dark)
                }
              }
              .buttonStyle(PlainButtonStyle())
              .contentShape(Circle().size(width: 40, height: 40))
            }
          }
          .padding(.horizontal, 16)
          .tag(pageIndex)
        }
      }
      .tabViewStyle(.page(indexDisplayMode: .never))
      .frame(height: 88)

      // Custom color picker section (expanded)
      if isExpanded {
        VStack(spacing: 16) {
          Divider()

          // 2D Color Picker Area
          GeometryReader { geometry in
            ZStack(alignment: .topLeading) {
              // Background gradient (saturation + brightness)
              LinearGradient(
                gradient: Gradient(colors: [
                  .white,
                  Color(hue: hue, saturation: 1.0, brightness: 1.0)
                ]),
                startPoint: .leading,
                endPoint: .trailing
              )
              .overlay(
                LinearGradient(
                  gradient: Gradient(colors: [.clear, .black]),
                  startPoint: .top,
                  endPoint: .bottom
                )
              )
              .cornerRadius(8)

              // Selector circle
              Circle()
                .strokeBorder(Color.white, lineWidth: 3)
                .background(Circle().fill(customColor))
                .frame(width: 24, height: 24)
                .shadow(color: Color.black.opacity(0.3), radius: 2)
                .position(
                  x: saturation * geometry.size.width,
                  y: (1 - brightness) * geometry.size.height
                )
            }
            .contentShape(Rectangle())
            .gesture(
              DragGesture(minimumDistance: 0)
                .onChanged { value in
                  saturation = min(max(value.location.x / geometry.size.width, 0), 1)
                  brightness = 1 - min(max(value.location.y / geometry.size.height, 0), 1)
                }
            )
          }
          .frame(height: 180)
          .padding(.horizontal, 16)

          // Improved Hue slider with rainbow gradient
          VStack(spacing: 8) {
            HStack {
              Text("Hue")
                .font(.jost(.caption2()))
                .foregroundColor(.gray)
              Spacer()
              Circle()
                .fill(customColor)
                .frame(width: 24, height: 24)
                .overlay(
                  Circle()
                    .strokeBorder(Color.gray.opacity(0.3), lineWidth: 1)
                )
            }

            // Custom rainbow hue slider
            GeometryReader { geometry in
              ZStack(alignment: .leading) {
                // Rainbow gradient background
                LinearGradient(
                  gradient: Gradient(colors: [
                    Color(hue: 0.0, saturation: 1.0, brightness: 1.0),   // Red
                    Color(hue: 0.17, saturation: 1.0, brightness: 1.0),  // Yellow
                    Color(hue: 0.33, saturation: 1.0, brightness: 1.0),  // Green
                    Color(hue: 0.5, saturation: 1.0, brightness: 1.0),   // Cyan
                    Color(hue: 0.67, saturation: 1.0, brightness: 1.0),  // Blue
                    Color(hue: 0.83, saturation: 1.0, brightness: 1.0),  // Magenta
                    Color(hue: 1.0, saturation: 1.0, brightness: 1.0)    // Red
                  ]),
                  startPoint: .leading,
                  endPoint: .trailing
                )
                .frame(height: 8)
                .cornerRadius(4)

                // Draggable thumb indicator
                Circle()
                  .fill(Color(hue: hue, saturation: 1.0, brightness: 1.0))
                  .frame(width: 20, height: 20)
                  .overlay(
                    Circle()
                      .strokeBorder(Color.white, lineWidth: 3)
                  )
                  .shadow(color: Color.black.opacity(0.3), radius: 2)
                  .offset(x: hue * (geometry.size.width - 20))
                  .gesture(
                    DragGesture(minimumDistance: 0)
                      .onChanged { value in
                        let newHue = min(max(value.location.x / geometry.size.width, 0), 1)
                        hue = newHue
                      }
                  )
              }
              .frame(height: 20)
              .contentShape(Rectangle())
              .gesture(
                DragGesture(minimumDistance: 0)
                  .onChanged { value in
                    let newHue = min(max(value.location.x / geometry.size.width, 0), 1)
                    hue = newHue
                  }
              )
            }
            .frame(height: 20)
          }
          .padding(.horizontal, 16)

          // Add button
          Button(action: {
            if pickerSource == .paintpalette {
              // Add to toolbar
              onColorSelected(customColor)
            } else {
              // Add to dropdown palette
              addCustomColorToDropdown()
            }
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
              isExpanded = false
            }
          }) {
            Text(pickerSource == .paintpalette ? "Add to Toolbar" : "Add to Palette")
              .font(.jost(.caption()))
              .foregroundColor(.white)
              .frame(maxWidth: .infinity)
              .padding(.vertical, 10)
              .background(Color.matchalight_dark)
              .cornerRadius(8)
          }
          .buttonStyle(PlainButtonStyle())
          .padding(.horizontal, 16)
          .padding(.bottom, 8)
        }
        .transition(.opacity)
      }

      // Pagination dots (if multiple pages in the future)
      if colorPages.count > 1 {
        HStack(spacing: 6) {
          ForEach(0..<colorPages.count, id: \.self) { index in
            Button(action: {
              withAnimation(.easeInOut(duration: 0.2)) {
                currentPage = index
              }
            }) {
              Circle()
                .fill(currentPage == index ? Color.matchalight_dark : Color.gray.opacity(0.3))
                .frame(width: 8, height: 8)
            }
            .buttonStyle(PlainButtonStyle())
          }
        }
        .padding(.bottom, 16)
      } else {
        Spacer().frame(height: 8)
      }
    }
    .frame(width: 360)
    .background(colorScheme == .dark ? Color(.systemGray6) : Color.white)
  }

  // Add custom color to the dropdown palette
  private func addCustomColorToDropdown() {
    customColors.append(customColor)
  }

  @ViewBuilder
  private func colorSwatch(at index: Int, page: Int) -> some View {
    if index < colorPages[page].count {
      let color = colorPages[page][index]
      let isSelected = colorsAreEqual(selectedColor, color)

      Button(action: {
        selectedColor = color
        onColorSelected(color)
      }) {
        ZStack {
          Circle()
            .fill(color)
            .frame(width: 32, height: 32)

          // Border for white color visibility
          if color == .white {
            Circle()
              .strokeBorder(Color.gray.opacity(0.3), lineWidth: 1)
              .frame(width: 32, height: 32)
          }

          // Checkmark for selected color
          if isSelected {
            Image(systemName: "checkmark")
              .font(.system(size: 12, weight: .bold))
              .foregroundColor(colorIsDark(color) ? .white : .black)
              .shadow(color: Color.black.opacity(0.2), radius: 1, x: 0, y: 1)
          }
        }
      }
      .buttonStyle(PlainButtonStyle())
    } else {
      Circle()
        .fill(Color.clear)
        .frame(width: 32, height: 32)
    }
  }

  // Helper to compare colors
  private func colorsAreEqual(_ color1: Color, _ color2: Color) -> Bool {
    let uiColor1 = UIColor(color1)
    let uiColor2 = UIColor(color2)

    var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
    var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0

    uiColor1.getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
    uiColor2.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)

    return abs(r1 - r2) < 0.01 && abs(g1 - g2) < 0.01 && abs(b1 - b2) < 0.01
  }

  // Helper to determine if color is dark (for checkmark visibility)
  private func colorIsDark(_ color: Color) -> Bool {
    let uiColor = UIColor(color)
    var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
    uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)

    // Calculate luminance
    let luminance = 0.299 * red + 0.587 * green + 0.114 * blue
    return luminance < 0.5
  }
}
