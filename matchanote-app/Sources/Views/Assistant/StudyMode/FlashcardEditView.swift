import SwiftUI

struct FlashcardEditView: View {
    @EnvironmentObject private var state: AIAssistantState
    @EnvironmentObject private var storageManager: StorageManager
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    @State private var editedFlashcards: [Flashcard]
    @State private var showingRegenerateAlert = false
    @State private var isGenerating = false
    @State private var expandedFlashcardId: UUID?

    init(flashcards: [Flashcard]) {
        _editedFlashcards = State(initialValue: flashcards)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                (colorScheme == .dark
                    ? Color.matchabackground_dark
                    : Color.matchabackground_light)
                    .brightness(colorScheme == .dark ? -0.05 : 0.05)
                    .ignoresSafeArea()

                if editedFlashcards.isEmpty && !isGenerating {
                    emptyState
                } else {
                    flashcardsList
                }
            }
            .navigationTitle("Edit Flashcards")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(colorScheme == .dark ? .matchabrown_dark : .matchabrown_light)
                    .fontWeight(.semibold)
                }

                ToolbarItem(placement: .bottomBar) {
                    HStack(spacing: 12) {
                        // Add Manually button
                        Button(action: addManualFlashcard) {
                            Label("Add Manually", systemImage: "plus.circle")
                                .font(.jost(.subheadline()))
                        }
                        .buttonStyle(.bordered)
                        .disabled(isGenerating)

                        Spacer()

                        // Generate More button
                        Button(action: generateMore) {
                            if isGenerating {
                                ProgressView()
                                    .controlSize(.small)
                            } else {
                                Label("Generate More", systemImage: "sparkles")
                                    .font(.jost(.subheadline()))
                            }
                        }
                        .buttonStyle(.bordered)
                        .tint(.green)
                        .disabled(isGenerating)

                        // Regenerate All button
                        Button(action: { showingRegenerateAlert = true }) {
                            Label("Regenerate All", systemImage: "arrow.clockwise")
                                .font(.jost(.subheadline()))
                        }
                        .buttonStyle(.bordered)
                        .tint(.orange)
                        .disabled(isGenerating)
                    }
                }
            }
            .alert("Regenerate All Flashcards?", isPresented: $showingRegenerateAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Regenerate", role: .destructive) {
                    regenerateAll()
                }
            } message: {
                Text("This will delete all current flashcards and generate new ones. This action cannot be undone.")
            }
        }
    }

    // MARK: - Empty State
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "rectangle.stack")
                .font(.system(size: 48))
                .foregroundColor(.secondary)

            Text("No Flashcards Yet")
                .font(.jost(.title3()))
                .fontWeight(.semibold)

            Text("Add flashcards manually or generate them with AI")
                .font(.jost(.subheadline()))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }

    // MARK: - Flashcards List
    private var flashcardsList: some View {
        ScrollViewReader { proxy in
            List {
                ForEach(Array(editedFlashcards.enumerated()), id: \.element.id) { index, flashcard in
                    FlashcardEditRow(
                        flashcard: binding(for: flashcard),
                        isExpanded: Binding(
                            get: { expandedFlashcardId == flashcard.id },
                            set: { isExpanded in
                                expandedFlashcardId = isExpanded ? flashcard.id : nil
                            }
                        ),
                        onDelete: { deleteFlashcard(at: index) },
                        onChange: { saveChanges() }
                    )
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                    .id(flashcard.id)
                }
                .onMove { from, to in
                    editedFlashcards.move(fromOffsets: from, toOffset: to)
                    saveChanges()
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .onChange(of: expandedFlashcardId) { _, newId in
                if let newId = newId {
                    proxy.scrollTo(newId, anchor: .center)
                }
            }
        }
    }

    // MARK: - Actions
    private func binding(for flashcard: Flashcard) -> Binding<Flashcard> {
        guard let index = editedFlashcards.firstIndex(where: { $0.id == flashcard.id }) else {
            fatalError("Flashcard not found")
        }
        return $editedFlashcards[index]
    }

    private func addManualFlashcard() {
        let newFlashcard = Flashcard(front: "", back: "")
        editedFlashcards.append(newFlashcard)
        expandedFlashcardId = newFlashcard.id
        saveChanges()
    }

    private func deleteFlashcard(at index: Int) {
        editedFlashcards.remove(at: index)
        saveChanges()
    }

    private func generateMore() {
        guard let note = state.currentNote else { return }

        isGenerating = true
        Task {
            do {
                // Temporarily store current flashcards
                let currentFlashcards = editedFlashcards

                // Generate new flashcards (5 at a time)
                try await state.generateFlashcards(note: note, storageManager: storageManager, count: 5)

                // Append new flashcards to current list
                if let session = state.studySession {
                    let newFlashcards = session.flashcards.filter { newF in
                        !currentFlashcards.contains(where: { $0.id == newF.id })
                    }
                    await MainActor.run {
                        editedFlashcards = currentFlashcards + newFlashcards
                        isGenerating = false
                        saveChanges()
                    }
                }
            } catch {
                print("Failed to generate more flashcards: \(error)")
                await MainActor.run {
                    isGenerating = false
                }
            }
        }
    }

    private func regenerateAll() {
        guard let note = state.currentNote else { return }

        isGenerating = true
        editedFlashcards.removeAll()

        Task {
            do {
                try await state.generateFlashcards(note: note, storageManager: storageManager, count: 15, regenerate: true)

                if let session = state.studySession {
                    await MainActor.run {
                        editedFlashcards = session.flashcards
                        isGenerating = false
                        saveChanges()
                    }
                }
            } catch {
                print("Failed to regenerate flashcards: \(error)")
                await MainActor.run {
                    isGenerating = false
                }
            }
        }
    }

    private func saveChanges() {
        // Validate flashcards
        let validFlashcards = editedFlashcards.filter { flashcard in
            !flashcard.front.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            !flashcard.back.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }

        // Update session
        if var session = state.studySession {
            session.flashcards = validFlashcards
            state.studySession = session
            state.studyStorage.saveSession(session)
        }
    }
}

// MARK: - Flashcard Edit Row
struct FlashcardEditRow: View {
    @Binding var flashcard: Flashcard
    @Binding var isExpanded: Bool
    let onDelete: () -> Void
    let onChange: () -> Void
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if !isExpanded {
                // Collapsed state - just show preview
                HStack(alignment: .top, spacing: 12) {
                    Text(flashcard.front.isEmpty ? "Empty term" : flashcard.front)
                        .font(.jost(.body()))
                        .fontWeight(.medium)
                        .foregroundColor(flashcard.front.isEmpty ? .secondary : .primary)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Button(action: onDelete) {
                        Image(systemName: "trash")
                            .foregroundColor(.red)
                            .font(.system(size: 16))
                    }
                    .buttonStyle(.plain)
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    isExpanded.toggle()
                }
            } else {
                // Expanded state - show editors
                VStack(alignment: .leading, spacing: 12) {
                    // Header with delete button
                    HStack {
                        Spacer()
                        Button(action: onDelete) {
                            Image(systemName: "trash")
                                .foregroundColor(.red)
                                .font(.system(size: 16))
                        }
                        .buttonStyle(.plain)
                    }

                    // Term text field
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Term")
                            .font(.jost(.caption()))
                            .foregroundColor(.secondary)

                        TextField("Enter term", text: Binding(
                            get: { flashcard.front },
                            set: { flashcard.front = $0; onChange() }
                        ), axis: .vertical)
                        .font(.jost(.body()))
                        .textFieldStyle(.plain)
                        .padding(8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(colorScheme == .dark ? Color(white: 0.15) : Color.white)
                        )
                    }

                    // Definition text field
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Definition")
                            .font(.jost(.caption()))
                            .foregroundColor(.secondary)

                        TextField("Enter definition", text: Binding(
                            get: { flashcard.back },
                            set: { flashcard.back = $0; onChange() }
                        ), axis: .vertical)
                        .font(.jost(.body()))
                        .textFieldStyle(.plain)
                        .padding(8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(colorScheme == .dark ? Color(white: 0.15) : Color.white)
                        )
                    }

                    // Tap to collapse
                    HStack {
                        Spacer()
                        Image(systemName: "chevron.up")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                    .padding(.vertical, 8)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        isExpanded.toggle()
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(
                    colorScheme == .dark
                        ? LinearGradient(
                            colors: [
                                Color(red: 0.14, green: 0.14, blue: 0.16).opacity(0.85),
                                Color(red: 0.13, green: 0.13, blue: 0.15).opacity(0.85)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        : LinearGradient(
                            colors: [
                                Color.white.opacity(0.98),
                                Color(red: 0.99, green: 0.99, blue: 1.0).opacity(0.95)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(
                    LinearGradient(
                        colors: colorScheme == .dark
                            ? [Color.white.opacity(0.08), Color.white.opacity(0.04)]
                            : [Color.white.opacity(0.8), Color.gray.opacity(0.12)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.25 : 0.06), radius: 10, x: 0, y: 3)
        .padding(.horizontal, 16)
    }
}
