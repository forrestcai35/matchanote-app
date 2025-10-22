import SwiftUI
// MARK: - Header "+ New" Button
extension HomeView {
    var headerNewButton: some View {
        Menu {
            // Note creation options
            Button {
                showNewWrittenNoteView = true
            } label: {
                Label("Note", systemImage: "pencil")
            }

            // Folder creation option
            Button {
                showNewFolderView = true
            } label: {
                Label("Folder", systemImage: "folder")
            }


            // Upload
            Button {
                showingFileImporter = true
            } label: {
                Label("Upload", systemImage: "arrow.up.doc")
            }

        } label: {
            if isCompactWidth {
                // Icon-only on compact screens
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.matchalight_light.opacity(0.2), Color.matchalight_light.opacity(0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 32, height: 32)
                        .aspectRatio(1, contentMode: .fit)
                    
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.matchalight_light)
                }
                .frame(width: 32, height: 32)
            } else {
                // Full button on larger screens
                HStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Color.matchalight_light.opacity(0.2), Color.matchalight_light.opacity(0.1)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 28, height: 28)
                        
                        Image(systemName: "plus")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.matchalight_light)
                    }
                    
                    Text("New")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 16)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color(.systemBackground))
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(Color(.systemGray5), lineWidth: 1)
                        )
                )
            }
        }
        .buttonStyle(PlainButtonStyle())
        .sheet(isPresented: $showNewWrittenNoteView) {
            NewWrittenNoteView(
                onSave: { newNote in
                    // Add to current folder if we're in one
                    if let currentFolderID = currentFolderID,
                        let folderIndex = storageManager.folders.firstIndex(where: {
                            $0.id == currentFolderID
                        })
                    {
                        var updatedFolder = storageManager.folders[folderIndex]
                        updatedFolder.addNote(noteID: newNote.id)
                        _ = storageManager.saveFolder(updatedFolder)
                    }
                    let savedNote = storageManager.saveNote(newNote)
                    TabManager.shared.openTab(note: savedNote)
                    selectedNote = savedNote
                },
                subject: selectedSubject
            )
        }
        .sheet(isPresented: $showNewFolderView) {
            NewFolderView(
                parentFolderID: currentFolderID,
                onSave: { newFolder in
                    _ = storageManager.saveFolder(newFolder)
                }
            )
        }
        .fileImporter(
            isPresented: $showingFileImporter,
            allowedContentTypes: [.pdf, .image, .matchaNote],
            allowsMultipleSelection: true
        ) { result in
            do {
                let urls = try result.get()
                handleImportedFiles(urls)
            } catch {
                print("Error importing file: \(error)")
            }
        }
    }
}