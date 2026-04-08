import SwiftUI
import PDFKit

struct ImportPreviewView: View {
    let pendingImport: PendingImport
    @EnvironmentObject var storageManager: StorageManager
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme

    @State private var isImporting = false
    @State private var previewImage: UIImage?

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Preview
                previewSection
                    .frame(maxHeight: 300)

                Divider()

                // File info
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: fileIcon)
                            .font(.system(size: 24))
                            .foregroundColor(.secondary)
                        Text(pendingImport.fileName)
                            .font(.jost(.body()))
                        Spacer()
                    }
                    .padding()
                }

                Spacer()

                Divider()

                // Action buttons
                HStack(spacing: 12) {
                    Button("Cancel") {
                        DocumentHandler.shared.clearPendingImport()
                        dismiss()
                    }
                    .buttonStyle(.bordered)
                    .disabled(isImporting)

                    Button {
                        performImport()
                    } label: {
                        if isImporting {
                            ProgressView()
                        } else {
                            Text("Import")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isImporting)
                }
                .padding()
            }
            .navigationTitle("Import File")
            .navigationBarTitleDisplayMode(.inline)
        }
        .onAppear {
            loadPreview()
        }
    }

    private var previewSection: some View {
        ZStack {
            if let image = previewImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
            } else {
                VStack(spacing: 12) {
                    Image(systemName: fileIcon)
                        .font(.system(size: 60))
                        .foregroundColor(.secondary)
                    Text(pendingImport.fileName)
                        .font(.jost(.caption()))
                        .foregroundColor(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.gray.opacity(0.1))
    }

    private var fileIcon: String {
        switch pendingImport.type {
        case "pdf": return "doc.fill"
        case "image": return "photo.fill"
        case "matcha": return "note.text"
        default: return "doc"
        }
    }

    private func loadPreview() {
        switch pendingImport.type {
        case "pdf":
            if let pdfDoc = PDFDocument(data: pendingImport.fileData),
               let page = pdfDoc.page(at: 0) {
                let pageRect = page.bounds(for: .mediaBox)
                let renderer = UIGraphicsImageRenderer(size: pageRect.size)
                previewImage = renderer.image { ctx in
                    UIColor.white.set()
                    ctx.fill(pageRect)
                    ctx.cgContext.translateBy(x: 0, y: pageRect.size.height)
                    ctx.cgContext.scaleBy(x: 1.0, y: -1.0)
                    page.draw(with: .mediaBox, to: ctx.cgContext)
                }
            }
        case "image":
            previewImage = UIImage(data: pendingImport.fileData)
        default:
            break
        }
    }

    private func performImport() {
        isImporting = true

        // Save file data to temp location
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(pendingImport.fileName)

        do {
            try pendingImport.fileData.write(to: tempURL)

            ImportManager.shared.handleDocumentImport(
                url: tempURL,
                type: pendingImport.type,
                storageManager: storageManager,
                currentFolderID: pendingImport.currentFolderID,
                selectedSubject: pendingImport.selectedSubject
            ) { note in
                DispatchQueue.main.async {
                    isImporting = false

                    if let note = note {
                        print("ImportPreviewView: Successfully imported")
                        // Set the imported note to trigger navigation in HomeView
                        DocumentHandler.shared.importedNote = note
                    }

                    // Dismiss sheet and cleanup after setting the imported note
                    DocumentHandler.shared.clearPendingImport()
                    dismiss()

                    // Clean up temp file
                    try? FileManager.default.removeItem(at: tempURL)
                }
            }
        } catch {
            print("ImportPreviewView: Error writing temp file: \(error)")
            isImporting = false
        }
    }
}
