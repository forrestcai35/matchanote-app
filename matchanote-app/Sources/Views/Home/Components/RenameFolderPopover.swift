import SwiftUI

/// Reusable popover view for renaming folders
/// Automatically saves when dismissed if the name has changed
struct RenameFolderPopover: View {
  let originalName: String
  let onSave: (String) -> Void
  @Binding var isPresented: Bool
  @State private var editedName: String
  @Environment(\.colorScheme) private var colorScheme

  init(
    originalName: String,
    isPresented: Binding<Bool>,
    onSave: @escaping (String) -> Void
  ) {
    self.originalName = originalName
    self._isPresented = isPresented
    self.onSave = onSave
    self._editedName = State(initialValue: originalName)
  }

  var body: some View {
    VStack(spacing: 12) {
      Text("Rename Folder")
        .font(.jost(.headline()))

      ClearableTextField(placeholder: "Folder name", text: $editedName)
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
        .disabled(editedName.isEmpty)
      }
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 12)
    .frame(minWidth: 240)
    .onChange(of: isPresented) { _, newValue in
      // Auto-save when popover is dismissed
      if !newValue && !editedName.isEmpty && editedName != originalName {
        onSave(editedName)
      }
    }
  }

  private func saveAndDismiss() {
    guard !editedName.isEmpty else { return }
    onSave(editedName)
    isPresented = false
  }
}
