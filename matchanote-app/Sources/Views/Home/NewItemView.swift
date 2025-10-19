import SwiftUI

struct NewWrittenNoteView: View {
  @Environment(\.dismiss) private var dismiss
  @Environment(\.colorScheme) private var colorScheme
  @State private var title: String = "New Note"
  @State private var paperColor: PaperColor = .white
  @State private var paperStyle: PaperStyle = .blank
  @State private var paperSize: PaperSize = .a4
  @State private var noteColor: Color = .matchalight_light

  var onSave: (Note) -> Void

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(spacing: 16) {
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
                .frame(width: 64, height: 64)
              
              Image(systemName: "pencil.and.outline")
                .font(.system(size: 28, weight: .medium))
                .foregroundColor(.matchalight_light)
            }
            
            Text("Create New Note")
              .font(.title2)
              .fontWeight(.semibold)
              .foregroundColor(.primary)
          }
          .padding(.top, 12)
          
          // Title input
          VStack(alignment: .leading, spacing: 8) {
            Text("Note Title")
              .font(.headline)
              .foregroundColor(.primary)
            
            TextField("Enter note title", text: $title)
              .textFieldStyle(ModernTextFieldStyle())
          }
          
          // Paper style selection
          VStack(alignment: .leading, spacing: 12) {
            Text("Paper Style")
              .font(.headline)
              .foregroundColor(.primary)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 2), spacing: 8) {
              ForEach(PaperStyle.allCases, id: \.self) { style in
                PaperStyleCard(
                  style: style,
                  isSelected: paperStyle == style,
                  onTap: { paperStyle = style }
                )
              }
            }
          }
          
          // Paper options side by side
          HStack(alignment: .top, spacing: 16) {
            // Paper color
            VStack(alignment: .leading, spacing: 12) {
              Text("Paper Color")
                .font(.headline)
                .foregroundColor(.primary)

              HStack(spacing: 12) {
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

            // Paper size
            VStack(alignment: .leading, spacing: 12) {
              Text("Paper Size")
                .font(.headline)
                .foregroundColor(.primary)

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
            .frame(maxWidth: .infinity, alignment: .leading)
          }
          
          // Create button
          Button(action: createNote) {
            HStack {
              Image(systemName: "plus.circle.fill")
              Text("Create Note")
                .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
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
          .padding(.top, 8)
          
          Spacer(minLength: 10)
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
          .foregroundColor(.secondary)
        }
      }
    }
    .presentationDetents([.large])
    .presentationDragIndicator(.visible)
  }
  
  private func createNote() {
    let newNote = Note(
      title: title,
      color: noteColor,
      dateCreated: Date(),
      dateModified: Date(),
      content: "",
      noteType: .written,
      paperColor: paperColor,
      paperStyle: paperStyle,
      paperSize: paperSize
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
  let isSelected: Bool
  let onTap: () -> Void
  
  var body: some View {
    Button(action: onTap) {
      VStack(spacing: 8) {
        ZStack {
          RoundedRectangle(cornerRadius: 8)
            .fill(paperColorForStyle(style))
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
          .font(.caption)
          .fontWeight(.medium)
          .foregroundColor(.primary)
      }
    }
    .buttonStyle(PlainButtonStyle())
  }
  
  private func paperColorForStyle(_ style: PaperStyle) -> Color {
    switch style {
    case .blank, .grid, .dotted, .lined:
      return .white
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
              .font(.title2)
              .fontWeight(.semibold)
              .foregroundColor(.primary)
          }
          .padding(.top, 20)
          
          // Folder name input
          VStack(alignment: .leading, spacing: 8) {
            Text("Folder Name")
              .font(.headline)
              .foregroundColor(.primary)
            
            TextField("Enter folder name", text: $name)
              .textFieldStyle(ModernTextFieldStyle())
          }
          
          
          // Create button
          Button(action: createFolder) {
            HStack {
              Image(systemName: "folder.badge.plus")
              Text("Create Folder")
                .fontWeight(.semibold)
            }
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
          .foregroundColor(.secondary)
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

