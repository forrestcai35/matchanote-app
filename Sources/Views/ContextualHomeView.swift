// ... existing code ...

// Add a helper view for folder grid items
public struct GridFolderItemView: View {
  let folder: Folder
  @Environment(\.colorScheme) private var colorScheme

  private func itemShadow(in colorScheme: ColorScheme) -> Color {
    return colorScheme == .dark ? Color.white.opacity(0.4) : Color.black.opacity(0.2)
  }

  public var body: some View {
    VStack(spacing: 2) {
      // Folder card
      ZStack {
        // Folder image instead of background
        Image("folder")
          .resizable()
          .scaledToFill()
          .frame(width: 112, height: 89.6)
          .clipped()

        // Favorite indicator
        Image(systemName: folder.isFavorite ? "star.fill" : "star")
          .foregroundColor(folder.isFavorite ? .yellow : .gray)
          .padding(6)
          .frame(maxWidth: 105.6, maxHeight: 62.4, alignment: .topTrailing)
      }
      // Folder title
      Text(folder.name)
        .padding(.top, 4)
        .lineLimit(1)
        .truncationMode(.tail)
        .frame(width: 102.4)
        .multilineTextAlignment(.center)
        .fontWeight(.medium)
        .font(.subheadline)
      // Date
      Text(folder.dateModified, style: .date)
        .padding(.bottom, 4)
        .font(.caption)
        .foregroundColor(.secondary)
        .frame(width: 102.4)
        .multilineTextAlignment(.center)
    }
    .padding(.top, 38.4)
    .frame(width: 102.4)
    .contentShape(Rectangle())
  }
}

// Add a helper view for grid items
public struct GridItemView: View {
  let note: Note
  @Environment(\.colorScheme) private var colorScheme

  private func itemShadow(in colorScheme: ColorScheme) -> Color {
    return colorScheme == .dark ? Color.white.opacity(0.4) : Color.black.opacity(0.2)
  }

  public var body: some View {
    VStack(spacing: 2) {
      // Note card
      ZStack {
        if note.noteType == .written {
          RoundedRectangle(cornerRadius: 8)
            .fill(note.color)
            .frame(width: 102.4, height: 128)
            .shadow(
              color: itemShadow(in: colorScheme),
              radius: 4,
              x: 0,
              y: 2
            )

          Image(systemName: "pencil.tip")
            .font(.system(size: 25.6))
            .foregroundColor(Color.white.opacity(0.3))
            .offset(x: 0, y: -19.2)

        } else if note.noteType == .text {

          RoundedRectangle(cornerRadius: 0)
            .fill(note.color)
            .frame(width: 102.4, height: 128)
            .shadow(
              color: itemShadow(in: colorScheme),
              radius: 5,
              x: 0,
              y: 2
            )
          Image(systemName: "text.alignleft")
            .font(.system(size: 25.6))
            .foregroundColor(Color.white.opacity(0.3))
            .offset(x: 0, y: -19.2)
        }

        Image(systemName: note.isFavorite ? "star.fill" : "star")
          .foregroundColor(note.isFavorite ? .yellow : .gray)
          .padding(6)
          .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)

        Image(systemName: noteTypeIcon(note.noteType))
          .foregroundColor(.white)
          .padding(5)
          .background(Color.black.opacity(0.3))
          .clipShape(Circle())
          .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
          .padding(6)
      }

      Text(note.title)
        .padding(.top, 4)
        .lineLimit(1)
        .truncationMode(.tail)
        .frame(width: 102.4)
        .multilineTextAlignment(.center)
        .fontWeight(.medium)
        .font(.subheadline)

      Text(note.dateModified, style: .date)
        .padding(.bottom, 4)
        .font(.caption)
        .foregroundColor(.secondary)
        .frame(width: 102.4)
        .multilineTextAlignment(.center)
    }
    .frame(width: 102.4)
    .contentShape(Rectangle())
  }

  // ... existing code ...
}

// ... existing code ...
