import SwiftUI

/// Reusable popover view for renaming notes
/// Automatically saves when dismissed if the title has changed
struct RenameNotePopover: View {
  let originalTitle: String
  let onSave: (String) -> Void
  @Binding var isPresented: Bool
  @State private var editedTitle: String
  @Environment(\.colorScheme) private var colorScheme

  init(
    originalTitle: String,
    isPresented: Binding<Bool>,
    onSave: @escaping (String) -> Void
  ) {
    self.originalTitle = originalTitle
    self._isPresented = isPresented
    self.onSave = onSave
    self._editedTitle = State(initialValue: originalTitle)
  }

  var body: some View {
    VStack(spacing: 12) {
      Text("Rename Note")
        .font(.jost(.headline()))

      ClearableTextField(placeholder: "Note name", text: $editedTitle)
        .frame(width: 200)

      HStack {
        Button("Cancel") {
          isPresented = false
        }
        .font(.jost(.body()))
        .foregroundColor(.red)

        Spacer()

        Button("Save") {
          saveAndDismiss()
        }
        .font(.jost(.body()))
        .foregroundColor(.blue)
        .disabled(editedTitle.isEmpty)
      }
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 12)
    .frame(minWidth: 240)
    .onChange(of: isPresented) { _, newValue in
      // Auto-save when popover is dismissed
      if !newValue && !editedTitle.isEmpty && editedTitle != originalTitle {
        onSave(editedTitle)
      }
    }
  }

  private func saveAndDismiss() {
    guard !editedTitle.isEmpty else { return }
    onSave(editedTitle)
    isPresented = false
  }
}
