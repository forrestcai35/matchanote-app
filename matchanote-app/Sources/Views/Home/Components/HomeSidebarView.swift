import SwiftUI

struct HomeSidebarView: View {
    @EnvironmentObject private var storageManager: StorageManager
    @Environment(\.colorScheme) private var colorScheme

    // Bindings from parent
    @Binding var searchText: String
    @Binding var selectedItem: String
    @Binding var selectedSubject: String?
    @Binding var showingSettings: Bool
    @Binding var currentFolderID: UUID?
    @Binding var folderPath: [Folder]
    @Binding var isSidebarVisible: Bool

    // Subject editing state
    @Binding var editingSubjectID: UUID?
    @Binding var editingSubjectName: String
    @Binding var isNewSubject: Bool
    @Binding var showDuplicateSubjectAlert: Bool
    @FocusState.Binding var subjectNameFieldFocused: Bool

    let isCompactWidth: Bool
    let shouldOverlaySidebar: Bool
    let sidebarItems: [SidebarItem]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header with logo and settings
            HStack(spacing: isCompactWidth ? 4 : 8) {
                Image("Logo")
                    .resizable()
                    .scaledToFit()
                    .frame(height: isCompactWidth ? 20 : 24)

                Text("Matcha")
                    .font(.system(isCompactWidth ? .title3 : .title, design: .serif))
                    .fontWeight(.bold)
                    .foregroundColor(
                        colorScheme == .dark ? Color.matchabrown_dark : Color.matchabrown_light)

                Spacer()

                // Settings button in sidebar
                Button(action: {
                    showingSettings = true
                }) {
                    Image(systemName: "gear")
                        .fontWeight(.medium)
                        .font(.system(size: isCompactWidth ? 14 : 16))
                        .foregroundStyle(
                            colorScheme == .dark
                                ? Color.matchabrown_dark : Color.matchabrown_light)
                }
            }
            .padding(.horizontal, isCompactWidth ? 12 : 16)
            .padding(.top, 15)

            searchBar
            sidebarList
            subjectsList

            Spacer()
        }
    }

    // MARK: - Component Views
    private var searchBar: some View {
        HomeSearchBar(text: $searchText)
            .padding(.horizontal, isCompactWidth ? 12 : 16)
            .padding(.top, 15)
    }

    private var sidebarList: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(sidebarItems) { item in
                HomeSidebarItem(
                    item: item,
                    isSelected: selectedItem == item.id,
                    onSelect: {
                        selectedItem = item.id
                        selectedSubject = nil
                        if item.id == "documents" {
                            currentFolderID = nil
                            folderPath = []
                        }
                        // Auto-close sidebar on small screens after selection
                        if shouldOverlaySidebar {
                            withAnimation {
                                isSidebarVisible = false
                            }
                        }
                    }
                )
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 15)
    }

    private var subjectsList: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header with "Subject" label and plus button
            HStack {
                Text("Subjects")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)
                    .padding(.leading, 18)

                Spacer()

                Button(action: createNewSubject) {
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(
                            colorScheme == .dark ? Color.matchabrown_dark : Color.matchabrown_light
                        )
                        .frame(width: 32, height: 32)
                        .contentShape(Rectangle())
                }
                .buttonStyle(PlainButtonStyle())
                .padding(.trailing, 10)
            }
            .padding(.top, 16)

            // Subjects list
            if !storageManager.subjects.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(storageManager.subjects.filter { !$0.name.isEmpty || $0.id == editingSubjectID }.sorted(by: { $0.dateCreated > $1.dateCreated })) { subject in
                        if editingSubjectID == subject.id {
                            subjectEditView(subject: subject)
                        } else {
                            subjectItemView(subject: subject)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .alert("Duplicate Subject Name", isPresented: $showDuplicateSubjectAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("A subject with this name already exists. Please choose a different name.")
        }
    }

    // MARK: - Subject Item Views
    private func subjectEditView(subject: Subject) -> some View {
        HStack(spacing: 12) {
            Circle()
                .fill(subject.color)
                .frame(width: 8, height: 8)

            TextField("Subject name", text: $editingSubjectName)
                .font(.system(size: 14, weight: .medium))
                .textFieldStyle(PlainTextFieldStyle())
                .focused($subjectNameFieldFocused)
                .onAppear {
                    editingSubjectName = subject.name
                    subjectNameFieldFocused = true
                }
                .onSubmit {
                    saveSubjectEdit(subject)
                }
                .onChange(of: subjectNameFieldFocused) { _, isFocused in
                    // When focus is lost, save or delete
                    if !isFocused && editingSubjectID == subject.id {
                        saveSubjectEdit(subject)
                    }
                }

            Spacer()
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(
                    colorScheme == .dark
                        ? Color.matchalight_dark.opacity(0.1)
                        : Color.matchalight_light.opacity(0.1)
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(
                    colorScheme == .dark ? Color.matchalight_dark : Color.matchalight_light,
                    lineWidth: 2
                )
        )
        .padding(.horizontal, 18)
    }

    private func subjectItemView(subject: Subject) -> some View {
        Button(action: {
            selectedItem = ""
            selectedSubject = subject.name
            // Auto-close sidebar on small screens after selection
            if shouldOverlaySidebar {
                withAnimation {
                    isSidebarVisible = false
                }
            }
        }) {
            HStack(spacing: 12) {
                Circle()
                    .fill(subject.color)
                    .frame(width: 8, height: 8)

                Text(subject.name)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(
                        selectedSubject == subject.name
                            ? (colorScheme == .dark ? Color.matchabrown_dark : Color.matchabrown_light)
                            : (colorScheme == .dark ? Color.matchabrown_dark.opacity(0.8) : Color.matchabrown_light.opacity(0.8))
                    )

                Spacer()
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(
                        selectedSubject == subject.name
                            ? subject.color.opacity(0.15)
                            : Color.clear
                    )
            )
            .padding(.horizontal, 18)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
        .contextMenu {
            Button(action: {
                editingSubjectID = subject.id
                editingSubjectName = subject.name
                isNewSubject = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    subjectNameFieldFocused = true
                }
            }) {
                Label("Rename", systemImage: "pencil")
            }

            Menu {
                ForEach([Color.blue, Color.red, Color.green, Color.yellow, Color.orange, Color.purple, Color.pink], id: \.self) { color in
                    Button(action: {
                        var updatedSubject = subject
                        updatedSubject.color = color
                        _ = storageManager.saveSubject(updatedSubject)
                    }) {
                        HStack {
                            Circle()
                                .fill(color)
                                .frame(width: 12, height: 12)
                            Text(colorName(for: color))
                        }
                    }
                }
            } label: {
                Label("Change Color", systemImage: "paintpalette")
            }

            Divider()

            Button(role: .destructive, action: {
                storageManager.deleteSubject(withID: subject.id)
            }) {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    // MARK: - Helper Functions
    private func createNewSubject() {
        let colors: [Color] = [.blue, .red, .green, .yellow, .orange, .purple, .pink]
        let randomColor = colors.randomElement() ?? .blue

        let newSubject = Subject(
            name: "",
            color: randomColor,
            dateCreated: Date()
        )
        let saved = storageManager.saveSubject(newSubject)

        editingSubjectID = saved.id
        editingSubjectName = ""
        isNewSubject = true

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            subjectNameFieldFocused = true
        }
    }

    private func saveSubjectEdit(_ subject: Subject) {
        let trimmedName = editingSubjectName.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmedName.isEmpty {
            if isNewSubject {
                storageManager.deleteSubject(withID: subject.id)
            }
            editingSubjectID = nil
            isNewSubject = false
            return
        }

        // Check for duplicate names (case-insensitive)
        let isDuplicate = storageManager.subjects.contains { existingSubject in
            existingSubject.id != subject.id &&
            existingSubject.name.lowercased() == trimmedName.lowercased()
        }

        if isDuplicate {
            showDuplicateSubjectAlert = true
            if isNewSubject {
                storageManager.deleteSubject(withID: subject.id)
            }
            editingSubjectID = nil
            isNewSubject = false
            return
        }

        var updatedSubject = subject
        updatedSubject.name = trimmedName
        _ = storageManager.saveSubject(updatedSubject)

        editingSubjectID = nil
        isNewSubject = false
    }

    private func colorName(for color: Color) -> String {
        switch color {
        case .blue: return "Blue"
        case .red: return "Red"
        case .green: return "Green"
        case .yellow: return "Yellow"
        case .orange: return "Orange"
        case .purple: return "Purple"
        case .pink: return "Pink"
        default: return "Color"
        }
    }
}
