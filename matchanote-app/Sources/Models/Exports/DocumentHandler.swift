//
//  DocumentHandler.swift
//  matchanote-app
//
//  Created by Forrest Cai on 4/2/25.
//

import Foundation
import SwiftUI
import UniformTypeIdentifiers

class DocumentHandler: ObservableObject {
    static let shared = DocumentHandler()
    
    @Published var pendingDocumentURL: URL?
    @Published var shouldProcessDocument = false
    
    private init() {}
    
    func handleDocumentURL(_ url: URL) {
        print("DocumentHandler: Received document URL: \(url)")
        
        // Store the URL for processing
        pendingDocumentURL = url
        shouldProcessDocument = true
    }
    
    func processDocument() {
        guard let url = pendingDocumentURL else { return }
        
        // Determine file type and handle accordingly
        let fileExtension = url.pathExtension.lowercased()
        print("DocumentHandler: Processing file with extension: \(fileExtension)")
        
        switch fileExtension {
        case "pdf":
            handlePDFDocument(url)
        case "jpg", "jpeg", "png", "heic", "heif", "gif", "bmp", "tiff":
            handleImageDocument(url)
        case "matcha":
            handleMatchaDocument(url)
        default:
            print("DocumentHandler: Unsupported file type: \(fileExtension)")
        }
        
        // Clear the pending document
        pendingDocumentURL = nil
        shouldProcessDocument = false
    }
    
    private func handlePDFDocument(_ url: URL) {
        print("DocumentHandler: Processing PDF document")
        // The existing PDF import logic from HomeView can be reused here
        NotificationCenter.default.post(
            name: .documentImported,
            object: nil,
            userInfo: ["url": url, "type": "pdf"]
        )
    }
    
    private func handleImageDocument(_ url: URL) {
        print("DocumentHandler: Processing image document")
        // The existing image import logic from HomeView can be reused here
        NotificationCenter.default.post(
            name: .documentImported,
            object: nil,
            userInfo: ["url": url, "type": "image"]
        )
    }
    
    private func handleMatchaDocument(_ url: URL) {
        print("DocumentHandler: Processing Matcha document")
        // Handle native Matcha note files
        NotificationCenter.default.post(
            name: .documentImported,
            object: nil,
            userInfo: ["url": url, "type": "matcha"]
        )
    }
}

// MARK: - Notification Names
extension Notification.Name {
    static let documentImported = Notification.Name("documentImported")
}
