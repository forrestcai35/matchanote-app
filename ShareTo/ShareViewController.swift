//
//  ShareViewController.swift
//  ShareTo
//
//  Created by Forrest Cai on 11/17/25.
//

import UIKit
import MobileCoreServices
import UniformTypeIdentifiers

class ShareViewController: UIViewController {

    @IBOutlet weak var imageView: UIImageView!

    private var activityIndicator: UIActivityIndicatorView!
    private var statusLabel: UILabel!

    override func viewDidLoad() {
        super.viewDidLoad()

        print("ShareViewController: viewDidLoad called")
        setupUI()
        handleImportedFile()
    }

    private func setupUI() {
        // Set background color so we can see the view
        view.backgroundColor = .systemBackground

        // Add activity indicator
        activityIndicator = UIActivityIndicatorView(style: .large)
        activityIndicator.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(activityIndicator)

        // Add status label
        statusLabel = UILabel()
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.textAlignment = .center
        statusLabel.numberOfLines = 0
        statusLabel.font = .systemFont(ofSize: 17, weight: .medium)
        statusLabel.text = "Importing to Matcha..."
        view.addSubview(statusLabel)

        NSLayoutConstraint.activate([
            activityIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            activityIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -20),

            statusLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            statusLabel.topAnchor.constraint(equalTo: activityIndicator.bottomAnchor, constant: 20),
            statusLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            statusLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20)
        ])

        activityIndicator.startAnimating()
    }

    private func handleImportedFile() {
        print("ShareViewController: handleImportedFile called")

        guard let extensionContext = extensionContext,
              let inputItems = extensionContext.inputItems as? [NSExtensionItem] else {
            print("ShareViewController: No extension context or input items")
            showError("No files found to import")
            return
        }

        print("ShareViewController: Found \(inputItems.count) input items")

        // Process the first file found
        for item in inputItems {
            guard let attachments = item.attachments else { continue }

            print("ShareViewController: Processing item with \(attachments.count) attachments")

            for provider in attachments {
                // Debug: Print all registered type identifiers
                print("ShareViewController: Provider registered type identifiers: \(provider.registeredTypeIdentifiers)")

                // Check for supported file types
                if provider.hasItemConformingToTypeIdentifier(UTType.pdf.identifier) {
                    print("ShareViewController: Found PDF file")
                    processFile(provider: provider, typeIdentifier: UTType.pdf.identifier)
                    return
                } else if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
                    print("ShareViewController: Found image file")
                    processFile(provider: provider, typeIdentifier: UTType.image.identifier)
                    return
                } else if provider.hasItemConformingToTypeIdentifier(UTType.data.identifier) {
                    print("ShareViewController: Found data file (possibly .matcha)")
                    // Check if it's a .matcha file by checking the URL
                    processFile(provider: provider, typeIdentifier: UTType.data.identifier)
                    return
                }

                print("ShareViewController: Provider doesn't match any supported types")
            }
        }

        print("ShareViewController: No supported files found")
        showError("No supported files found. MatchaNote supports PDFs, images, and .matcha files.")
    }

    private func processFile(provider: NSItemProvider, typeIdentifier: String) {
        provider.loadItem(forTypeIdentifier: typeIdentifier, options: nil) { [weak self] (item, error) in
            guard let self = self else { return }

            if let error = error {
                DispatchQueue.main.async {
                    self.showError("Error loading file: \(error.localizedDescription)")
                }
                return
            }

            var fileURL: URL?

            // Handle different item types
            if let url = item as? URL {
                fileURL = url
            } else if let data = item as? Data {
                // Save data to temporary file
                fileURL = self.saveDataToTempFile(data: data)
            }

            guard let url = fileURL else {
                DispatchQueue.main.async {
                    self.showError("Could not access file")
                }
                return
            }

            // Read file and pass to main app
            self.readFileAndOpenApp(sourceURL: url)
        }
    }

    private func saveDataToTempFile(data: Data) -> URL? {
        let tempDir = FileManager.default.temporaryDirectory
        let fileName = "import_\(UUID().uuidString)"
        let tempURL = tempDir.appendingPathComponent(fileName)

        do {
            try data.write(to: tempURL)
            return tempURL
        } catch {
            print("Error saving data to temp file: \(error)")
            return nil
        }
    }

    private func readFileAndOpenApp(sourceURL: URL) {
        do {
            // Access security scoped resource if needed
            let accessGranted = sourceURL.startAccessingSecurityScopedResource()
            defer {
                if accessGranted {
                    sourceURL.stopAccessingSecurityScopedResource()
                }
            }

            // Read the file data
            let fileData = try Data(contentsOf: sourceURL)
            let fileName = sourceURL.lastPathComponent

            // Open the main app with the file data
            DispatchQueue.main.async {
                self.openMainApp(fileName: fileName, fileData: fileData)
            }
        } catch {
            DispatchQueue.main.async {
                self.showError("Error reading file: \(error.localizedDescription)")
            }
        }
    }

    private func openMainApp(fileName: String, fileData: Data) {
        print("ShareViewController: openMainApp called with file: \(fileName), size: \(fileData.count) bytes")

        // Encode file data as base64
        let base64Data = fileData.base64EncodedString()
        print("ShareViewController: Encoded to base64, length: \(base64Data.count)")

        // Encode parameters for URL scheme
        guard let encodedFileName = fileName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let encodedData = base64Data.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            print("ShareViewController: Failed to encode file data for URL")
            showError("Could not encode file data")
            return
        }

        // Create URL scheme to open main app with file data
        let urlString = "matchanote://import?filename=\(encodedFileName)&data=\(encodedData)"
        print("ShareViewController: Creating URL scheme (truncated): matchanote://import?filename=\(encodedFileName)&data=...")

        guard let appURL = URL(string: urlString) else {
            print("ShareViewController: Failed to create URL from string")
            showError("Could not create app URL")
            return
        }

        print("ShareViewController: URL created successfully, attempting to open")

        // Try to open the main app
        var responder: UIResponder? = self
        while responder != nil {
            if let application = responder as? UIApplication {
                print("ShareViewController: Found UIApplication, attempting to open URL")
                application.open(appURL, options: [:]) { [weak self] success in
                    DispatchQueue.main.async {
                        print("ShareViewController: UIApplication.open result: \(success)")
                        if success {
                            self?.completeRequest()
                        } else {
                            self?.showError("Could not open MatchaNote app")
                        }
                    }
                }
                return
            }
            responder = responder?.next
        }

        // Fallback: use the extension context to open URL
        print("ShareViewController: UIApplication not found, using extensionContext.open")
        self.extensionContext?.open(appURL, completionHandler: { [weak self] success in
            DispatchQueue.main.async {
                print("ShareViewController: extensionContext.open result: \(success)")
                if success {
                    self?.completeRequest()
                } else {
                    self?.showError("Could not open Matcha app. Please make sure the app is installed.")
                }
            }
        })
    }

    private func showError(_ message: String) {
        activityIndicator.stopAnimating()
        statusLabel.text = message
        statusLabel.textColor = .systemRed

        // Auto-dismiss after 3 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
            self?.cancelRequest()
        }
    }

    private func completeRequest() {
        extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
    }

    private func cancelRequest() {
        extensionContext?.cancelRequest(withError: NSError(domain: "com.matchanote.shareto", code: -1))
    }

    @IBAction func done() {
        completeRequest()
    }

}
