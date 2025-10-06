//
//  CanvasImage.swift
//  MatchaNotes
//
//  Image management for PencilKit canvas overlays
//

import SwiftUI
import UIKit
import PencilKit

// MARK: - Canvas Image Model
public struct CanvasImage: Identifiable, Codable {
    public var id: UUID
    public var imageData: Data
    public var position: CGPoint
    public var size: CGSize
    public var rotation: Double = 0.0
    public var zIndex: Int = 0
    public var pageIndex: Int
    
    public init(imageData: Data, position: CGPoint, size: CGSize, pageIndex: Int) {
        self.id = UUID()
        self.imageData = imageData
        self.position = position
        self.size = size
        self.pageIndex = pageIndex
    }
    
    // MARK: - Computed Properties
    public var frame: CGRect {
        CGRect(origin: position, size: size)
    }
    
    public var centerPoint: CGPoint {
        CGPoint(
            x: position.x + size.width / 2,
            y: position.y + size.height / 2
        )
    }
    
    // MARK: - Helper Methods
    public func contains(point: CGPoint) -> Bool {
        frame.contains(point)
    }
    
    public mutating func move(by offset: CGPoint) {
        position.x += offset.x
        position.y += offset.y
    }
    
    public mutating func resize(to newSize: CGSize) {
        size = newSize
    }
    
    public mutating func updatePosition(to newPosition: CGPoint) {
        position = newPosition
    }
    
    public mutating func updateCenter(to centerPoint: CGPoint) {
        position = CGPoint(
            x: centerPoint.x - size.width / 2,
            y: centerPoint.y - size.height / 2
        )
    }
}

// MARK: - Canvas Image Manager
public class CanvasImageManager: ObservableObject {
    @Published public var imagesByPage: [Int: [CanvasImage]] = [:]
    @Published public var selectedImageId: UUID?
    
    // Undo manager reference for integrating with PencilKit undo system
    public weak var undoManager: UndoManager?
    
    public init() {}
    
    // MARK: - Undo Manager Setup
    public func setUndoManager(_ undoManager: UndoManager?) {
        self.undoManager = undoManager
    }
    
    // MARK: - Image Management
    public func addImage(_ image: CanvasImage) {
        // Register undo action before adding
        undoManager?.registerUndo(withTarget: self) { manager in
            manager.removeImage(withId: image.id, fromPage: image.pageIndex)
        }
        undoManager?.setActionName("Add Image")
        
        if imagesByPage[image.pageIndex] == nil {
            imagesByPage[image.pageIndex] = []
        }
        imagesByPage[image.pageIndex]?.append(image)
    }
    
    public func removeImage(withId id: UUID, fromPage pageIndex: Int) {
        // Find the image before removing it for undo registration
        guard let images = imagesByPage[pageIndex],
              let imageToRemove = images.first(where: { $0.id == id }) else { return }
        
        // Register undo action before removing
        undoManager?.registerUndo(withTarget: self) { manager in
            manager.addImage(imageToRemove)
            if manager.selectedImageId == nil {
                manager.selectedImageId = id
            }
        }
        undoManager?.setActionName("Delete Image")
        
        imagesByPage[pageIndex]?.removeAll { $0.id == id }
        if selectedImageId == id {
            selectedImageId = nil
        }
    }
    
    public func updateImage(_ updatedImage: CanvasImage) {
        guard var images = imagesByPage[updatedImage.pageIndex] else { return }
        
        if let index = images.firstIndex(where: { $0.id == updatedImage.id }) {
            let previousImage = images[index]
            
            // Skip update if position hasn't changed (performance optimization)
            guard previousImage.position != updatedImage.position else { return }
            
            // Register undo action before updating
            undoManager?.registerUndo(withTarget: self) { manager in
                manager.updateImage(previousImage)
            }
            undoManager?.setActionName("Move/Resize Image")
            
            images[index] = updatedImage
            imagesByPage[updatedImage.pageIndex] = images
        }
    }
    
    public func getImagesForPage(_ pageIndex: Int) -> [CanvasImage] {
        return imagesByPage[pageIndex] ?? []
    }
    
    public func getImage(withId id: UUID, onPage pageIndex: Int) -> CanvasImage? {
        return imagesByPage[pageIndex]?.first { $0.id == id }
    }
    
    // MARK: - Selection Management
    public func selectImage(withId id: UUID?) {
        selectedImageId = id
    }
    
    public func deselectImage() {
        selectedImageId = nil
    }
    
    public var hasSelectedImage: Bool {
        selectedImageId != nil
    }
    
    // MARK: - Hit Testing
    public func imageAt(point: CGPoint, onPage pageIndex: Int) -> CanvasImage? {
        let images = getImagesForPage(pageIndex)
        // Return the topmost image (highest zIndex) that contains the point
        return images
            .filter { $0.contains(point: point) }
            .max { $0.zIndex < $1.zIndex }
    }
    
    // MARK: - Data Conversion for Persistence
    public func getAllImagesData() -> [String: [Data]] {
        var result: [String: [Data]] = [:]
        
        for (pageIndex, images) in imagesByPage {
            let imageDataArray = images.compactMap { image -> Data? in
                do {
                    return try JSONEncoder().encode(image)
                } catch {
                    print("Failed to encode image: \(error)")
                    return nil
                }
            }
            
            if !imageDataArray.isEmpty {
                result[String(pageIndex)] = imageDataArray
            }
        }
        
        return result
    }
    
    public func loadImagesData(_ data: [String: [Data]]) {
        imagesByPage.removeAll()
        
        for (pageIndexString, imageDataArray) in data {
            guard let pageIndex = Int(pageIndexString) else { continue }
            
            let images = imageDataArray.compactMap { imageData -> CanvasImage? in
                do {
                    return try JSONDecoder().decode(CanvasImage.self, from: imageData)
                } catch {
                    print("Failed to decode image: \(error)")
                    return nil
                }
            }
            
            if !images.isEmpty {
                imagesByPage[pageIndex] = images
            }
        }
    }
    
    // MARK: - Utility Methods
    public func moveSelectedImageToFront(onPage pageIndex: Int) {
        guard let selectedId = selectedImageId,
              var images = imagesByPage[pageIndex],
              let imageIndex = images.firstIndex(where: { $0.id == selectedId }) else { return }
        
        let previousImage = images[imageIndex]
        let maxZIndex = images.map { $0.zIndex }.max() ?? 0
        
        // Register undo action before changing z-index
        undoManager?.registerUndo(withTarget: self) { manager in
            manager.updateImage(previousImage)
        }
        undoManager?.setActionName("Bring to Front")
        
        images[imageIndex].zIndex = maxZIndex + 1
        imagesByPage[pageIndex] = images
    }
    
    public func moveSelectedImageToBack(onPage pageIndex: Int) {
        guard let selectedId = selectedImageId,
              var images = imagesByPage[pageIndex],
              let imageIndex = images.firstIndex(where: { $0.id == selectedId }) else { return }
        
        let previousImage = images[imageIndex]
        let minZIndex = images.map { $0.zIndex }.min() ?? 0
        
        // Register undo action before changing z-index
        undoManager?.registerUndo(withTarget: self) { manager in
            manager.updateImage(previousImage)
        }
        undoManager?.setActionName("Send to Back")
        
        images[imageIndex].zIndex = minZIndex - 1
        imagesByPage[pageIndex] = images
    }
    
    public func clearAllImagesFromPage(_ pageIndex: Int) {
        guard let images = imagesByPage[pageIndex], !images.isEmpty else { return }
        
        // Register undo action before clearing
        undoManager?.registerUndo(withTarget: self) { manager in
            for image in images {
                manager.addImage(image)
            }
        }
        undoManager?.setActionName("Clear All Images")
        
        // Clear all images from the page
        imagesByPage[pageIndex] = []
        
        // Clear selection if the selected image was on this page
        if let selectedId = selectedImageId,
           images.contains(where: { $0.id == selectedId }) {
            selectedImageId = nil
        }
    }
}

// MARK: - Image Utilities
public struct ImageUtilities {
    
    // Convert UIImage to Data for storage
    public static func imageToData(_ image: UIImage, compressionQuality: CGFloat = 0.8) -> Data? {
        return image.jpegData(compressionQuality: compressionQuality)
    }
    
    // Convert Data back to UIImage
    public static func dataToImage(_ data: Data) -> UIImage? {
        return UIImage(data: data)
    }
    
    // Resize image while maintaining aspect ratio
    public static func resizeImage(_ image: UIImage, to targetSize: CGSize) -> UIImage? {
        let aspectRatio = image.size.width / image.size.height
        let targetAspectRatio = targetSize.width / targetSize.height
        
        var scaledSize: CGSize
        
        if aspectRatio > targetAspectRatio {
            // Image is wider than target
            scaledSize = CGSize(width: targetSize.width, height: targetSize.width / aspectRatio)
        } else {
            // Image is taller than target
            scaledSize = CGSize(width: targetSize.height * aspectRatio, height: targetSize.height)
        }
        
        UIGraphicsBeginImageContextWithOptions(scaledSize, false, image.scale)
        image.draw(in: CGRect(origin: .zero, size: scaledSize))
        let scaledImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return scaledImage
    }
    
    // Calculate appropriate initial size for image on canvas
    public static func calculateInitialSize(for image: UIImage, maxWidth: CGFloat = 300, maxHeight: CGFloat = 300) -> CGSize {
        let aspectRatio = image.size.width / image.size.height
        
        if image.size.width > maxWidth || image.size.height > maxHeight {
            if aspectRatio > 1 {
                // Landscape
                return CGSize(width: maxWidth, height: maxWidth / aspectRatio)
            } else {
                // Portrait
                return CGSize(width: maxHeight * aspectRatio, height: maxHeight)
            }
        } else {
            // Image is smaller than max constraints, use original size
            return image.size
        }
    }
}
