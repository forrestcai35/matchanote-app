import SwiftUI

struct NewWrittenNoteView: View {
  @Environment(\.dismiss) private var dismiss
  @Environment(\.colorScheme) private var colorScheme
  @State private var title: String = "New Note"
  @State private var paperColor: PaperColor = .white
  @State private var paperStyle: PaperStyle = .blank
  @State private var paperSize: PaperSize = .a4
  @State private var paperOrientation: PaperOrientation = .portrait
  @State private var noteColor: Color = .matchalight_light

  var onSave: (Note) -> Void
  var subject: String? = nil

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(spacing: 12) {
          // Header with icon - more compact
          VStack(spacing: 8) {
            ZStack {
              Circle()
                .fill(
                  LinearGradient(
                    colors: [Color.matchalight_light.opacity(0.2), Color.matchalight_light.opacity(0.1)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                  )
                )
                .frame(width: 50, height: 50)

              Image(systemName: "pencil.and.outline")
                .font(.system(size: 22, weight: .medium))
                .foregroundColor(.matchalight_light)
            }

            Text("Create New Note")
              .font(.jost(.title3()))
              .foregroundColor(colorScheme == .dark ? Color.matchabrown_dark : Color.matchabrown_light)
          }
          .padding(.top, 8)

          // Title input
          VStack(alignment: .leading, spacing: 6) {
            Text("Note Title")
              .font(.jost(.headline()))
              .foregroundColor(colorScheme == .dark ? Color.matchabrown_dark : Color.matchabrown_light)
            
            TextField("Enter note title", text: $title)
              .textFieldStyle(ModernTextFieldStyle())
          }
          
          // Paper style selection
          VStack(alignment: .leading, spacing: 8) {
            Text("Paper Style")
              .font(.jost(.subheadline()))
              .foregroundColor(colorScheme == .dark ? Color.matchabrown_dark : Color.matchabrown_light)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 2), spacing: 6) {
              ForEach(PaperStyle.allCases, id: \.self) { style in
                PaperStyleCard(
                  style: style,
                  paperColor: paperColor,
                  isSelected: paperStyle == style,
                  onTap: { paperStyle = style }
                )
              }
            }
          }
          
          // Paper size, orientation, and color in one row
          HStack(alignment: .top, spacing: 12) {
            // Paper size
            VStack(alignment: .leading, spacing: 8) {
              Text("Size")
                .font(.jost(.subheadline()))
                .foregroundColor(colorScheme == .dark ? Color.matchabrown_dark : Color.matchabrown_light)

              Menu {
                ForEach(PaperSize.allCases, id: \.self) { size in
                  Button(action: { paperSize = size }) {
                    HStack {
                      Text(displayName(for: size))
                      if paperSize == size {
                        Image(systemName: "checkmark")
                      }
                    }
                  }
                }
              } label: {
                HStack(spacing: 8) {
                  Text(displayName(for: paperSize))
                    .foregroundColor(.primary)
                  Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.secondary)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(
                  RoundedRectangle(cornerRadius: 10)
                    .fill(Color(.systemGray6))
                    .overlay(
                      RoundedRectangle(cornerRadius: 10)
                        .stroke(Color(.systemGray4), lineWidth: 1)
                    )
                )
              }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Orientation
            VStack(alignment: .leading, spacing: 8) {
              Text("Orientation")
                .font(.jost(.subheadline()))
                .foregroundColor(colorScheme == .dark ? Color.matchabrown_dark : Color.matchabrown_light)

              HStack(spacing: 8) {
                ForEach(PaperOrientation.allCases, id: \.self) { orientation in
                  Button(action: { paperOrientation = orientation }) {
                    VStack(spacing: 4) {
                      Image(systemName: orientation == .portrait ? "rectangle.portrait" : "rectangle")
                        .font(.system(size: 20))
                        .foregroundColor(paperOrientation == orientation ? .matchalight_light : .secondary)
                      Text(orientation == .portrait ? "Portrait" : "Landscape")
                        .font(.jost(.caption2()))
                        .foregroundColor(paperOrientation == orientation ? .matchalight_light : .secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(
                      RoundedRectangle(cornerRadius: 10)
                        .fill(paperOrientation == orientation ? Color.matchalight_light.opacity(0.1) : Color(.systemGray6))
                        .overlay(
                          RoundedRectangle(cornerRadius: 10)
                            .stroke(paperOrientation == orientation ? Color.matchalight_light : Color(.systemGray4), lineWidth: paperOrientation == orientation ? 2 : 1)
                        )
                    )
                  }
                  .buttonStyle(PlainButtonStyle())
                }
              }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Paper color
            VStack(alignment: .leading, spacing: 8) {
              Text("Color")
                .font(.jost(.subheadline()))
                .foregroundColor(colorScheme == .dark ? Color.matchabrown_dark : Color.matchabrown_light)

              HStack(spacing: 8) {
                ForEach(PaperColor.allCases, id: \.self) { color in
                  PaperColorCard(
                    color: color,
                    isSelected: paperColor == color,
                    onTap: { paperColor = color }
                  )
                }
              }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
          }

          // Create button
          Button(action: createNote) {
            HStack {
              Image(systemName: "plus.circle.fill")
              Text("Create Note")
            }
            .font(.jost(.headline()))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(
              LinearGradient(
                colors: [Color.matchalight_dark, Color.matchalight_light],
                startPoint: .leading,
                endPoint: .trailing
              )
            )
            .foregroundColor(.white)
            .clipShape(RoundedRectangle(cornerRadius: 12))
          }
          .padding(.top, 4)

          Spacer(minLength: 4)
        }
        .padding(.horizontal, 20)
      }
      .scrollDisabled(true)
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .navigationBarLeading) {
          Button("Cancel") {
            dismiss()
          }
          .foregroundColor(colorScheme == .dark ? Color.matchabrown_dark : Color.matchabrown_light)
        }
      }
    }
    .presentationDetents([.large])
    .presentationDragIndicator(.visible)
  }
  
  private func createNote() {
    let newNote = Note(
      title: title,
      subject: subject ?? "",
      color: noteColor,
      dateCreated: Date(),
      dateModified: Date(),
      content: "",
      noteType: .written,
      paperColor: paperColor,
      paperStyle: paperStyle,
      paperSize: paperSize,
      paperOrientation: paperOrientation
    )
    onSave(newNote)
    dismiss()
  }
}

extension NewWrittenNoteView {
  private func displayName(for size: PaperSize) -> String {
    switch size {
    case .a4: return "A4"
    case .letter: return "Letter"
    case .legal: return "Legal"
    case .tabloid: return "Tabloid"
    }
  }
}

// MARK: - Supporting Views

struct ModernTextFieldStyle: TextFieldStyle {
  func _body(configuration: TextField<Self._Label>) -> some View {
    configuration
      .padding(.horizontal, 12)
      .padding(.vertical, 10)
      .background(
        RoundedRectangle(cornerRadius: 12)
          .fill(Color(.systemGray6))
          .overlay(
            RoundedRectangle(cornerRadius: 12)
              .stroke(Color(.systemGray4), lineWidth: 1)
          )
      )
  }
}

struct PaperStyleCard: View {
  let style: PaperStyle
  let paperColor: PaperColor
  let isSelected: Bool
  let onTap: () -> Void
  @Environment(\.colorScheme) private var colorScheme

  var body: some View {
    Button(action: onTap) {
      VStack(spacing: 8) {
        ZStack {
          RoundedRectangle(cornerRadius: 8)
            .fill(colorForPaperColor(paperColor))
            .frame(height: 48)
            .overlay(
              paperPatternForStyle(style)
            )

          if isSelected {
            RoundedRectangle(cornerRadius: 8)
              .stroke(Color.matchalight_light, lineWidth: 2)
              .frame(height: 48)
          }
        }

        Text(style.rawValue.capitalized)
          .font(.jost(.caption()))
          .foregroundColor(colorScheme == .dark ? Color.matchabrown_dark : Color.matchabrown_light)
      }
    }
    .buttonStyle(PlainButtonStyle())
  }
  
  private func colorForPaperColor(_ paperColor: PaperColor) -> Color {
    switch paperColor {
    case .white:
      return .white
    case .offwhite:
      return Color.paper_offwhite
    case .dark:
      return Color.paper_dark
    }
  }
  
  @ViewBuilder
  private func paperPatternForStyle(_ style: PaperStyle) -> some View {
    switch style {
    case .blank:
      EmptyView()
    case .grid:
      GridPattern()
    case .dotted:
      DottedPattern()
    case .lined:
      LinedPattern()
    }
  }
}

struct PaperColorCard: View {
  let color: PaperColor
  let isSelected: Bool
  let onTap: () -> Void
  
  var body: some View {
    Button(action: onTap) {
      ZStack {
        Circle()
          .fill(colorForPaperColor(color))
          .frame(width: 40, height: 40)
          .overlay(
            Circle()
              .stroke(Color(.systemGray4), lineWidth: 1)
          )
        
        if isSelected {
          Circle()
            .stroke(Color.matchalight_light, lineWidth: 2)
            .frame(width: 40, height: 40)
          
          Image(systemName: "checkmark")
            .font(.system(size: 14, weight: .bold))
            .foregroundColor(.white)
        }
      }
    }
    .buttonStyle(PlainButtonStyle())
  }
  
  private func colorForPaperColor(_ paperColor: PaperColor) -> Color {
    switch paperColor {
    case .white:
      return .white
    case .offwhite:
      return Color.paper_offwhite
    case .dark:
      return Color.paper_dark
    }
  }
}

// MARK: - Pattern Views

struct GridPattern: View {
  var body: some View {
    GeometryReader { geometry in
      Path { path in
        let spacing: CGFloat = 8
        let width = geometry.size.width
        let height = geometry.size.height
        
        // Vertical lines
        for x in stride(from: 0, through: width, by: spacing) {
          path.move(to: CGPoint(x: x, y: 0))
          path.addLine(to: CGPoint(x: x, y: height))
        }
        
        // Horizontal lines
        for y in stride(from: 0, through: height, by: spacing) {
          path.move(to: CGPoint(x: 0, y: y))
          path.addLine(to: CGPoint(x: width, y: y))
        }
      }
      .stroke(Color(.systemGray5), lineWidth: 0.5)
    }
  }
}

struct DottedPattern: View {
  var body: some View {
    GeometryReader { geometry in
      Path { path in
        let spacing: CGFloat = 8
        let width = geometry.size.width
        let height = geometry.size.height
        
        for x in stride(from: spacing, through: width - spacing, by: spacing) {
          for y in stride(from: spacing, through: height - spacing, by: spacing) {
            path.addEllipse(in: CGRect(x: x - 1, y: y - 1, width: 2, height: 2))
          }
        }
      }
      .fill(Color(.systemGray5))
    }
  }
}

struct LinedPattern: View {
  var body: some View {
    GeometryReader { geometry in
      Path { path in
        let spacing: CGFloat = 12
        let width = geometry.size.width
        let height = geometry.size.height
        
        for y in stride(from: spacing, through: height - spacing, by: spacing) {
          path.move(to: CGPoint(x: 0, y: y))
          path.addLine(to: CGPoint(x: width, y: y))
        }
      }
      .stroke(Color(.systemGray5), lineWidth: 0.5)
    }
  }
}

struct NewFolderView: View {
  @Environment(\.dismiss) private var dismiss
  @Environment(\.colorScheme) private var colorScheme

  @State private var name: String = "New Folder"

  var parentFolderID: UUID?
  var onSave: (Folder) -> Void

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(spacing: 24) {
          // Header with icon
          VStack(spacing: 12) {
            ZStack {
              Circle()
                .fill(
                  LinearGradient(
                    colors: [Color.matchalight_light.opacity(0.2), Color.matchalight_light.opacity(0.1)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                  )
                )
                .frame(width: 80, height: 80)
              
              Image(systemName: "folder.badge.plus")
                .font(.system(size: 32, weight: .medium))
                .foregroundColor(.matchalight_light)
            }
            
            Text("Create New Folder")
              .font(.jost(.title2()))
              .foregroundColor(colorScheme == .dark ? Color.matchabrown_dark : Color.matchabrown_light)
          }
          .padding(.top, 20)
          
          // Folder name input
          VStack(alignment: .leading, spacing: 8) {
            Text("Folder Name")
              .font(.jost(.headline()))
              .foregroundColor(colorScheme == .dark ? Color.matchabrown_dark : Color.matchabrown_light)
            
            TextField("Enter folder name", text: $name)
              .textFieldStyle(ModernTextFieldStyle())
          }
          
          
          // Create button
          Button(action: createFolder) {
            HStack {
              Image(systemName: "folder.badge.plus")
              Text("Create Folder")
            }
            .font(.jost(.headline()))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
                  .background(
              LinearGradient(
                colors: [Color.matchalight_dark, Color.matchalight_light],
                startPoint: .leading,
                endPoint: .trailing
              )
            )
            .foregroundColor(.white)
            .clipShape(RoundedRectangle(cornerRadius: 16))
          }
          .padding(.top, 8)
          
          Spacer(minLength: 20)
        }
        .padding(.horizontal, 24)
      }
      .scrollDisabled(true)
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .navigationBarLeading) {
          Button("Cancel") {
            dismiss()
          }
          .foregroundColor(colorScheme == .dark ? Color.matchabrown_dark : Color.matchabrown_light)
        }
      }
    }
    .presentationDetents([.large])
    .presentationDragIndicator(.visible)
  }


  private func createFolder() {
    let newFolder = Folder(
      name: name,
      parentID: parentFolderID,
      dateCreated: Date()
    )
    onSave(newFolder)
    dismiss()
  }
}

