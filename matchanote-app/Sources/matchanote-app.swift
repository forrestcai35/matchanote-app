
import SwiftUI

@main
struct matchanote_App: App {
    @StateObject private var authManager = LocalAuthManager.shared
    @StateObject private var storageManager = StorageManager()
    @StateObject private var preferencesManager = PreferencesManager.shared
    @StateObject private var documentHandler = DocumentHandler.shared

    var body: some Scene {
        WindowGroup {
            AuthView()
                .environmentObject(authManager)
                .environmentObject(storageManager)
                .environmentObject(preferencesManager)
                .environmentObject(documentHandler)
                .preferredColorScheme(colorSchemeForTheme(preferencesManager.theme))
                .onOpenURL { url in
                    handleOpenURL(url)
                }
        }
    }
    
    private func handleOpenURL(_ url: URL) {
        print("App: Received URL: \(url)")

        // Check if it's the import URL scheme from the action extension
        if url.scheme == "matchanote", url.host == "import" {
            handleImportURL(url)
            return
        }

        // Check if it's a document URL
        if url.startAccessingSecurityScopedResource() {
            documentHandler.handleDocumentURL(url)
            url.stopAccessingSecurityScopedResource()
        } else {
            // Handle other URL schemes (like auth callbacks)
            if url.scheme == "matchanote" {
                // Handle auth callback or other app-specific URLs
                print("App: Handling app-specific URL: \(url)")
            }
        }
    }

    private func handleImportURL(_ url: URL) {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let queryItems = components.queryItems,
              let fileNameItem = queryItems.first(where: { $0.name == "filename" }),
              let encodedFileName = fileNameItem.value,
              let fileName = encodedFileName.removingPercentEncoding,
              let dataItem = queryItems.first(where: { $0.name == "data" }),
              let encodedData = dataItem.value,
              let base64String = encodedData.removingPercentEncoding,
              let fileData = Data(base64Encoded: base64String) else {
            print("App: Could not parse import URL or decode file data")
            return
        }

        print("App: Importing file from action extension: \(fileName) (\(fileData.count) bytes)")

        // Handle the document import with pre-read data
        documentHandler.handleDocumentData(fileData, fileName: fileName)
    }

    private func colorSchemeForTheme(_ theme: AppTheme) -> ColorScheme? {
        switch theme {
        case .light:
            return .light
        case .dark:
            return .dark
        case .system:
            return nil // Uses system setting
        }
    }
}
