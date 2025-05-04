import SwiftUI


struct NewWrittenNoteView: View {
  @Environment(\.dismiss) private var dismiss
  @Environment(\.colorScheme) private var colorScheme

  @State private var title: String = "New Note"
  @State private var subject: String = ""
  @State private var paperColor: PaperColor = .white
  @State private var paperStyle: PaperStyle = .blank
  @State private var noteColor: Color = .matchalight_light

  var onSave: (Note) -> Void

  var body: some View {
    NavigationView {
      Form {
        Section(header: Text("Note Information")) {
          TextField("Title", text: $title)
        }

        Section(header: Text("Paper Style")) {


          Picker("Paper Style", selection: $paperStyle) {
            ForEach(PaperStyle.allCases, id: \.self) { style in
              Text(style.rawValue.capitalized)
            }
          }
        }
          Picker("Paper Color", selection: $paperColor) {
            ForEach(PaperColor.allCases, id: \.self) { color in
              Text(color.rawValue.capitalized)
            }
          }
        

        Section {
          Button("Create Note") {
            let newNote = Note(
              title: title,
              subject: subject,
              color: noteColor,
              dateCreated: Date(),
              dateModified: Date(),
              content: "",
              noteType: .written,
              paperColor: paperColor,
              paperStyle: paperStyle
            )
            onSave(newNote)
            dismiss()
          }
          .frame(maxWidth: .infinity)
          .foregroundColor(colorScheme == .dark ? Color.matchabrown_dark : Color.matchabrown_light)
        }
      }
      .navigationTitle("New Written Note")
      .navigationBarItems(
        trailing: Button("Cancel") {
          dismiss()
        })
    }
  }
}

struct NewFolderView: View {
  @Environment(\.dismiss) private var dismiss
  @Environment(\.colorScheme) private var colorScheme

  @State private var name: String = "New Folder"
  @State private var folderColor: Color = .blue

  var parentFolderID: UUID?
  var onSave: (Folder) -> Void

  var body: some View {
    NavigationView {
      Form {
        Section(header: Text("Folder Information")) {
          TextField("Name", text: $name)
        }


        Section {
          Button("Create Folder") {
            let newFolder = Folder(
              name: name,
              color: folderColor,
              parentID: parentFolderID,
              dateCreated: Date()
            )
            onSave(newFolder)
            dismiss()
          }
          .frame(maxWidth: .infinity)
          .foregroundColor(colorScheme == .dark ? Color.matchabrown_dark : Color.matchabrown_light)
        }
      }
      .navigationTitle("New Folder")
      .navigationBarItems(
        trailing: Button("Cancel") {
          dismiss()
        })
    }
  }
}


